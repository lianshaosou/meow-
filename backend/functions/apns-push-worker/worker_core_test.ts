import { runWorkerCycle, WorkerCycleError, type WorkerRPCClient } from "./worker_core.ts"
import type { ClaimedJob } from "./worker_utils.ts"

function makeJob(id: string): ClaimedJob {
  return {
    id,
    notification_id: `notification-${id}`,
    user_id: "user-1",
    token: `token-${id}`,
    environment: "sandbox",
    payload: { title: "Hi", body: "Body" },
    attempts: 1,
    next_attempt_at: new Date().toISOString(),
  }
}

class MockRPCClient implements WorkerRPCClient {
  calls: Array<{ name: string; args: Record<string, unknown> }> = []
  private responses: Record<string, { data: unknown; error: { message: string } | null }>

  constructor(responses: Record<string, { data: unknown; error: { message: string } | null }>) {
    this.responses = responses
  }

  async rpc(name: string, args: Record<string, unknown>) {
    this.calls.push({ name, args })
    const response = this.responses[name]
    if (!response) return { data: null, error: null }
    return response
  }
}

Deno.test("runWorkerCycle success path marks sent", async () => {
  const client = new MockRPCClient({
    recover_stale_push_delivery_jobs: { data: 2, error: null },
    claim_push_delivery_jobs: { data: [makeJob("a")], error: null },
    mark_push_delivery_job_sent: { data: true, error: null },
  })

  const summary = await runWorkerCycle(
    client,
    async () => ({ status: 200, apns_id: "x" }),
    { batchSize: 50, maxAttempts: 5, lockTimeoutSeconds: 300, workerID: "worker-a" },
  )

  if (summary.recovered != 2) throw new Error("expected recovered count")
  if (summary.claimed != 1) throw new Error("expected claimed count")
  if (summary.sent != 1) throw new Error("expected sent count")
  if (summary.failed != 0) throw new Error("expected zero failures")
})

Deno.test("runWorkerCycle permanent token error deactivates token", async () => {
  const client = new MockRPCClient({
    recover_stale_push_delivery_jobs: { data: 0, error: null },
    claim_push_delivery_jobs: { data: [makeJob("b")], error: null },
    mark_push_delivery_job_failed: { data: true, error: null },
    deactivate_push_token_for_job: { data: true, error: null },
  })

  const summary = await runWorkerCycle(
    client,
    async () => {
      throw { status: 410, reason: "Unregistered", message: "dead token" }
    },
    { batchSize: 50, maxAttempts: 5, lockTimeoutSeconds: 300, workerID: "worker-b" },
  )

  if (summary.sent != 0 || summary.failed != 1) throw new Error("expected one failed job")

  const markFailedCall = client.calls.find((call) => call.name === "mark_push_delivery_job_failed")
  if (!markFailedCall) throw new Error("expected mark_push_delivery_job_failed call")
  if (markFailedCall.args.input_max_attempts !== 1) throw new Error("permanent error must use terminal max attempts")

  const deactivateCall = client.calls.find((call) => call.name === "deactivate_push_token_for_job")
  if (!deactivateCall) throw new Error("expected deactivate_push_token_for_job call")
})

Deno.test("runWorkerCycle wraps claim failure", async () => {
  const client = new MockRPCClient({
    recover_stale_push_delivery_jobs: { data: 0, error: null },
    claim_push_delivery_jobs: { data: null, error: { message: "boom" } },
  })

  let failedWithExpectedError = false
  try {
    await runWorkerCycle(
      client,
      async () => ({ status: 200 }),
      { batchSize: 50, maxAttempts: 5, lockTimeoutSeconds: 300, workerID: "worker-c" },
    )
  } catch (error) {
    failedWithExpectedError = error instanceof WorkerCycleError && error.code === "claim_failed"
  }

  if (!failedWithExpectedError) throw new Error("expected claim_failed WorkerCycleError")
})
