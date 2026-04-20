import React, { useState, useEffect } from 'react';
import { 
  TextInput, Select, Button, Paper, Text, 
  Title, Box, Group, ActionIcon, Stack, useMantineColorScheme 
} from '@mantine/core';
import { supabase } from '../lib/supabase';
import styles from './CrearFormulario.module.css';

const TIPOS_CAMPOS = [
  { label: 'Texto', value: 'text' },
  { label: 'Número (decimal)', value: 'numeric' },
  { label: 'Entero', value: 'integer' },
  { label: 'Fecha', value: 'date' },
  { label: 'Booleano (Si/No)', value: 'boolean' },
];

const CrearFormulario = ({ onSuccess }) => {
  const { colorScheme } = useMantineColorScheme();
  const isDark = colorScheme === 'dark';

  const [loading, setLoading] = useState(false);
  const [areas, setAreas] = useState([]);
  const [modoArea, setModoArea] = useState(null); 
  
  const [areaId, setAreaId] = useState('');
  const [nuevoNombreArea, setNuevoNombreArea] = useState('');
  const [nombreTabla, setNombreTabla] = useState('');
  const [descripcion, setDescripcion] = useState('');
  const [camposExtras, setCamposExtras] = useState([{ nombre: '', tipo: 'text' }]);

  useEffect(() => {
    const fetchAreas = async () => {
      const { data } = await supabase.from('areas').select('id, nombre').eq('activo', true).order('nombre');
      if (data) setAreas(data.map(a => ({ value: a.id, label: a.nombre })));
    };
    fetchAreas();
  }, []);

  const handleAddCampo = () => setCamposExtras([...camposExtras, { nombre: '', tipo: 'text' }]);
  const handleRemoveCampo = (index) => setCamposExtras(camposExtras.filter((_, i) => i !== index));
  const handleCampoChange = (index, key, value) => {
    const nuevos = [...camposExtras];
    nuevos[index][key] = value;
    setCamposExtras(nuevos);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      const payload = {
        nombre_tabla: nombreTabla.toLowerCase().replace(/\s+/g, '_'),
        descripcion,
        area_id: modoArea === 'existente' ? areaId : null,
        nuevo_nombre_area: modoArea === 'nueva' ? nuevoNombreArea : null,
        campos_adicionales: camposExtras.filter(c => c.nombre)
      };

      const { data, error } = await supabase.functions.invoke('modulo-create', { body: payload });
      if (error) throw error;
      if (onSuccess) { onSuccess(); }
    } catch (err) {
      alert("Error: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  // PANTALLA 1: Pregunta inicial
  if (!modoArea) {
    return (
      <Box className={styles.container}>
        <Title className={styles.title}>Nuevo Módulo</Title>
        <Paper className={styles.sectionPaper} radius="md" p="xl">
          <Text size="sm" mb="xl" ta="center" fw={500} c={isDark ? 'gray.4' : 'gray.7'}>
            ¿El área de este nuevo formulario ya existe en el sistema?
          </Text>
          <Stack>
            <Button 
              className={styles.choiceButton} 
              variant="filled" 
              color={isDark ? 'dark.5' : 'gray.1'}
              onClick={() => setModoArea('existente')}
            >
              SÍ, EL ÁREA YA EXISTE
            </Button>
            <Button 
              className={styles.choiceButton} 
              variant="outline" 
              color="cyan"
              onClick={() => setModoArea('nueva')}
            >
              NO, ES UN ÁREA NUEVA
            </Button>
          </Stack>
        </Paper>
      </Box>
    );
  }

  // PANTALLA 2: Formulario de creación
  return (
    <Box className={styles.container}>
      <Group justify="space-between" mb="lg">
        <Title className={styles.title} style={{ marginBottom: 0 }}>Configurar Módulo</Title>
        <Button variant="subtle" color="gray" size="xs" onClick={() => setModoArea(null)}>← VOLVER</Button>
      </Group>

      <form onSubmit={handleSubmit}>
        <Paper className={styles.sectionPaper}>
          <Text className={styles.sectionTitle}>1. Ubicación del Módulo</Text>
          {modoArea === 'existente' ? (
            <Select
              label="Seleccionar Área"
              placeholder="Elige un área"
              data={areas}
              value={areaId}
              onChange={setAreaId}
              classNames={{ label: styles.label, input: styles.inputField }}
              required
            />
          ) : (
            <TextInput
              label="Nombre de la Nueva Área"
              placeholder="Ej: Recursos Hídricos"
              value={nuevoNombreArea}
              onChange={(e) => setNuevoNombreArea(e.currentTarget.value)}
              classNames={{ label: styles.label, input: styles.inputField }}
              required
            />
          )}
        </Paper>

        <Paper className={styles.sectionPaper}>
          <Text className={styles.sectionTitle}>2. Datos Técnicos</Text>
          <Stack gap="md">
            <TextInput
              label="Nombre de la Tabla (Slug)"
              placeholder="ej: control_fauna"
              value={nombreTabla}
              onChange={(e) => setNombreTabla(e.currentTarget.value)}
              classNames={{ label: styles.label, input: styles.inputField }}
              required
            />
            <TextInput
              label="Descripción Amigable"
              placeholder="Ej: Registro de Fauna"
              value={descripcion}
              onChange={(e) => setDescripcion(e.currentTarget.value)}
              classNames={{ label: styles.label, input: styles.inputField }}
              required
            />
          </Stack>
          <Text className={styles.helperText}>* La tabla incluirá automáticamente los campos base de Auditoría y Geo.</Text>
        </Paper>

        <Paper className={styles.sectionPaper}>
          <Group justify="space-between" mb="md">
            <Text className={styles.sectionTitle} style={{ marginBottom: 0 }}>3. Campos Adicionales</Text>
            <Button variant="light" color="cyan" size="xs" onClick={handleAddCampo}>+ AGREGAR</Button>
          </Group>

          <Stack gap="xs">
            {camposExtras.map((campo, index) => (
              <Group key={index} align="flex-start" gap="xs">
                <TextInput
                  placeholder="nombre_campo"
                  value={campo.nombre}
                  onChange={(e) => handleCampoChange(index, 'nombre', e.currentTarget.value)}
                  style={{ flex: 1 }}
                  classNames={{ input: styles.inputField }}
                />
                <Select
                  data={TIPOS_CAMPOS}
                  value={campo.tipo}
                  onChange={(val) => handleCampoChange(index, 'tipo', val)}
                  style={{ width: 140 }}
                  classNames={{ input: styles.inputField }}
                />
                <ActionIcon 
                  variant="subtle" 
                  color="red" 
                  onClick={() => handleRemoveCampo(index)}
                  size="lg"
                  mt={3}
                >
                  ✕
                </ActionIcon>
              </Group>
            ))}
          </Stack>
        </Paper>

        <Button 
          type="submit" 
          className={styles.submitButton} 
          loading={loading}
          fullWidth
        >
          CREAR MÓDULO Y GENERAR TABLA
        </Button>
      </form>
    </Box>
  );
};

export default CrearFormulario;