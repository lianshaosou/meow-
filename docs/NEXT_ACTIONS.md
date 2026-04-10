# Next Actions

## Completed in Current Session
1. Scaffolded shared Swift package module boundaries in `ios/MeowCore`.
2. Authored first Postgres migrations for core entities and RLS policies.
3. Added global default balance seed data and backend setup notes.
4. Added geohash encoder and home/outside classification utility.
5. Added simulation time-domain clock utility with tests.
6. Added data layer contracts and in-memory repositories for auth/home/time snapshots.
7. Added feature-layer view models for auth, onboarding, and app bootstrap simulation trigger.
8. Added baseline SwiftUI screens for auth and onboarding.
9. Expanded test suite to cover feature scaffolding and onboarding flow.
10. Added XcodeGen iOS app target scaffold in `ios/MeowApp` with root flow wiring.
11. Installed `xcodegen`, generated `MeowApp.xcodeproj`, and validated simulator build.
12. Added Supabase-backed auth and repository implementations for profile/home/time snapshots.
13. Wired runtime dependency selection to use Supabase when environment config is present.
14. Expanded tests to include Supabase config loader coverage.
15. Added first encounter eligibility service (home/outside + cooldown + geohash output).
16. Replaced placeholder Apple sign-in button flow with native Apple credential flow on iOS.
17. Added persistent Supabase session storage and refresh hook.
18. Added backend RPC migration for region activation + initial encounter roll.
19. Added Supabase encounter repository for latest encounter and activation RPC calls.
20. Connected first outside/explore screen to eligibility + encounter pipeline.
21. Added encounter notification scheduling from encounter success -> `notification_events`.
22. Added account-link method to connect email credentials to active user sessions.
23. Upgraded session persistence to prefer Keychain with fallback support.
24. Added account link screen/view model and wired it into Explore navigation.
25. Integrated live CoreLocation-backed Explore mode with manual fallback.
26. Added telemetry repository stack and instrumentation for Explore + account-link flows.
27. Added provider management screen with linked-provider listing, re-auth, and unlink safeguards.
28. Added region-country override enrichment and upgraded encounter RPC/client contracts.
29. Implemented Supabase provider-unlink workflow with identity lookup and guarded delete.
30. Added Supabase integration-path tests for encounter RPC and provider unlink workflows.
31. Added notification delivery worker RPC flow and app-side processing service.
32. Added local notification dispatch bridge and wired delivery service to real app notifications.
33. Added automated re-auth prompt flow in provider unlink UX with one-tap retry after re-authentication.
34. Added optional live Supabase integration tests (auth, encounter RPC, notification lifecycle, push token registration) gated by env flag.
35. Replaced manual explore fallback coordinate fields with map-assisted debug controls (map center selection, home center jump, outside-home jump).
36. Added telemetry dashboard SQL queries and provider-unlink telemetry instrumentation for funnel/drop-off analysis.
37. Added service-role live-ops tools for dynamic country override management (list/upsert/delete RPCs + runbook).
38. Added APNs provider worker backend primitives (push job claim/sent/failed RPCs with retry scheduling) and worker runbook.
39. Added deployable Supabase Edge Function scaffold (`apns-push-worker`) to claim jobs, call APNs, and mark outcomes.
40. Added APNs scheduling + token-rotation rollout strategy docs and implemented in-worker JWT minting support for APNs auth.
41. Added push worker observability query pack for queue lag, failure rate, and APNs error-reason monitoring.
42. Added automatic stale-lock recovery for `processing` push jobs and wired worker pre-claim recovery step.
43. Added dead-token remediation for APNs permanent token failures with automatic token deactivation and job cleanup.
44. Added push worker utility tests (Deno) for APNs retry/permanent-error logic and payload shaping.
45. Added P1 CI validation workflow (Swift + Deno tests) and a manual staging smoke step for APNs worker invocation.
46. Added manual workflow path for staging DB migration checks (`0009`-`0011`) with RPC verification scripts.
47. Added push worker cycle tests for RPC flow/error branches by extracting cycle orchestration into testable `worker_core` module.
48. Added one-shot staging closeout workflow/script (`run_staging_closeout`) to run DB checks + APNs smoke in a single dispatch.
49. Added explicit P1 closeout checklist and workflow-dispatch instructions docs.
50. Removed accidental Next.js `web/` module to keep scope strictly on iOS + backend.
51. Switched staging DB checks to Supabase Management API (`supabase db query --linked`) and added migration `0012` fixing push claim RPC ambiguity.
52. Deployed `apns-push-worker` function and completed one-shot staging closeout checks successfully.
53. Started P2 timeline implementation: added multi-domain bootstrap progression hooks (user + home) with monotonic progression validation and timeline update reporting.
54. Implemented P2 region dormancy lifecycle model (`active/dormant/archived`) with retention-driven transition RPCs and activation reactivation semantics.
55. Implemented P2 encounter ecology persistence with familiarity-biased re-encounter weighting and adjacency roaming candidate selection.
56. Added integration-path coverage for encounter ecology metadata and region reactivation fields in Supabase encounter RPC mapping tests.
57. Added Explore telemetry instrumentation for encounter ecology context (`cat_source`, familiarity count, adjacent roam usage, region reactivation state) with feature-test coverage.
58. Added timeline consumer orchestration for care/region signals on app-active bootstrap deltas (care-cycle due notifications + dormancy candidate telemetry).
59. Added Supabase integration-path coverage for region dormancy transition RPC calls with new region lifecycle repository abstraction.
60. Added scheduled backend worker path for region lifecycle sweeps (deployed edge function + hourly GitHub Actions workflow + smoke script).
61. Added region lifecycle worker observability foundation (run-log table, worker run persistence, and alert query pack).
62. Added consolidated ops alert check SQL and analytics alert response runbook for lifecycle + telemetry health.
63. Added scheduled automated ops alert check workflow (`ops-alert-checks`) with optional webhook notification on alert=true.
64. Added optional GitHub incident issue creation path in `ops-alert-checks` workflow for alert=true runs.

## Immediate Implementation Queue
1. Wire dashboard consumers (Grafana/Metabase/Supabase SQL dashboards) for lifecycle worker alerts and ecology/timeline metrics.
2. Expand encounter ecology telemetry trend dashboards to include per-country and density-tier splits.
3. Add Jira/third-party incident sink integration in addition to GitHub issue path for active alerts.

## Definition of Done for P1
- App builds and runs on iOS 17+ simulator/device.
- User can authenticate via Apple or Email.
- User can complete onboarding and set home area.
- Core database schema is migrated and queryable with RLS enabled.
- Project includes docs and phase tracking for continuity.

## Risks to Address Early
- GPS jitter around home boundary causing mode-flip confusion.
- Account linking edge cases between Apple and Email identities.
- Premature hardcoding of balancing values instead of config tables.

## Open Product Decision
- Confirm default dead-cat retention policy:
  - Recommended: retain indefinitely with archive/memorial continuity.
