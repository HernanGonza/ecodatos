import { useEffect, useState, useMemo } from "react";
import {
  Box,
  Modal,
  Stack,
  Group,
  Button,
  Text,
  Badge,
  Paper,
  ActionIcon,
  Select,
  TextInput,
  Textarea,
  LoadingOverlay,
  Center,
  Divider,
  Table,
  Tooltip,
} from "@mantine/core";
import {
  IconLink,
  IconPlus,
  IconTrash,
  IconEye,
  IconArrowRight,
  IconSearch,
} from "@tabler/icons-react";
import { notifications } from "@mantine/notifications";
import { supabase } from "../lib/supabase";
import FormularioDinamico from "./FormularioDinamico";

const COLUMNAS_EXCLUIDAS_PICKER = [
  "id",
  "user_id",
  "rol_id",
  "formulario_id",
  "created_by",
  "activo",
  "geom",
  "area_id",
  "ciudad_temp",
  "municipio_id",
  "departamento_id",
  "fotos",
  "audios",
];

const TRADUCCIONES_HEADER = {
  created_at: "Creado",
  updated_at: "Actualizado",
  municipio_nombre: "Municipio",
  departamento_nombre: "Departamento",
};

const formatHeader = (key) =>
  TRADUCCIONES_HEADER[key] ||
  key.replace(/_/g, " ").replace(/\b\w/g, (l) => l.toUpperCase());

const formatCellValue = (val) => {
  if (val === null || val === undefined || val === "") return "—";
  if (Array.isArray(val)) return val.length ? `${val.length} archivo(s)` : "—";
  if (typeof val === "boolean") return val ? "Sí" : "No";
  return String(val);
};

const pickLabel = (row) => {
  if (!row) return "—";
  return (
    row.nombre ||
    row.descripcion ||
    row.titulo ||
    row.n_orden ||
    row.municipio_nombre ||
    (row.created_at ? new Date(row.created_at).toLocaleDateString() : null) ||
    `Registro ${String(row.id || "").slice(0, 8)}`
  );
};

export default function PanelVinculaciones({ tabla, registroId, opened, onClose }) {
  const [loading, setLoading] = useState(false);
  const [vinculos, setVinculos] = useState([]);
  const [currentUserId, setCurrentUserId] = useState(null);

  const [wizardOpen, setWizardOpen] = useState(false);
  const [areas, setAreas] = useState([]);
  const [formularios, setFormularios] = useState([]);
  const [areaId, setAreaId] = useState(null);
  const [formSlug, setFormSlug] = useState(null);
  const [busqueda, setBusqueda] = useState("");
  const [candidatos, setCandidatos] = useState([]);
  const [candidatosLoading, setCandidatosLoading] = useState(false);
  const [registroElegido, setRegistroElegido] = useState(null);
  const [tipoRelacion, setTipoRelacion] = useState("");
  const [nota, setNota] = useState("");
  const [guardando, setGuardando] = useState(false);

  const [viewing, setViewing] = useState(null); // { tabla, resumen }

  const fetchVinculos = async () => {
    if (!tabla || !registroId) return;
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("listar_vinculaciones", {
        p_tabla: tabla,
        p_id: registroId,
      });
      if (error) throw error;
      setVinculos(data || []);
    } catch (err) {
      notifications.show({ title: "Error", message: err.message, color: "red" });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (opened) {
      fetchVinculos();
      supabase.auth.getSession().then(({ data }) => {
        setCurrentUserId(data?.session?.user?.id || null);
      });
    } else {
      setWizardOpen(false);
      setViewing(null);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [opened, tabla, registroId]);

  const abrirWizard = async () => {
    setWizardOpen(true);
    setAreaId(null);
    setFormSlug(null);
    setBusqueda("");
    setCandidatos([]);
    setRegistroElegido(null);
    setTipoRelacion("");
    setNota("");
    if (areas.length === 0) {
      const { data: areasData } = await supabase
        .from("areas")
        .select("id, nombre")
        .eq("activo", true)
        .order("nombre");
      setAreas(areasData || []);
    }
    if (formularios.length === 0) {
      const { data: formsData } = await supabase
        .from("formularios")
        .select("id, slug, nombre, area_id")
        .eq("activo", true)
        .order("nombre");
      setFormularios(formsData || []);
    }
  };

  const formulariosDelArea = useMemo(
    () => formularios.filter((f) => f.area_id === areaId && f.slug !== "users"),
    [formularios, areaId],
  );

  const buscarCandidatos = async (slug) => {
    if (!slug) return;
    setCandidatosLoading(true);
    setCandidatos([]);
    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      const { data, error } = await supabase.functions.invoke(
        `universal-list?t=${slug}`,
        { method: "GET", headers: { Authorization: `Bearer ${session.access_token}` } },
      );
      if (error) throw error;
      setCandidatos(Array.isArray(data) ? data : []);
    } catch (err) {
      notifications.show({ title: "Error", message: err.message, color: "red" });
    } finally {
      setCandidatosLoading(false);
    }
  };

  const candidatosFiltrados = useMemo(() => {
    if (!busqueda.trim()) return candidatos;
    const q = busqueda.toLowerCase();
    return candidatos.filter((row) =>
      Object.values(row).some((v) => String(v ?? "").toLowerCase().includes(q)),
    );
  }, [candidatos, busqueda]);

  const columnasCandidatos = useMemo(() => {
    const sample = candidatos[0] || {};
    return Object.keys(sample).filter((k) => !COLUMNAS_EXCLUIDAS_PICKER.includes(k));
  }, [candidatos]);

  const confirmarVinculo = async () => {
    if (!formSlug || !registroElegido) return;
    setGuardando(true);
    try {
      const { error } = await supabase.from("vinculaciones").insert({
        tabla_origen: tabla,
        registro_origen_id: registroId,
        tabla_destino: formSlug,
        registro_destino_id: registroElegido.id,
        tipo_relacion: tipoRelacion.trim() || null,
        nota: nota.trim() || null,
      });
      if (error) throw error;
      notifications.show({ title: "Vínculo creado", color: "blue" });
      setWizardOpen(false);
      fetchVinculos();
    } catch (err) {
      notifications.show({ title: "No se pudo vincular", message: err.message, color: "red" });
    } finally {
      setGuardando(false);
    }
  };

  const eliminarVinculo = async (id) => {
    try {
      const { error } = await supabase.from("vinculaciones").delete().eq("id", id);
      if (error) throw error;
      setVinculos((prev) => prev.filter((v) => v.vinculacion_id !== id));
      notifications.show({ title: "Vínculo eliminado", color: "blue" });
    } catch (err) {
      notifications.show({ title: "Error", message: err.message, color: "red" });
    }
  };

  return (
    <>
      <Modal
        opened={opened}
        onClose={onClose}
        title={
          <Group gap="xs">
            <IconLink size={18} />
            <Text fw={800}>Registros vinculados</Text>
          </Group>
        }
        size="lg"
        centered
      >
        <Stack gap="md">
          <Group justify="flex-end">
            <Button
              size="xs"
              variant="light"
              color="cyan"
              leftSection={<IconPlus size={14} />}
              onClick={abrirWizard}
            >
              Vincular registro
            </Button>
          </Group>

          <Box mih={80} pos="relative">
            <LoadingOverlay visible={loading} />
            {!loading && vinculos.length === 0 && (
              <Center p="lg">
                <Text size="sm" c="dimmed">
                  Este registro no tiene vínculos todavía.
                </Text>
              </Center>
            )}
            <Stack gap="xs">
              {vinculos.map((v) => (
                <Paper key={v.vinculacion_id} withBorder p="sm" radius="md">
                  <Group justify="space-between" align="flex-start" wrap="nowrap">
                    <Stack gap={4} style={{ flex: 1 }}>
                      <Group gap="xs">
                        <Badge size="sm" variant="light" color="cyan">
                          {v.area_nombre || "Área desconocida"}
                        </Badge>
                        <Text size="sm" fw={700}>
                          {v.formulario_nombre || v.tabla_relacionada}
                        </Text>
                      </Group>
                      {v.tipo_relacion && (
                        <Text size="xs" c="dimmed" fw={600}>
                          {v.tipo_relacion}
                        </Text>
                      )}
                      {v.nota && (
                        <Text size="xs" c="dimmed">
                          {v.nota}
                        </Text>
                      )}
                      {v.resumen && (
                        <Text size="xs" fw={500}>
                          {pickLabel(v.resumen)}
                        </Text>
                      )}
                    </Stack>
                    <Group gap={4} wrap="nowrap">
                      <Tooltip label="Ver registro">
                        <ActionIcon
                          variant="light"
                          color="cyan"
                          disabled={!v.resumen}
                          onClick={() =>
                            setViewing({ tabla: v.tabla_relacionada, resumen: v.resumen })
                          }
                        >
                          <IconEye size={16} />
                        </ActionIcon>
                      </Tooltip>
                      {(v.created_by === currentUserId || !currentUserId) && (
                        <Tooltip label="Quitar vínculo">
                          <ActionIcon
                            variant="light"
                            color="red"
                            onClick={() => eliminarVinculo(v.vinculacion_id)}
                          >
                            <IconTrash size={16} />
                          </ActionIcon>
                        </Tooltip>
                      )}
                    </Group>
                  </Group>
                </Paper>
              ))}
            </Stack>
          </Box>
        </Stack>
      </Modal>

      {/* Wizard: crear nuevo vínculo */}
      <Modal
        opened={wizardOpen}
        onClose={() => setWizardOpen(false)}
        title={<Text fw={800}>Vincular registro</Text>}
        size="calc(100vw - 4rem)"
        centered
      >
        <Stack gap="md">
          <Group grow>
            <Select
              label="Área"
              placeholder="Elegí un área"
              data={areas.map((a) => ({ value: a.id, label: a.nombre }))}
              value={areaId}
              onChange={(v) => {
                setAreaId(v);
                setFormSlug(null);
                setCandidatos([]);
                setRegistroElegido(null);
              }}
              searchable
            />
            <Select
              label="Formulario / tabla"
              placeholder="Elegí un módulo"
              data={formulariosDelArea.map((f) => ({ value: f.slug, label: f.nombre }))}
              value={formSlug}
              onChange={(v) => {
                setFormSlug(v);
                setRegistroElegido(null);
                buscarCandidatos(v);
              }}
              disabled={!areaId}
              searchable
            />
          </Group>

          {formSlug && (
            <>
              <TextInput
                placeholder="Buscar registro..."
                leftSection={<IconSearch size={14} />}
                value={busqueda}
                onChange={(e) => setBusqueda(e.currentTarget.value)}
              />
              <Box pos="relative" mih={60}>
                <LoadingOverlay visible={candidatosLoading} />
                {candidatosFiltrados.length === 0 && !candidatosLoading && (
                  <Text size="xs" c="dimmed" ta="center" py="md">
                    Sin resultados. Si esperabas ver algo acá, puede que no
                    tengas acceso de lectura a esta área.
                  </Text>
                )}
                {candidatosFiltrados.length > 0 && (
                  <Table.ScrollContainer minWidth={500} h={280}>
                    <Table
                      stickyHeader
                      highlightOnHover
                      withTableBorder
                      withColumnBorders
                      striped
                    >
                      <Table.Thead>
                        <Table.Tr>
                          {columnasCandidatos.map((col) => (
                            <Table.Th key={col} style={{ whiteSpace: "nowrap" }}>
                              {formatHeader(col)}
                            </Table.Th>
                          ))}
                        </Table.Tr>
                      </Table.Thead>
                      <Table.Tbody>
                        {candidatosFiltrados.map((row) => (
                          <Table.Tr
                            key={row.id}
                            onClick={() => setRegistroElegido(row)}
                            bg={
                              registroElegido?.id === row.id
                                ? "var(--mantine-color-cyan-light)"
                                : undefined
                            }
                            style={{ cursor: "pointer" }}
                          >
                            {columnasCandidatos.map((col) => (
                              <Table.Td
                                key={col}
                                style={{
                                  maxWidth: 220,
                                  overflow: "hidden",
                                  textOverflow: "ellipsis",
                                  whiteSpace: "nowrap",
                                }}
                              >
                                {formatCellValue(row[col])}
                              </Table.Td>
                            ))}
                          </Table.Tr>
                        ))}
                      </Table.Tbody>
                    </Table>
                  </Table.ScrollContainer>
                )}
              </Box>
              {registroElegido && (
                <Text size="xs" c="dimmed">
                  Elegido: <b>{pickLabel(registroElegido)}</b>
                </Text>
              )}
            </>
          )}

          {registroElegido && (
            <>
              <Divider label="Datos del vínculo (opcional)" />
              <TextInput
                label="Tipo de relación"
                placeholder='Ej: "relacionado con", "mismo operativo"'
                value={tipoRelacion}
                onChange={(e) => setTipoRelacion(e.currentTarget.value)}
              />
              <Textarea
                label="Nota"
                placeholder="Observación libre"
                value={nota}
                onChange={(e) => setNota(e.currentTarget.value)}
                autosize
                minRows={2}
              />
              <Group justify="flex-end">
                <Button
                  color="cyan"
                  leftSection={<IconArrowRight size={14} />}
                  loading={guardando}
                  onClick={confirmarVinculo}
                >
                  Confirmar vínculo
                </Button>
              </Group>
            </>
          )}
        </Stack>
      </Modal>

      {/* Visor de solo lectura del registro relacionado */}
      <Modal
        opened={!!viewing}
        onClose={() => setViewing(null)}
        title={<Text fw={800}>Vista del registro relacionado</Text>}
        size="xl"
        centered
      >
        {viewing && (
          <FormularioDinamico
            slug={viewing.tabla}
            initialData={viewing.resumen}
            readOnly
          />
        )}
      </Modal>
    </>
  );
}
