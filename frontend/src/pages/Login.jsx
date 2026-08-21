import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Box,
  Button,
  Title,
  TextInput,
  PasswordInput,
  Alert,
  Center,
  Paper,
  Stack,
  Text,
  useMantineColorScheme,
  Container,
  Anchor,
  Modal,
  Group,
} from '@mantine/core';
import { useDisclosure } from '@mantine/hooks';
import { IconAlertCircle, IconMail, IconLock, IconCheck } from '@tabler/icons-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import ThemeSwitcher from '../components/ThemeSwitcher';
import classes from './Login.module.css';

export default function Login() {
  const navigate = useNavigate();
  const { user } = useAuth();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  
  const [opened, { open, close }] = useDisclosure(false);
  const [resetEmail, setResetEmail] = useState('');
  const [resetSent, setResetSent] = useState(false);

  const { colorScheme } = useMantineColorScheme();
  const isDark = colorScheme === 'dark';

  useEffect(() => {
    // Redirigir si ya está logueado y no está en un flujo de recuperación
    if (user && !window.location.hash.includes('type=recovery')) {
      navigate('/formularios');
    }
  }, [user, navigate]);

  const handleLogin = async (e) => {
    if (e) e.preventDefault();
    setLoading(true);
    setError(null);

    const { error: loginError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (loginError) {
      setError(loginError.message === 'Invalid login credentials' 
        ? 'Credenciales incorrectas. Verifique sus datos.' 
        : loginError.message
      );
      setLoading(false);
    }
  };

  const handleForgotPassword = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { error: resetError } = await supabase.auth.resetPasswordForEmail(resetEmail, {
      // Importante: Redirige a la página de recuperación
      redirectTo: `${window.location.origin}/recuperacion`,
    });

    if (resetError) {
      setError(resetError.message);
      setLoading(false);
    } else {
      setResetSent(true);
      setLoading(false);
    }
  };

  return (
    <Box 
      className={classes.loginContainer} 
      h="100vh" 
      bg={isDark ? 'var(--mantine-color-gray-9)' : 'var(--mantine-color-gray-0)'}
    >
      <Container size="xs" h="100%">
        <Center h="100%">
          <Box pos="absolute" top={24} right={24}>
            <ThemeSwitcher />
          </Box>

          <Paper
            className={classes.paperCard}
            w="100%"
            p={40}
            radius="md"
            shadow="xl"
            withBorder
            bg={isDark ? 'var(--mantine-color-gray-8)' : 'white'}
          >
            <Stack gap="xl">
              <Stack align="center" gap={4}>
                <img src="/ECODATOS-verde.png" alt="Eco Datos" style={{ width: '120px', height: '100px'}}/>
                <Title order={2} ta="center" fw={800} c="cyan.6" style={{ letterSpacing: '-1.5px' }}>
                  Eco Datos
                </Title>
                <Text fw={700} ta="center" size="lg" c={isDark ? 'white' : 'gray.8'}>
                  Observatorio Ambiental
                </Text>
                <Text size="xs" fw={500} c="dimmed" ta="center" style={{ textTransform: 'uppercase', letterSpacing: '1px' }}>
                  Subsecretaría de Ordenamiento Territorial
                </Text>
              </Stack>

              <form onSubmit={handleLogin}>
                <Stack gap="md">
                  <TextInput
                    label="Correo Electrónico"
                    placeholder="tu@email.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    size="md"
                    leftSection={<IconMail size={18} stroke={1.5} />}
                  />

                  <Box>
                    <PasswordInput
                      label="Contraseña"
                      placeholder="••••••••"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      required
                      size="md"
                      leftSection={<IconLock size={18} stroke={1.5} />}
                    />
                    <Group justify="flex-end" mt={5}>
                      <Anchor 
                        component="button" 
                        type="button" 
                        size="xs" 
                        c="cyan.7" 
                        fw={600} 
                        onClick={() => {
                          setError(null);
                          setResetSent(false);
                          open();
                        }}
                      >
                        ¿Olvidaste tu contraseña?
                      </Anchor>
                    </Group>
                  </Box>

                  <Button
                    type="submit"
                    size="md"
                    fullWidth
                    color="cyan.6"
                    className={classes.loginButton}
                    loading={loading}
                    mt="md"
                    fw={700}
                  >
                    Ingresar al Sistema
                  </Button>
                </Stack>
              </form>

              {error && (
                <Alert color="red" variant="subtle" icon={<IconAlertCircle size={20} />} radius="md">
                  <Text size="sm" fw={600}>{error}</Text>
                </Alert>
              )}
            </Stack>
          </Paper>
        </Center>
      </Container>

      <Modal 
        opened={opened} 
        onClose={close} 
        title={<Text fw={700}>Recuperar contraseña</Text>} 
        centered 
        radius="md"
      >
        {!resetSent ? (
          <form onSubmit={handleForgotPassword}>
            <Stack>
              <Text size="sm" c="dimmed">
                Ingresa tu email y te enviaremos un enlace para restablecer tu contraseña.
              </Text>
              <TextInput 
                label="Email de tu cuenta" 
                placeholder="tu@email.com" 
                required 
                value={resetEmail}
                onChange={(e) => setResetEmail(e.target.value)}
              />
              <Button fullWidth color="cyan.6" type="submit" loading={loading} mt="sm">
                Enviar enlace de recuperación
              </Button>
            </Stack>
          </form>
        ) : (
          <Stack align="center" py="md" gap="sm">
            <IconCheck size={44} color="var(--mantine-color-green-6)" />
            <Text ta="center" fw={600}>¡Enlace enviado!</Text>
            <Text ta="center" size="sm" c="dimmed">
              Revisa tu bandeja de entrada para continuar.
            </Text>
            <Button variant="light" fullWidth onClick={close} mt="md">
              Entendido
            </Button>
          </Stack>
        )}
      </Modal>

      <Box pos="absolute" bottom={20} w="100%">
        <Text size="xs" fw={600} c="dimmed" ta="center" style={{ letterSpacing: '0.5px' }}>
          © {new Date().getFullYear()} OBSERVATORIO AMBIENTAL
        </Text>
      </Box>
    </Box>
  );
}