import { useEffect, useState } from 'react'
import {
  Box,
  Spinner,
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
} from '@chakra-ui/react'
import { supabase } from '../lib/supabase'

export default function TablaDinamica({ formulario }) {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchData = async () => {
      const { data } = await supabase
        .from(formulario.tabla_destino)
        .select('*')

      setRows(data || [])
      setLoading(false)
    }

    fetchData()
  }, [formulario])

  if (loading) return <Spinner color="cyan.400" />

  if (!rows.length) {
    return <Box color="gray.400">Sin registros</Box>
  }

  const columns = Object.keys(rows[0])

  return (
    <Table variant="simple" size="sm">
      <Thead>
        <Tr>
          {columns.map((col) => (
            <Th key={col}>{col}</Th>
          ))}
        </Tr>
      </Thead>

      <Tbody>
        {rows.map((row, i) => (
          <Tr key={i}>
            {columns.map((col) => (
              <Td key={col}>{row[col]}</Td>
            ))}
          </Tr>
        ))}
      </Tbody>
    </Table>
  )
}
