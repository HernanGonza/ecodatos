import React, { useState, useEffect } from 'react';
import { Box, Paper, Loader, Center, Text, Title, Group, Stack, Button } from '@mantine/core';
import { useAuth } from '../context/AuthContext';

const GEOLYTIC_SECRET = 'GRzKkjRZk6W0HlQlncknFnZ5Mk0oyFsKpnaEouLz';

async function generateGeolyticToken(email) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = { email };

  const encode = (obj) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');

  const headerB64 = encode(header);
  const payloadB64 = encode(payload);
  const data = `${headerB64}.${payloadB64}`;

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(GEOLYTIC_SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data));

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  return `${data}.${signatureB64}`;
}

export default function MapaGeolytic() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [key, setKey] = useState(0);
  const [geolyticUrl, setGeolyticUrl] = useState('');

  useEffect(() => {
    if (user?.email) {
      generateGeolyticToken(user.email).then((token) => {
  console.log('Token generado:', token);
  console.log('Email usado:', user.email);
  setGeolyticUrl(`/mapas/auth/external?token=${token}`);
});
    }
  }, [user]);

  const handleLoad = () => { setLoading(false); setError(false); };
  const reloadIframe = () => { setLoading(true); setError(false); setKey((prev) => prev + 1); };

  if (!geolyticUrl) return null;

  return (
    <Box p="md" style={{ height: 'calc(100vh - 80px)', display: 'flex', flexDirection: 'column' }}>
      <Group justify="space-between" mb="md">
        <Stack gap={0}>
          <Title order={3} c="cyan.5" style={{ textTransform: 'uppercase', letterSpacing: '1px' }}>
            Visor Geolytic
          </Title>
          <Text size="xs" c="dimmed">Conectado a: 10.0.0.243</Text>
        </Stack>
        <Button variant="light" color="cyan" size="xs" onClick={reloadIframe} loading={loading}>
          RECARGAR MAPA
        </Button>
      </Group>

      <Paper shadow="md" radius="md" withBorder style={{ flex: 1, position: 'relative', overflow: 'hidden', backgroundColor: 'var(--mantine-color-body)' }}>
        {loading && (
          <Center style={{ position: 'absolute', inset: 0, zIndex: 10, backgroundColor: 'var(--mantine-color-body)', flexDirection: 'column' }}>
            <Stack align="center" gap="sm">
              <Loader color="cyan" size="lg" type="bars" />
              <Text size="sm" c="cyan.5" fw={700} style={{ letterSpacing: '1px' }}>
                ESTABLECIENDO CONEXIÓN SEGURA...
              </Text>
            </Stack>
          </Center>
        )}
        {error && (
          <Center style={{ position: 'absolute', inset: 0, zIndex: 20, backgroundColor: 'var(--mantine-color-body)' }}>
            <Stack align="center">
              <Text c="red" fw={600}>No se pudo cargar el servidor de mapas.</Text>
              <Button variant="outline" color="red" size="sm" onClick={reloadIframe}>Reintentar</Button>
            </Stack>
          </Center>
        )}
        <iframe
          key={key}
          src={geolyticUrl}
          title="Geolytic Maps"
          width="100%"
          height="100%"
          style={{ border: 'none' }}
          onLoad={handleLoad}
          referrerPolicy="no-referrer-when-downgrade"
          allow="geolocation; microphone; camera"
        />
      </Paper>
    </Box>
  );
}