import { useState, useEffect } from 'react';
import {
  Stack, TextInput, Select, Button, Checkbox, Group, Box,
  Text, Title, Paper, ScrollArea, LoadingOverlay, Badge, Divider, SimpleGrid, Collapse
} from '@mantine/core';
import { IconUser, IconMail, IconShieldLock, IconFileText, IconMapPin, IconEye } from '@tabler/icons-react';
import { notifications } from '@mantine/notifications';
import { supabase } from '../lib/supabase';
import classes from './FormularioUsuario.module.css';

export default function FormularioUsuario({ selectedRecord, isReadOnly, onSuccess }) {
  const [loading, setLoading] = useState(false);
  const [roles, setRoles] = useState([]);
  const [areas, setAreas] = useState([]);
  const [todosLosFormularios, setTodosLosFormularios] = useState([]);
  
  // Control de visibilidad para la sección de lectura
  const [mostrarLectura, setMostrarLectura] = useState(false);

  const [formData, setFormData] = useState({
    nombre_completo: '',
    email: '',
    rol_id: '',
    // Secciones de EDICIÓN
    areas_edit: [],
    forms_edit: [],
    // Secciones de LECTURA
    areas_read: [],
    forms_read: [],
  });

  const selectedRolData = roles.find(r => String(r.id) === String(formData.rol_id));
  const isAdminOrSuper = selectedRolData?.key === 'admin' || selectedRolData?.key === 'superadmin';
  const isNormalUser = selectedRolData?.key === 'usuario';

  useEffect(() => {
    const init = async () => {
      setLoading(true);
      try {
        const [resRoles, resAreas, resForms] = await Promise.all([
          supabase.from('roles').select('*').order('nombre', { ascending: true }),
          supabase.from('areas').select('*').eq('activo', true).order('nombre', { ascending: true }),
          supabase.from('formularios').select('*').eq('activo', true).order('nombre', { ascending: true }),
        ]);
        
        setRoles(resRoles.data || []);
        setAreas(resAreas.data || []);
        setTodosLosFormularios(resForms.data || []);

        if (selectedRecord) {
          const [resUserAreas, resUserForms] = await Promise.all([
            supabase.from('usuarios_areas').select('area_id, es_editor').eq('user_id', selectedRecord.id),
            supabase.from('usuarios_formularios').select('formulario_id, es_editor').eq('user_id', selectedRecord.id)
          ]);

          const currentRol = (resRoles.data || []).find(r => 
            r.key === selectedRecord.rol_key || r.id === selectedRecord.rol_id
          );

          // Si tiene algo marcado como lectura (es_editor: false), abrimos el panel automáticamente
          const tieneLectura = resUserAreas.data?.some(a => !a.es_editor) || resUserForms.data?.some(f => !f.es_editor);
          if (tieneLectura) setMostrarLectura(true);

          setFormData({
            nombre_completo: selectedRecord.nombre_completo || '',
            email: selectedRecord.email || '',
            rol_id: currentRol ? String(currentRol.id) : '',
            areas_edit: resUserAreas.data?.filter(a => a.es_editor).map(a => String(a.area_id)) || [],
            areas_read: resUserAreas.data?.filter(a => !a.es_editor).map(a => String(a.area_id)) || [],
            forms_edit: resUserForms.data?.filter(f => f.es_editor).map(f => String(f.formulario_id)) || [],
            forms_read: resUserForms.data?.filter(f => !f.es_editor).map(f => String(f.formulario_id)) || [],
          });
        }
      } catch (err) { 
        console.error("Error cargando datos:", err); 
      } finally { setLoading(false); }
    };
    init();
  }, [selectedRecord]);

  // Filtrado de formularios para EDICIÓN
  const formsEditDisponibles = isAdminOrSuper 
    ? todosLosFormularios 
    : todosLosFormularios.filter(f => formData.areas_edit.includes(String(f.area_id)));

  // Filtrado de formularios para LECTURA (Todos los de las áreas seleccionadas en lectura)
  const formsReadDisponibles = todosLosFormularios.filter(f => formData.areas_read.includes(String(f.area_id)));

  const handleRolChange = (val) => {
    const newRol = roles.find(r => String(r.id) === String(val));
    setFormData(prev => ({ 
      ...prev, 
      rol_id: val, 
      areas_edit: (newRol?.key === 'admin' || newRol?.key === 'superadmin') ? areas.map(a => String(a.id)) : []
    }));
  };

  const handleSubmit = async (e) => {
    if (e) e.preventDefault();
    setLoading(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const endpoint = selectedRecord?.id ? 'users-update' : 'users-create';

      // Combinamos áreas y formularios con su flag correspondiente
      const payload = {
        id: selectedRecord?.id,
        nombre_completo: formData.nombre_completo,
        email: formData.email,
        rol_id: formData.rol_id,
        areas: [
          ...formData.areas_edit.map(id => ({ id, es_editor: true })),
          ...formData.areas_read.map(id => ({ id, es_editor: false }))
        ],
        formularios: [
          ...formData.forms_edit.map(id => ({ id, es_editor: true })),
          ...formData.forms_read.map(id => ({ id, es_editor: false }))
        ]
      };

      const { data, error } = await supabase.functions.invoke(endpoint, {
        body: payload,
        headers: { Authorization: `Bearer ${session?.access_token}` },
      });

      if (error || data?.error) throw new Error(error?.message || data?.error);
      
      notifications.show({ title: 'Éxito', message: 'Usuario guardado', color: 'green' });
      onSuccess();
    } catch (err) {
      notifications.show({ title: 'Error', message: err.message, color: 'red' });
    } finally { setLoading(false); }
  };

  return (
    <Box pos="relative" h="100%">
      <LoadingOverlay visible={loading} overlayProps={{ blur: 1 }} />
      <ScrollArea h="calc(100vh - 120px)" p="xl">
        <Title order={3} mb="xl">{selectedRecord ? 'Editar Usuario' : 'Nuevo Usuario'}</Title>

        <form onSubmit={handleSubmit}>
          <Stack gap="lg">
            <TextInput label="Nombre Completo" value={formData.nombre_completo} onChange={(e) => setFormData({ ...formData, nombre_completo: e.target.value })} required disabled={isReadOnly} leftSection={<IconUser size={18} />} />
            <TextInput label="Email" value={formData.email} onChange={(e) => setFormData({ ...formData, email: e.target.value })} required disabled={!!selectedRecord || isReadOnly} leftSection={<IconMail size={18} />} />
            <Select label="Rol" value={formData.rol_id} onChange={handleRolChange} data={roles.map(r => ({ value: String(r.id), label: r.nombre }))} required disabled={isReadOnly} leftSection={<IconShieldLock size={18} />} />

            {/* --- SECCIÓN EDICIÓN --- */}
            <Divider my="sm" label="Permisos de Edición" labelPosition="center" />
            <Box>
              <Text fw={700} size="xs" c="dimmed" mb={5}>ÁREAS DONDE PUEDE EDITAR</Text>
              <Paper p="md" withBorder>
                <Checkbox.Group 
                  value={formData.areas_edit} 
                  onChange={(val) => setFormData(prev => ({ 
                    ...prev, 
                    areas_edit: isNormalUser ? (val.length > 0 ? [val[val.length - 1]] : []) : val 
                  }))}
                >
                  <SimpleGrid cols={2}>
                    {areas.map((a) => (
                      <Checkbox key={a.id} value={String(a.id)} label={a.nombre} disabled={isReadOnly || isAdminOrSuper} />
                    ))}
                  </SimpleGrid>
                </Checkbox.Group>
              </Paper>
            </Box>

            {formsEditDisponibles.length > 0 && (
              <Box>
                <Text fw={700} size="xs" c="dimmed" mb={5}>FORMULARIOS PARA EDITAR</Text>
                <Paper p="md" withBorder>
                  <Checkbox.Group value={formData.forms_edit} onChange={(val) => setFormData(prev => ({ ...prev, forms_edit: val }))}>
                    <Stack gap="xs">
                      {formsEditDisponibles.map((f) => (
                        <Checkbox key={f.id} value={String(f.id)} label={f.nombre} disabled={isReadOnly || isAdminOrSuper} />
                      ))}
                    </Stack>
                  </Checkbox.Group>
                </Paper>
              </Box>
            )}

            {/* --- SECCIÓN LECTURA --- */}
            <Box mt="xl">
              <Checkbox 
                label="¿Necesita tener acceso de lectura a otras áreas?" 
                checked={mostrarLectura} 
                onChange={(event) => setMostrarLectura(event.currentTarget.checked)}
                disabled={isReadOnly}
              />
              
              <Collapse in={mostrarLectura}>
                <Stack mt="md" gap="lg">
                  <Divider label="Permisos de Lectura" labelPosition="center" color="blue" />
                  
                  <Box>
                    <Text fw={700} size="xs" c="blue" mb={5}>ÁREAS DE SOLO LECTURA</Text>
                    <Paper p="md" withBorder style={{ borderColor: 'var(--mantine-color-blue-2)' }}>
                      <Checkbox.Group value={formData.areas_read} onChange={(val) => setFormData(prev => ({ ...prev, areas_read: val }))}>
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

                  {formsReadDisponibles.length > 0 && (
                    <Box>
                      <Text fw={700} size="xs" c="blue" mb={5}>FORMULARIOS DE SOLO LECTURA</Text>
                      <Paper p="md" withBorder style={{ borderColor: 'var(--mantine-color-blue-2)' }}>
                        <Checkbox.Group value={formData.forms_read} onChange={(val) => setFormData(prev => ({ ...prev, forms_read: val }))}>
                          <Stack gap="xs">
                            {formsReadDisponibles.map((f) => (
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

            {!isReadOnly && (
              <Button type="submit" loading={loading} size="lg" fullWidth mt="xl">
                {selectedRecord ? 'GUARDAR CAMBIOS' : 'REGISTRAR USUARIO'}
              </Button>
            )}
          </Stack>
        </form>
      </ScrollArea>
    </Box>
  );
}