import { useState } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useMantineColorScheme, Box } from '@mantine/core';
import { motion, AnimatePresence } from 'framer-motion';
import BrandLoader from '../components/BrandLoader';

export default function ProtectedRoute({ children }) {
  const { user, loading: authLoading } = useAuth();
  const [isAnimationDone, setIsAnimationDone] = useState(false);
  const { colorScheme } = useMantineColorScheme();
  const isDark = colorScheme === 'dark';

  const bgColor = isDark ? 'var(--mantine-color-gray-9)' : 'var(--mantine-color-gray-0)';

  if (!authLoading && !user) return <Navigate to="/" replace />;

  return (
    <Box style={{ position: 'relative', minHeight: '100vh', background: bgColor }}>
      <AnimatePresence>
        {(!user || !isAnimationDone) && (
          <motion.div
            key="loader-wrapper"
            initial={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.8, ease: "easeInOut" }} // Fade out más lento para el cruce
            style={{
              position: 'fixed',
              inset: 0,
              zIndex: 9999,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: bgColor
            }}
          >
            {user && <BrandLoader onFinished={() => setIsAnimationDone(true)} />}
          </motion.div>
        )}
      </AnimatePresence>

      {/* El contenido ya está ahí, pero oculto por el loader arriba */}
      {user && isAnimationDone && (
        <motion.div
          key="app-content"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.8 }}
        >
          {children}
        </motion.div>
      )}
    </Box>
  );
}