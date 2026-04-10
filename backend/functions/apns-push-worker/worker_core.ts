import {
  isPermanentTokenError,
  normalizeError,
  suggestedRetryDelaySeconds,
  type ClaimedJob,
} from "./worker_utils.ts"

export type WorkerRunOptions = {
  batchSize: number
  maxAttempts: number
  lockTimeoutSeconds: number
  workerID: string
}

export type WorkerCycleSummary = {
  workerID: string
  recovered: number
  claimed: number
  sent: number
  failed: number
}

export type WorkerRPCError = {
  message: string
}

export type WorkerRPCResponse = {
  data: unknown
  error: WorkerRPCError | null
}

export type WorkerRPCClient = {
  rpc(name: string, args: Record<string, unknown>): Promise<WorkerRPCResponse>
}

export type PushSender = (job: ClaimedJob) => Promise<Record<string, unknown>>

export class WorkerCycleError extends Error {
  code: "recover_stale_locks_failed" | "claim_failed"

  constructor(code: "recover_stale_locks_failed" | "claim_failed", details: string) {
    super(details)
    this.code = code
  }
}

export async function runWorkerCycle(
  client: WorkerRPCClient,
  sendPush: PushSender,
  options: WorkerRunOptions,
): Promise<WorkerCycleSummary> {
  const recoverResponse = await client.rpc("recover_stale_push_delivery_jobs", {
    input_lock_timeout_seconds: options.lockTimeoutSeconds,
    input_max_attempts: options.maxAttempts,
  })
  if (recoverResponse.error) {
    throw new WorkerCycleError("recover_stale_locks_failed", recoverResponse.error.message)
  }

  const claimResponse = await client.rpc("claim_push_delivery_jobs", {
    input_batch_size: options.batchSize,
    input_worker_id: options.workerID,
    input_max_attempts: options.maxAttempts,
  })
  if (claimResponse.error) {
    throw new WorkerCycleError("claim_failed", claimResponse.error.message)
  }

  const jobs = ((claimResponse.data ?? []) as ClaimedJob[])
  let sent = 0
  let failed = 0

  for (const job of jobs) {
    try {
      const provider = await sendPush(job)
      const markSent = await client.rpc("mark_push_delivery_job_sent", {
        input_job_id: job.id,
        input_provider_response: provider,
      })
      if (markSent.error) {
        failed += 1
        continue
      }
      sent += 1
    } catch (error) {
      failed += 1
      const details = normalizeError(error)
      const tokenIsInvalid = isPermanentTokenError(details.status, details.reason)
      const retryDelaySeconds = suggestedRetryDelaySeconds(details.status)
      await client.rpc("mark_push_delivery_job_failed", {
        input_job_id: job.id,
        input_error: details.message,
        input_retry_delay_seconds: retryDelaySeconds,
        input_max_attempts: tokenIsInvalid ? 1 : options.maxAttempts,
        input_provider_response: {
          status: details.status,
          reason: details.reason,
          body: details.body,
        },
      })

      if (tokenIsInvalid) {
        await client.rpc("deactivate_push_token_for_job", {
          input_job_id: job.id,
          input_reason: details.reason ?? "apns_unregistered",
        })
      }
    }
  }

  return {
    workerID: options.workerID,
    recovered: Number(recoverResponse.data ?? 0),
    claimed: jobs.length,
    sent,
    failed,
  }
}
