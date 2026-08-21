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

      <Route
        path="/formularios/*"
        element={
          <ProtectedRoute>
            <Formularios />
          </ProtectedRoute>
        }
      />

      {/* NUEVO: ruta integrada dentro del flujo principal */}
      <Route
        path="/formularios/mapa"
        element={
          <ProtectedRoute>
            <MapaGeolytic />
          </ProtectedRoute>
        }
      />

      {/* Ruta vieja /mapas — la dejamos como redirect por si había bookmarks */}
      <Route
        path="/mapas"
        element={<Navigate to="/formularios/mapa" replace />}
      />

      <Route path="*" element={<Navigate to="/" />} />
    </Routes>
  );
}