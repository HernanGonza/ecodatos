import React, { useEffect, useState, forwardRef, useImperativeHandle, useMemo, useRef, useCallback } from "react";
import {
  Box, Badge, Text, Center, LoadingOverlay, Checkbox, Group,
  Button, Transition, ActionIcon, Tooltip, Modal, Stack,
  TextInput, Select, Alert, Paper
} from '@mantine/core';
import {
  IconEye, IconEdit, IconTrash, IconX, IconAlertTriangle,
  IconSearch, IconSelector, IconChevronUp, IconChevronDown,
  IconUserPlus, IconClock, IconPencil, IconInfoCircle
} from '@tabler/icons-react';
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  flexRender,
} from '@tanstack/react-table';
import { useVirtualizer } from '@tanstack/react-virtual';
import { notifications } from '@mantine/notifications';
import { supabase } from "../lib/supabase";
import classes from './TablaDinamica.module.css';

const ROW_HEIGHT = 48;

const MemoizedCell = ({ value, columnKey, isUserTable }) => {
  const val = value;

  if (isUserTable && (columnKey === "areas" || columnKey === "formularios") && Array.isArray(val)) {
    if (val.length === 0) return <Text size="xs" c="dimmed">Ninguno</Text>;
    return (
      <Group gap={4} wrap="wrap">
        {val.map((item, idx) => (
          <Tooltip key={idx} label={item.es_editor ? "Editor" : "Lector"} withArrow>
            <Badge variant="light" color={item.es_editor ? "cyan" : "blue"} size="xs" radius="xs"
              leftSection={item.es_editor ? <IconPencil size={10} /> : <IconEye size={10} />}>
              {item.id.split('-')[0]}
            </Badge>
          </Tooltip>
        ))}
      </Group>
    );
  }

  if ((columnKey === 'updated_at' || columnKey === 'created_at') && val) {
    return (
      <Group gap={4} wrap="nowrap">
        <IconClock size={11} color="var(--mantine-color-gray-5)" />
        <Text size="xs" c="dimmed">{new Date(val).toLocaleString()}</Text>
      </Group>
    );
  }

  const strVal = String(val ?? "");
  return (
    <Tooltip label={strVal} disabled={strVal.length < 30} multiline w={220} withArrow>
      <Text size="xs" fw={500} className={classes.cellText}>{strVal || "—"}</Text>
    </Tooltip>
  );
};

const MemoizedCellWrapper = React.memo(MemoizedCell, (prev, next) =>
  prev.value === next.value && prev.columnKey === next.columnKey
);

const TablaDinamica = forwardRef(({ formulario, onEdit, onView }, ref) => {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [sorting, setSorting] = useState([]);
  const [globalFilter, setGlobalFilter] = useState('');
  const [rowSelection, setRowSelection] = useState({});
  const [esEditorDelForm, setEsEditorDelForm] = useState(true);
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [idsToDelete, setIdsToDelete] = useState([]);
  const [bulkReassignOpen, setBulkReassignOpen] = useState(false);
  const [tecnicos, setTecnicos] = useState([]);
  const [selectedTecnico, setSelectedTecnico] = useState(null);
  const [isUpdating, setIsUpdating] = useState(false);
  const [columnSizing, setColumnSizing] = useState({});

  const scrollRef = useRef(null);
  const isOrphanMode = formulario?.isOrphanMode;

  useImperativeHandle(ref, () => ({ refresh: () => fetchData() }));

  const fetchData = async () => {
    if (!formulario?.slug) return;
    setLoading(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) return;

      if (formulario.slug !== "users") {
        const { data: permiso } = await supabase
          .from('usuarios_formularios').select('es_editor')
          .eq('user_id', session.user.id).eq('formulario_id', formulario.id).maybeSingle();
        setEsEditorDelForm(permiso ? permiso.es_editor : true);
      } else {
        setEsEditorDelForm(true);
      }

      let endpoint = formulario.slug === "users" ? "users-list" : `universal-list?t=${formulario.slug}`;
      if (isOrphanMode && formulario.slug !== "users") endpoint += `&orphans=true`;

      const { data: res, error } = await supabase.functions.invoke(endpoint, {
        method: "GET",
        headers: { Authorization: `Bearer ${session.access_token}` },
      });

      if (error) throw error;
      setData(Array.isArray(res) ? res : []);
      setRowSelection({});

      if (isOrphanMode) {
        const { data: users } = await supabase.from('perfiles_visibles').select('user_id, nombre');
        setTecnicos(users?.map(u => ({ value: u.user_id, label: u.nombre })) || []);
      }
    } catch (err) {
      notifications.show({ title: 'Error', message: 'Error de conexión', color: 'red' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchData(); }, [formulario.slug, isOrphanMode]);

  const handleBulkReassign = async () => {
    if (!selectedTecnico) return;
    setIsUpdating(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const selectedIds = Object.keys(rowSelection);
      const { error } = await supabase.functions.invoke('universal-update', {
        body: { t: formulario.slug, ids: selectedIds, data: { user_id: selectedTecnico } },
        headers: { Authorization: `Bearer ${session.access_token}` },
      });
      if (error) throw error;
      notifications.show({ title: 'Éxito', message: `Reasignados ${selectedIds.length} registros`, color: 'blue' });
      setBulkReassignOpen(false);
      setRowSelection({});
      fetchData();
    } catch (err) {
      notifications.show({ title: 'Error', message: err.message, color: 'red' });
    } finally {
      setIsUpdating(false);
    }
  };

  const confirmDelete = async () => {
    setDeleteModalOpen(false);
    setLoading(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const isUserTable = formulario.slug === "users";
      const { error } = await supabase.functions.invoke(isUserTable ? "users-delete" : "universal-delete", {
        body: { ids: idsToDelete, tabla: formulario.slug },
        headers: { Authorization: `Bearer ${session.access_token}` },
      });
      if (error) throw error;
      setData(prev => prev.filter(r => !idsToDelete.includes(String(r.id || r.user_id))));
      setRowSelection({});
      notifications.show({ title: "Registros eliminados correctamente", color: 'blue' });
    } catch (err) {
      notifications.show({ title: "Error", message: err.message, color: 'red' });
    } finally {
      setLoading(false);
    }
  };

  const columns = useMemo(() => {
    const sample = data[0] || {};
    const isUserTable = formulario.slug === "users";
    const columnTranslations = {
      created_at: "CREADO", updated_at: "ACTUALIZADO", nombre: "NOMBRE",
      email: "CORREO", nombre_completo: "USUARIO", rol: "ROL",
      areas: "ÁREAS", formularios: "FORMULARIOS",
      municipio_nombre: "MUNICIPIO", departamento_nombre: "DEPARTAMENTO",
    };

    const keys = Object.keys(sample).filter(c => {
      if (isUserTable) return !["id", "rol_id", "rol_key"].includes(c);
      if (c === 'municipio_id' || c === 'departamento_id') return false;
      return !["id", "user_id", "rol_id", "formulario_id", "created_by", "activo", "geom", "area_id", "ciudad_temp"].includes(c);
    });

    const cols = [];

    if (esEditorDelForm) {
      cols.push({
        id: 'select', size: 52, enableResizing: false,
        header: ({ table }) => (
          <Checkbox size="xs"
            checked={table.getIsAllRowsSelected()}
            indeterminate={table.getIsSomeRowsSelected()}
            onChange={table.getToggleAllRowsSelectedHandler()}
          />
        ),
        cell: ({ row }) => (
          <Checkbox size="xs"
            checked={row.getIsSelected()}
            onChange={row.getToggleSelectedHandler()}
          />
        ),
      });
    }

    if (isOrphanMode) {
      cols.push({
        id: 'estado_huerfano', header: 'ESTADO', size: 100, enableResizing: false,
        cell: () => <Badge color="orange.9" variant="filled" radius="xs" fw={900} size="xs">HUÉRFANO</Badge>
      });
    }

    keys.forEach(key => {
      cols.push({
        accessorKey: key,
        header: columnTranslations[key] || key.replace(/_/g, ' ').toUpperCase(),
        size: key === 'created_at' || key === 'updated_at' ? 160 : 180,
        cell: info => (
          <MemoizedCellWrapper value={info.getValue()} columnKey={key} isUserTable={isUserTable} />
        ),
      });
    });

    return cols;
  }, [data, isOrphanMode, formulario.slug, esEditorDelForm]);

  const table = useReactTable({
    data,
    columns,
    state: { sorting, globalFilter, rowSelection, columnSizing },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    onRowSelectionChange: setRowSelection,
    onColumnSizingChange: setColumnSizing,
    columnResizeMode: 'onChange',
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getRowId: (row) => String(row.id || row.user_id),
  });

  const { rows } = table.getRowModel();

  const virtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => ROW_HEIGHT,
    overscan: 10,
  });

  const virtualRows = virtualizer.getVirtualItems();
  const totalSize = virtualizer.getTotalSize();
  const paddingTop = virtualRows.length > 0 ? virtualRows[0].start : 0;
  const paddingBottom = virtualRows.length > 0 ? totalSize - virtualRows[virtualRows.length - 1].end : 0;

  const selectedRowsIds = Object.keys(rowSelection);

  return (
    <Box className={classes.tableWrapper}>
      <LoadingOverlay visible={loading} overlayProps={{ blur: 1, backgroundOpacity: 0.1 }} />

      {!esEditorDelForm && !loading && (
        <Box px="md" pt="md">
          <Alert variant="light" color="blue" title="Modo Lectura" icon={<IconInfoCircle />}>
            Solo lectura. No tenés permisos de edición en este formulario.
          </Alert>
        </Box>
      )}

      {/* Barra de búsqueda + contador */}
      <Box className={classes.searchHeader}>
        <Group justify="space-between" align="center">
          <TextInput
            placeholder="Buscar en todos los campos..."
            leftSection={<IconSearch size={15} />}
            value={globalFilter ?? ''}
            onChange={e => setGlobalFilter(e.target.value)}
            size="sm"
            radius="md"
            style={{ width: 320 }}
          />
          <Text size="xs" c="dimmed" fw={600}>
            {table.getFilteredRowModel().rows.length} registros
            {globalFilter && ` · filtrando "${globalFilter}"`}
          </Text>
        </Group>
      </Box>

      {/* Tabla virtualizada */}
      <Box className={classes.tableScrollContainer}>
        <div
          ref={scrollRef}
          className={classes.scrollContainer}
          style={{ overflow: 'auto', height: 'calc(100vh - 160px)' }}
        >
          <table className={classes.table} style={{ width: table.getTotalSize() }}>
            <thead className={classes.thead}>
              {table.getHeaderGroups().map(headerGroup => (
                <tr key={headerGroup.id}>
                  {headerGroup.headers.map(header => (
                    <th
                      key={header.id}
                      className={`${classes.th} ${header.id === 'select' ? classes.stickyColumn : ''}`}
                      style={{ width: header.getSize(), position: 'relative' }}
                    >
                      <div
                        className={classes.thContent}
                        onClick={header.column.getCanSort() ? header.column.getToggleSortingHandler() : undefined}
                        style={{ cursor: header.column.getCanSort() ? 'pointer' : 'default' }}
                      >
                        <span className={classes.headerText}>
                          {flexRender(header.column.columnDef.header, header.getContext())}
                        </span>
                        {header.column.getCanSort() && (
                          <span className={classes.sortIcon}>
                            {{ asc: <IconChevronUp size={12} />, desc: <IconChevronDown size={12} /> }
                              [header.column.getIsSorted()] ?? <IconSelector size={12} />}
                          </span>
                        )}
                      </div>
                      {/* Resize handle */}
                      {header.column.getCanResize() && (
                        <div
                          onMouseDown={header.getResizeHandler()}
                          onTouchStart={header.getResizeHandler()}
                          className={`${classes.resizeHandle} ${header.column.getIsResizing() ? classes.resizeHandleActive : ''}`}
                        />
                      )}
                    </th>
                  ))}
                </tr>
              ))}
            </thead>
            <tbody>
              {paddingTop > 0 && <tr><td style={{ height: paddingTop }} /></tr>}
              {virtualRows.map(virtualRow => {
                const row = rows[virtualRow.index];
                return (
                  <tr
                    key={row.id}
                    className={`${classes.tr} ${row.getIsSelected() ? classes.rowSelected : ''}`}
                    style={{ height: ROW_HEIGHT }}
                  >
                    {row.getVisibleCells().map(cell => (
                      <td
                        key={cell.id}
                        className={`${classes.td} ${cell.column.id === 'select' ? classes.stickyColumn : ''}`}
                        style={{ width: cell.column.getSize() }}
                      >
                        {flexRender(cell.column.columnDef.cell, cell.getContext())}
                      </td>
                    ))}
                  </tr>
                );
              })}
              {paddingBottom > 0 && <tr><td style={{ height: paddingBottom }} /></tr>}
            </tbody>
          </table>

          {data.length === 0 && !loading && (
            <Center p={100}>
              <Text c="dimmed" size="xs" fw={700}>SIN REGISTROS</Text>
            </Center>
          )}
        </div>
      </Box>

      {/* Action Pill */}
      <Box className={classes.actionPillContainer}>
        <Transition mounted={selectedRowsIds.length > 0 && esEditorDelForm} transition="slide-up">
          {(styles) => (
            <Paper style={styles} className={classes.actionPill} withBorder shadow="xl">
              <Group gap="lg" wrap="nowrap">
                <Badge size="lg" radius="sm" color="cyan" variant="filled" fw={900}>
                  {selectedRowsIds.length}
                </Badge>
                <Group gap="xs">
                  {selectedRowsIds.length === 1 && !isOrphanMode && (
                    <>
                      <Button variant="light" color="cyan" size="compact-sm" leftSection={<IconEye size={14} />}
                        onClick={() => onView(data.find(r => String(r.id || r.user_id) === selectedRowsIds[0]))}>
                        VER
                      </Button>
                      <Button variant="light" color="cyan" size="compact-sm" leftSection={<IconEdit size={14} />}
                        onClick={() => onEdit(data.find(r => String(r.id || r.user_id) === selectedRowsIds[0]))}>
                        EDITAR
                      </Button>
                    </>
                  )}
                  {isOrphanMode ? (
                    <Button variant="filled" color="orange.8" size="compact-sm" leftSection={<IconUserPlus size={14} />}
                      onClick={() => selectedRowsIds.length === 1
                        ? onEdit(data.find(r => String(r.id || r.user_id) === selectedRowsIds[0]))
                        : setBulkReassignOpen(true)}>
                      REASIGNAR
                    </Button>
                  ) : (
                    <Button color="red.7" size="compact-sm" leftSection={<IconTrash size={14} />}
                      onClick={() => { setIdsToDelete(selectedRowsIds); setDeleteModalOpen(true); }}>
                      ELIMINAR
                    </Button>
                  )}
                </Group>
                <ActionIcon variant="subtle" color="gray" onClick={() => setRowSelection({})} radius="xl">
                  <IconX size={18} />
                </ActionIcon>
              </Group>
            </Paper>
          )}
        </Transition>
      </Box>

      {/* Modales */}
      <Modal opened={bulkReassignOpen} onClose={() => setBulkReassignOpen(false)}
        title={<Text fw={800}>Reasignación Masiva</Text>} centered radius="md">
        <Stack gap="md">
          <Text size="sm">Seleccioná el nuevo responsable para los <b>{selectedRowsIds.length}</b> registros:</Text>
          <Select label="Nuevo Técnico" placeholder="Buscar..." data={tecnicos}
            value={selectedTecnico} onChange={setSelectedTecnico} searchable />
          <Group justify="flex-end" mt="md">
            <Button variant="subtle" color="gray" onClick={() => setBulkReassignOpen(false)}>Cancelar</Button>
            <Button color="orange.8" onClick={handleBulkReassign} loading={isUpdating} disabled={!selectedTecnico}>
              Confirmar lote
            </Button>
          </Group>
        </Stack>
      </Modal>

      <Modal opened={deleteModalOpen} onClose={() => setDeleteModalOpen(false)}
        title={<Text fw={800}>Confirmar eliminación</Text>} centered>
        <Stack gap="md">
          <Group align="center" c="red.6" gap="xs">
            <IconAlertTriangle size={24} stroke={2.5} />
            <Text fw={700}>Acción Irreversible</Text>
          </Group>
          <Text size="sm" c="dimmed">
            ¿Eliminás permanentemente <b>{idsToDelete.length}</b> registros?
          </Text>
          <Group justify="flex-end" mt="lg">
            <Button variant="subtle" color="gray" onClick={() => setDeleteModalOpen(false)}>Cancelar</Button>
            <Button color="red.6" onClick={confirmDelete}>Eliminar</Button>
          </Group>
        </Stack>
      </Modal>
    </Box>
  );
});

export default TablaDinamica;