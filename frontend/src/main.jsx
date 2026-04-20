// src/main.jsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { Notifications } from '@mantine/notifications'

// Estilos obligatorios de Mantine
import '@mantine/core/styles.css'
import '@mantine/notifications/styles.css'
import 'leaflet/dist/leaflet.css'


// Archivos locales
import App from './App'
import { AuthProvider } from './context/AuthContext'
import { chakraTheme } from './lib/ChakraTheme' // Importamos tu nuevo theme
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <MantineProvider theme={chakraTheme} defaultColorScheme="dark">
      <Notifications position="top-right" zIndex={2000} />
      <AuthProvider>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </AuthProvider>
    </MantineProvider>
  </React.StrictMode>
)