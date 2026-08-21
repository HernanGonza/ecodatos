import { Box, Text } from '@mantine/core';
import { motion, useTransform, useMotionValue, animate, AnimatePresence } from 'framer-motion';
import { useEffect, useState } from 'react';
import classes from './BrandLoader.module.css';

export default function BrandLoader({ onFinished }) {
  const DURATION = 4;
  const progress = useMotionValue(0);
  const [index, setIndex] = useState(-1); // Empezamos en -1 para que no haya texto al inicio

  const texts = [
    "AUTENTICANDO ACCESO",
    "VERIFICANDO CREDENCIALES",
    "INICIANDO PANEL DE GESTIÓN"
  ];

  // --- CONFIGURACIÓN DE SINCRONÍA (Offset) ---
  // Subí estos números si sentís que el texto sigue apareciendo antes que el logo
  const inicioTexto1 = 35; // El primer texto aparece cuando el logo ya llenó el 12%
  const inicioTexto2 = 45; // El segundo texto aparece al 45%
  const inicioTexto3 = 78; // El tercer texto aparece al 78%

  useEffect(() => {
    const controls = animate(progress, 100, {
      duration: DURATION,
      ease: "linear",
      onUpdate: (latest) => {
        // Lógica de disparos de texto con delay visual
        if (latest < inicioTexto1) {
          setIndex(-1);
        } else if (latest < inicioTexto2) {
          setIndex(0);
        } else if (latest < inicioTexto3) {
          setIndex(1);
        } else {
          setIndex(2);
        }
      },
      onComplete: () => {
        setTimeout(() => onFinished?.(), 500);
      }
    });

    return () => controls.stop();
  }, [onFinished, progress]);

  // Altura del logo atada al progreso
  const height = useTransform(progress, [0, 100], ["0%", "100%"]);

  return (
    <div className={classes.overlay}>
      <div className={classes.logoContainer}>
        <img src="/ECODATOS-verde.png" className={classes.logoBase} alt="base" />
        
        <motion.div 
          className={classes.logoFillWrapper}
          style={{ height }}
        >
          <img src="/ECODATOS-verde.png" className={classes.logoFill} alt="fill" />
        </motion.div>
      </div>

      <Box h={40} mt="xl" style={{ textAlign: 'center', width: '100%' }}>
        <AnimatePresence mode="wait">
          {index >= 0 && (
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.6, ease: "easeOut" }}
            >
              <Text 
                size="xl" 
                fw={700} 
                c="cyan.6" 
                className={classes.loadingText}
              >
                {texts[index]}
              </Text>
            </motion.div>
          )}
        </AnimatePresence>
      </Box>
    </div>
  );
}