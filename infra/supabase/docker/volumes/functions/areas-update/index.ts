import { createClient } from 'npm:@supabase/supabase-js@2'
const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

async function requireSuperAdmin(req: Request) {
  const jwt = req.headers.get("Authorization")?.replace("Bearer ", "")
  if (!jwt) throw new Error("Missing token")

  const { data: userData, error } = await supabaseAdmin.auth.getUser(jwt)
  if (error || !userData.user) throw new Error("Invalid token")

  const user = userData.user

  const { data: rol } = await supabaseAdmin
    .from("usuarios_rol")
    .select("roles(key)")
    .eq("user_id", user.id)
    .single()

  if (rol?.roles?.key !== "superadmin") throw new Error("Forbidden")
  return user
}

Deno.serve(async (req) => {
  try {
    await requireSuperAdmin(req)
    const { id, nombre, descripcion, activo } = await req.json()
    if (!id || !nombre) throw new Error("Missing fields")

    const { error } = await supabaseAdmin
      .from("areas")
      .update({ nombre, descripcion, activo })
      .eq("id", id)
    if (error) throw error

    return Response.json({ ok: true })
  } catch (e) {
    return Response.json({ error: e.message }, { status: 400 })
  }
})
