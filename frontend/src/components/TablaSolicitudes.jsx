import { useState, useEffect } from 'react';
import {
  Box, Table, ScrollArea, Badge, Text, Center, Group,
  LoadingOverlay, Checkbox, Button, Transition, ActionIcon,
  Paper, TextInput, Stack, Tooltip, Modal, Drawer, Divider
} from '@mantine/core';
import {
  IconSearch, IconCheck, IconClock, IconX,
  IconUserEdit, IconMail, IconEye, IconRotate, IconHistory
} from '@tabler/icons-react';
import { notifications } from '@mantine/notifications';
import { supabase } from '../lib/supabase';
import FormularioSolicitud from './FormularioSolicitud';
import classes from './TablaDinamica.module.css';

const estadoBadge = (estado) => {
  switch (estado) {
    case 'aprobada':
      return <Badge color="teal" variant="filled" size="xs" leftSection={<IconCheck size={10} />}>Aprobada</Badge>;
    case 'rechazada':
      return <Badge color="red" variant="filled" size="xs" leftSection={<IconX size={10} />}>Rechazada</Badge>;
    case 'revision':
      return <Badge color="orange" variant="light" size="xs" leftSection={<IconRotate size={10} />}>En Revisión</Badge>;
    default:
      return <Badge color="yellow" variant="light" size="xs" leftSection={<IconClock size={10} />}>Pendiente</Badge>;
  }
};

export default function TablaSolicitudes() {
  const [enCola, setEnCola] = useState([]);
  const [enRevision, setEnRevision] = useState([]);
  const [historial, setHistorial] = useState([]);
  const [loading, setLoading] = useState(true);
  const [aprobando, setAprobando] = useState(false);
  const [rowSelection, setRowSelection] = useState({});
  const [searchCola, setSearchCola] = useState('');
  const [searchRevision, setSearchRevision] = useState('');
  const [searchHistorial, setSearchHistorial] = useState('');
  const [confirmModalOpen, setConfirmModalOpen] = useState(false);
  const [verDrawerOpen, setVerDrawerOpen] = useState(false);
  const [solicitudSeleccionada, setSolicitudSeleccionada] = useState(null);

  const fetchData = async () => {
    setLoading(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const { data, error } = await supabase.functions.invoke('solicitudes-list', {
        method: 'GET',
        headers: { Authorization: `Bearer ${session?.access_token}` },
      });
      if (error) throw error;
      const all = Array.isArray(data) ? data : [];
      setEnCola(all.filter(s => s.estado === 'pendiente' || !s.estado));
      setEnRevision(all.filter(s => s.estado === 'revision'));
      setHistorial(all.filter(s => s.estado === 'aprobada' || s.estado === 'rechazada'));
      setRowSelection({});
    } catch (err) {
      notifications.show({ title: 'Error', message: err.message, color: 'red' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchData(); }, []);

  const handleAprobar = async () => {
    setConfirmModalOpen(false);
    setAprobando(true);
    const selectedIds = Object.keys(rowSelection);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      await Promise.all(selectedIds.map(id =>
        supabase.functions.invoke('queue-publish', {
          body: { subject: 'jobs.solicitudes.approve', payload: { solicitud_id: id } },
          headers: { Authorization: `Bearer ${session?.access_token}` },
        })
      ));
      notifications.show({
        title: 'Procesando',
        message: `${selectedIds.length} solicitud${selectedIds.length > 1 ? 'es enviadas' : ' enviada'} a la cola`,
        color: 'teal'
      });
      setRowSelection({});
      setTimeout(fetchData, 3000);
    } catch (err) {
      notifications.show({ title: 'Error', message: err.message, color: 'red' });
    } finally {
      setAprobando(false);
    }
  };

  const handleVerSolicitud = () => {
    const id = Object.keys(rowSelection)[0];
    const sol = [...enCola, ...enRevision, ...historial].find(s => s.id === id);
    if (sol) {
      setSolicitudSeleccionada(sol);
      setVerDrawerOpen(true);
    }
  };

  const selectedIds = Object.keys(rowSelection);
  const isSingleSelected = selectedIds.length === 1;

  const allSelectedAreEnCola = selectedIds.length > 0 &&
    selectedIds.every(id => enCola.find(s => s.id === id));

  const selectedIsHistorial = isSingleSelected &&
    historial.find(s => s.id === selectedIds[0]);

  const filterRows = (rows, search) => rows.filter(s =>
    s.nombre_completo?.toLowerCase().includes(search.toLowerCase()) ||
    s.email?.toLowerCase().includes(search.toLowerCase()) ||
    s.solicitante_nombre?.toLowerCase().includes(search.toLowerCase())
  );

  const ColHeader = () => (
    <Table.Tr>
      <Table.Th className={classes.stickyColumn} style={{ width: 40 }} />
      <Table.Th><Text size="xs" fw={800} className={classes.headerText}>ESTADO</Text></Table.Th>
      <Table.Th><Text size="xs" fw={800} className={classes.headerText}>TIPO</Text></Table.Th>
      <Table.Th><Text size="xs" fw={800} className={classes.headerText}>USUARIO AFECTADO</Text></Table.Th>
      <Table.Th><Text size="xs" fw={800} className={classes.headerText}>ROL</Text></Table.Th>
      <Table.Th><Text size="xs" fw={800} className={classes.headerText}>SOLICITANTE</Text></Table.Th>
      <Table.Th ta="center"><Text size="xs" fw={800} className={classes.headerText}>REIT.</Text></Table.Th>
      <Table.Th ta="center"><Text size="xs" fw={800} className={classes.headerText}>FECHA</Text></Table.Th>
    </Table.Tr>
  );

  const ColRow = ({ sol, showCheckbox = true }) => (
    <Table.Tr
      key={sol.id}
      className={rowSelection[sol.id] ? classes.rowSelected : ''}
      style={{ cursor: 'pointer' }}
      onClick={() => {
        if (!showCheckbox) return;
        const newSel = { ...rowSelection };
        if (newSel[sol.id]) delete newSel[sol.id];
        else newSel[sol.id] = true;
        setRowSelection(newSel);
      }}
    >
      <Table.Td className={classes.stickyColumn} onClick={e => e.stopPropagation()}>
        {showCheckbox ? (
          <Checkbox
            checked={!!rowSelection[sol.id]}
            onChange={(e) => {
              const newSel = { ...rowSelection };
              if (e.currentTarget.checked) newSel[sol.id] = true;
              else delete newSel[sol.id];
              setRowSelection(newSel);
            }}
            color="orange"
          />
        ) : null}
      </Table.Td>
      <Table.Td>{estadoBadge(sol.estado)}</Table.Td>
      <Table.Td>
        <Badge variant="dot" color={sol.tipo === 'update' ? "blue" : "teal"} size="xs"
          styles={{ root: { textTransform: 'none' } }}>
          {sol.tipo === 'update' ? 'Cambio' : 'Nuevo'}
        </Badge>
      </Table.Td>
      <Table.Td>
        <Stack gap={0}>
          <Text size="sm" fw={600} className={classes.cellText}>{sol.nombre_completo}</Text>
          <Text size="xs" c="dimmed">{sol.email}</Text>
        </Stack>
      </Table.Td>
      <Table.Td>
        <Badge variant="light" color="cyan" size="sm">{sol.roles?.nombre || '—'}</Badge>
      </Table.Td>
      <Table.Td>
        <Group gap={4} wrap="nowrap">
          <Tooltip label={sol.solicitante_email} withArrow>
            <IconMail size={12} color="gray" />
          </Tooltip>
          <Text size="xs" c="dimmed" truncate>{sol.solicitante_nombre || '—'}</Text>
        </Group>
      </Table.Td>
      <Table.Td ta="center">
        {sol.reiteraciones > 0
          ? <Badge color="red" variant="filled" size="xs">{sol.reiteraciones}</Badge>
          : <Text size="xs" c="dimmed">—</Text>}
      </Table.Td>
      <Table.Td ta="center">
        <Text size="xs" c="dimmed">{new Date(sol.created_at).toLocaleDateString('es-AR')}</Text>
      </Table.Td>
    </Table.Tr>
  );

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

  return (
    <Box className={classes.tableWrapper} style={{ display: 'flex', flexDirection: 'column' }}>
      <LoadingOverlay visible={loading} overlayProps={{ blur: 1, backgroundOpacity: 0.1 }} />

      <ScrollArea style={{ flex: 1 }} offsetScrollbars>

        {/* SECCIÓN 1 — EN COLA */}
        <Box mb="xl">
          <SectionHeader
            icon={<IconClock size={16} color="var(--mantine-color-orange-6)" />}
            title="EN COLA"
            color="orange"
            count={enCola.length}
            search={searchCola}
            onSearch={setSearchCola}
          />
          <Table verticalSpacing="sm" highlightOnHover withTableBorder={false} stickyHeader>
            <Table.Thead className={classes.stickyHeader}><ColHeader /></Table.Thead>
            <Table.Tbody>
              {filterRows(enCola, searchCola).map(sol => <ColRow key={sol.id} sol={sol} />)}
            </Table.Tbody>
          </Table>
          {filterRows(enCola, searchCola).length === 0 && !loading && (
            <Center p={40}><Text c="dimmed" size="xs" fw={700}>SIN SOLICITUDES EN COLA</Text></Center>
          )}
        </Box>

        <Divider mx="md" />

        {/* SECCIÓN 2 — DEVUELTAS PARA CORRECCIÓN */}
        <Box my="xl">
          <SectionHeader
            icon={<IconRotate size={16} color="var(--mantine-color-yellow-6)" />}
            title="DEVUELTAS PARA CORRECCIÓN"
            color="yellow"
            count={enRevision.length}
            search={searchRevision}
            onSearch={setSearchRevision}
          />
          <Table verticalSpacing="sm" highlightOnHover withTableBorder={false} stickyHeader>
            <Table.Thead className={classes.stickyHeader}><ColHeader /></Table.Thead>
            <Table.Tbody>
              {filterRows(enRevision, searchRevision).map(sol => <ColRow key={sol.id} sol={sol} />)}
            </Table.Tbody>
          </Table>
          {filterRows(enRevision, searchRevision).length === 0 && !loading && (
            <Center p={40}><Text c="dimmed" size="xs" fw={700}>SIN SOLICITUDES DEVUELTAS</Text></Center>
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
          <Table verticalSpacing="sm" highlightOnHover withTableBorder={false} stickyHeader>
            <Table.Thead className={classes.stickyHeader}><ColHeader /></Table.Thead>
            <Table.Tbody>
              {filterRows(historial, searchHistorial).map(sol => (
                <ColRow key={sol.id} sol={sol} showCheckbox={false} />
              ))}
            </Table.Tbody>
          </Table>
          {filterRows(historial, searchHistorial).length === 0 && !loading && (
            <Center p={40}><Text c="dimmed" size="xs" fw={700}>SIN HISTORIAL</Text></Center>
          )}
        </Box>

        <Box h={120} />
      </ScrollArea>

      {/* ACTION PILL */}
      <div className={classes.actionPillContainer}>
        <Transition mounted={selectedIds.length > 0} transition="slide-up">
          {(styles) => (
            <Paper style={styles} className={classes.actionPill} withBorder shadow="xl">
              <Group gap="lg" wrap="nowrap">
                <Badge size="lg" radius="sm" color="orange" variant="filled" fw={900}>
                  {selectedIds.length}
                </Badge>

                {isSingleSelected && (
                  <Button
                    variant="light"
                    color="cyan.6"
                    size="compact-sm"
                    leftSection={<IconEye size={14} />}
                    onClick={handleVerSolicitud}
                  >
                    VER
                  </Button>
                )}

                {allSelectedAreEnCola && (
                  <Button
                    variant="filled"
                    color="teal.7"
                    size="compact-sm"
                    leftSection={<IconCheck size={14} />}
                    loading={aprobando}
                    onClick={() => setConfirmModalOpen(true)}
                  >
                    APROBAR
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

      {/* MODAL CONFIRMACIÓN */}
      <Modal
        opened={confirmModalOpen}
        onClose={() => setConfirmModalOpen(false)}
        title={<Text fw={800}>Procesar Solicitudes</Text>}
        centered radius="md"
      >
        <Stack gap="md">
          <Group align="center" c="teal.7" gap="xs">
            <IconUserEdit size={24} />
            <Text fw={700}>Procesar {selectedIds.length} solicitud{selectedIds.length > 1 ? 'es' : ''}</Text>
          </Group>
          <Text size="sm" c="dimmed">
            Esta acción ejecutará los cambios en el sistema y notificará a los usuarios involucrados.
          </Text>
          <Group justify="flex-end" mt="lg">
            <Button variant="subtle" color="gray" onClick={() => setConfirmModalOpen(false)}>Cancelar</Button>
            <Button color="teal.7" onClick={handleAprobar} loading={aprobando}>Confirmar y Ejecutar</Button>
          </Group>
        </Stack>
      </Modal>

      {/* DRAWER VER */}
      <Drawer
        opened={verDrawerOpen}
        onClose={() => { setVerDrawerOpen(false); setSolicitudSeleccionada(null); }}
        size="xl"
        position="right"
        lockScroll={false}
        transitionProps={{ duration: 300, transition: 'slide-left' }}
        title={
          <Group gap="xs">
            <IconEye size={18} color="var(--mantine-color-cyan-6)" />
            <Text fw={800} size="md" lts="1px" c="cyan.5">REVISIÓN DE SOLICITUD</Text>
          </Group>
        }
        padding={0}
      >
        {verDrawerOpen && solicitudSeleccionada && (
          <FormularioSolicitud
            initialData={solicitudSeleccionada}
            isSuperadmin={true}
            isHistorial={solicitudSeleccionada?.estado === 'aprobada' || solicitudSeleccionada?.estado === 'rechazada'}
            onSuccess={() => {
              setVerDrawerOpen(false);
              setSolicitudSeleccionada(null);
              fetchData();
            }}
          />
        )}
      </Drawer>
    </Box>
  );
}