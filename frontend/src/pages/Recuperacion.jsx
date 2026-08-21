import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Box, Button, Title, PasswordInput, Alert, Center, Paper,
  Stack, Text, useMantineColorScheme, Container, List, ThemeIcon, Group
} from '@mantine/core';
import { IconAlertCircle, IconCheck, IconLock, IconX, IconCircleCheck } from '@tabler/icons-react';
import { supabase } from '../lib/supabase';
import ThemeSwitcher from '../components/ThemeSwitcher';
import classes from './Login.module.css';

export default function Recuperacion() {
  const navigate = useNavigate();
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const { colorScheme } = useMantineColorScheme();
  const isDark = colorScheme === 'dark';

  // Validaciones en tiempo real
  const checks = {
    length: password.length >= 8,
    upper: /[A-Z]/.test(password),
    number: /[0-9]/.test(password),
    special: /[!@#$%^&*(),.?":{}|<>]/.test(password),
    match: password === confirmPassword && password.length > 0
  };

  const allValid = Object.values(checks).every(Boolean);

  useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event) => {
      if (event === 'PASSWORD_RECOVERY') {
        console.log("Evento de recuperación detectado");
      }
    });

    const checkInitialSession = async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session && !window.location.hash) {
        setError("Acceso denegado o enlace expirado.");
      }
    };
    
    checkInitialSession();
    return () => subscription.unsubscribe();
  }, []);

  const handleUpdatePassword = async (e) => {
    e.preventDefault();
    if (!allValid) return;

    setLoading(true);
    setError(null);

    const { error: updateError } = await supabase.auth.updateUser({ 
      password: password 
    });

    if (updateError) {
      setError(updateError.message);
      setLoading(false);
    } else {
      setSuccess(true);
      setLoading(false);
      setTimeout(async () => {
        await supabase.auth.signOut();
        navigate('/');
      }, 3000);
    }
  };

  const Requirement = ({ met, label }) => (
    <List.Item
      icon={
        <ThemeIcon color={met ? 'teal' : 'gray'} size={16} radius="xl">
          {met ? <IconCheck size={12} /> : <IconX size={12} />}
        </ThemeIcon>
      }
    >
      <Text size="xs" c={met ? 'teal' : 'dimmed'} fw={met ? 700 : 400}>
        {label}
      </Text>
    </List.Item>
  );

  return (
    <Box className={classes.loginContainer} h="100vh" bg={isDark ? 'gray.9' : 'gray.0'}>
      <Container size="xs" h="100%">
        <Center h="100%">
          <Box pos="absolute" top={24} right={24}><ThemeSwitcher /></Box>

          <Paper className={classes.paperCard} w="100%" p={40} radius="md" shadow="xl" withBorder bg={isDark ? 'gray.8' : 'white'}>
            <Stack gap="xl">
              <Stack align="center" gap={4}>
                <Title order={2} ta="center" fw={800} c="cyan.6" lts="-1.5px">Restablecer Clave</Title>
                <Text size="sm" c="dimmed">Crea una contraseña segura para tu cuenta</Text>
              </Stack>

              {success ? (
                <Stack align="center" py="md">
                  <IconCircleCheck size={48} color="var(--mantine-color-teal-6)" />
                  <Alert color="teal" variant="light" w="100%">
                    <Text fw={700} ta="center">¡Contraseña actualizada!</Text>
                    <Text size="xs" ta="center">Cerrando sesión y redirigiendo...</Text>
                  </Alert>
                </Stack>
              ) : (
                <form onSubmit={handleUpdatePassword}>
                  <Stack gap="md">
                    <PasswordInput
                      label="Nueva Contraseña"
                      placeholder="••••••••"
                      required
                      size="md"
                      value={password}
                      onChange={(e) => setPassword(e.currentTarget.value)}
                      leftSection={<IconLock size={18} />}
                    />
                    <PasswordInput
                      label="Confirmar Contraseña"
                      placeholder="••••••••"
                      required
                      size="md"
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.currentTarget.value)}
                      leftSection={<IconLock size={18} />}
                      error={!checks.match && confirmPassword.length > 0 ? "No coinciden" : null}
                    />

                    <Paper withBorder p="sm" radius="md" bg={isDark ? 'gray.9' : 'gray.0'}>
                      <Text size="xs" fw={700} mb={8} c="dimmed">REQUISITOS:</Text>
                      <List spacing="xs" size="sm" center>
                        <Requirement met={checks.length} label="Mínimo 8 caracteres" />
                        <Requirement met={checks.upper} label="Una letra mayúscula" />
                        <Requirement met={checks.number} label="Al menos un número" />
                        <Requirement met={checks.special} label="Un carácter especial" />
                        <Requirement met={checks.match} label="Las contraseñas coinciden" />
                      </List>
                    </Paper>

                    {error && (
                      <Alert color="red" variant="subtle" icon={<IconAlertCircle size={20} />}>
                        <Text size="xs" fw={600}>{error}</Text>
                      </Alert>
                    )}

                    <Button
                      type="submit"
                      fullWidth
                      color="cyan.6"
                      size="md"
                      loading={loading}
                      disabled={!allValid}
                      fw={700}
                    >
                      Actualizar y Salir
                    </Button>
                  </Stack>
                </form>
              )}
            </Stack>
          </Paper>
        </Center>
      </Container>
    </Box>
  );
}