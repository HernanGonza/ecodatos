import { useEffect, useState, useCallback, useMemo, useRef } from "react";
import {
  Box,
  Title,
  SimpleGrid,
  Card,
  Button,
  Group,
  Text,
  Badge,
  Modal,
  PasswordInput,
  ScrollArea,
  Paper,
  Stack,
  Drawer,
  ActionIcon,
  useMantineColorScheme,
  Container,
  ThemeIcon,
  List,
  LoadingOverlay,
} from "@mantine/core";
import {
  IconFolder,
  IconFileText,
  IconUsers,
  IconLogout,
  IconPlus,
  IconTable,
  IconChartBar,
  IconPencil,
  IconEye,
  IconCheck,
  IconX,
  IconLock,
  IconUserPlus,
  IconSettingsAutomation,
  IconDownload,
  IconMap2,
  IconUpload,
} from "@tabler/icons-react";
import { notifications } from "@mantine/notifications";
import { useNavigate, useMatch } from "react-router-dom";
import { supabase } from "../lib/supabase";
import { useAuth } from "../context/AuthContext";

// Componentes propios
import TablaDinamica from "../components/TablaDinamica";
import ThemeSwitcher from "../components/ThemeSwitcher";
import FormularioDinamico from "../components/FormularioDinamico";
import FormularioUsuario from "../components/FormularioUsuario";
import VisualizacionEstadisticas from "../components/VisualizacionEstadisticas";
import FormularioSolicitud from "../components/FormularioSolicitud";
import MisSolicitudes from "../components/MisSolicitudes";
import TablaSolicitudes from "../components/TablaSolicitudes";
import CrearFormulario from "../components/CrearFormulario";
import SubirAppMovil from "../components/SubirAppMovil";
import classes from "./Formularios.module.css";

export default function Formularios() {
  const { signOut, user } = useAuth();
  const { colorScheme } = useMantineColorScheme();
  const isDark = colorScheme === "dark";
  const navigate = useNavigate();
  const tablaRef = useRef(null);
  

  // --- LEER URL ---
  const matchNuevoDesdeTabla = useMatch("/formularios/area/:areaKey/tabla/:formSlug/nuevo")
  const matchArea        = useMatch("/formularios/area/:areaKey");
  const matchTabla       = useMatch("/formularios/area/:areaKey/tabla/:formSlug");
  const matchStats       = useMatch("/formularios/area/:areaKey/stats/:formSlug");
  const matchRegistro    = useMatch("/formularios/area/:areaKey/tabla/:formSlug/registro/:recordId");
  const matchRegistroVer = useMatch("/formularios/area/:areaKey/tabla/:formSlug/registro/:recordId/ver");
  const matchNuevo       = useMatch("/formularios/area/:areaKey/nuevo/:formSlug");
  const matchSolicitud   = useMatch("/formularios/solicitud");
  const matchMisSol      = useMatch("/formularios/mis-solicitudes");
  const matchSolAdmin    = useMatch("/formularios/solicitudes-admin");
  const matchCrearModulo = useMatch("/formularios/crear-modulo");
  const matchUsersTabla  = useMatch("/formularios/usuarios/tabla");
  const matchUsersNuevo     = useMatch("/formularios/usuarios/nuevo");
  const matchUsersRegistro    = useMatch("/formularios/usuarios/registro/:recordId");
  const matchUsersRegistroVer = useMatch("/formularios/usuarios/registro/:recordId/ver");
  const [mobileApps, setMobileApps] = useState([]);
  const [subirAppOpen, setSubirAppOpen] = useState(false);


  // Parámetros activos — los matches más específicos tienen prioridad
  const activeAreaKey = matchRegistroVer?.params.areaKey
    || matchRegistro?.params.areaKey
    || matchNuevo?.params.areaKey
    || matchTabla?.params.areaKey
    || matchStats?.params.areaKey
    || matchArea?.params.areaKey;

  const activeFormSlug = matchRegistroVer?.params.formSlug
    || matchRegistro?.params.formSlug
    || matchNuevo?.params.formSlug
    || matchTabla?.params.formSlug
    || matchStats?.params.formSlug;

  // Flags de apertura
  const areaModalOpen              = !!(matchArea || matchTabla || matchStats || matchRegistro || matchRegistroVer || matchNuevo);
  const tableDrawerOpen = !!(matchTabla || matchRegistro || matchRegistroVer || matchNuevoDesdeTabla || matchUsersTabla || matchUsersRegistro || matchUsersRegistroVer)
  const statsDrawerOpen            = !!matchStats;
  const formDrawerOpen = !!(matchRegistro || matchRegistroVer || matchNuevo || matchNuevoDesdeTabla || matchUsersNuevo || matchUsersRegistro || matchUsersRegistroVer)
  const solicitudDrawerOpen        = !!matchSolicitud;
  const misSolicitudesDrawerOpen   = !!matchMisSol;
  const solicitudesAdminDrawerOpen = !!matchSolAdmin;
  const crearModuloDrawerOpen      = !!matchCrearModulo;

  // --- ESTADOS ---
  const [formularios, setFormularios] = useState([]);
  const [areas, setAreas] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedForm, setSelectedForm] = useState(null);
  const [selectedArea, setSelectedArea] = useState(null);
  const [userRole, setUserRole] = useState(null);
  const [displayName, setDisplayName] = useState("");
  

  // --- ESTADOS PASSWORD ---
  const [showPasswordModal, setShowPasswordModal] = useState(false);
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [isUpdatingPass, setIsUpdatingPass] = useState(false);

  const [selectedRecord, setSelectedRecord] = useState(null);
  const [isFetchingRecord, setIsFetchingRecord] = useState(false);
  const [isReadOnly, setIsReadOnly] = useState(false);

  // --- HELPERS DE NAVEGACIÓN ---
  const closeAll    = useCallback(() => navigate("/formularios"), [navigate]);

  const closeDrawer = useCallback(() => {
    if (matchRegistro || matchRegistroVer) {
      // Desde edición/vista en tabla → volver a la tabla
      const p = matchRegistro?.params || matchRegistroVer?.params;
      navigate(`/formularios/area/${p.areaKey}/tabla/${p.formSlug}`);
    } else if (matchNuevo) {
      // Desde nuevo en modal → volver al modal del área
      navigate(`/formularios/area/${matchNuevo.params.areaKey}`);
    } else if (matchTabla) {
      navigate(`/formularios/area/${matchTabla.params.areaKey}`);
    } else if (matchStats) {
      navigate(`/formularios/area/${matchStats.params.areaKey}`);
    } else if (matchUsersRegistro || matchUsersRegistroVer) {
      // Editar/ver usuario desde tabla → volver a la tabla
      navigate("/formularios/usuarios/tabla");
    } else if (matchUsersNuevo) {
      // Nuevo usuario desde card → volver al inicio (no a la tabla)
      navigate("/formularios");
    } 
     else if (matchNuevoDesdeTabla) {
  navigate(`/formularios/area/${matchNuevoDesdeTabla.params.areaKey}/tabla/${matchNuevoDesdeTabla.params.formSlug}`)
}
    else if (matchUsersTabla) {
      navigate("/formularios");
    } 
    else {
      navigate("/formularios");
    }
  }, [navigate, matchRegistro, matchRegistroVer, matchNuevo, matchNuevoDesdeTabla, matchTabla, matchStats, matchUsersNuevo, matchUsersTabla, matchUsersRegistro, matchUsersRegistroVer]);

  // --- TRANSICIÓN CUSTOM PARA DRAWERS ---
  const drawerTransition = {
    transition: "scale-x",
    duration: 400,
    timingFunction: "cubic-bezier(.08,.52,.52,1)",
  };

  // --- LÓGICA DE VALIDACIÓN DE PASSWORD ---
  const passChecks = {
    length: newPassword.length >= 8,
    upper: /[A-Z]/.test(newPassword),
    number: /[0-9]/.test(newPassword),
    special: /[!@#$%^&*(),.?":{}|<>]/.test(newPassword),
    match: newPassword === confirmPassword && newPassword.length > 0,
  };
  const isPassValid = Object.values(passChecks).every(Boolean);

 const fetchMobileApps = useCallback(async () => {
  try {
    const { data, error } = await supabase
      .from('mobile_apps')
      .select('*')
      .eq('activo', true)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error al cargar apps móviles:', error);
      return;
    }

    setMobileApps(data || []);
  } catch (err) {
    console.error('Error fetching mobile apps:', err);
  }
}, []);   // ← vacío está bien

  // Una sola app (EcoAlerta) para todas las áreas: tomamos la versión activa más reciente.
  const appMovilActual = mobileApps[0] || null;
  const appMovilUrl = appMovilActual
    ? supabase.storage.from("apks").getPublicUrl(appMovilActual.apk_path).data.publicUrl
    : null;

  // --- LÓGICA DE DATOS ---
  const fetchData = useCallback(async () => {
    try {
      if (!user) return;

      const {
        data: { user: freshUser },
      } = await supabase.auth.getUser();

      if (freshUser) {
        setDisplayName(
          freshUser.user_metadata?.full_name || freshUser.email?.split("@")[0],
        );

        const metadata = freshUser.user_metadata || {};

        if (
          metadata.password_changed === false ||
          metadata.needs_password_update === true
        ) {
          setShowPasswordModal(true);
        }
      }

      // 1. Obtener Rol
      const { data: roleRes } = await supabase
        .from("usuarios_rol")
        .select(`roles!rol_id ( key )`)
        .eq("user_id", user.id)
        .maybeSingle();

      const finalRole = roleRes?.roles?.key || "usuario";
      setUserRole(finalRole);

      // 2. Cargar Áreas y Formularios
      const isPrivileged = finalRole === "superadmin" || finalRole === "admin";

if (isPrivileged) {
  const [areasRes, formsRes] = await Promise.all([
    supabase.from("areas").select("*").eq("activo", true).order("nombre"),
    supabase
      .from("formularios")
      .select("*")
      .eq("activo", true)
      .order("nombre"),
  ]);
  setAreas(areasRes.data || []);
  setFormularios(
    formsRes.data?.map((f) => ({ ...f, es_editor: true })) || [],
  );
} else {
  const { data: assignedForms, error: assignedError } = await supabase
    .from("usuarios_formularios")
    .select(`
      es_editor,
      formularios!formulario_id (
        *,
        areas!area_id (*)
      )
    `)
    .eq("user_id", user.id);

  if (!assignedError && assignedForms) {
    const forms = assignedForms
      .filter((f) => f.formularios?.activo)
      .map((f) => ({
        ...f.formularios,
        es_editor: f.es_editor,
      }));

    setFormularios(forms);

    const uniqueAreas = [];
    const areaIds = new Set();
    forms.forEach((f) => {
      if (f.areas && !areaIds.has(f.areas.id)) {
        areaIds.add(f.areas.id);
        uniqueAreas.push(f.areas);
      }
    });
    setAreas(uniqueAreas);
  }
}

// ←←← Mover aquí: cargar apps SIEMPRE
await fetchMobileApps();
    } catch (err) {
      console.error("Falla carga de datos:", err);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const formsByArea = useMemo(() => {
    return formularios.reduce((acc, form) => {
      if (!acc[form.area_id]) acc[form.area_id] = [];
      acc[form.area_id].push(form);
      return acc;
    }, {});
  }, [formularios]);

  // --- SINCRONIZAR selectedArea, selectedForm y selectedRecord desde URL al recargar ---
  useEffect(() => {
    if (loading) return;

    if (activeAreaKey && areas.length > 0) {
      const area = areas.find((a) => a.key === activeAreaKey);
      if (area) setSelectedArea({ ...area, forms: formsByArea[area.id] || [] });
    }

    if (activeFormSlug && formularios.length > 0) {
      const form = formularios.find((f) => f.slug === activeFormSlug);
      if (form) setSelectedForm(form);
    }

    // Usuarios — setear selectedForm para todas las rutas de usuario
    // Se hace antes del fetch del registro para que el render nunca lea .slug sobre null
    if (matchUsersRegistroVer || matchUsersRegistro || matchUsersNuevo || matchUsersTabla) {
      if (!selectedForm) {
        setSelectedForm({ id: "users", slug: "users", nombre: "Gestión de Usuarios", es_editor: true });
      }
    }

    // Recuperar registro desde URL al recargar
    const recordId = matchRegistroVer?.params.recordId
      || matchRegistro?.params.recordId
      || matchUsersRegistroVer?.params.recordId
      || matchUsersRegistro?.params.recordId;

    // readOnly = true si la URL termina en /ver
    const urlIsReadOnly = !!(matchRegistroVer || matchUsersRegistroVer);

    if (recordId && !selectedRecord) {
      const fetchRecord = async () => {
        setIsFetchingRecord(true);
        if (matchRegistro || matchRegistroVer) {
          const form = formularios.find((f) => f.slug === activeFormSlug);
          if (!form) return;
          const { data } = await supabase.from(form.slug).select("*").eq("id", recordId).maybeSingle();
          if (data) {
            setSelectedRecord(data);
            setIsReadOnly(urlIsReadOnly || !form.es_editor);
          }
        } else if (matchUsersRegistro || matchUsersRegistroVer) {
          // Llamar a users-list y filtrar por ID para obtener el objeto
          // con la misma estructura que usa FormularioUsuario:
          // { id, full_name→nombre_completo, email, rol_key, rol_id }
          const { data: { session } } = await supabase.auth.getSession();
          if (!session) return;
          const { data: usersList } = await supabase.functions.invoke("users-list", {
            method: "GET",
            headers: { Authorization: `Bearer ${session.access_token}` },
          });
          const found = Array.isArray(usersList)
            ? usersList.find((u) => u.id === recordId)
            : null;
          if (found) {
            // Fetch rol por separado (users-list no lo incluye)
            const { data: rolRow } = await supabase
              .from("usuarios_rol")
              .select("rol_id, roles(id, key, nombre)")
              .eq("user_id", recordId)
              .maybeSingle();

            setSelectedRecord({
              ...found,
              // FormularioUsuario espera nombre_completo
              nombre_completo: found.nombre_completo || found.full_name || "",
              // FormularioUsuario busca por rol_key o rol_id
              rol_id:  rolRow?.rol_id ?? found.rol_id ?? null,
              rol_key: rolRow?.roles?.key ?? found.rol_key ?? null,
            });
            setIsReadOnly(urlIsReadOnly);
          }
        }
        setIsFetchingRecord(false);
      };
      fetchRecord();
    }
    if (matchNuevoDesdeTabla && formularios.length > 0) {
  const form = formularios.find(f => f.slug === matchNuevoDesdeTabla.params.formSlug)
  if (form) {
    setSelectedForm(form)
    setSelectedRecord(null)
    setIsReadOnly(false)
  }
}
  }, [loading, activeAreaKey, activeFormSlug, areas, formularios, formsByArea,
      matchUsersTabla, matchUsersNuevo, matchUsersRegistro, matchUsersRegistroVer,
      matchRegistro, matchRegistroVer, matchNuevoDesdeTabla, selectedRecord, fetchMobileApps]);

  // --- HANDLERS UI ---
  const handleNewFromTable = (form) => {
  setSelectedForm(form)
  setSelectedRecord(null)
  setIsReadOnly(false)
  const area = areas.find((a) => a.id === form.area_id)
  if (!area) return
  navigate(`/formularios/area/${area.key}/tabla/${form.slug}/nuevo`)
}

  const handleOpenArea = (areaId) => {
    const areaObj = areas.find((a) => a.id === areaId);
    setSelectedArea({ ...areaObj, forms: formsByArea[areaId] });
    navigate(`/formularios/area/${areaObj.key}`);
  };

  const handleOpenTable = (form) => {
    setSelectedForm(form);
    if (form.slug === "users") {
      navigate("/formularios/usuarios/tabla");
    } else {
      const area = areas.find((a) => a.id === form.area_id);
      if (area) navigate(`/formularios/area/${area.key}/tabla/${form.slug}`);
    }
  };

  const handleOpenForm = (form, record = null, readOnly = false) => {
    setSelectedForm(form);
    setSelectedRecord(record);
    setIsReadOnly(readOnly);
    if (form.slug === "users") {
      if (record) {
        const base = `/formularios/usuarios/registro/${record.id}`;
        navigate(readOnly ? `${base}/ver` : base);
      } else {
        navigate("/formularios/usuarios/nuevo");
      }
    } else {
      const area = areas.find((a) => a.id === form.area_id);
      if (!area) return;
      if (record) {
        const base = `/formularios/area/${area.key}/tabla/${form.slug}/registro/${record.id}`;
        navigate(readOnly ? `${base}/ver` : base);
      } else {
        navigate(`/formularios/area/${area.key}/nuevo/${form.slug}`);
      }
    }
  };

  const handleOpenStats = (form) => {
    setSelectedForm(form);
    const area = areas.find((a) => a.id === form.area_id);
    if (area) navigate(`/formularios/area/${area.key}/stats/${form.slug}`);
  };

  const handleUpdatePassword = async () => {
    if (!isPassValid) return;

    setIsUpdatingPass(true);

    const { error } = await supabase.auth.updateUser({
      password: newPassword,
      data: {
        password_changed: true,
        needs_password_update: false,
      },
    });

    if (error) {
      notifications.show({
        title: "Error",
        message: error.message,
        color: "red",
      });
    } else {
      notifications.show({
        title: "Éxito",
        message: "Contraseña actualizada correctamente",
        color: "green",
      });
      setShowPasswordModal(false);
    }
    setIsUpdatingPass(false);
  };

  // Componente interno para mostrar los requisitos
  const Requirement = ({ met, label }) => (
    <Group gap={8} mb={4}>
      <ThemeIcon color={met ? "teal.6" : "gray.5"} size={14} radius="xl">
        {met ? <IconCheck size={10} /> : <IconX size={10} />}
      </ThemeIcon>
      <Text size="xs" c={met ? "teal.6" : "dimmed"} fw={met ? 700 : 400}>
        {label}
      </Text>
    </Group>
  );

  if (loading) return null;

  return (
    <Box
      style={{ minHeight: '100vh' }}
      bg={isDark ? "gray.9" : "gray.0"}
      p="md"
      className={classes.mainWrapper}
    >
      <Container size="100%" style={{ maxWidth: "1800px" }}>
        {/* Header */}
        <Group justify="space-between" align="center" mb={40} pt="md">
          <Box>
            <Title
              order={2}
              fw={800}
              lts="-0.5px"
              c={isDark ? "white" : "gray.9"}
              style={{ textTransform: "uppercase" }}
            >
              Panel de Gestión
            </Title>
            <Text size="xs" fw={700} c="cyan.6" lts="1px">
              OBSERVATORIO AMBIENTAL • MISIONES
            </Text>
          </Box>

          <Group gap="lg">
            <ThemeSwitcher />
            <Group gap="xs">
              <Box ta="right">
                <Text size="sm" fw={700} c="cyan.6" style={{ lineHeight: 1.2 }}>
                  {displayName}
                </Text>
                <Badge color="cyan.6" variant="dot" size="xs">
                  {userRole?.toUpperCase()}
                </Badge>
              </Box>
              <ActionIcon
                variant="light"
                color="red.6"
                size="lg"
                radius="md"
                onClick={signOut}
                title="Cerrar Sesión"
              >
                <IconLogout size={20} />
              </ActionIcon>
            </Group>
          </Group>
        </Group>

        <SimpleGrid
          cols={{ base: 1, sm: 2, lg: 3, xl: 4, xxl: 5 }}
          spacing="xl"
        >
          {userRole === "superadmin" && (
            <Card withBorder radius="md" p="xl" className={classes.cardHover}>
              <CustomThemeIcon color="cyan">
                <IconUsers size={22} />
              </CustomThemeIcon>
              <Title order={4} mt="md" mb={4} fw={800}>
                USUARIOS
              </Title>
              <Text size="xs" c="dimmed" mb="xl">
                Control de accesos y perfiles.
              </Text>
              <Group grow gap="xs">
                <Button
                  color="cyan.6"
                  variant="light"
                  size="xs"
                  onClick={() =>
                    handleOpenForm({
                      id: "users",
                      slug: "users",
                      nombre: "Nuevo Usuario",
                      es_editor: true,
                    })
                  }
                >
                  Crear
                </Button>
                <Button
                  color="cyan.6"
                  variant="outline"
                  size="xs"
                  onClick={() =>
                    handleOpenTable({
                      id: "users",
                      nombre: "Gestión de Usuarios",
                      slug: "users",
                      es_editor: true,
                    })
                  }
                >
                  Tabla
                </Button>
                <Button
                  color="orange.6"
                  variant="light"
                  size="xs"
                  onClick={() => navigate("/formularios/solicitudes-admin")}
                >
                  Solicitudes
                </Button>
              </Group>
            </Card>
          )}

          {/* CARD PARA CREACIÓN DE MÓDULOS */}
          {userRole === "superadmin" && (
            <Card withBorder radius="md" p="xl" className={classes.cardHover}>
              <CustomThemeIcon color="cyan">
                <IconSettingsAutomation size={22} />
              </CustomThemeIcon>
              <Title order={4} mt="md" mb={4} fw={800}>
                ESTRUCTURA Y TABLAS
              </Title>
              <Text size="xs" c="dimmed" mb="xl">
                Configura nuevos módulos y genera tablas automáticas en la base
                de datos.
              </Text>
              <Button
                color="cyan.7"
                variant="light"
                fullWidth
                onClick={() => navigate("/formularios/crear-modulo")}
              >
                Configurar Nuevo Módulo
              </Button>
            </Card>
          )}

          {(userRole === "admin" || userRole === "adminArea") && (
            <Card withBorder radius="md" p="xl" className={classes.cardHover}>
              <CustomThemeIcon color="teal">
                <IconUserPlus size={22} />
              </CustomThemeIcon>
              <Title order={4} mt="md" mb={4} fw={800}>
                SOLICITAR ACCESOS
              </Title>
              <Text size="xs" c="dimmed" mb="xl">
                Pedí accesos para usuarios de tu área.
              </Text>
              <Group grow gap="xs">
                <Button
                  color="teal.6"
                  variant="light"
                  size="xs"
                  onClick={() => navigate("/formularios/solicitud")}
                >
                  Nueva
                </Button>
                <Button
                  color="teal.6"
                  variant="outline"
                  size="xs"
                  onClick={() => navigate("/formularios/mis-solicitudes")}
                >
                  Mis solicitudes
                </Button>
              </Group>
            </Card>
          )}

          {/* TARJETA VISOR DE MAPAS — visible para todos */}
<Card withBorder radius="md" p="xl" className={classes.cardHover}>
  <CustomThemeIcon color="teal">
    <IconMap2 size={22} />
  </CustomThemeIcon>
  <Title order={4} mt="md" mb={4} fw={800}>
    VISOR DE MAPAS
  </Title>
  <Text size="xs" c="dimmed" mb="xl">
    Visualizá los datos georeferenciados del observatorio en el mapa interactivo.
  </Text>
  <Button
    color="teal.6"
    variant="light"
    fullWidth
    onClick={() => navigate('/formularios/mapa')}
  >
    Abrir Visor
  </Button>
</Card>

          {/* TARJETA ÚNICA DE APP MÓVIL — siempre visible, con o sin versión publicada */}
          <Card withBorder radius="md" p="xl" className={classes.cardHover}>
            <CustomThemeIcon color="green">
              <IconDownload size={22} />
            </CustomThemeIcon>
            <Group gap="xs" align="center" mt="md" mb={4}>
              <Title order={4} fw={800}>
                {appMovilActual?.nombre?.toUpperCase() || "APP MÓVIL"}
              </Title>
              {appMovilActual?.version && (
                <Badge variant="outline" color="green" size="sm">
                  v{appMovilActual.version}
                </Badge>
              )}
            </Group>
            <Text size="xs" c="dimmed" mb="xl">
              {appMovilActual
                ? appMovilActual.descripcion ||
                  "App para cargar reportes de campo desde el celular, sin conexión."
                : "Acá vas a poder descargar la aplicación móvil apenas publiquemos una versión."}
            </Text>
            <Button
              leftSection={<IconDownload size={16} />}
              color="green.7"
              variant="light"
              fullWidth
              disabled={!appMovilActual}
              onClick={() => appMovilUrl && window.open(appMovilUrl, "_blank")}
            >
              {appMovilActual ? "Descargar APK" : "Todavía no disponible"}
            </Button>
            {userRole === "superadmin" && (
              <Button
                mt="sm"
                leftSection={<IconUpload size={16} />}
                color="cyan.6"
                variant="outline"
                fullWidth
                onClick={() => setSubirAppOpen(true)}
              >
                Subir nueva versión
              </Button>
            )}
          </Card>

          {areas.map((area) => {
            const formsDeEstaArea = formsByArea[area.id] || [];
            const tienePermisoEdicion = formsDeEstaArea.some(
              (f) => f.es_editor,
            );

            return (
              <Card
                key={area.id}
                withBorder
                radius="md"
                p="xl"
                className={classes.cardHover}
                onClick={() => handleOpenArea(area.id)}
                style={{
                  cursor: "pointer",
                  borderTop: tienePermisoEdicion
                    ? "4px solid var(--mantine-color-cyan-6)"
                    : "4px solid var(--mantine-color-blue-5)",
                }}
              >
                <Group justify="space-between" align="flex-start">
                  <CustomThemeIcon
                    color={tienePermisoEdicion ? "cyan" : "blue"}
                  >
                    {tienePermisoEdicion ? (
                      <IconPencil size={22} />
                    ) : (
                      <IconEye size={22} />
                    )}
                  </CustomThemeIcon>
                  <Stack align="flex-end" gap={4}>
                    <Badge
                      variant="light"
                      color={tienePermisoEdicion ? "cyan.6" : "blue.6"}
                      size="sm"
                      fw={800}
                    >
                      {formsDeEstaArea.length}{" "}
                      {formsDeEstaArea.length === 1 ? "FORM" : "FORMS"}
                    </Badge>
                    {!tienePermisoEdicion && (
                      <Badge variant="dot" color="blue.4" size="xs" fw={700}>
                        SÓLO LECTURA
                      </Badge>
                    )}
                  </Stack>
                </Group>
                <Title order={4} mt="md" mb={4} fw={800}>
                  {area.nombre.toUpperCase()}
                </Title>
                <Text size="xs" c="dimmed">
                  {tienePermisoEdicion
                    ? "Gestión y edición de registros."
                    : "Consulta de datos vinculados."}
                </Text>
              </Card>
            );
          })}
        </SimpleGrid>
      </Container>

      {/* MODAL DE AREA */}
{/* MODAL DE AREA */}
<Modal
  opened={areaModalOpen}
  onClose={closeAll}
  size="900px"
  padding="xl"
  lockScroll={false}
  title={
    <Group gap="xs">
      <ThemeIcon variant="light" color="cyan.6" size="lg" radius="md">
        <IconFolder size={20} />
      </ThemeIcon>
      <Title order={3} fw={800} lts="0.5px">
        {selectedArea?.nombre?.toUpperCase()}
      </Title>
    </Group>
  }
  radius="lg"
  centered
  overlayProps={{ backgroundOpacity: 0.7, blur: 10 }}
>
  <Stack gap="xl">
    {/* === FORMULARIOS === */}
    <Box>
      <Text size="xs" fw={700} c="gray.5" mb="md" lts="1px">
        FORMULARIOS DISPONIBLES
      </Text>
      <Stack gap="md">
        {selectedArea?.forms?.map((form) => (
          <Paper
            key={form.id}
            withBorder
            p="md"
            radius="md"
            bg={isDark ? "gray.9" : "gray.0"}
            className={classes.areaFormCard}
          >
            <Group justify="space-between" wrap="nowrap">
              <Group gap="md" wrap="nowrap" style={{ flex: 1 }}>
                <ThemeIcon variant="white" color="cyan.6" radius="md">
                  <IconFileText size={18} />
                </ThemeIcon>
                <Box style={{ minWidth: 0 }}>
                  <Text
                    fw={800}
                    size="sm"
                    c={isDark ? "white" : "gray.9"}
                    truncate
                  >
                    {form.nombre.toUpperCase()}
                  </Text>
                  <Group gap={6}>
                    <Text size="xs" c="dimmed">
                      Tabla: {form.slug}
                    </Text>
                    {!form.es_editor && (
                      <Badge size="xs" color="blue" variant="outline">
                        LECTURA
                      </Badge>
                    )}
                  </Group>
                </Box>
              </Group>

              <Group gap="xs" wrap="nowrap">
                {form.es_editor && (
                  <Button
                    variant="light"
                    color="cyan.6"
                    size="xs"
                    radius="md"
                    leftSection={<IconPlus size={14} />}
                    onClick={() => handleOpenForm(form)}
                  >
                    NUEVO
                  </Button>
                )}
                <Button
                  variant="outline"
                  color="cyan.6"
                  size="xs"
                  radius="md"
                  leftSection={<IconTable size={14} />}
                  onClick={() => handleOpenTable(form)}
                >
                  TABLA
                </Button>
                {form.es_editor && (
                  <Button
                    variant="filled"
                    color="indigo.6"
                    size="xs"
                    radius="md"
                    leftSection={<IconChartBar size={14} />}
                    onClick={() => handleOpenStats(form)}
                  >
                    ESTADÍSTICAS
                  </Button>
                )}
              </Group>
            </Group>
          </Paper>
        ))}
      </Stack>
    </Box>
  </Stack>
</Modal>

      {/* DRAWERS */}
      <Drawer
        opened={statsDrawerOpen}
        onClose={closeDrawer}
        size="100%"
        position="right"
        lockScroll={false}
        transitionProps={{ duration: 250, transition: "slide-left" }}
        title={
          <Text fw={900} size="lg" lts="1.5px" c="indigo.5">
            ESTADÍSTICAS: {selectedForm?.nombre?.toUpperCase()}
          </Text>
        }
      >
        <ScrollArea h="calc(100vh - 80px)">
          <Box p="md">
            {statsDrawerOpen && (
              <VisualizacionEstadisticas formulario={selectedForm} />
            )}
          </Box>
        </ScrollArea>
      </Drawer>

      <Drawer
  opened={tableDrawerOpen}
  onClose={closeDrawer}
  size="100%"
  position="right"
  lockScroll={false}
  transitionProps={drawerTransition}
  className={classes.drawerCustom}
  title={
    <Text fw={900} size="lg" lts="1.5px" c="cyan.5">
      {selectedForm?.nombre?.toUpperCase()}
    </Text>
  }
  padding={0}
>
  <Box h="100%" bg={isDark ? "gray.9" : "white"}>
    <TablaDinamica
      ref={tablaRef}  // ← AGREGAR ESTO
      formulario={selectedForm}
      onEdit={(rec) => handleOpenForm(selectedForm, rec, false)}
      onView={(rec) => handleOpenForm(selectedForm, rec, true)}
      onNew={() => handleNewFromTable(selectedForm)}
    />
  </Box>
</Drawer>

      <Drawer
        opened={formDrawerOpen}
        onClose={closeDrawer}
        size="xl"
        position="right"
        lockScroll={false}
        transitionProps={drawerTransition}
        title={
          <Group gap="xs">
            <ThemeIcon variant="light" color="cyan.5">
              <IconFileText size={18} />
            </ThemeIcon>
            <Text fw={800} size="md" lts="1px">
              {isReadOnly
                ? "VISTA DETALLADA"
                : selectedRecord
                  ? "EDICIÓN DE REGISTRO"
                  : "ALTA DE REGISTRO"}
            </Text>
          </Group>
        }
      >
        <ScrollArea h="calc(100vh - 80px)" p={0}>
          {isFetchingRecord ? (
            <Box style={{ position: "relative", height: "calc(100vh - 80px)" }}>
              <LoadingOverlay visible={true} overlayProps={{ blur: 0, backgroundOpacity: 0 }} />
            </Box>
          ) : selectedForm?.slug === "users" ? (
            <FormularioUsuario
              selectedRecord={selectedRecord}
              isReadOnly={isReadOnly}
              onSuccess={() => {
                closeDrawer();
                fetchData();
              }}
            />
          ) : (
            <FormularioDinamico
  slug={selectedForm?.slug}
  initialData={selectedRecord}
  readOnly={isReadOnly}
  onSuccess={() => {
  closeDrawer();
  setTimeout(() => {
    if (tablaRef.current?.refresh) {
      tablaRef.current.refresh();
    }
  }, 300);
}}
/>
          )}
        </ScrollArea>
      </Drawer>

      {/* DRAWER NUEVA SOLICITUD (admin/adminArea) */}
      <Drawer
        opened={solicitudDrawerOpen}
        onClose={closeAll}
        size="xl"
        position="right"
        lockScroll={false}
        transitionProps={drawerTransition}
        title={
          <Group gap="xs">
            <ThemeIcon variant="light" color="teal.5">
              <IconUserPlus size={18} />
            </ThemeIcon>
            <Text fw={800} size="md" lts="1px">
              SOLICITAR ACCESO
            </Text>
          </Group>
        }
      >
        <ScrollArea h="calc(100vh - 80px)" p={0}>
          <FormularioSolicitud
            userRole={userRole}
            onSuccess={closeAll}
          />
        </ScrollArea>
      </Drawer>

      {/* DRAWER MIS SOLICITUDES (admin/adminArea) */}
      <Drawer
        opened={misSolicitudesDrawerOpen}
        onClose={closeAll}
        size="100%"
        position="right"
        lockScroll={false}
        transitionProps={drawerTransition}
        title={
          <Text fw={900} size="lg" lts="1.5px" c="teal.5">
            MIS SOLICITUDES
          </Text>
        }
        padding={0}
      >
        <Box h="100%" bg={isDark ? "gray.9" : "white"}>
          {misSolicitudesDrawerOpen && <MisSolicitudes userRole={userRole} />}
        </Box>
      </Drawer>

      {/* DRAWER SOLICITUDES PENDIENTES (superadmin) */}
      <Drawer
        opened={solicitudesAdminDrawerOpen}
        onClose={closeAll}
        size="100%"
        position="right"
        lockScroll={false}
        transitionProps={drawerTransition}
        title={
          <Text fw={900} size="lg" lts="1.5px" c="orange.5">
            SOLICITUDES DE ACCESO
          </Text>
        }
        padding={0}
      >
        <Box h="100%" bg={isDark ? "gray.9" : "white"}>
          {solicitudesAdminDrawerOpen && <TablaSolicitudes />}
        </Box>
      </Drawer>

      {/* MODAL CAMBIO DE PASSWORD OBLIGATORIO */}
      <Modal
        opened={showPasswordModal}
        onClose={() => {}}
        withCloseButton={false}
        closeOnClickOutside={false}
        centered
        radius="lg"
        lockScroll={false}
        overlayProps={{ backgroundOpacity: 0.9, blur: 15 }}
        title={
          <Text fw={900} lts="1px" c="red.6">
            ACTUALIZACIÓN OBLIGATORIA
          </Text>
        }
      >
        <Stack p="xs">
          <Text size="sm" fw={500} mb="xs">
            Por motivos de seguridad, debe crear una contraseña segura antes de
            acceder al panel.
          </Text>

          <PasswordInput
            label="NUEVA CONTRASEÑA"
            placeholder="••••••••"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            required
            leftSection={<IconLock size={16} />}
          />

          <PasswordInput
            label="CONFIRMAR CONTRASEÑA"
            placeholder="••••••••"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            required
            leftSection={<IconLock size={16} />}
            error={
              !passChecks.match && confirmPassword.length > 0
                ? "Las contraseñas no coinciden"
                : null
            }
          />

          <Paper
            withBorder
            p="sm"
            radius="md"
            mt="xs"
            bg={isDark ? "gray.9" : "gray.0"}
          >
            <Text size="xs" fw={700} c="dimmed" mb={8} lts="0.5px">
              REQUISITOS DE SEGURIDAD:
            </Text>
            <Requirement met={passChecks.length} label="Mínimo 8 caracteres" />
            <Requirement
              met={passChecks.upper}
              label="Al menos una mayúscula"
            />
            <Requirement met={passChecks.number} label="Al menos un número" />
            <Requirement
              met={passChecks.special}
              label="Un carácter especial (!@#$)"
            />
            <Requirement
              met={passChecks.match}
              label="Ambas contraseñas coinciden"
            />
          </Paper>

          <Button
            color="cyan.6"
            fullWidth
            size="md"
            radius="md"
            loading={isUpdatingPass}
            onClick={handleUpdatePassword}
            mt="md"
            disabled={!isPassValid}
            style={{ fontWeight: 800 }}
          >
            ACTUALIZAR Y ENTRAR
          </Button>
        </Stack>
      </Modal>

      {/* DRAWER PARA CREACIÓN DE MÓDULOS Y TABLAS (Solo Superadmin) */}
      <Drawer
        opened={crearModuloDrawerOpen}
        onClose={closeAll}
        size="xl"
        position="right"
        lockScroll={false}
        transitionProps={drawerTransition}
        title={
          <Group gap="xs">
            <ThemeIcon variant="light" color="cyan.5">
              <IconSettingsAutomation size={18} />
            </ThemeIcon>
            <Text fw={800} size="md" lts="1px">
              CONFIGURAR NUEVO MÓDULO
            </Text>
          </Group>
        }
      >
        <ScrollArea h="calc(100vh - 80px)" p={0}>
          {crearModuloDrawerOpen && (
            <CrearFormulario
              onSuccess={() => {
                closeAll();
                fetchData();
              }}
            />
          )}
        </ScrollArea>
      </Drawer>

      {/* MODAL SUBIR NUEVA VERSIÓN DE LA APP MÓVIL (Solo Superadmin) */}
      {userRole === "superadmin" && (
        <SubirAppMovil
          opened={subirAppOpen}
          onClose={() => setSubirAppOpen(false)}
          appActual={appMovilActual}
          onSuccess={() => {
            setSubirAppOpen(false);
            fetchMobileApps();
          }}
        />
      )}
    </Box>
  );
}

function CustomThemeIcon({ children, color }) {
  return (
    <Box
      style={{
        backgroundColor: `var(--mantine-color-${color}-9)`,
        color: `var(--mantine-color-${color}-4)`,
        width: 48,
        height: 48,
        borderRadius: "12px",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
      }}
    >
      {children}
    </Box>
  );
}