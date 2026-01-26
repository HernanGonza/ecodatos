import { Routes, Route, Navigate } from 'react-router-dom'
import Login from './pages/Login'
import Formularios from './pages/Formularios'
import ProtectedRoute from './components/ProtectedRoute'

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Login />} />

      <Route
        path="/formularios"
        element={
          <ProtectedRoute>
            <Formularios />
          </ProtectedRoute>
        }
      />

      <Route path="*" element={<Navigate to="/" />} />
    </Routes>
  )
}
