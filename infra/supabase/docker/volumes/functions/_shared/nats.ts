import { connect, StringCodec } from "https://deno.land/x/nats@v1.16.0/src/mod.ts";

const sc = StringCodec();
let nc: any;

export async function getNats() {
  if (!nc) {
    // Intentamos conectar al host de Supabase NATS
    const natsUrl = Deno.env.get("NATS_URL") ?? "nats://supabase-nats:4222";
    console.log(`🔌 Conectando a NATS en ${natsUrl}...`);
    
    nc = await connect({
      servers: natsUrl,
      user: Deno.env.get("NATS_USER") ?? "admin",
      pass: Deno.env.get("NATS_PASS") ?? "admin_pass",
    });
    console.log("✅ Conexión compartida de NATS lista.");
  }
  return nc;
}

// Para mensajería instantánea (Fuego y olvido)
export async function publish(subject: string, payload: unknown) {
  const nc = await getNats();
  nc.publish(subject, sc.encode(JSON.stringify(payload)));
}

// Para la cola persistente (JetStream) - CRÍTICO para Queue
export async function enqueue(subject: string, payload: unknown) {
  const nc = await getNats();
  const js = nc.jetstream();
  
  console.log(`[NATS Shared] Publicando en ${subject}...`);
  
  // Publicamos
  const pa = await js.publish(subject, sc.encode(JSON.stringify(payload)));
  
  // FORZAMOS EL ENVÍO (Crucial para evitar el Early Termination)
  await nc.flush(); 
  
  return pa;
}

