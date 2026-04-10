import {
  isPermanentTokenError,
  makeApsPayload,
  normalizeError,
  normalizePrivateKey,
  suggestedRetryDelaySeconds,
  type ClaimedJob,
} from "./worker_utils.ts"

Deno.test("isPermanentTokenError matches APNs permanent token failures", () => {
  if (!isPermanentTokenError(410, "Unregistered")) throw new Error("expected 410 to be permanent")
  if (!isPermanentTokenError(400, "Unregistered")) throw new Error("expected Unregistered to be permanent")
  if (!isPermanentTokenError(400, "BadDeviceToken")) throw new Error("expected BadDeviceToken to be permanent")
  if (!isPermanentTokenError(400, "DeviceTokenNotForTopic")) throw new Error("expected DeviceTokenNotForTopic to be permanent")
  if (isPermanentTokenError(429, "TooManyRequests")) throw new Error("expected 429 to be retryable")
})

Deno.test("suggestedRetryDelaySeconds returns tuned delays", () => {
  if (suggestedRetryDelaySeconds(undefined) !== 60) throw new Error("default delay mismatch")
  if (suggestedRetryDelaySeconds(429) !== 180) throw new Error("429 delay mismatch")
  if (suggestedRetryDelaySeconds(500) !== 120) throw new Error("5xx delay mismatch")
  if (suggestedRetryDelaySeconds(410) !== 600) throw new Error("410 delay mismatch")
})

Deno.test("makeApsPayload uses fallback and keeps metadata", () => {
  const job: ClaimedJob = {
    id: "job-id",
    notification_id: "n-1",
    user_id: "u-1",
    token: "token",
    environment: "sandbox",
    payload: { category: "encounter" },
    attempts: 1,
    next_attempt_at: new Date().toISOString(),
  }
  const payload = makeApsPayload(job)
  const aps = payload.aps as Record<string, unknown>
  const alert = aps.alert as Record<string, unknown>
  const data = payload.data as Record<string, unknown>

  if (alert.title !== "Meow") throw new Error("fallback title mismatch")
  if (data.notification_id !== "n-1") throw new Error("notification id missing")
  if (data.user_id !== "u-1") throw new Error("user id missing")
})

Deno.test("normalizePrivateKey expands escaped newlines", () => {
  const input = "-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----"
  const output = normalizePrivateKey(input)
  if (!output.includes("\nabc\n")) throw new Error("newline expansion failed")
})

Deno.test("normalizeError handles unknown and object errors", () => {
  const unknown = normalizeError("boom")
  if (unknown.message !== "boom") throw new Error("string normalize mismatch")

  const object = normalizeError({ status: 410, reason: "Unregistered", message: "failed" })
  if (object.status !== 410) throw new Error("status normalize mismatch")
  if (object.reason !== "Unregistered") throw new Error("reason normalize mismatch")
  if (object.message !== "failed") throw new Error("message normalize mismatch")
})
