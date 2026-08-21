// supabase/functions/broadcast-nats/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { getNats } from "../_shared/nats.ts"

serve(async (req) => {
  try {
    const nc = await getNats();
    const sc = new TextEncoder();
    
    // Notificamos a todos los interesados
    nc.publish("cambios.huerfanos", sc.encode(JSON.stringify({ refresh: true })));
    
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (err) {
    return new Response(err.message, { status: 500 });
  }
});