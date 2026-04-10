# Triggering P1 Closeout Workflow

Run the `P1 Validation` workflow manually in GitHub Actions with:
- `run_staging_closeout=true`

Before dispatch, configure:
- Actions secret: `SUPABASE_ACCESS_TOKEN`
- Actions variable: `STAGING_PROJECT_REF`
- Actions secrets: `APNS_WORKER_SMOKE_URL`, `APNS_WORKER_SMOKE_BEARER`

If you use GitHub CLI:

```bash
gh workflow run "P1 Validation" -f run_staging_closeout=true
```

Check latest run:

```bash
gh run list --workflow "P1 Validation" --limit 1
```

View run logs:

```bash
gh run view --log
```

If the closeout succeeds, update:
- `docs/ROADMAP.md` (`P1` -> `done`)
- `docs/NEXT_ACTIONS.md` (replace P1 closeout item with P2 start items)
