import { Navigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { Box, Spinner } from '@chakra-ui/react'

export default function ProtectedRoute({ children }) {
  const { user, loading } = useAuth()

  // ⏳ Mientras valida sesión
  if (loading) {
    return (
      <Box
        minH="100vh"
        display="flex"
        alignItems="center"
        justifyContent="center"
        bg="gray.900"
      >
        <Spinner size="xl" color="cyan.400" />
      </Box>
    )
  }

  // 🚫 No logueado
  if (!user) {
    return <Navigate to="/" replace />
  }

  // ✅ Logueado
  return children
}
