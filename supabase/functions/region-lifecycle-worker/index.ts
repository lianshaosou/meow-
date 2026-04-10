import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseURL = Deno.env.get("SUPABASE_URL") ?? ""
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""

const supabase = createClient(supabaseURL, serviceRoleKey)

type WorkerRequest = {
  workerID?: string
  idleHours?: number
  batchSize?: number
  dormancyReason?: string
  archiveReason?: string
  retentionDays?: number | null
  runArchiveSweep?: boolean
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405)
  }

  if (!supabaseURL || !serviceRoleKey) {
    return json({ error: "missing_supabase_env" }, 500)
  }

  const body = await safeJSON(request)
  const input = (body ?? {}) as WorkerRequest

  const workerID = normalizeReason(input.workerID, `region-lifecycle-${crypto.randomUUID().slice(0, 8)}`)
  const idleHours = clampInt(input.idleHours, 1, 24 * 365, 72)
  const batchSize = clampInt(input.batchSize, 1, 2000, 500)
  const dormancyReason = normalizeReason(input.dormancyReason, "idle_timeout")
  const archiveReason = normalizeReason(input.archiveReason, "retention_elapsed")
  const runArchiveSweep = input.runArchiveSweep ?? true
  const retentionDays = normalizeOptionalInt(input.retentionDays, 1, 3650)
  const startedAt = new Date().toISOString()

  const { data: dormantData, error: dormantError } = await supabase.rpc("mark_stale_regions_dormant", {
    input_idle_hours: idleHours,
    input_batch_size: batchSize,
    input_reason: dormancyReason,
    input_retention_days: retentionDays,
  })

  if (dormantError) {
    await logRun({
      workerID,
      status: "failed",
      dormantMarked: 0,
      archivedMarked: 0,
      idleHours,
      batchSize,
      runArchiveSweep,
      startedAt,
      failureStage: "dormancy_sweep",
      errorMessage: dormantError.message,
      details: {
        dormancyReason,
        archiveReason,
        retentionDays,
      },
    })
    return json({ error: "dormancy_sweep_failed", details: dormantError.message }, 500)
  }

  const dormantMarked = numberFromRPCResult(dormantData)
  let archivedMarked = 0

  if (runArchiveSweep) {
    const { data: archiveData, error: archiveError } = await supabase.rpc("mark_expired_dormant_regions_archived", {
      input_batch_size: batchSize,
      input_reason: archiveReason,
    })

    if (archiveError) {
      await logRun({
        workerID,
        status: "failed",
        dormantMarked,
        archivedMarked: 0,
        idleHours,
        batchSize,
        runArchiveSweep,
        startedAt,
        failureStage: "archive_sweep",
        errorMessage: archiveError.message,
        details: {
          dormancyReason,
          archiveReason,
          retentionDays,
        },
      })
      return json({
        error: "archive_sweep_failed",
        details: archiveError.message,
        dormantMarked,
      }, 500)
    }

    archivedMarked = numberFromRPCResult(archiveData)
  }

  await logRun({
    workerID,
    status: "success",
    dormantMarked,
    archivedMarked,
    idleHours,
    batchSize,
    runArchiveSweep,
    startedAt,
    details: {
      dormancyReason,
      archiveReason,
      retentionDays,
    },
  })

  return json(
    {
      workerID,
      dormantMarked,
      archivedMarked,
      runArchiveSweep,
      config: {
        idleHours,
        batchSize,
        dormancyReason,
        archiveReason,
        retentionDays,
      },
    },
    200,
  )
})

function numberFromRPCResult(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value)
  if (typeof value === "string") {
    const parsed = Number(value)
    if (Number.isFinite(parsed)) return Math.trunc(parsed)
  }
  return 0
}

type WorkerRunLog = {
  workerID: string
  status: "success" | "failed"
  dormantMarked: number
  archivedMarked: number
  idleHours: number
  batchSize: number
  runArchiveSweep: boolean
  startedAt: string
  failureStage?: string
  errorMessage?: string
  details: Record<string, unknown>
}

async function logRun(input: WorkerRunLog): Promise<void> {
  const payload = {
    worker_id: input.workerID,
    status: input.status,
    dormant_marked: input.dormantMarked,
    archived_marked: input.archivedMarked,
    idle_hours: input.idleHours,
    batch_size: input.batchSize,
    run_archive_sweep: input.runArchiveSweep,
    failure_stage: input.failureStage ?? null,
    error_message: input.errorMessage ?? null,
    details: input.details,
    started_at: input.startedAt,
    finished_at: new Date().toISOString(),
  }

  const { error } = await supabase.from("region_lifecycle_worker_runs").insert(payload)
  if (error) {
    console.error("region_lifecycle_worker_log_failed", error.message)
  }
}

function clampInt(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || Number.isFinite(value) === false) return fallback
  return Math.min(max, Math.max(min, Math.trunc(value)))
}

function normalizeOptionalInt(value: unknown, min: number, max: number): number | null {
  if (value === null || value === undefined) return null
  if (typeof value !== "number" || Number.isFinite(value) === false) return null
  return Math.min(max, Math.max(min, Math.trunc(value)))
}

function normalizeReason(value: unknown, fallback: string): string {
  if (typeof value === "string" && value.trim().length > 0) {
    return value.trim().slice(0, 120)
  }
  return fallback
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

function json(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  })
}
