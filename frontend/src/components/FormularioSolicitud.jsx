import { useState, useEffect } from 'react';
import {
  Stack, TextInput, Select, Button, Checkbox, Group, Box,
  Text, Title, Paper, ScrollArea, LoadingOverlay, Divider, 
  SimpleGrid, Collapse, Textarea, Alert
} from '@mantine/core';
import { 
  IconUser, IconMail, IconShieldLock, IconCheck, 
  IconX, IconRotate, IconInfoCircle 
} from '@tabler/icons-react';
import { notifications } from '@mantine/notifications';
import { supabase } from '../lib/supabase';
import classes from './FormularioSolicitud.module.css';

export default function FormularioSolicitud({ userRole, onSuccess, initialData, isSuperadmin }) {
  const [loading, setLoading] = useState(false);
  const [accionando, setAccionando] = useState(null); // 'aprobando' | 'rechazando' | 'revision'
  const [roles, setRoles] = useState([]);
  const [areas, setAreas] = useState([]);
  const [todosLosFormularios, setTodosLosFormularios] = useState([]);
  const [misAreas, setMisAreas] = useState([]);
  const [mostrarLectura, setMostrarLectura] = useState(false);
  const [motivo, setMotivo] = useState('');

  const [formData, setFormData] = useState({
    nombre_completo: '',
    email: '',
    rol_id: '',
    areas_edit: [],
    forms_edit: [],
    areas_read: [],
    forms_read: [],
    tipo: 'registro',
    user_id: null,
    solicitud_id: null
  });

  const selectedRolData = roles.find(r => String(r.id) === String(formData.rol_id));
  const isAdminOrSuper = selectedRolData?.key === 'admin' || selectedRolData?.key === 'superadmin';
  const isNormalUser = selectedRolData?.key === 'usuario';
  const isAdminArea = userRole === 'adminArea';

  // En modo superadmin todo es readonly
  const isReadOnly = isSuperadmin;

  useEffect(() => {
    const init = async () => {
      setLoading(true);
      try {
        const { data: { session } } = await supabase.auth.getSession();

        const [resRoles, resAreas, resForms] = await Promise.all([
          supabase.from('roles').select('*').order('nombre', { ascending: true }),
          supabase.from('areas').select('*').eq('activo', true).order('nombre', { ascending: true }),
          supabase.from('formularios').select('*').eq('activo', true).order('nombre', { ascending: true }),
        ]);

        setRoles(resRoles.data || []);
        setTodosLosFormularios(resForms.data || []);

        if (isAdminArea) {
          const { data: misAreasData } = await supabase
            .from('usuarios_areas')
            .select('area_id')
            .eq('user_id', session.user.id)
            .eq('es_editor', true);

          const misAreaIds = misAreasData?.map(a => String(a.area_id)) || [];
          const areasFiltered = (resAreas.data || []).filter(a => misAreaIds.includes(String(a.id)));
          setMisAreas(areasFiltered);
          setAreas(resAreas.data || []);
        } else {
          setAreas(resAreas.data || []);
        }

        if (initialData) {
          const rawAreas = typeof initialData.areas === 'string' 
            ? JSON.parse(initialData.areas) 
            : (initialData.areas || []);
          const rawForms = typeof initialData.formularios === 'string' 
            ? JSON.parse(initialData.formularios) 
            : (initialData.formularios || []);

          setFormData({
            nombre_completo: initialData.nombre_completo || '',
            email: initialData.email || '',
            rol_id: String(initialData.rol_id),
            areas_edit: rawAreas.filter(a => a.es_editor).map(a => String(a.id)),
            areas_read: rawAreas.filter(a => !a.es_editor).map(a => String(a.id)),
            forms_edit: rawForms.filter(f => f.es_editor).map(f => String(f.id)),
            forms_read: rawForms.filter(f => !f.es_editor).map(f => String(f.id)),
            tipo: initialData.tipo || 'registro',
            user_id: initialData.user_id,
            solicitud_id: initialData.estado === 'revision' ? initialData.id : null
          });

          if (rawAreas.some(a => !a.es_editor) || rawForms.some(f => !f.es_editor)) {
            setMostrarLectura(true);
          }
        }

      } catch (err) {
        console.error('Error cargando datos:', err);
      } finally {
        setLoading(false);
      }
    };
    init();
  }, [userRole, initialData, isSuperadmin]);

  const areasEditDisponibles = isAdminArea ? misAreas : areas;

  const formsEditDisponibles = isAdminOrSuper
    ? todosLosFormularios
    : todosLosFormularios.filter(f => formData.areas_edit.includes(String(f.area_id)));

  const formsReadDisponibles = todosLosFormularios.filter(f =>
    formData.areas_read.includes(String(f.area_id))
  );

  const handleRolChange = (val) => {
    if (isReadOnly) return;
    const newRol = roles.find(r => String(r.id) === String(val));
    setFormData(prev => ({
      ...prev,
      rol_id: val,
      areas_edit: (newRol?.key === 'admin' || newRol?.key === 'superadmin')
        ? areas.map(a => String(a.id))
        : []
    }));
  };

  const handleSubmit = async (e) => {
    if (e) e.preventDefault();
    if (isReadOnly) return;
    setLoading(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();

      const payload = {
        nombre_completo: formData.nombre_completo,
        email: formData.email,
        rol_id: formData.rol_id,
        tipo: formData.tipo,
        user_id: formData.user_id,
        solicitud_id: formData.solicitud_id,
        areas: [
          ...formData.areas_edit.map(id => ({ id, es_editor: true })),
          ...formData.areas_read.map(id => ({ id, es_editor: false })),
        ],
        formularios: [
          ...formData.forms_edit.map(id => ({ id, es_editor: true })),
          ...formData.forms_read.map(id => ({ id, es_editor: false })),
        ],
      };

      const { data, error } = await supabase.functions.invoke('solicitudes-create', {
        body: payload,
        headers: { Authorization: `Bearer ${session?.access_token}` },
      });

      if (error || data?.error) throw new Error(error?.message || data?.error);

      notifications.show({
        title: formData.tipo === 'update' ? 'Solicitud de cambio enviada' : 'Solicitud enviada',
        message: 'Los administradores la revisarán a la brevedad',
        color: 'teal'
      });
      onSuccess?.();
    } catch (err) {
      notifications.show({ title: 'Error', message: err.message, color: 'red' });
    } finally {
      setLoading(false);
    }
  };

  // Acciones del superadmin
  const handleAccion = async (accion) => {
    if (accion !== 'aprobada' && !motivo.trim()) {
      notifications.show({ 
        title: 'Falta el motivo', 
        message: 'Escribí el motivo antes de rechazar o devolver para revisión', 
        color: 'orange' 
      });
      return;
    }

    setAccionando(accion);
    try {
      const { data: { session } } = await supabase.auth.getSession();

      if (accion === 'aprobada') {
        // Aprobar → publicar en la cola igual que antes
        const { data, error } = await supabase.functions.invoke('queue-publish', {
          body: {
            subject: 'jobs.solicitudes.approve',
            payload: { solicitud_id: initialData.id }
          },
          headers: { Authorization: `Bearer ${session?.access_token}` },
        });
        if (error || data?.error) throw new Error(error?.message || data?.error);
        notifications.show({ title: 'Aprobada', message: 'Solicitud enviada a la cola de procesamiento', color: 'teal' });
      } else {
        // Rechazar o devolver para revisión → solicitudes-reject
        const { data, error } = await supabase.functions.invoke('solicitudes-reject', {
          body: {
            solicitud_id: initialData.id,
            accion: accion === 'rechazada' ? 'rechazada' : 'revision',
            motivo: motivo.trim()
          },
          headers: { Authorization: `Bearer ${session?.access_token}` },
        });
        if (error || data?.error) throw new Error(error?.message || data?.error);
        notifications.show({ 
          title: accion === 'rechazada' ? 'Solicitud rechazada' : 'Devuelta para revisión',
          message: 'Se notificó al solicitante por email', 
          color: accion === 'rechazada' ? 'red' : 'orange' 
        });
      }

      onSuccess?.();
    } catch (err) {
      notifications.show({ title: 'Error', message: err.message, color: 'red' });
    } finally {
      setAccionando(null);
    }
  };

  return (
    <Box pos="relative">
      <LoadingOverlay visible={loading} overlayProps={{ blur: 1 }} />
      <ScrollArea h="calc(100vh - 180px)" px="xl">

        <Title order={4} mb="xs" mt="md">
          {isSuperadmin 
            ? 'Revisión de Solicitud' 
            : formData.tipo === 'update' 
              ? 'Solicitar Modificación de Acceso' 
              : 'Nueva Solicitud de Acceso'
          }
        </Title>

        {/* Info del tipo de solicitud para superadmin */}
        {isSuperadmin && (
          <Alert 
            icon={<IconInfoCircle size={16} />} 
            color={formData.tipo === 'update' ? 'blue' : 'teal'} 
            variant="light" 
            mb="lg"
          >
            <Text size="sm" fw={600}>
              {formData.tipo === 'update' 
                ? 'Solicitud de cambio de permisos para un usuario existente' 
                : 'Solicitud de creación de nuevo usuario'}
            </Text>
            <Text size="xs" c="dimmed" mt={2}>
              Solicitado por: <strong>{initialData?.solicitante_nombre}</strong> ({initialData?.solicitante_email})
            </Text>
          </Alert>
        )}

        <form onSubmit={handleSubmit}>
          <Stack gap="lg">

            <TextInput
              label="Nombre Completo"
              classNames={{ label: classes.label, input: classes.inputField }}
              value={formData.nombre_completo}
              onChange={(e) => !isReadOnly && setFormData({ ...formData, nombre_completo: e.target.value })}
              required={!isReadOnly}
              readOnly={isReadOnly}
              leftSection={<IconUser size={18} />}
            />

            <TextInput
              label="Email"
              classNames={{ label: classes.label, input: classes.inputField }}
              value={formData.email}
              onChange={(e) => !isReadOnly && setFormData({ ...formData, email: e.target.value })}
              required={!isReadOnly}
              type="email"
              readOnly={isReadOnly}
              disabled={!isReadOnly && formData.tipo === 'update'}
              leftSection={<IconMail size={18} />}
              description={!isReadOnly && formData.tipo === 'update' ? 'El email no puede modificarse en una actualización de permisos' : null}
            />

            <Select
              label="Rol"
              classNames={{ label: classes.label }}
              value={formData.rol_id}
              onChange={handleRolChange}
              data={roles
                .filter(r => r.key !== 'superadmin')
                .map(r => ({ value: String(r.id), label: r.nombre }))}
              required={!isReadOnly}
              readOnly={isReadOnly}
              leftSection={<IconShieldLock size={18} />}
            />

            {/* SECCIÓN EDICIÓN */}
            <Divider
              my="sm"
              label={<Text className={classes.dividerLabel}>Permisos de Edición</Text>}
              labelPosition="center"
            />

            <Box>
              <Text className={classes.label} mb={5}>ÁREAS DONDE PUEDE EDITAR</Text>
              <Paper p="md" withBorder className={isAdminOrSuper || isReadOnly ? classes.areaPaperDisabled : classes.areaPaper}>
                <Checkbox.Group
                  value={formData.areas_edit}
                  onChange={(val) => {
                    if (isReadOnly) return;
                    setFormData(prev => ({
                      ...prev,
                      areas_edit: isNormalUser ? (val.length > 0 ? [val[val.length - 1]] : []) : val
                    }));
                  }}
                >
                  <SimpleGrid cols={2}>
                    {(isReadOnly ? areas : areasEditDisponibles).map((a) => (
                      <Checkbox
                        key={a.id}
                        value={String(a.id)}
                        label={a.nombre}
                        disabled={isAdminOrSuper || isReadOnly}
                      />
                    ))}
                  </SimpleGrid>
                </Checkbox.Group>
              </Paper>
            </Box>

            {(isReadOnly ? formData.forms_edit.length > 0 : formsEditDisponibles.length > 0) && (
              <Box>
                <Text className={classes.label} mb={5}>FORMULARIOS PARA EDITAR</Text>
                <Paper p="md" withBorder className={isAdminOrSuper || isReadOnly ? classes.areaPaperDisabled : classes.areaPaper}>
                  <Checkbox.Group
                    value={formData.forms_edit}
                    onChange={(val) => !isReadOnly && setFormData(prev => ({ ...prev, forms_edit: val }))}
                  >
                    <Stack gap="xs" className={classes.formListContainer}>
                      {(isReadOnly ? todosLosFormularios.filter(f => formData.forms_edit.includes(String(f.id))) : formsEditDisponibles).map((f) => (
                        <Checkbox
                          key={f.id}
                          value={String(f.id)}
                          label={f.nombre}
                          disabled={isAdminOrSuper || isReadOnly}
                        />
                      ))}
                    </Stack>
                  </Checkbox.Group>
                </Paper>
              </Box>
            )}

            {/* SECCIÓN LECTURA */}
            {(mostrarLectura || (!isReadOnly)) && (
              <Box mt="xl">
                {!isReadOnly && (
                  <Checkbox
                    label="¿Necesita tener acceso de lectura a otras áreas?"
                    checked={mostrarLectura}
                    onChange={(e) => setMostrarLectura(e.currentTarget.checked)}
                  />
                )}
                <Collapse in={mostrarLectura}>
                  <Stack mt={isReadOnly ? 0 : "md"} gap="lg">
                    <Divider
                      label={<Text className={classes.dividerLabel} c="blue">Permisos de Lectura</Text>}
                      labelPosition="center"
                      color="blue"
                    />

                    <Box>
                      <Text className={classes.label} c="blue" mb={5}>ÁREAS DE SOLO LECTURA</Text>
                      <Paper p="md" withBorder style={{ borderColor: 'var(--mantine-color-blue-2)' }}>
                        <Checkbox.Group
                          value={formData.areas_read}
                          onChange={(val) => !isReadOnly && setFormData(prev => ({ ...prev, areas_read: val }))}
                        >
                          <SimpleGrid cols={2}>
                            {areas.map((a) => (
                              <Checkbox
                                key={a.id}
                                value={String(a.id)}
                                label={a.nombre}
                                disabled={isReadOnly || formData.areas_edit.includes(String(a.id))}
                              />
                            ))}
                          </SimpleGrid>
                        </Checkbox.Group>
                      </Paper>
                    </Box>

                    {(isReadOnly ? formData.forms_read.length > 0 : formsReadDisponibles.length > 0) && (
                      <Box>
                        <Text className={classes.label} c="blue" mb={5}>FORMULARIOS DE SOLO LECTURA</Text>
                        <Paper p="md" withBorder style={{ borderColor: 'var(--mantine-color-blue-2)' }}>
                          <Checkbox.Group
                            value={formData.forms_read}
                            onChange={(val) => !isReadOnly && setFormData(prev => ({ ...prev, forms_read: val }))}
                          >
                            <Stack gap="xs" className={classes.formListContainer}>
                              {(isReadOnly 
                                ? todosLosFormularios.filter(f => formData.forms_read.includes(String(f.id))) 
                                : formsReadDisponibles
                              ).map((f) => (
                                <Checkbox
                                  key={f.id}
                                  value={String(f.id)}
                                  label={f.nombre}
                                  disabled={isReadOnly || formData.forms_edit.includes(String(f.id))}
                                />
                              ))}
                            </Stack>
                          </Checkbox.Group>
                        </Paper>
                      </Box>
                    )}
                  </Stack>
                </Collapse>
              </Box>
            )}

            {/* SECCIÓN SUPERADMIN — Motivo y acciones */}
            {isSuperadmin && (
              <>
                <Divider
                  my="sm"
                  label={<Text className={classes.dividerLabel} c="orange">Decisión del Administrador</Text>}
                  labelPosition="center"
                  color="orange"
                />

                <Textarea
                  label="MOTIVO / COMENTARIO"
                  description="Obligatorio para rechazar o devolver para revisión. Opcional para aprobar."
                  placeholder="Escribí el motivo de la decisión o comentarios para el solicitante..."
                  value={motivo}
                  onChange={(e) => setMotivo(e.target.value)}
                  minRows={3}
                  autosize
                  classNames={{ label: classes.label }}
                />

                <Group grow mt="md" mb="xl">
                  <Button
                    variant="light"
                    color="red.6"
                    leftSection={<IconX size={16} />}
                    loading={accionando === 'rechazada'}
                    disabled={!!accionando && accionando !== 'rechazada'}
                    onClick={() => handleAccion('rechazada')}
                  >
                    RECHAZAR
                  </Button>
                  <Button
                    variant="light"
                    color="orange.6"
                    leftSection={<IconRotate size={16} />}
                    loading={accionando === 'revision'}
                    disabled={!!accionando && accionando !== 'revision'}
                    onClick={() => handleAccion('revision')}
                  >
                    DEVOLVER PARA REVISIÓN
                  </Button>
                  <Button
                    variant="filled"
                    color="teal.7"
                    leftSection={<IconCheck size={16} />}
                    loading={accionando === 'aprobada'}
                    disabled={!!accionando && accionando !== 'aprobada'}
                    onClick={() => handleAccion('aprobada')}
                  >
                    APROBAR
                  </Button>
                </Group>
              </>
            )}

            {/* BOTÓN SUBMIT — solo para admin/adminArea */}
            {!isSuperadmin && (
              <Button
                type="submit"
                loading={loading}
                fullWidth
                mt="xl"
                color={formData.tipo === 'update' ? 'blue' : 'brand'}
                className={classes.submitButton}
              >
                {formData.tipo === 'update' ? 'SOLICITAR CAMBIO' : 'ENVIAR SOLICITUD'}
              </Button>
            )}

          </Stack>
        </form>
      </ScrollArea>
    </Box>
  );
}