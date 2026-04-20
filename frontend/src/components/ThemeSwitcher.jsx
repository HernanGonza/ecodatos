import { ActionIcon, useMantineColorScheme, Tooltip, Box } from '@mantine/core';
import { IconSun, IconMoon } from '@tabler/icons-react';
import classes from './ThemeSwitcher.module.css';

export default function ThemeSwitcher() {
  const { colorScheme, toggleColorScheme } = useMantineColorScheme();
  const isDark = colorScheme === 'dark';

  return (
    <Tooltip 
      label={isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro'} 
      withArrow 
      position="bottom"
      offset={10}
      radius="sm"
      fw={600}
    >
      <ActionIcon
        onClick={() => toggleColorScheme()}
        variant="subtle"
        color="gray" // Usamos gris para el estado base estilo Chakra
        size="lg"
        radius="md"
        className={classes.actionIcon}
        aria-label="Cambiar tema de color"
      >
        <Box className={classes.iconWrapper}>
          {isDark ? (
            <IconSun 
              size={20} 
              stroke={2} 
              color="var(--mantine-color-yellow-4)" 
            />
          ) : (
            <IconMoon 
              size={20} 
              stroke={2} 
              color="var(--mantine-color-cyan-7)" 
            />
          )}
        </Box>
      </ActionIcon>
    </Tooltip>
  );
}