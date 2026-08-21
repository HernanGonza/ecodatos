// src/lib/ChakraTheme.js
import { createTheme, rem } from '@mantine/core';

export const chakraTheme = createTheme({
  primaryColor: 'cyan',
  primaryShade: 6,
  fontFamily: 'Inter, system-ui, sans-serif',
  defaultRadius: 'md',

  // COLORES: Extraídos de Chakra UI v3
  colors: {
    gray: [
      '#F7FAFC', '#EDF2F7', '#E2E8F0', '#CBD5E0', '#A0AEC0', 
      '#718096', '#4A5568', '#2D3748', '#1A202C', '#171923'
    ],
    cyan: [
      '#EDFDFD', '#C4F1F9', '#9DECF9', '#76E4F7', '#0BC5EA', 
      '#00B5D8', '#00A3C4', '#0987A0', '#086F83', '#065666'
    ],
    red: [
      '#FFF5F5', '#FED7D7', '#FEB2B2', '#FC8181', '#F56565',
      '#E53E3E', '#C53030', '#9B2C2C', '#822727', '#63171B'
    ],
    green: [
      '#F0FFF4', '#C6F6D5', '#9AE6B4', '#68D391', '#48BB78',
      '#38A169', '#2F855A', '#276749', '#22543D', '#1C4532'
    ],
    orange: [
      '#FFFAF0', '#FEEBC8', '#FBD38D', '#F6AD55', '#ED8936',
      '#DD6B20', '#C05621', '#9C4221', '#7B341E', '#652B19'
    ]
  },

  // SOMBRAS: Elevación real de Chakra
  shadows: {
    xs: '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
    sm: '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06)',
    md: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
    lg: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
    xl: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
    '2xl': '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
  },

  // COMPONENTES: Ajustes para forzar el comportamiento de Chakra
  components: {
    Button: {
      defaultProps: { fw: 600, radius: 'md' },
      styles: {
        root: { transition: 'all 0.2s cubic-bezier(.08,.52,.52,1)' }
      }
    },
    TextInput: {
      styles: (theme) => ({
        input: {
          backgroundColor: 'var(--mantine-color-body)',
          color: 'var(--mantine-color-text)',
          '&::placeholder': {
            color: 'var(--mantine-color-dimmed)',
          },
        },
      }),
    },
    Select: {
      styles: (theme) => ({
        input: {
          backgroundColor: 'var(--mantine-color-body)',
          color: 'var(--mantine-color-text)',
        },
        dropdown: {
          backgroundColor: 'var(--mantine-color-body)',
          border: `${rem(1)} solid var(--mantine-color-default-border)`,
        },
        option: {
          // Esto arregla que las opciones no se vean en tema claro
          '&[data-selected]': {
            backgroundColor: 'var(--mantine-color-cyan-filled)',
          },
          '&[data-hovered]': {
            backgroundColor: 'var(--mantine-color-gray-light)',
          },
        },
      }),
    },
    Paper: {
      defaultProps: { withBorder: true, shadow: 'sm', radius: 'md' },
    },
    Card: {
      defaultProps: { withBorder: true, shadow: 'sm', radius: 'md' }
    },
    Checkbox: {
      styles: {
        input: { cursor: 'pointer', borderRadius: '4px' }
      }
    },
    Table: {
      defaultProps: { verticalSpacing: 'md', horizontalSpacing: 'md' },
      vars: (theme) => ({
        root: {
          '--table-bg': 'var(--mantine-color-body)',
          '--table-hover-color': 'var(--mantine-color-gray-light)',
        },
      }),
      styles: {
        th: {
          textTransform: 'uppercase',
          fontSize: '11px',
          fontWeight: 700,
          letterSpacing: '0.05em',
          backgroundColor: 'var(--mantine-color-gray-light)',
        }
      }
    },
    Modal: {
      defaultProps: { radius: 'lg', shadow: 'xl' },
      styles: { title: { fontWeight: 700 } }
    },
    Drawer: {
      defaultProps: { position: 'right', size: 'lg' }
    }
  }
});