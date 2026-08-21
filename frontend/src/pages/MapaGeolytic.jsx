import { useState, useEffect } from 'react';
import {
  Box, Group, Text, Button, Loader, Center, Stack,
  Badge, ActionIcon, Tooltip, useMantineColorScheme,
} from '@mantine/core';
import { IconArrowLeft, IconRefresh, IconMap2, IconUser } from '@tabler/icons-react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const GEOLYTIC_SECRET = 'GRzKkjRZk6W0HlQlncknFnZ5Mk0oyFsKpnaEouLz';

async function generateGeolyticToken(email) {
  const encode = (obj) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const header  = encode({ alg: 'HS256', typ: 'JWT' });
  const payload = encode({ email });
  const data    = `${header}.${payload}`;

  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(GEOLYTIC_SECRET),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  return `${data}.${sigB64}`;
}

export default function MapaGeolytic() {
  const { user } = useAuth();
  const navigate  = useNavigate();
  const { colorScheme } = useMantineColorScheme();
  const isDark = colorScheme === 'dark';

  const [loading,     setLoading]     = useState(true);
  const [iframeKey,   setIframeKey]   = useState(0);
  const [geolyticUrl, setGeolyticUrl] = useState('');

  useEffect(() => {
    if (user?.email) {
      generateGeolyticToken(user.email).then((token) => {
        setGeolyticUrl(`/mapas/auth/external?token=${token}`);
      });
    }
  }, [user]);

  const reload = () => { setLoading(true); setIframeKey((k) => k + 1); };

  const displayName = user?.user_metadata?.nombre_completo
    || user?.email?.split('@')[0]
    || 'Usuario';

  return (
    <Box style={{ height: '100vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>

      {/* ── BARRA SUPERIOR ── */}
      <Box
        px="md"
        style={{
          height: 52,
          flexShrink: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderBottom: `1px solid ${isDark ? 'var(--mantine-color-dark-4)' : 'var(--mantine-color-gray-3)'}`,
          background: isDark ? 'var(--mantine-color-dark-7)' : 'white',
        }}
      >
        {/* Izquierda: volver */}
        <Button
          variant="subtle"
          color="cyan"
          size="sm"
          leftSection={<IconArrowLeft size={16} />}
          onClick={() => navigate('/formularios')}
        >
          Volver a EcoDatos
        </Button>

        {/* Centro: título + badge */}
        <Group gap="xs">
          <IconMap2 size={18} color="var(--mantine-color-cyan-5)" />
          <Text fw={800} size="sm" lts="1.5px" tt="uppercase" c="cyan.5">
            Visor de Mapas
          </Text>
          {loading && (
            <Badge color="yellow" variant="dot" size="sm">Cargando...</Badge>
          )}
          {!loading && (
            <Badge color="green" variant="dot" size="sm">Conectado</Badge>
          )}
        </Group>

        {/* Derecha: usuario + recargar */}
        <Group gap="sm">
          <Group gap={6}>
            <IconUser size={14} color="var(--mantine-color-dimmed)" />
            <Text size="xs" c="dimmed">{displayName}</Text>
          </Group>
          <Tooltip label="Recargar mapa" withArrow>
            <ActionIcon
              variant="light"
              color="cyan"
              size="sm"
              onClick={reload}
              loading={loading}
            >
              <IconRefresh size={14} />
            </ActionIcon>
          </Tooltip>
        </Group>
      </Box>

      {/* ── IFRAME ÁREA ── */}
      <Box style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
        {loading && (
          <Center style={{ position: 'absolute', inset: 0, zIndex: 10, background: isDark ? 'var(--mantine-color-dark-8)' : 'var(--mantine-color-gray-0)' }}>
            <Stack align="center" gap="sm">
              <Loader color="cyan" size="lg" type="bars" />
              <Text size="sm" c="cyan.5" fw={700} lts="1px">
                ESTABLECIENDO CONEXIÓN SEGURA...
              </Text>
            </Stack>
          </Center>
        )}

        {geolyticUrl && (
          <iframe
            key={iframeKey}
            src={geolyticUrl}
            title="Geolytic Visor de Mapas"
            width="100%"
            height="100%"
            style={{ border: 'none', display: 'block' }}
            onLoad={() => setLoading(false)}
            referrerPolicy="no-referrer-when-downgrade"
            allow="geolocation"
          />
        )}
      </Box>
    </Box>
  );
}