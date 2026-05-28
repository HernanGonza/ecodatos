import { useEffect, useState, forwardRef, useImperativeHandle, useMemo } from "react";
import {
  Box, Table, ScrollArea, Badge, Text, Paper, Center,
  LoadingOverlay, Checkbox, Group, Button, Transition, ActionIcon,
  Tooltip, Modal, Stack, TextInput, Select, Alert
} from '@mantine/core';
import {
  IconEye, IconEdit, IconTrash, IconX, IconAlertTriangle,
  IconSearch, IconSelector, IconChevronUp, IconChevronDown,
  IconUserPlus, IconCheck, IconClock, IconPencil, IconInfoCircle
} from '@tabler/icons-react';
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  flexRender,
} from '@tanstack/react-table';
import { notifications } from '@mantine/notifications';
import { supabase } from "../lib/supabase";
import classes from './TablaDinamica.module.css';

const TablaDinamica = forwardRef(({ formulario, onEdit, onView }, ref) => {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [sorting, setSorting] = useState([]);
  const [globalFilter, setGlobalFilter] = useState('');
  const [rowSelection, setRowSelection] = useState({});

  // Seguridad: Control de permisos
  const [esEditorDelForm, setEsEditorDelForm] = useState(true);

  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [idsToDelete, setIdsToDelete] = useState([]);

  const [bulkReassignOpen, setBulkReassignOpen] = useState(false);
  const [tecnicos, setTecnicos] = useState([]);
  const [selectedTecnico, setSelectedTecnico] = useState(null);
  const [isUpdating, setIsUpdating] = useState(false);

  const isOrphanMode = formulario?.isOrphanMode;

  useImperativeHandle(ref, () => ({
    refresh: () => fetchData(),
  }));

  const fetchData = async () => {
    if (!formulario?.slug) return;
    setLoading(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) return;

      // --- VALIDACIÓN DE PERMISOS ---
      if (formulario.slug !== "users") {
        const { data: permiso } = await supabase
          .from('usuarios_formularios')
          .select('es_editor')
          .eq('user_id', session.user.id)
          .eq('formulario_id', formulario.id)
          .maybeSingle();

        // Si no existe registro es porque es admin o no tiene acceso,
        // pero por seguridad si existe y es_editor es false, bloqueamos.
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
        body: {
          t: formulario.slug,
          ids: selectedIds,
          data: { user_id: selectedTecnico }
        },
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
      const endpoint = isUserTable ? "users-delete" : "universal-delete";

      const { error } = await supabase.functions.invoke(endpoint, {
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
    created_at: "CREADO",
    updated_at: "ÚLTIMA VEZ ACTUALIZADO",
    nombre: "NOMBRE",
    email: "CORREO",
    nombre_completo: "USUARIO",
    rol: "ROL",
    areas: "ÁREAS Y PERMISOS",
    formularios: "FORMULARIOS",
    municipio_nombre: "MUNICIPIO",
    departamento_nombre: "DEPARTAMENTO",
  };

  const keys = Object.keys(sample).filter(c => {
    if (isUserTable) {
      return !["id", "rol_id", "rol_key"].includes(c);
    }

    // ==================== FILTRO MEJORADO ====================
    // Ocultar siempre los IDs de foreign keys cuando tenemos los nombres
    if (c === 'municipio_id' || c === 'departamento_id') {
      return false;
    }

    // Ocultar otros campos internos que no queremos mostrar
    const hiddenFields = [
      "id",
      "user_id",
      "rol_id",
      "formulario_id",
      "created_by",
      "activo",
      "geom",
      "area_id",
      "ciudad_temp"
    ];

    return !hiddenFields.includes(c);
    // ========================================================
  });

  const cols = [];

  // --- CHECKBOX DE SELECCIÓN (solo si es editor) ---
  if (esEditorDelForm) {
    cols.push({
      id: 'select',
      header: ({ table }) => (
        <Checkbox
          checked={table.getIsAllRowsSelected()}
          indeterminate={table.getIsSomeRowsSelected()}
          onChange={table.getToggleAllRowsSelectedHandler()}
          color="brand"
        />
      ),
      cell: ({ row }) => (
        <Checkbox
          checked={row.getIsSelected()}
          onChange={row.getToggleSelectedHandler()}
          color="brand"
        />
      ),
    });
  }

  if (isOrphanMode) {
    cols.push({
      id: 'estado_huerfano',
      header: 'ESTADO',
      cell: () => <Badge color="orange.9" variant="filled" radius="xs" fw={900} size="xs">HUÉRFANO</Badge>
    });
  }

  // Generar columnas para los campos permitidos
  keys.forEach(key => {
    cols.push({
      accessorKey: key,
      header: columnTranslations[key] || key.replace(/_/g, ' ').toUpperCase(),
      cell: info => {
        const val = info.getValue();

        if (isUserTable && (key === "areas" || key === "formularios") && Array.isArray(val)) {
          if (val.length === 0) return <Text size="xs" c="dimmed">Ninguno</Text>;
          return (
            <Group gap={4}>
              {val.map((item, idx) => (
                <Tooltip key={idx} label={item.es_editor ? "Editor" : "Lector"} withArrow>
                  <Badge variant="light" color={item.es_editor ? "brand" : "blue"} size="xs" radius="xs"
                         leftSection={item.es_editor ? <IconPencil size={10} /> : <IconEye size={10} />}>
                    {item.id.split('-')[0]}
                  </Badge>
                </Tooltip>
              ))}
            </Group>
          );
        }

        if ((key === 'updated_at' || key === 'created_at') && val) {
          return (
            <Group gap={4} wrap="nowrap">
              <IconClock size={12} color="var(--mantine-color-gray-6)" />
              <Text size="xs" c="dimmed">{new Date(val).toLocaleString()}</Text>
            </Group>
          );
        }

        return (
          <Tooltip label={String(val ?? "")} disabled={String(val ?? "").length < 30} multiline w={220} withArrow>
            <Text size="xs" fw={500} className={classes.cellText}>
              {String(val ?? "-")}
            </Text>
          </Tooltip>
        );
      }
    });
  });

  return cols;
}, [data, isOrphanMode, formulario.slug, esEditorDelForm]);

  const table = useReactTable({
    data,
    columns,
    state: { sorting, globalFilter, rowSelection },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    onRowSelectionChange: setRowSelection,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getRowId: (row) => String(row.id || row.user_id),
  });

  const selectedRowsIds = Object.keys(rowSelection);

  return (
    <Box className={classes.tableWrapper}>
      <LoadingOverlay visible={loading} overlayProps={{ blur: 1, backgroundOpacity: 0.1 }} />

      {!esEditorDelForm && !loading && (
        <Box px="md" pt="md">
          <Alert variant="light" color="blue" title="Modo Lectura" icon={<IconInfoCircle />}>
            No tienes permisos de edición en este formulario. Puedes visualizar los datos pero no realizar modificaciones.
          </Alert>
        </Box>
      )}

      <Box p="md" className={classes.searchHeader}>
        <TextInput
          placeholder="Buscar registros..."
          leftSection={<IconSearch size={16} />}
          value={globalFilter ?? ''}
          onChange={e => setGlobalFilter(e.target.value)}
          size="xs"
          radius="sm"
          className={classes.searchInput}
        />
      </Box>

      <ScrollArea h="calc(100% - 70px)" offsetScrollbars>
        <Table verticalSpacing="sm" highlightOnHover withTableBorder={false} stickyHeader>
          <Table.Thead className={classes.stickyHeader}>
            {table.getHeaderGroups().map(headerGroup => (
              <Table.Tr key={headerGroup.id}>
                {headerGroup.headers.map(header => (
                  <Table.Th
                    key={header.id}
                    className={header.id === 'select' ? classes.stickyColumn : ''}
                    onClick={header.column.getCanSort() ? header.column.getToggleSortingHandler() : undefined}
                    style={{ cursor: header.column.getCanSort() ? 'pointer' : 'default' }}
                  >
                    <Group gap={4} wrap="nowrap">
                      <Text size="xs" fw={800} className={classes.headerText}>
                        {flexRender(header.column.columnDef.header, header.getContext())}
                      </Text>
                      {header.column.getCanSort() && (
                        <Box opacity={0.5}>
                          {{ asc: <IconChevronUp size={14} />, desc: <IconChevronDown size={14} /> }[header.column.getIsSorted()] ?? <IconSelector size={14} />}
                        </Box>
                      )}
                    </Group>
                  </Table.Th>
                ))}
              </Table.Tr>
            ))}
          </Table.Thead>
          <Table.Tbody>
            {table.getRowModel().rows.map(row => (
              <Table.Tr key={row.id} className={row.getIsSelected() ? classes.rowSelected : ''}>
                {row.getVisibleCells().map(cell => (
                  <Table.Td
                    key={cell.id}
                    className={cell.column.id === 'select' ? classes.stickyColumn : ''}
                  >
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </Table.Td>
                ))}
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
        {data.length === 0 && !loading && (
          <Center p={100}><Text c="dimmed" size="xs" fw={700}>SIN REGISTROS</Text></Center>
        )}
        <Box h={120} />
      </ScrollArea>

      <div className={classes.actionPillContainer}>
        {/* LA TRANSICION AHORA TAMBIÉN DEPENDE DE esEditorDelForm */}
        <Transition mounted={selectedRowsIds.length > 0 && esEditorDelForm} transition="slide-up">
          {(styles) => (
            <Paper style={styles} className={classes.actionPill} withBorder shadow="xl">
              <Group gap="lg" wrap="nowrap">
                <Badge size="lg" radius="sm" color="brand" variant="filled" fw={900}>{selectedRowsIds.length}</Badge>
                <Group gap="xs">
                  {selectedRowsIds.length === 1 && !isOrphanMode && (
                    <>
                      <Button variant="light" color="brand" size="compact-sm" leftSection={<IconEye size={14} />} onClick={() => onView(data.find(r => String(r.id || r.user_id) === selectedRowsIds[0]))}>VER</Button>
                      <Button variant="light" color="brand" size="compact-sm" leftSection={<IconEdit size={14} />} onClick={() => onEdit(data.find(r => String(r.id || r.user_id) === selectedRowsIds[0]))}>EDITAR</Button>
                    </>
                  )}
                  {isOrphanMode ? (
                     <Button variant="filled" color="orange.8" size="compact-sm" leftSection={<IconUserPlus size={14} />} onClick={() => selectedRowsIds.length === 1 ? onEdit(data.find(r => String(r.id || r.user_id) === selectedRowsIds[0])) : setBulkReassignOpen(true)}>REASIGNAR</Button>
                  ) : (
                     <Button color="red.7" size="compact-sm" leftSection={<IconTrash size={14} />} onClick={() => { setIdsToDelete(selectedRowsIds); setDeleteModalOpen(true); }}>ELIMINAR</Button>
                  )}
                </Group>
                <ActionIcon variant="subtle" color="gray" onClick={() => setRowSelection({})} radius="xl"><IconX size={18} /></ActionIcon>
              </Group>
            </Paper>
          )}
        </Transition>
      </div>

      {/* MODALES ÍNTEGROS */}
      <Modal opened={bulkReassignOpen} onClose={() => setBulkReassignOpen(false)} title={<Text fw={800}>Reasignación Masiva</Text>} centered radius="md">
        <Stack gap="md">
          <Text size="sm">Selecciona el nuevo responsable para los <b>{selectedRowsIds.length}</b> registros:</Text>
          <Select label="Nuevo Técnico" placeholder="Buscar..." data={tecnicos} value={selectedTecnico} onChange={setSelectedTecnico} searchable />
          <Group justify="flex-end" mt="md">
            <Button variant="subtle" color="gray" onClick={() => setBulkReassignOpen(false)}>Cancelar</Button>
            <Button color="orange.8" onClick={handleBulkReassign} loading={isUpdating} disabled={!selectedTecnico}>Confirmar lote</Button>
          </Group>
        </Stack>
      </Modal>

      <Modal opened={deleteModalOpen} onClose={() => setDeleteModalOpen(false)} title={<Text fw={800}>Confirmar eliminación</Text>} centered>
        <Stack gap="md">
          <Group align="center" c="red.6" gap="xs">
            <IconAlertTriangle size={24} stroke={2.5} />
            <Text fw={700}>Acción Irreversible</Text>
          </Group>
          <Text size="sm" c="dimmed">¿Deseas eliminar permanentemente <b>{idsToDelete.length}</b> registros?</Text>
          <Group justify="flex-end" mt="lg">
            <Button variant="subtle" color="gray" onClick={() => setDeleteModalOpen(false)}>Cancelar</Button>
            <Button color="red.6" onClick={confirmDelete}>Eliminar registros</Button>
          </Group>
        </Stack>
      </Modal>
    </Box>
  );
});

export default TablaDinamica;
