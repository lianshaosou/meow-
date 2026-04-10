# Country Override Live Ops Runbook

Use these RPCs with a **service role** key to manage `region_country_overrides` without editing migrations.

## RPCs
- `list_region_country_overrides(input_region_code, input_limit, input_offset)`
- `upsert_region_country_override(input_region_code, input_density_tier, input_support_level, input_risk_level, input_spawn_probability_multiplier, input_metadata)`
- `delete_region_country_override(input_region_code)`

## Example (JavaScript / Node)

```js
import { createClient } from "@supabase/supabase-js"

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)

const { data: before } = await supabase.rpc("list_region_country_overrides", {
  input_region_code: null,
  input_limit: 100,
  input_offset: 0,
})

const { data: upserted, error: upsertError } = await supabase.rpc("upsert_region_country_override", {
  input_region_code: "CA",
  input_density_tier: "suburban",
  input_support_level: 0.36,
  input_risk_level: 0.19,
  input_spawn_probability_multiplier: 1.04,
  input_metadata: { source: "live_ops", note: "spring balance pass" },
})

if (upsertError) throw upsertError
console.log(upserted)

const { data: deleted } = await supabase.rpc("delete_region_country_override", {
  input_region_code: "CA",
})

console.log({ deleted, countBefore: before?.length ?? 0 })
```

## Guardrails
- `region_code` is normalized to uppercase.
- `density_tier` is normalized to lowercase.
- Validation rules in RPC:
  - `support_level`: `0..1`
  - `risk_level`: `0..1`
  - `spawn_probability_multiplier`: `0..3`
- RPCs reject non-service-role callers.
