import { useEffect, useState } from "react"
import {
  Box,
  Button,
  Input,
  Textarea,
  Spinner,
  Text
} from "@chakra-ui/react"
import { supabase } from "../lib/supabase"

const CAMPOS_EXCLUIDOS = [
  "id",
  "created_at",
  "created_by",
  "user_id",
  "formulario_id"
]

export default function FormularioDinamico({ slug, onSubmit }) {
  console.log("🟢 MOUNT FormularioDinamico", { slug })

  const [fields, setFields] = useState([])
  const [values, setValues] = useState({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    console.log("🟡 useEffect disparado", { slug })

    const fetchMetadata = async () => {
      console.log("🔵 fetchMetadata INICIO")
      setLoading(true)
      setError(null)

      try {
        const {
          data: { session },
          error: sessionError
        } = await supabase.auth.getSession()

        console.log("🧩 session", session)
        console.log("🧩 sessionError", sessionError)

        if (!session) {
          console.error("❌ No hay sesión válida")
          setError("Sesión no válida")
          setLoading(false)
          return
        }

        const url = `/functions/v1/formulario-metadata?slug=${slug}`
        console.log("🌍 FETCH URL:", url)

        const res = await fetch(url, {
          headers: {
            Authorization: `Bearer ${session.access_token}`
          }
        })

        console.log("📡 response.status", res.status)
        console.log("📡 response.ok", res.ok)
        console.log(
          "📡 response.headers",
          Object.fromEntries(res.headers.entries())
        )

        const rawText = await res.text()
        console.log("📦 RAW RESPONSE:", rawText)

        let json
        try {
          json = JSON.parse(rawText)
        } catch (e) {
          console.error("❌ La respuesta NO es JSON")
          setError("La API no devolvió JSON válido")
          setLoading(false)
          return
        }

        console.log("✅ JSON PARSEADO:", json)

        const filteredFields = (json.fields ?? []).filter(
          f => !CAMPOS_EXCLUIDOS.includes(f.campo)
        )

        console.log("🧹 fields filtrados:", filteredFields)

        setFields(filteredFields)
        console.log("🟢 setFields ejecutado")
      } catch (err) {
        console.error("🔥 ERROR en fetchMetadata", err)
        setError("No se pudo cargar el formulario")
      } finally {
        setLoading(false)
        console.log("⏹ loading = false")
      }
    }

    if (!slug) {
      console.warn("⚠️ slug vacío, no se ejecuta fetch")
      setLoading(false)
      return
    }

    fetchMetadata()
  }, [slug])

  console.log("🧱 RENDER", { loading, error, fields })

  const renderField = (f) => {
    console.log("🧩 renderField", f)

    const commonProps = {
      placeholder: f.label ?? f.campo,
      required: f.requerido,
      onChange: e =>
        setValues(v => {
          const newValues = { ...v, [f.campo]: e.target.value }
          console.log("✏️ values update", newValues)
          return newValues
        })
    }

    if (f.campo === "observaciones") {
      return <Textarea {...commonProps} />
    }

    switch (f.tipo) {
      case "integer":
        return (
          <Input
            type="number"
            {...commonProps}
            onChange={e =>
              setValues(v => {
                const newValues = {
                  ...v,
                  [f.campo]: e.target.value
                    ? Number(e.target.value)
                    : null
                }
                console.log("✏️ values update (int)", newValues)
                return newValues
              })
            }
          />
        )

      case "double precision":
        return (
          <Input
            type="number"
            step="any"
            {...commonProps}
            onChange={e =>
              setValues(v => {
                const newValues = {
                  ...v,
                  [f.campo]: e.target.value
                    ? Number(e.target.value)
                    : null
                }
                console.log("✏️ values update (double)", newValues)
                return newValues
              })
            }
          />
        )

      case "date":
        return <Input type="date" {...commonProps} />

      default:
        return <Input type="text" {...commonProps} />
    }
  }

  if (loading) {
    console.log("⏳ mostrando Spinner")
    return <Spinner />
  }

  if (error) {
    console.log("❌ mostrando error", error)
    return <Text color="red.400">{error}</Text>
  }

  if (!fields.length) {
    console.warn("📭 no hay fields para renderizar")
    return <Text color="gray.400">Este formulario no tiene campos</Text>
  }

  return (
    <Box display="flex" flexDirection="column" gap={4}>
      {fields.map(f => (
        <Box key={f.campo}>
          {renderField(f)}
        </Box>
      ))}

      <Button
        colorScheme="cyan"
        onClick={() => {
          console.log("🚀 SUBMIT", values)
          onSubmit(values)
        }}
      >
        Guardar
      </Button>
    </Box>
  )
}
