import { useState, useEffect, useMemo } from 'react';
import {
  Box, Table, ScrollArea, Badge, Text, Center,
  LoadingOverlay, Checkbox, Group, Button, Transition,
  ActionIcon, Paper, TextInput, Stack, Modal, Divider
} from '@mantine/core';
import {
  IconRefresh, IconCheck, IconClock, IconX,
  IconSearch, IconSelector, IconChevronUp, IconChevronDown,
  IconUserEdit, IconRotate, IconAlertTriangle, IconHistory
} from '@tabler/icons-react';
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  flexRender,
} from '@tanstack/react-table';
import { useDisclosure } from '@mantine/hooks';
import { notifications } from '@mantine/notifications';
import { supabase } from '../lib/supabase';
import FormularioSolicitud from './FormularioSolicitud';
import classes from './MisSolicitudes.module.css';

const estadoBadge = (estado) => {
  if (estado === 'aprobada') return (
    <Badge color="teal" variant="filled" size="sm" leftSection={<IconCheck size={10} />}>Aprobada</Badge>
  );
  if (estado === 'rechazada') return (
    <Badge color="red" variant="filled" size="sm" leftSection={<IconX size={10} />}>Rechazada</Badge>
  );
  if (estado === 'revision') return (
    <Badge color="orange" variant="light" size="sm" leftSection={<IconRotate size={10} />}>En Revisión</Badge>
  );
  return (
    <Badge color="yellow" variant="light" size="sm" leftSection={<IconClock size={10} />}>Pendiente</Badge>
  );
};

export default function MisSolicitudes({ userRole }) {
  const [revision, setRevision] = useState([]);
  const [pendientes, setPendientes] = useState([]);
  const [historial, setHistorial] = useState([]);
  const [loading, setLoading] = useState(true);
  const [reiterando, setReiterando] = useState(false);
  const [sorting, setSorting] = useState([]);
  const [rowSelection, setRowSelection] = useState({});
  const [searchRevision, setSearchRevision] = useState('');
  const [searchPendientes, setSearchPendientes] = useState('');
  const [searchHistorial, setSearchHistorial] = useState('');

  const [opened, { open, close }] = useDisclosure(false);
  const [selectedData, setSelectedData] = useState(null);

  const fetchSolicitudes = async () => {
    setLoading(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const { data: res, error } = await supabase.functions.invoke('solicitudes-list', {
        method: 'GET',
        headers: { Authorization: `Bearer ${session?.access_token}` },
      });
      if (error) throw error;
      const all = Array.isArray(res) ? res : [];
      setRevision(all.filter(s => s.estado === 'revision'));
      setPendientes(all.filter(s => s.estado === 'pendiente' || !s.estado));
      setHistorial(all.filter(s => s.estado === 'aprobada' || s.estado === 'rechazada'));
      setRowSelection({});
    } catch (err) {
      notifications.show({ title: 'Error', message: err.message, color: 'red' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchSolicitudes(); }, []);

  const handleReiterar = async () => {
    const selectedIds = Object.keys(rowSelection);
    if (!selectedIds.length) return;
    setReiterando(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      await Promise.all(selectedIds.map(id =>
        supabase.functions.invoke('solicitudes-reiterar', {
          body: { solicitud_id: id },
          headers: { Authorization: `Bearer ${session?.access_token}` },
        })
      ));
      notifications.show({
        title: 'Reiteración enviada',
        message: `${selectedIds.length} solicitud${selectedIds.length > 1 ? 'es reiteradas' : ' reiterada'} correctamente`,
        color: 'teal'
      });
      setRowSelection({});
      fetchSolicitudes();
    } catch (err) {
      notifications.show({ title: 'Error', message: err.message, color: 'red' });
    } finally {
      setReiterando(false);
    }
  };

  const handleOpenEdit = () => {
    const selectedId = Object.keys(rowSelection)[0];
    const all = [...revision, ...pendientes, ...historial];
    const item = all.find(d => String(d.id) === selectedId);
    if (item) {
      setSelectedData(item);
      open();
    }
  };

  const filterRows = (rows, search) => rows.filter(s =>
    s.nombre_completo?.toLowerCase().includes(search.toLowerCase()) ||
    s.email?.toLowerCase().includes(search.toLowerCase())
  );

  const columns = useMemo(() => [
    {
      id: 'select',
      header: ({ table }) => (
        <Checkbox
          checked={table.getIsAllRowsSelected()}
          indeterminate={table.getIsSomeRowsSelected()}
          onChange={table.getToggleAllRowsSelectedHandler()}
          color="cyan"
        />
      ),
      cell: ({ row }) => (
        <Checkbox
          checked={row.getIsSelected()}
          onChange={row.getToggleSelectedHandler()}
          color="cyan"
        />
      ),
    },
    {
      accessorKey: 'tipo',
      header: 'TIPO',
      cell: info => {
        const isUpdate = info.getValue() === 'update';
        return (
          <Badge variant="dot" color={isUpdate ? "blue" : "teal"} size="sm"
            styles={{ root: { textTransform: 'none' } }}>
            {isUpdate ? 'Actualización' : 'Nuevo Ingreso'}
          </Badge>
        );
      },
    },
    {
      accessorKey: 'nombre_completo',
      header: 'USUARIO',
      cell: info => (
        <Stack gap={0}>
          <Text size="sm" fw={600}>{info.getValue()}</Text>
          <Text size="xs" c="dimmed">{info.row.original.email}</Text>
        </Stack>
      ),
    },
    {
      accessorKey: 'roles',
      header: 'ROL SOLICITADO',
      cell: info => (
        <Badge variant="light" color="gray" size="sm">{info.getValue()?.nombre || '—'}</Badge>
      ),
    },
    {
      accessorKey: 'estado',
      header: 'ESTADO',
      cell: info => estadoBadge(info.getValue()),
    },
    {
      accessorKey: 'reiteraciones',
      header: 'REIT.',
      cell: info => info.getValue() > 0
        ? <Badge color="red" variant="light" size="sm">{info.getValue()}</Badge>
        : <Text size="xs" c="dimmed">—</Text>,
    },
    {
      accessorKey: 'created_at',
      header: 'FECHA',
      cell: info => (
        <Text size="xs" c="dimmed">{new Date(info.getValue()).toLocaleDateString('es-AR')}</Text>
      ),
    },
  ], []);

  const makeTable = (data) => useReactTable({
    data,
    columns,
    state: { sorting, rowSelection },
    onSortingChange: setSorting,
    onRowSelectionChange: setRowSelection,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getRowId: (row) => String(row.id),
    enableRowSelection: true,
  });

  const selectedRowsIds = Object.keys(rowSelection);
  const selectedRowsObjects = selectedRowsIds.map(id => {
    const all = [...revision, ...pendientes, ...historial];
    return all.find(s => String(s.id) === id);
  }).filter(Boolean);

  const isSingleAndAprobada = selectedRowsObjects.length === 1 &&
    selectedRowsObjects[0].estado === 'aprobada';

  const isSingleAndRevision = selectedRowsObjects.length === 1 &&
    selectedRowsObjects[0].estado === 'revision';

  const allSelectedArePendiente = selectedRowsObjects.length > 0 &&
    selectedRowsObjects.every(r => r.estado === 'pendiente' || !r.estado);

  const SectionHeader = ({ icon, title, color, count, search, onSearch }) => (
    <Group justify="space-between" align="center" p="md" className={classes.searchHeader}>
      <Group gap="xs">
        {icon}
        <Text size="sm" fw={800} c={color}>{title}</Text>
        <Badge color={color} variant="filled" size="sm" radius="sm">{count}</Badge>
      </Group>
      <TextInput
        placeholder="Filtrar..."
        leftSection={<IconSearch size={14} />}
        value={search}
        onChange={e => onSearch(e.target.value)}
        size="xs"
        radius="sm"
        style={{ width: 180 }}
      />
    </Group>
  );

  const TableBody = ({ rows }) => (
    <Table verticalSpacing="sm" highlightOnHover withTableBorder={false}>
      <Table.Thead className={classes.stickyHeader}>
        <Table.Tr>
          <Table.Th className={classes.stickyColumn} style={{ width: 40 }}>
            <Checkbox
              checked={rows.length > 0 && rows.every(r => rowSelection[r.id])}
              indeterminate={rows.some(r => rowSelection[r.id]) && !rows.every(r => rowSelection[r.id])}
              onChange={(e) => {
                const newSel = { ...rowSelection };
                if (e.currentTarget.checked) rows.forEach(r => { newSel[r.id] = true; });
                else rows.forEach(r => { delete newSel[r.id]; });
                setRowSelection(newSel);
              }}
              color="cyan"
            />
          </Table.Th>
          <Table.Th><Text size="xs" fw={800} className={classes.headerText}>TIPO</Text></Table.Th>
          <Table.Th><Text size="xs" fw={800} className={classes.headerText}>USUARIO</Text></Table.Th>
          <Table.Th><Text size="xs" fw={800} className={classes.headerText}>ROL SOLICITADO</Text></Table.Th>
          <Table.Th><Text size="xs" fw={800} className={classes.headerText}>ESTADO</Text></Table.Th>
          <Table.Th ta="center"><Text size="xs" fw={800} className={classes.headerText}>REIT.</Text></Table.Th>
          <Table.Th ta="center"><Text size="xs" fw={800} className={classes.headerText}>FECHA</Text></Table.Th>
        </Table.Tr>
      </Table.Thead>
      <Table.Tbody>
        {rows.map(sol => (
          <Table.Tr key={sol.id} className={rowSelection[sol.id] ? classes.rowSelected : ''}>
            <Table.Td className={classes.stickyColumn}>
              <Checkbox
                checked={!!rowSelection[sol.id]}
                onChange={(e) => {
                  const newSel = { ...rowSelection };
                  if (e.currentTarget.checked) newSel[sol.id] = true;
                  else delete newSel[sol.id];
                  setRowSelection(newSel);
                }}
                color="cyan"
              />
            </Table.Td>
            <Table.Td>
              <Badge variant="dot" color={sol.tipo === 'update' ? "blue" : "teal"} size="sm"
                styles={{ root: { textTransform: 'none' } }}>
                {sol.tipo === 'update' ? 'Actualización' : 'Nuevo Ingreso'}
              </Badge>
            </Table.Td>
            <Table.Td>
              <Stack gap={0}>
                <Text size="sm" fw={600}>{sol.nombre_completo}</Text>
                <Text size="xs" c="dimmed">{sol.email}</Text>
              </Stack>
            </Table.Td>
            <Table.Td>
              <Badge variant="light" color="gray" size="sm">{sol.roles?.nombre || '—'}</Badge>
            </Table.Td>
            <Table.Td>{estadoBadge(sol.estado)}</Table.Td>
            <Table.Td ta="center">
              {sol.reiteraciones > 0
                ? <Badge color="red" variant="light" size="sm">{sol.reiteraciones}</Badge>
                : <Text size="xs" c="dimmed">—</Text>}
            </Table.Td>
            <Table.Td ta="center">
              <Text size="xs" c="dimmed">{new Date(sol.created_at).toLocaleDateString('es-AR')}</Text>
            </Table.Td>
          </Table.Tr>
        ))}
      </Table.Tbody>
    </Table>
  );

  return (
    <Box className={classes.tableWrapper}>
      <LoadingOverlay visible={loading} overlayProps={{ blur: 1, backgroundOpacity: 0.1 }} />

      <Modal
        opened={opened}
        onClose={close}
        title={<Text fw={800}>{selectedData?.estado === 'revision' ? 'CORREGIR SOLICITUD' : 'SOLICITAR CAMBIO DE PERMISOS'}</Text>}
        size="xl"
      >
        <FormularioSolicitud
          initialData={selectedData}
          userRole={userRole}
          onSuccess={() => { close(); fetchSolicitudes(); }}
        />
      </Modal>

      <ScrollArea h="calc(100% - 20px)" offsetScrollbars>

        {/* SECCIÓN 1 — REQUIEREN TU ATENCIÓN */}
        <Box mb="xl">
          <SectionHeader
            icon={<IconAlertTriangle size={16} color="var(--mantine-color-orange-6)" />}
            title="REQUIEREN TU ATENCIÓN"
            color="orange"
            count={revision.length}
            search={searchRevision}
            onSearch={setSearchRevision}
          />
          <TableBody rows={filterRows(revision, searchRevision)} />
          {filterRows(revision, searchRevision).length === 0 && !loading && (
            <Center p={40}><Text c="dimmed" size="xs" fw={700}>SIN SOLICITUDES PARA CORREGIR</Text></Center>
          )}
        </Box>

        <Divider mx="md" />

        {/* SECCIÓN 2 — EN ESPERA DE APROBACIÓN */}
        <Box my="xl">
          <SectionHeader
            icon={<IconClock size={16} color="var(--mantine-color-cyan-6)" />}
            title="EN ESPERA DE APROBACIÓN"
            color="cyan"
            count={pendientes.length}
            search={searchPendientes}
            onSearch={setSearchPendientes}
          />
          <TableBody rows={filterRows(pendientes, searchPendientes)} />
          {filterRows(pendientes, searchPendientes).length === 0 && !loading && (
            <Center p={40}><Text c="dimmed" size="xs" fw={700}>SIN SOLICITUDES PENDIENTES</Text></Center>
          )}
        </Box>

        <Divider mx="md" />

        {/* SECCIÓN 3 — HISTORIAL */}
        <Box my="xl">
          <SectionHeader
            icon={<IconHistory size={16} color="var(--mantine-color-gray-6)" />}
            title="HISTORIAL"
            color="gray"
            count={historial.length}
            search={searchHistorial}
            onSearch={setSearchHistorial}
          />
          <TableBody rows={filterRows(historial, searchHistorial)} />
          {filterRows(historial, searchHistorial).length === 0 && !loading && (
            <Center p={40}><Text c="dimmed" size="xs" fw={700}>SIN HISTORIAL</Text></Center>
          )}
        </Box>

        <Box h={120} />
      </ScrollArea>

      {/* ACTION PILL */}
      <div className={classes.actionPillContainer}>
        <Transition mounted={selectedRowsIds.length > 0} transition="slide-up">
          {(styles) => (
            <Paper style={styles} className={classes.actionPill} withBorder shadow="xl">
              <Group gap="lg" wrap="nowrap">
                <Badge size="lg" radius="sm" color="cyan" variant="filled" fw={900}>
                  {selectedRowsIds.length}
                </Badge>

                {allSelectedArePendiente && (
                  <Button variant="filled" color="orange.6" size="compact-sm"
                    leftSection={<IconRefresh size={14} />}
                    loading={reiterando} onClick={handleReiterar}>
                    REITERAR
                  </Button>
                )}

                {isSingleAndRevision && (
                  <Button variant="filled" color="orange.6" size="compact-sm"
                    leftSection={<IconRotate size={14} />}
                    onClick={handleOpenEdit}>
                    CORREGIR SOLICITUD
                  </Button>
                )}

                {isSingleAndAprobada && (
                  <Button variant="filled" color="blue.6" size="compact-sm"
                    leftSection={<IconUserEdit size={14} />}
                    onClick={handleOpenEdit}>
                    MODIFICAR PERMISOS
                  </Button>
                )}

                <ActionIcon variant="subtle" color="gray" onClick={() => setRowSelection({})} radius="xl">
                  <IconX size={18} />
                </ActionIcon>
              </Group>
            </Paper>
          )}
        </Transition>
      </div>
    </Box>
  );
}