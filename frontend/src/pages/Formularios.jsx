import { useEffect, useState } from 'react'
import {
  Box,
  Heading,
  Text,
  SimpleGrid,
  Button,
  Card,
  CardHeader,
  CardBody,
  CardFooter,
  Spinner,
  Alert,
  AlertTitle,
  AlertDescription,
  Drawer,
  DrawerOverlay,
  DrawerContent,
  DrawerHeader,
  DrawerBody,
  DrawerCloseButton,
  Stack,
  useDisclosure,
} from '@chakra-ui/react'
import { supabase } from '../lib/supabase'
import FormularioDinamico from '../components/FormularioDinamico'
import TablaDinamica from '../components/TablaDinamica'

export default function Formularios() {
  const [formularios, setFormularios] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const { isOpen, onOpen, onClose } = useDisclosure()
  const [drawerMode, setDrawerMode] = useState(null) // 'form' | 'table'
  const [selectedForm, setSelectedForm] = useState(null)

  useEffect(() => {
    const fetchFormularios = async () => {
      const { data, error } = await supabase
        .from('formularios')
        .select('*')

      if (error) {
        setError(error.message)
      } else {
        setFormularios(data)
      }

      setLoading(false)
    }

    fetchFormularios()
  }, [])

  const openDrawer = (mode, form) => {
    setDrawerMode(mode)
    setSelectedForm(form)
    onOpen()
  }

  // ⏳ Loading
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

  // ❌ Error
  if (error) {
    return (
      <Box minH="100vh" bg="gray.900" p={10}>
        <Alert status="error" borderRadius="md">
          <Box>
            <AlertTitle>Error</AlertTitle>
            <AlertDescription>{error}</AlertDescription>
          </Box>
        </Alert>
      </Box>
    )
  }

  return (
    <Box minH="100vh" bg="gray.900" p={10}>
      <Heading mb={8} color="white">
        Formularios disponibles
      </Heading>

      <SimpleGrid columns={{ base: 1, md: 2, lg: 4 }} spacing={6}>
        {formularios.map((form) => (
          <Card
            key={form.id}
            bg="gray.800"
            borderColor="gray.700"
            borderWidth="1px"
            _hover={{ borderColor: 'cyan.400', transform: 'translateY(-2px)' }}
            transition="all 0.2s"
          >
            <CardHeader>
              <Heading size="md" color="white">
                {form.nombre}
              </Heading>
            </CardHeader>

            <CardBody>
              <Text color="gray.300" fontSize="sm">
                {form.descripcion}
              </Text>
            </CardBody>

            <CardFooter>
              <Stack spacing={2} width="100%">
                <Button
                  colorScheme="cyan"
                  onClick={() => openDrawer('form', form)}
                >
                  Cargar nuevo registro
                </Button>

                <Button
                  variant="outline"
                  colorScheme="cyan"
                  onClick={() => openDrawer('table', form)}
                >
                  Ver tabla
                </Button>
              </Stack>
            </CardFooter>
          </Card>
        ))}
      </SimpleGrid>

      {/* DRAWER */}
      <Drawer isOpen={isOpen} placement="right" onClose={onClose} size={drawerMode === 'table' ? 'full' : 'lg'}>
        <DrawerOverlay />
        <DrawerContent bg="gray.900" color="white">
          <DrawerCloseButton />
          <DrawerHeader borderBottomWidth="1px" borderColor="gray.700">
            {drawerMode === 'form'
              ? `Nuevo registro – ${selectedForm?.nombre}`
              : `Registros – ${selectedForm?.nombre}`}
          </DrawerHeader>

          <DrawerBody>
            {drawerMode === 'form' && (
  <FormularioDinamico
  slug={selectedForm.slug}
  onSubmit={(values) => {
    console.log("SUBMIT", values)
  }}
/>
)}

{drawerMode === 'table' && (
  <TablaDinamica formulario={selectedForm} />
)}
            

            {drawerMode === 'table' && (
              <Box>
                <Text mb={4} color="gray.300">
                  Acá va la tabla con los registros cargados.
                </Text>

                {/* 🔧 FUTURO: tabla real */}
                <Text fontSize="sm" color="gray.500">
                  (placeholder)
                </Text>
              </Box>
            )}
          </DrawerBody>
        </DrawerContent>
      </Drawer>
    </Box>
  )
}
