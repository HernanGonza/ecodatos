import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

Deno.serve(async (req) => {
  try {
    const { id, nombre, descripcion, slug, activo } = await req.json()

    const { error } = await supabase
      .from("formularios")
      .update({ nombre, descripcion, slug, activo })
      .eq("id", id)

    if (error) throw error

    return Response.json({ ok: true })
  } catch (e) {
    return Response.json({ error: e.message }, { status: 400 })
  }
})
