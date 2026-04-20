import { useEffect, useState } from 'react';
import {
  Box,
  Text,
  Loader,
  Select,
  useMantineColorScheme,
} from '@mantine/core';
import { supabase } from "../lib/supabase";
import classes from './RelationalSelect.module.css';

export default function RelationalSelect({ field, value, onChange, disabled }) {
  const [options, setOptions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const { colorScheme } = useMantineColorScheme();
  const isDark = colorScheme === 'dark';

  useEffect(() => {
    const fetchOptions = async () => {
      if (!field.foreign_table) return;
      setLoading(true);
      setError(null);
      
      try {
        const { data, error: fetchError } = await supabase
          .from(field.foreign_table)
          .select('*')
          .order('id', { ascending: true });

        if (fetchError) throw fetchError;

        const formatted = data.map(item => ({
          value: String(item.id), 
          label: String(
            item.nombre || 
            item.nombre_municipio || 
            item.denominacion || 
            item.descripcion || 
            item.email || 
            item.cuit || 
            item.id
          )
        }));
        setOptions(formatted);
      } catch (err) {
        console.error(`Error cargando ${field.foreign_table}:`, err);
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchOptions();
  }, [field.foreign_table]);

  if (error) {
    return (
      <Box>
        <Text c="red.6" size="xs" fw={700}>
          ERROR: {field.label || field.campo.toUpperCase()}
        </Text>
        <Text c="dimmed" size="xs">{error}</Text>
      </Box>
    );
  }

  return (
    <Box className={classes.wrapper}>
      <Select
        label={field.label || field.campo.toUpperCase()}
        placeholder={loading ? "Cargando..." : "Seleccionar opción"}
        value={value ? String(value) : null}
        onChange={(val) => onChange(val)}
        data={options}
        searchable
        clearable
        nothingFoundMessage="Sin resultados"
        disabled={loading || disabled}
        size="sm"
        radius="md"
        checkIconPosition="right"
        comboboxProps={{ transitionProps: { transition: 'pop', duration: 200 } }}
        className={classes.selectRoot}
        classNames={{
          input: classes.selectInput,
          label: classes.selectLabel,
          dropdown: classes.selectDropdown,
          option: classes.selectOption
        }}
        rightSection={loading ? <Loader size={14} color="cyan.6" /> : null}
      />
      
      {loading && !options.length && (
        <Box className={classes.loaderWrapper}>
          <Text size="10px" fw={700} c="cyan.6" style={{ letterSpacing: '0.5px' }}>
            SINCRONIZANDO DATOS...
          </Text>
        </Box>
      )}
    </Box>
  );
}