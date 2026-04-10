# P1 Closeout Checklist

Use this checklist to mark P1 complete without adding scope.

## Scope Freeze
- P1 includes only foundation and platform setup from `docs/ROADMAP.md`.
- No new P1 work should be added unless it fixes a blocking defect in existing P1 scope.

## Required Preconditions
- Repository secret/variable configured in GitHub Actions:
  - `SUPABASE_ACCESS_TOKEN`
  - `STAGING_PROJECT_REF` (Actions variable)
  - `APNS_WORKER_SMOKE_URL`
  - `APNS_WORKER_SMOKE_BEARER`
- Staging Supabase environment available.

## Validation Steps
1. Trigger workflow `.github/workflows/p1-validation.yml` with:
   - `run_staging_closeout=true`
2. Confirm workflow jobs pass:
   - `swift-tests`
   - `deno-worker-tests`
   - `staging-p1-closeout`
3. Confirm staging closeout output contains:
   - push migrations `0009`-`0012` applied/verified
   - APNs smoke response with `claimed`, `sent`, `failed`

## Evidence to Record
- Workflow run URL
- Date/time of successful run
- Commit SHA used for closeout

## Exit Criteria
- All checks above pass once on staging with no manual patching between steps.
- `docs/ROADMAP.md` updated to set `P1` status to `done`.
- `docs/NEXT_ACTIONS.md` queue moved to P2 planning/implementation items.
