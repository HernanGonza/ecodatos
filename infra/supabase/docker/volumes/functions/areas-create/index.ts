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
    if (req.method !== "POST") throw new Error("Method not allowed")
    await requireSuperAdmin(req)

    const { key, nombre, descripcion } = await req.json()
    if (!key || !nombre) throw new Error("Missing fields")

    const { data, error } = await supabaseAdmin
      .from("areas")
      .insert({ key, nombre, descripcion, activo: true })
      .select()
      .single()
    if (error) throw error

    return Response.json(data)
  } catch (e) {
    return Response.json({ error: e.message }, { status: 400 })
  }
})
