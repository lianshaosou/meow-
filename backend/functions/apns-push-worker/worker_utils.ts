export type ClaimedJob = {
  id: string
  notification_id: string
  user_id: string
  token: string
  environment: "sandbox" | "production"
  payload: Record<string, unknown>
  attempts: number
  next_attempt_at: string
}

export function makeApsPayload(job: ClaimedJob): Record<string, unknown> {
  const title = stringifyOr(job.payload?.title, "Meow")
  const body = stringifyOr(job.payload?.body, "A cat event is waiting for you.")

  const basePayload = {
    ...job.payload,
    notification_id: job.notification_id,
    user_id: job.user_id,
  }

  return {
    aps: {
      alert: {
        title,
        body,
      },
      sound: "default",
    },
    data: basePayload,
  }
}

export function suggestedRetryDelaySeconds(status?: number): number {
  if (!status) return 60
  if (status === 429) return 180
  if (status >= 500) return 120
  if (status === 410 || status === 400) return 600
  return 60
}

export function isPermanentTokenError(status?: number, reason?: string): boolean {
  if (status === 410) return true
  if (status !== 400 || !reason) return false

  return [
    "BadDeviceToken",
    "DeviceTokenNotForTopic",
    "Unregistered",
  ].includes(reason)
}

export function normalizeError(error: unknown): { status?: number; reason?: string; body?: unknown; message: string } {
  if (error && typeof error === "object") {
    const input = error as Record<string, unknown>
    return {
      status: typeof input.status === "number" ? input.status : undefined,
      reason: typeof input.reason === "string" ? input.reason : undefined,
      body: input.body,
      message: typeof input.message === "string" ? input.message : "unknown_error",
    }
  }
  return { message: String(error) }
}

export function normalizePrivateKey(input: string): string {
  const trimmed = input.trim()
  if (!trimmed) return ""
  return trimmed.replace(/\\n/g, "\n")
}

function stringifyOr(value: unknown, fallback: string): string {
  if (typeof value === "string" && value.trim().length > 0) return value
  return fallback
}
