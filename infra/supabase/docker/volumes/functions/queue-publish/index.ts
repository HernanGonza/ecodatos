import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { getNats } from "../_shared/nats.ts";
import { StringCodec } from "https://deno.land/x/nats@v1.16.0/src/mod.ts";

const sc = StringCodec();

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { subject, payload } = await req.json();

    if (!subject || !payload) {
      return new Response(
        JSON.stringify({ error: "Faltan campos: subject, payload" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const nc = await getNats();
    const js = nc.jetstream();

    const pa = await js.publish(subject, sc.encode(JSON.stringify(payload)), {
      msgID: crypto.randomUUID(),
    });
    await nc.flush();

    console.log(`📤 [PUBLISH] ${subject} (seq: ${pa.seq})`);

    // Despertador — igual que en universal-create
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    fetch("http://kong:8000/functions/v1/queue", {
      method: "GET",
      headers: { Authorization: `Bearer ${SERVICE_ROLE}` },
    }).catch(() => {});

    return new Response(
      JSON.stringify({ ok: true, subject }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("💥 PUBLISH ERROR:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});