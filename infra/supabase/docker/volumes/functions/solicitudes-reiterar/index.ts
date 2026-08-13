import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const authHeader = req.headers.get('Authorization')!
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  const supabaseUser = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  try {
    // 1. Verificar sesión
    const { data: { user } } = await supabaseUser.auth.getUser()
    if (!user) throw new Error('No autenticado')

    const { solicitud_id } = await req.json()
    if (!solicitud_id) throw new Error('Falta solicitud_id')

    // 2. Verificar que la solicitud pertenece al usuario y no está aprobada
    const { data: sol, error: solError } = await supabaseAdmin
      .from('solicitudes')
      .select('id, creado, reiteraciones, solicitante_id')
      .eq('id', solicitud_id)
      .single()

    if (solError || !sol) throw new Error('Solicitud no encontrada')
    if (sol.solicitante_id !== user.id) throw new Error('Sin permisos')
    if (sol.creado) throw new Error('La solicitud ya fue aprobada')

    // 3. Incrementar reiteraciones
    const { error: updateError } = await supabaseAdmin
      .from('solicitudes')
      .update({ reiteraciones: (sol.reiteraciones || 0) + 1 })
      .eq('id', solicitud_id)

    if (updateError) throw updateError

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})