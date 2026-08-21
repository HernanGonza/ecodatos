import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

Deno.serve(async (req) => {
  try {
    const { area_id, nombre, descripcion, slug } = await req.json()

    const { data, error } = await supabase
      .from("formularios")
      .insert({ area_id, nombre, descripcion, slug })
      .select()
      .single()

    if (error) throw error

    return Response.json(data)
  } catch (e) {
    return Response.json({ error: e.message }, { status: 400 })
  }
})
