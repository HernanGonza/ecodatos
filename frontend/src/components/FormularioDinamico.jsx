import { useEffect, useState } from "react";
import {
  Box,
  Button,
  TextInput,
  NumberInput,
  Select,
  LoadingOverlay,
  Text,
  Title,
  Paper,
  SimpleGrid,
  Group,
  Stack,
  ScrollArea,
  ThemeIcon,
  Divider,
  Badge,
  Modal,
  ActionIcon,
} from "@mantine/core";
import { useDisclosure } from "@mantine/hooks";
import {
  IconMapPin,
  IconDatabase,
  IconInfoCircle,
  IconDeviceFloppy,
  IconMaximize,
  IconCheck,
  IconPencil,
  IconPlus,
  IconPhoto,
  IconMicrophone,
  IconLink,
} from "@tabler/icons-react";
import { notifications } from "@mantine/notifications";
import { supabase } from "../lib/supabase";
import PanelVinculaciones from "./PanelVinculaciones";
import classes from "./FormularioDinamico.module.css";

// --- IMPORTACIONES PARA EL MAPA ---
import {
  MapContainer,
  TileLayer,
  Marker,
  useMapEvents,
  useMap,
} from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";

// Fix para el icono de Leaflet
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl:
    "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png",
  iconUrl:
    "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png",
  shadowUrl:
    "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png",
});

const parseDmsToDecimal = (dmsStr) => {
  if (!dmsStr) return "";
  const parts = dmsStr.match(/[-+]?([0-9]*\.[0-9]+|[0-9]+)/g);
  if (!parts || parts.length < 3) return "";
  const d = Math.abs(parseFloat(parts[0]));
  const m = parseFloat(parts[1]);
  const s = parseFloat(parts[2]);
  let decimal = d + m / 60 + s / 3600;
  const isNegative =
    /[-SWO]/.test(dmsStr.toUpperCase()) || parseFloat(parts[0]) < 0;
  if (isNegative) decimal *= -1;
  return decimal.toFixed(6);
};

const parseDecimalToDms = (decVal) => {
  const decimal = parseFloat(decVal);
  if (isNaN(decimal)) return "";
  const absDec = Math.abs(decimal);
  const d = Math.floor(absDec);
  const m = Math.floor((absDec - d) * 60);
  const s = ((absDec - d) * 60 - m) * 60;
  const sign = decimal < 0 ? "-" : "";
  return `${sign}${d}° ${m}' ${s.toFixed(2)}"`;
};

const RecenterMap = ({ lat, lon }) => {
  const map = useMap();
  useEffect(() => {
    if (
      lat != null &&
      lon != null &&
      !isNaN(lat) &&
      !isNaN(lon) &&
      isFinite(lat) &&
      isFinite(lon)
    ) {
      map.setView([lat, lon], map.getZoom());
    }
  }, [lat, lon, map]);
  return null;
};

const MapaBase = ({
  lat,
  lon,
  onPositionChange,
  readOnly,
  height = "100%",
}) => {
  const latitude = parseFloat(lat);
  const longitude = parseFloat(lon);

  const safeLat = isNaN(latitude) || !isFinite(latitude) ? -34.6037 : latitude;
  const safeLon =
    isNaN(longitude) || !isFinite(longitude) ? -58.3816 : longitude;

  const MapEvents = () => {
    useMapEvents({
      click(e) {
        if (!readOnly) {
          onPositionChange(e.latlng.lat, e.latlng.lng);
        }
      },
    });
    return null;
  };

  return (
    <MapContainer
      center={[safeLat, safeLon]}
      zoom={15}
      style={{ height: height, width: "100%" }}
      scrollWheelZoom={true}
      attributionControl={false}
    >
      <RecenterMap lat={latitude} lon={longitude} />
      <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
      {!isNaN(latitude) &&
        !isNaN(longitude) &&
        isFinite(latitude) &&
        isFinite(longitude) && (
          <Marker
            position={[latitude, longitude]}
            draggable={!readOnly}
            eventHandlers={{
              dragend: (e) => {
                const marker = e.target;
                const position = marker.getLatLng();
                onPositionChange(position.lat, position.lng);
              },
            }}
          />
        )}
      <MapEvents />
    </MapContainer>
  );
};

const CAMPOS_EXCLUIDOS = [
  "id",
  "created_at",
  "created_by",
  "user_id",
  "formulario_id",
  "updated_at",
  "geom",
  "geometria",
  "geometry",
  "latitud_gms",
  "longitud_gms",
  "latitud_decimal",
  "longitud_decimal",
  "activo",
  "fotos",
  "audios",
  "ciudad_temp",
];

export default function FormularioDinamico({
  slug,
  initialData = null,
  readOnly = false,
  onSuccess,
}) {
  const [fields, setFields] = useState([]);
  const [values, setValues] = useState({});
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [foreignData, setForeignData] = useState({});
  const [opened, { open, close }] = useDisclosure(false);
  const [fotoAmpliada, setFotoAmpliada] = useState(null);
  const [inlineAddModal, setInlineAddModal] = useState({
    open: false,
    field: "",
    table: "",
  });
  const [inlineAddValue, setInlineAddValue] = useState("");
  const [inlineAddLoading, setInlineAddLoading] = useState(false);
  const [foreignDataLoaded, setForeignDataLoaded] = useState(false);

  const [vinculosOpen, setVinculosOpen] = useState(false);
  const [vinculos, setVinculos] = useState([]);

  const fetchVinculos = async () => {
    if (!slug || slug === "users" || !initialData?.id) {
      setVinculos([]);
      return;
    }
    const { data, error } = await supabase.rpc("listar_vinculaciones", {
      p_tabla: slug,
      p_id: initialData.id,
    });
    if (!error) setVinculos(data || []);
  };

  useEffect(() => {
    fetchVinculos();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [slug, initialData?.id]);

  const [isEditingLocally, setIsEditingLocally] = useState(false);
  const isEffectivelyReadOnly = readOnly && !isEditingLocally;

  useEffect(() => {
    setIsEditingLocally(false);
  }, [initialData?.id]);

  // 1. Cargar metadata y datos foráneos
  useEffect(() => {
    const fetchMetadata = async () => {
      setLoading(true);
      setForeignDataLoaded(false);
      try {
        const {
          data: { session },
        } = await supabase.auth.getSession();
        const res = await fetch(
          `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/formulario-metadata?slug=${slug}`,
          { headers: { Authorization: `Bearer ${session.access_token}` } },
        );
        const json = await res.json();
        const filteredFields = (json.fields ?? []).filter(
          (f) => !CAMPOS_EXCLUIDOS.includes(f.campo),
        );
        setFields(filteredFields);

        const fData = {};
        for (const field of filteredFields) {
          if (field.foreign_table) {
            const selectQuery =
              field.foreign_table === "municipios"
                ? "id, nombre, departamento_id"
                : "id, nombre";
            const { data } = await supabase
              .from(field.foreign_table)
              .select(selectQuery)
              .order("nombre", { ascending: true });
            fData[field.campo] = data || [];
          }
        }
        setForeignData(fData);
        setForeignDataLoaded(true);
      } catch (err) {
        console.error(err);
        notifications.show({
          title: "Error",
          message: err.message,
          color: "red.5",
        });
      } finally {
        setLoading(false);
      }
    };
    if (slug) fetchMetadata();
  }, [slug]);

  // 2. Cargar datos del formulario (con reparación de campos faltantes)
  useEffect(() => {
    const loadData = async () => {
      if (foreignDataLoaded) {
        let finalData = initialData ? { ...initialData } : {};

        // 🔧 REPARACIÓN: Si estamos en modo edición, obtenemos el registro completo
        // de la BD por si la vista de lista (universal-list) omitió campos como departamento_id
        if (initialData?.id && slug) {
          try {
            const tableName = slug.replace(/-/g, "_");
            const { data: fullRecord, error } = await supabase
              .from(tableName)
              .select("*")
              .eq("id", initialData.id)
              .single();

            if (!error && fullRecord) {
              // Fusionamos: priorizamos los datos completos de la BD
              finalData = { ...fullRecord, ...initialData };
            }
          } catch (err) {
            console.error("Error cargando registro completo para edición:", err);
          }
        }

        setValues(finalData);
      }
    };
    loadData();
  }, [foreignDataLoaded, initialData, slug]);

  const handleInputChange = (campo, valor) => {
    setValues((prev) => {
      const next = { ...prev, [campo]: valor };
      if (campo === "departamento_id") next.municipio_id = "";
      if (campo === "latitud_gms") {
        const dec = parseDmsToDecimal(valor);
        if (dec !== "") next.latitud_decimal = dec;
      } else if (campo === "latitud_decimal") {
        next.latitud_gms = parseDecimalToDms(valor);
      } else if (campo === "longitud_gms") {
        const dec = parseDmsToDecimal(valor);
        if (dec !== "") next.longitud_decimal = dec;
      } else if (campo === "longitud_decimal") {
        next.longitud_gms = parseDecimalToDms(valor);
      }
      return next;
    });
  };

  const handleMapMove = (lat, lon) => {
    if (isNaN(lat) || isNaN(lon) || !isFinite(lat) || !isFinite(lon)) return;

    setValues((prev) => ({
      ...prev,
      latitud_decimal: lat.toFixed(6),
      longitud_decimal: lon.toFixed(6),
      latitud_gms: parseDecimalToDms(lat),
      longitud_gms: parseDecimalToDms(lon),
    }));
  };

  const handleInlineAdd = async () => {
    if (!inlineAddValue.trim()) return;
    setInlineAddLoading(true);
    try {
      const { data, error } = await supabase
        .from(inlineAddModal.table)
        .insert({ nombre: inlineAddValue.trim(), activo: true })
        .select("id, nombre")
        .single();
      if (error) throw error;
      setForeignData((prev) => ({
        ...prev,
        [inlineAddModal.field]: [...(prev[inlineAddModal.field] || []), data],
      }));
      handleInputChange(inlineAddModal.field, data.id);
      setInlineAddModal({ open: false, field: "", table: "" });
      setInlineAddValue("");
      notifications.show({
        title: "Agregado",
        message: `"${data.nombre}" agregado correctamente`,
        color: "green",
      });
    } catch (err) {
      notifications.show({
        title: "Error",
        message: err.message,
        color: "red",
      });
    } finally {
      setInlineAddLoading(false);
    }
  };

  const handleSubmit = async () => {
    setSubmitting(true);
    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session) throw new Error("No hay sesión activa");

      const isEditing = !!initialData?.id;
      const endpoint = isEditing ? "universal-update" : "universal-create";

      const validFields = new Set([
        ...fields.map((f) => f.campo),
        "user_id",
        "formulario_id",
        "created_by",
        "activo",
        "latitud_decimal",
        "longitud_decimal",
        "departamento_id",
        "municipio_id",
      ]);

      const systemKeys = [
        "id",
        "created_at",
        "updated_at",
        "geom",
        "geometria",
        "geometry",
        "slug",
        "area_id",
      ];

      const cleanData = Object.fromEntries(
        Object.entries(values).filter(
          ([key]) => validFields.has(key) && !systemKeys.includes(key),
        ),
      );

      const dataFinal = {
        ...cleanData,
        ...(!isEditing && { user_id: session.user.id }),
        latitud_decimal: values.latitud_decimal
          ? parseFloat(values.latitud_decimal)
          : null,
        longitud_decimal: values.longitud_decimal
          ? parseFloat(values.longitud_decimal)
          : null,
        latitud_gms: values.latitud_gms || null,
        longitud_gms: values.longitud_gms || null,
      };

      const payload = {
        t: slug.replace(/-/g, "_"),
        id: isEditing ? initialData.id : undefined,
        data: dataFinal,
      };

      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/${endpoint}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${session.access_token}`,
          },
          body: JSON.stringify(payload),
        },
      );

      const result = await res.json();
      if (!res.ok) throw new Error(result.error || "Error en el servidor");

      notifications.show({
        title: "Éxito",
        message: "Registro procesado correctamente",
        color: "green.5",
      });
      if (onSuccess) onSuccess();
    } catch (err) {
      console.error("❌ Error en handleSubmit:", err);
      notifications.show({
        title: "Error",
        message: err.message,
        color: "red.5",
      });
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <Box pos="relative" h={400} w="100%">
        <LoadingOverlay
          visible
          zIndex={1000}
          overlayProps={{ blur: 1, backgroundOpacity: 0.1 }}
        />
      </Box>
    );
  }

  return (
    <>
      <Modal
        opened={opened}
        onClose={close}
        size="95%"
        title={<Text fw={700}>Seleccionar ubicación precisa</Text>}
        centered
        styles={{ body: { height: "80vh", padding: 0 } }}
      >
        <Box h="100%" w="100%" pos="relative">
          <MapaBase
            lat={values.latitud_decimal}
            lon={values.longitud_decimal}
            onPositionChange={handleMapMove}
            readOnly={isEffectivelyReadOnly}
          />
          <Button
            onClick={close}
            pos="absolute"
            bottom={20}
            right={20}
            style={{ zIndex: 1000 }}
            color="green"
            leftSection={<IconCheck size={18} />}
          >
            Confirmar Ubicación
          </Button>
        </Box>
      </Modal>

      <ScrollArea h="100%" scrollbarSize={6}>
        <Box p="xl" pos="relative">
          <Stack gap="xl">
            <Box>
              <Title order={2} className={classes.title} mb={8}>
                {isEffectivelyReadOnly
                  ? "Vista de Registro"
                  : initialData?.id
                    ? "Editar Registro"
                    : "Nuevo Registro"}
              </Title>
              <Group gap="xs" mb={8}>
                <Badge variant="dot" color="cyan.5" size="lg" radius="sm">
                  {slug.replace(/[-_]/g, " ").toUpperCase()}
                </Badge>
                {initialData?.id && (
                  <Button
                    variant="light"
                    color={isEffectivelyReadOnly ? "cyan.6" : "gray.6"}
                    size="xs"
                    radius="md"
                    leftSection={<IconPencil size={14} />}
                    onClick={() => setIsEditingLocally((v) => !v)}
                  >
                    {isEffectivelyReadOnly
                      ? "EDITAR ESTE REGISTRO"
                      : "VOLVER A LECTURA"}
                  </Button>
                )}
              </Group>
              <Text size="sm" c="gray.5" fw={500}>
                {isEffectivelyReadOnly ? (
                  "Vista de solo lectura. Usá el botón para habilitar la edición."
                ) : (
                  <>
                    Complete los campos requeridos para la gestión de datos en
                    la tabla{" "}
                    <Text component="span" c="cyan.4" fw={700}>
                      {slug.replace(/[-_]/g, " ")}
                    </Text>
                    .
                  </>
                )}
              </Text>
            </Box>

            {initialData?.id && slug !== "users" && (
              <Paper withBorder p="sm" radius="md">
                <Group justify="space-between" wrap="wrap" gap="xs">
                  <Group gap="xs" wrap="wrap">
                    <IconLink size={16} />
                    <Text size="sm" fw={700}>
                      {vinculos.length > 0
                        ? `${vinculos.length} vínculo${vinculos.length > 1 ? "s" : ""}`
                        : "Sin vínculos"}
                    </Text>
                    {vinculos.map((v) => (
                      <Badge
                        key={v.vinculacion_id}
                        variant="light"
                        color="grape"
                        size="sm"
                      >
                        {v.area_nombre || v.tabla_relacionada}
                      </Badge>
                    ))}
                  </Group>
                  <Button
                    variant="light"
                    color="grape"
                    size="xs"
                    leftSection={<IconLink size={14} />}
                    onClick={() => setVinculosOpen(true)}
                  >
                    Vínculos
                  </Button>
                </Group>
              </Paper>
            )}

            <Divider color="gray.8" />

            <SimpleGrid cols={{ base: 1, md: 2 }} spacing="lg">
              {fields.map((f) => {
                const isBoolean = f.tipo === "boolean";
                const isTime =
                  f.tipo === "time without time zone" ||
                  f.tipo === "time" ||
                  f.tipo === "time with time zone";
                const isDate =
                  f.tipo === "date" || f.tipo?.includes("timestamp");
                const isNumber =
                  f.tipo === "integer" ||
                  f.tipo === "numeric" ||
                  f.tipo === "double precision";

                const commonProps = {
                  label: f.label || f.campo.replace(/_/g, " ").toUpperCase(),
                  disabled: isEffectivelyReadOnly,
                  required: f.requerido,
                  classNames: {
                    input: classes.inputField,
                    label: classes.label,
                  },
                };

                if (f.foreign_table || foreignData[f.campo]) {
                  let opciones = foreignData[f.campo] || [];
                  let deshabilitado = false;
                  if (f.campo === "municipio_id") {
                    const deptoId = values.departamento_id;
                    if (!deptoId) {
                      opciones = [];
                      deshabilitado = true;
                    } else {
                      opciones = opciones.filter(
                        (m) => String(m.departamento_id) === String(deptoId),
                      );
                    }
                  }

                  const allowsInlineAdd =
                    f.foreign_table === "tipo_actividad_impacto_ambiental";

                  return (
                    <Group key={f.campo} gap="xs" align="flex-end">
                      <Select
                        style={{ flex: 1 }}
                        {...commonProps}
                        placeholder={
                          deshabilitado
                            ? "Seleccione Departamento"
                            : "Seleccionar..."
                        }
                        value={values[f.campo] ? String(values[f.campo]) : null}
                        onChange={(val) => handleInputChange(f.campo, val)}
                        data={opciones.map((opt) => ({
                          value: String(opt.id),
                          label: String(
                            opt.nombre || opt.descripcion || opt.id,
                          ),
                        }))}
                        disabled={isEffectivelyReadOnly || deshabilitado}
                        searchable
                        clearable
                        required
                      />
                      {allowsInlineAdd && !isEffectivelyReadOnly && (
                        <ActionIcon
                          variant="light"
                          color="cyan"
                          size="lg"
                          onClick={() =>
                            setInlineAddModal({
                              open: true,
                              field: f.campo,
                              table: f.foreign_table,
                            })
                          }
                        >
                          <IconPlus size={16} />
                        </ActionIcon>
                      )}
                    </Group>
                  );
                }

                if (isBoolean) {
                  return (
                    <Select
                      key={f.campo}
                      {...commonProps}
                      value={
                        values[f.campo] === true
                          ? "true"
                          : values[f.campo] === false
                            ? "false"
                            : ""
                      }
                      onChange={(val) =>
                        handleInputChange(
                          f.campo,
                          val === "" ? null : val === "true",
                        )
                      }
                      data={[
                        { value: "true", label: "SI" },
                        { value: "false", label: "NO" },
                      ]}
                      clearable
                    />
                  );
                }

                if (isTime) {
                  return (
                    <TextInput
                      key={f.campo}
                      {...commonProps}
                      type="time"
                      value={values[f.campo] || ""}
                      onChange={(e) =>
                        handleInputChange(f.campo, e.target.value)
                      }
                      step="1"
                    />
                  );
                }

                if (isDate) {
                  return (
                    <TextInput
                      key={f.campo}
                      {...commonProps}
                      type="date"
                      value={values[f.campo] || ""}
                      onChange={(e) =>
                        handleInputChange(f.campo, e.target.value)
                      }
                    />
                  );
                }

                if (isNumber) {
                  return (
                    <NumberInput
                      key={f.campo}
                      {...commonProps}
                      value={values[f.campo] ?? ""}
                      onChange={(val) => handleInputChange(f.campo, val)}
                      precision={f.tipo === "double precision" ? 6 : 0}
                      hideControls
                    />
                  );
                }

                return (
                  <TextInput
                    key={f.campo}
                    {...commonProps}
                    value={values[f.campo] || ""}
                    onChange={(e) => handleInputChange(f.campo, e.target.value)}
                  />
                );
              })}
            </SimpleGrid>

            <Paper className={classes.geoPaper} p="xl" radius="md">
              <Group mb="xl" justify="space-between">
                <Group gap="xs">
                  <ThemeIcon variant="light" color="cyan.5" radius="md">
                    <IconMapPin size={20} />
                  </ThemeIcon>
                  <Title order={4} className={classes.geoTitle}>
                    GEOPOSICIONAMIENTO
                  </Title>
                </Group>
                <ActionIcon
                  variant="light"
                  color="cyan.5"
                  size="lg"
                  onClick={open}
                  title="Agrandar mapa"
                >
                  <IconMaximize size={22} />
                </ActionIcon>
              </Group>

              <SimpleGrid cols={{ base: 1, md: 2 }} spacing="xl">
                <Stack gap="lg">
                  <Box>
                    <Text size="xs" fw={700} c="gray.5" mb={8} lts="1px">
                      LATITUD
                    </Text>
                    <Group grow gap="xs">
                      <TextInput
                        placeholder="GMS"
                        value={values.latitud_gms || ""}
                        onChange={(e) =>
                          handleInputChange("latitud_gms", e.target.value)
                        }
                        disabled={isEffectivelyReadOnly}
                        classNames={{ input: classes.inputField }}
                      />
                      <NumberInput
                        placeholder="Decimal"
                        value={values.latitud_decimal ?? ""}
                        onChange={(val) => {
                          if (val === null || val === "") {
                            handleInputChange("latitud_decimal", "");
                          } else if (!isNaN(val) && isFinite(val)) {
                            handleInputChange("latitud_decimal", val);
                          }
                        }}
                        disabled={isEffectivelyReadOnly}
                        precision={6}
                        hideControls
                        classNames={{ input: classes.inputField }}
                      />
                    </Group>
                  </Box>

                  <Box>
                    <Text size="xs" fw={700} c="gray.5" mb={8} lts="1px">
                      LONGITUD
                    </Text>
                    <Group grow gap="xs">
                      <TextInput
                        placeholder="GMS"
                        value={values.longitud_gms || ""}
                        onChange={(e) =>
                          handleInputChange("longitud_gms", e.target.value)
                        }
                        disabled={isEffectivelyReadOnly}
                        classNames={{ input: classes.inputField }}
                      />
                      <NumberInput
                        placeholder="Decimal"
                        value={values.longitud_decimal ?? ""}
                        onChange={(val) => {
                          if (val === null || val === "") {
                            handleInputChange("longitud_decimal", "");
                          } else if (!isNaN(val) && isFinite(val)) {
                            handleInputChange("longitud_decimal", val);
                          }
                        }}
                        disabled={isEffectivelyReadOnly}
                        precision={6}
                        hideControls
                        classNames={{ input: classes.inputField }}
                      />
                    </Group>
                  </Box>

                  {!isEffectivelyReadOnly && (
                    <Group gap="xs" mt="sm">
                      <IconInfoCircle
                        size={14}
                        color="var(--mantine-color-gray-6)"
                      />
                      <Text size="xs" c="gray.6" fs="italic">
                        Puedes mover el marcador o expandir el mapa para más
                        precisión.
                      </Text>
                    </Group>
                  )}
                </Stack>

                <Box
                  h={250}
                  pos="relative"
                  style={{ borderRadius: "8px", overflow: "hidden" }}
                >
                  {values.latitud_decimal && values.longitud_decimal ? (
                    <MapaBase
                      lat={values.latitud_decimal}
                      lon={values.longitud_decimal}
                      onPositionChange={handleMapMove}
                      readOnly={isEffectivelyReadOnly}
                    />
                  ) : (
                    <Paper
                      h="100%"
                      radius="md"
                      withBorder
                      p="md"
                      ta="center"
                      className={classes.mapPlaceholder}
                    >
                      <Stack align="center" justify="center" h="100%" gap="xs">
                        <IconMapPin
                          size={32}
                          color="var(--mantine-color-gray-7)"
                        />
                        <Text c="gray.6" size="sm" fw={500}>
                          Esperando coordenadas válidas...
                        </Text>
                      </Stack>
                    </Paper>
                  )}
                </Box>
              </SimpleGrid>
            </Paper>

            {initialData?.id &&
              (values.fotos?.length > 0 || values.audios?.length > 0) && (
                <Paper className={classes.geoPaper} p="xl" radius="md">
                  <Group gap="xs" mb="lg">
                    <ThemeIcon variant="light" color="cyan.5" radius="md">
                      <IconPhoto size={20} />
                    </ThemeIcon>
                    <Title order={4} className={classes.geoTitle}>
                      FOTOS Y AUDIOS
                    </Title>
                  </Group>
                  <Text size="xs" c="gray.6" mb="md">
                    Capturados desde la app móvil. Solo lectura.
                  </Text>

                  {values.fotos?.length > 0 && (
                    <Box mb={values.audios?.length > 0 ? "lg" : 0}>
                      <Text size="xs" fw={700} c="gray.5" mb={8} lts="1px">
                        FOTOS ({values.fotos.length})
                      </Text>
                      <Group gap="sm">
                        {values.fotos.map((url, i) => (
                          <Box
                            key={i}
                            onClick={() => setFotoAmpliada(url)}
                            style={{
                              width: 84,
                              height: 84,
                              borderRadius: 8,
                              overflow: "hidden",
                              cursor: "pointer",
                              border: "1px solid var(--mantine-color-gray-7)",
                            }}
                          >
                            <img
                              src={url}
                              alt={`Foto ${i + 1}`}
                              style={{
                                width: "100%",
                                height: "100%",
                                objectFit: "cover",
                              }}
                            />
                          </Box>
                        ))}
                      </Group>
                    </Box>
                  )}

                  {values.audios?.length > 0 && (
                    <Box>
                      <Text size="xs" fw={700} c="gray.5" mb={8} lts="1px">
                        NOTAS DE VOZ ({values.audios.length})
                      </Text>
                      <Stack gap="xs">
                        {values.audios.map((url, i) => (
                          <Group key={i} gap="xs" wrap="nowrap">
                            <ThemeIcon
                              variant="light"
                              color="cyan.5"
                              size="sm"
                              radius="xl"
                            >
                              <IconMicrophone size={12} />
                            </ThemeIcon>
                            <audio
                              controls
                              src={url}
                              style={{ height: 32, flex: 1 }}
                            />
                          </Group>
                        ))}
                      </Stack>
                    </Box>
                  )}
                </Paper>
              )}

            {!isEffectivelyReadOnly && (
              <Button
                className={classes.submitButton}
                onClick={handleSubmit}
                loading={submitting}
                size="lg"
                fullWidth
                leftSection={<IconDeviceFloppy size={20} />}
              >
                {initialData?.id
                  ? "GUARDAR ACTUALIZACIÓN"
                  : "REGISTRAR INFORMACIÓN"}
              </Button>
            )}
          </Stack>
        </Box>
      </ScrollArea>
      <Modal
        opened={inlineAddModal.open}
        onClose={() => {
          setInlineAddModal({ open: false, field: "", table: "" });
          setInlineAddValue("");
        }}
        title={<Text fw={700}>Agregar nueva opción</Text>}
        centered
        size="sm"
      >
        <Stack gap="md">
          <TextInput
            label="Nombre"
            placeholder="Escribí el nombre..."
            value={inlineAddValue}
            onChange={(e) => setInlineAddValue(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleInlineAdd()}
            autoFocus
            classNames={{ input: classes.inputField, label: classes.label }}
          />
          <Group justify="flex-end">
            <Button
              variant="subtle"
              color="gray"
              onClick={() => {
                setInlineAddModal({ open: false, field: "", table: "" });
                setInlineAddValue("");
              }}
            >
              Cancelar
            </Button>
            <Button
              color="cyan"
              onClick={handleInlineAdd}
              loading={inlineAddLoading}
              disabled={!inlineAddValue.trim()}
            >
              Agregar
            </Button>
          </Group>
        </Stack>
      </Modal>

      <Modal
        opened={!!fotoAmpliada}
        onClose={() => setFotoAmpliada(null)}
        size="auto"
        centered
        withCloseButton
        padding={0}
        styles={{ body: { lineHeight: 0 } }}
      >
        {fotoAmpliada && (
          <img
            src={fotoAmpliada}
            alt="Foto ampliada"
            style={{ maxWidth: "90vw", maxHeight: "85vh", display: "block" }}
          />
        )}
      </Modal>

      <PanelVinculaciones
        tabla={slug}
        registroId={initialData?.id}
        opened={vinculosOpen}
        onClose={() => {
          setVinculosOpen(false);
          fetchVinculos();
        }}
      />
    </>
  );
}