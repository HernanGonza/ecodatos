import { Routes, Route, Navigate } from "react-router-dom";
import Login from "./pages/Login";
import Formularios from "./pages/Formularios";
import Recuperacion from "./pages/Recuperacion";
import ProtectedRoute from "./components/ProtectedRoute";
import MapaGeolytic from "./pages/MapaGeolytic";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Login />} />
      <Route path="/recuperacion" element={<Recuperacion />} />

      {/* Formularios maneja sus propias sub-rutas internamente */}
      <Route
        path="/formularios/*"
        element={
          <ProtectedRoute>
            <Formularios />
          </ProtectedRoute>
        }
      />

      <Route
        path="/mapas"
        element={
          <ProtectedRoute>
            <MapaGeolytic />
          </ProtectedRoute>
        }
      />

      <Route path="*" element={<Navigate to="/" />} />
    </Routes>
  );
}