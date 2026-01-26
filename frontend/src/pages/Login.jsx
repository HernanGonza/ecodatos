import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Box,
  Button,
  Heading,
  Input,
  Stack,
  Text,
  Alert,
  Spinner,
} from '@chakra-ui/react'
import { supabase } from '../lib/supabase'
import { useAuth } from '../context/AuthContext'

export default function Login() {
  const navigate = useNavigate()
  const { user } = useAuth()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (user) {
      navigate('/formularios')
    }
  }, [user, navigate])

  const handleLogin = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError(null)

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })

    setLoading(false)

    if (error) {
      setError(error.message)
    }
  }

  return (
    <Box
      minH="100vh"
      display="flex"
      alignItems="center"
      justifyContent="center"
      px={4}
      bg="gray.900"
    >
      <Box
        w="100%"
        maxW="420px"
        bg="gray.800"
        p={8}
        borderRadius="lg"
        boxShadow="xl"
      >
        <Stack spacing={6}>
          <Box textAlign="center">
            <Heading size="md" color="white">
              Carga de datos – Observatorio Ambiental
            </Heading>
            <Text fontSize="sm" color="gray.400" mt={2}>
              Subsecretaría de Ordenamiento Territorial
            </Text>
          </Box>

          <form onSubmit={handleLogin}>
            <Stack spacing={4}>
              <Input
                type="email"
                placeholder="Email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                bg="gray.700"
                border="none"
                color="white"
                _focus={{ bg: 'gray.600' }}
                required
              />

              <Input
                type="password"
                placeholder="Contraseña"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                bg="gray.700"
                border="none"
                color="white"
                _focus={{ bg: 'gray.600' }}
                required
              />

              <Button
                type="submit"
                colorScheme="cyan"
                isDisabled={loading}
              >
                {loading ? (
                  <>
                    <Spinner size="sm" mr={2} />
                    Ingresando…
                  </>
                ) : (
                  'Ingresar'
                )}
              </Button>
            </Stack>
          </form>

          {error && (
            <Alert status="error" borderRadius="md">
              {error}
            </Alert>
          )}
        </Stack>
      </Box>
    </Box>
  )
}
