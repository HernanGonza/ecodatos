import { createClient } from 'npm:@supabase/supabase-js@2'
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

async function requireSuperAdmin(req: Request) {
  const jwt = req.headers.get("Authorization")?.replace("Bearer ", "")
  if (!jwt) throw new Error("Missing token")

  const { data } = await supabase.auth.getUser(jwt)
  const user = data.user
  if (!user) throw new Error("Invalid token")

  const { data: rol } = await supabase
    .from("usuarios_rol")
    .select("roles(nombre)")
    .eq("user_id", user.id)
    .single()

  if (rol?.roles?.nombre !== "superadmin") {
    throw new Error("Forbidden")
  }

  return user
}

Deno.serve(async (req) => {
  try {
    const jwt = req.headers.get("Authorization")?.replace("Bearer ", "")
    if (!jwt) throw new Error("Missing token")

    const { data } = await supabase.auth.getUser(jwt)
    const user = data.user
    if (!user) throw new Error("Invalid token")

    const { data: rol } = await supabase
      .from("usuarios_rol")
      .select("roles(nombre)")
      .eq("user_id", user.id)
      .single()

    const { data: areas } = await supabase
      .from("usuarios_areas")
      .select("areas(id, nombre)")
      .eq("user_id", user.id)

    return Response.json({
      id: user.id,
      email: user.email,
      rol: rol?.roles?.nombre ?? null,
      areas: areas?.map(a => a.areas) ?? []
    })
  } catch (e) {
    return Response.json({ error: e.message }, { status: 401 })
  }
})
