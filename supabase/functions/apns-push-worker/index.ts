import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  makeApsPayload,
  normalizePrivateKey,
  type ClaimedJob,
} from "./worker_utils.ts"
import { runWorkerCycle, WorkerCycleError } from "./worker_core.ts"

const supabaseURL = Deno.env.get("SUPABASE_URL") ?? ""
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const apnsTopic = Deno.env.get("APNS_TOPIC") ?? ""
const apnsAuthBearerToken = Deno.env.get("APNS_AUTH_BEARER_TOKEN") ?? ""
const apnsKeyID = Deno.env.get("APNS_KEY_ID") ?? ""
const apnsTeamID = Deno.env.get("APNS_TEAM_ID") ?? ""
const apnsPrivateKeyP8 = Deno.env.get("APNS_PRIVATE_KEY_P8") ?? ""
const apnsAuthTokenTTLSeconds = clampInt(
  Number(Deno.env.get("APNS_AUTH_TOKEN_TTL_SECONDS") ?? "3000"),
  300,
  3300,
  3000,
)

const supabase = createClient(supabaseURL, serviceRoleKey)
let cachedAPNSToken: { token: string; expiresAtMillis: number } | null = null

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405)
  }

  if (!supabaseURL || !serviceRoleKey || !apnsTopic) {
    return json({ error: "missing_required_env" }, 500)
  }

  if (!apnsAuthBearerToken && !(apnsKeyID && apnsTeamID && apnsPrivateKeyP8)) {
    return json({ error: "missing_required_env" }, 500)
  }

  const body = await safeJSON(request)
  const batchSize = clampInt(body?.batchSize, 1, 200, 50)
  const maxAttempts = clampInt(body?.maxAttempts, 1, 20, 5)
  const lockTimeoutSeconds = clampInt(body?.lockTimeoutSeconds, 30, 3600, 300)
  const workerID = typeof body?.workerID === "string" && body.workerID.trim().length > 0
    ? body.workerID.trim()
    : `apns-edge-${crypto.randomUUID().slice(0, 8)}`

  try {
    const summary = await runWorkerCycle(
      {
        async rpc(name: string, args: Record<string, unknown>) {
          const result = await supabase.rpc(name, args)
          return {
            data: result.data,
            error: result.error ? { message: result.error.message } : null,
          }
        },
      },
      sendAPNS,
      { batchSize, maxAttempts, lockTimeoutSeconds, workerID },
    )

    return json(summary, 200)
  } catch (error) {
    if (error instanceof WorkerCycleError) {
      return json({ error: error.code, details: error.message }, 500)
    }
    return json({ error: "worker_cycle_failed", details: String(error) }, 500)
  }
})

async function sendAPNS(job: ClaimedJob): Promise<Record<string, unknown>> {
  const host = job.environment === "production"
    ? "api.push.apple.com"
    : "api.sandbox.push.apple.com"

  const deviceToken = job.token.trim()
  const endpoint = `https://${host}/3/device/${encodeURIComponent(deviceToken)}`
  const apsPayload = makeApsPayload(job)
  const authToken = await getAPNSAuthToken()

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      authorization: `bearer ${authToken}`,
      "apns-topic": apnsTopic,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: JSON.stringify(apsPayload),
  })

  const rawBody = await response.text()
  const parsedBody = safeParseJSON(rawBody)

  if (!response.ok) {
    const reason = typeof parsedBody?.reason === "string" ? parsedBody.reason : "APNS_REQUEST_FAILED"
    throw {
      status: response.status,
      reason,
      body: parsedBody ?? rawBody,
      message: `APNs request failed (${response.status}) ${reason}`,
    }
  }

  return {
    status: response.status,
    apns_id: response.headers.get("apns-id"),
    body: parsedBody ?? rawBody,
  }
}

async function getAPNSAuthToken(): Promise<string> {
  const staticToken = apnsAuthBearerToken.trim()
  if (staticToken) {
    return staticToken
  }

  const now = Date.now()
  if (cachedAPNSToken && now < cachedAPNSToken.expiresAtMillis) {
    return cachedAPNSToken.token
  }

  const keyID = apnsKeyID.trim()
  const teamID = apnsTeamID.trim()
  const privateKey = normalizePrivateKey(apnsPrivateKeyP8)
  if (!keyID || !teamID || !privateKey) {
    throw new Error("missing_apns_jwt_material")
  }

  const token = await generateAPNSJWT({ keyID, teamID, privateKey })
  cachedAPNSToken = {
    token,
    expiresAtMillis: now + apnsAuthTokenTTLSeconds * 1000,
  }
  return token
}

async function generateAPNSJWT(input: { keyID: string; teamID: string; privateKey: string }): Promise<string> {
  const header = { alg: "ES256", kid: input.keyID, typ: "JWT" }
  const payload = { iss: input.teamID, iat: Math.floor(Date.now() / 1000) }
  const headerPayload = `${toBase64UrlJSON(header)}.${toBase64UrlJSON(payload)}`

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(input.privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  )

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    new TextEncoder().encode(headerPayload),
  )

  return `${headerPayload}.${toBase64Url(new Uint8Array(signature))}`
}

function safeParseJSON(input: string): Record<string, unknown> | null {
  if (!input) return null
  try {
    const value = JSON.parse(input)
    if (value && typeof value === "object" && !Array.isArray(value)) {
      return value as Record<string, unknown>
    }
    return { value }
  } catch {
    return null
  }
}

async function safeJSON(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const value = await request.json()
    if (value && typeof value === "object" && !Array.isArray(value)) {
      return value as Record<string, unknown>
    }
    return null
  } catch {
    return null
  }
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "")
  const bytes = Uint8Array.from(atob(base64), (char) => char.charCodeAt(0))
  return bytes.buffer
}

function toBase64UrlJSON(input: Record<string, unknown>): string {
  return toBase64Url(new TextEncoder().encode(JSON.stringify(input)))
}

function toBase64Url(input: Uint8Array): string {
  let binary = ""
  for (const byte of input) {
    binary += String.fromCharCode(byte)
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
}

function clampInt(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || Number.isFinite(value) === false) return fallback
  return Math.min(max, Math.max(min, Math.trunc(value)))
}

function json(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  })
}
