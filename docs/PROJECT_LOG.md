# Project Log

## 2026-04-05 - Kickoff Planning
- Parsed and synthesized the product specification from `Meow!!.pdf` (43 pages).
- Aligned on build posture: deep simulation architecture from day one, with feature flags for staged rollout.
- Locked core architecture principles:
  - Persistent world entities (cats are not stateless encounter artifacts)
  - Region-based activation and dormancy for cost control
  - Lazy, event-driven simulation forward progression
  - Data-driven balancing tables (not hardcoded app logic)
  - Emotional continuity via death history and memorial support
- Confirmed implementation stack and scope:
  - Backend: Supabase/Postgres
  - Region model: Geohash
  - Auth: Apple Sign-In + Email
  - Launch scope: Global
- Defined delivery phases P1-P8 and a first playable milestone that preserves full architecture.

## 2026-04-05 - Project Tracking Initialized
- Created persistent planning and progress docs:
  - `docs/ROADMAP.md`
  - `docs/DECISIONS.md`
  - `docs/NEXT_ACTIONS.md`
- Established a single source of truth for future sessions to continue work with historical context.

## 2026-04-05 - P1 Scaffold Started
- Moved P1 roadmap status to `in_progress`.
- Started backend foundation artifacts for Supabase/Postgres:
  - Core schema migration draft
  - RLS and ownership policy migration draft
  - Initial global balance configuration seed
- Started iOS/shared Swift scaffold for:
  - Domain entities
  - Time-domain simulation clock utilities
  - Home/outside location classification and geohash encoding

## 2026-04-05 - P1 Scaffold Implemented (Initial Cut)
- Added backend foundation files:
  - `backend/migrations/0001_core_schema.sql`
  - `backend/migrations/0002_rls_policies.sql`
  - `backend/seeds/0001_global_balance_seed.sql`
  - `backend/.env.example`
  - `backend/README.md`
- Added shared Swift package scaffold:
  - `ios/MeowCore/Package.swift`
  - `ios/MeowCore/Sources/MeowDomain/*`
  - `ios/MeowCore/Sources/MeowSimulation/*`
  - `ios/MeowCore/Sources/MeowLocation/*`
  - `ios/MeowCore/Tests/*`
  - `ios/MeowCore/README.md`
- Validation:
  - Ran `swift test` in `ios/MeowCore` successfully (4 tests passing).

## 2026-04-05 - P1 Feature Foundation Continued
- Extended Swift package architecture with additional runtime layers:
  - New targets in `ios/MeowCore/Package.swift`: `MeowData`, `MeowFeatures`
- Implemented data-layer scaffolding:
  - `AuthService` protocol + in-memory auth implementation
  - `ProfileRepository`, `HomeRepository`, `TimeSnapshotRepository` + in-memory implementations
  - Supabase config loader for `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- Implemented feature-layer scaffolding:
  - `AuthViewModel` with Email and Apple sign-in paths
  - `OnboardingViewModel` with nickname/home validation and geohash-based home save
  - `AppBootstrapService` to persist time snapshots on app active
  - Basic SwiftUI screens for auth and onboarding
- Added tests for feature foundations:
  - auth view model behaviors
  - onboarding validation and persistence flow
  - bootstrap snapshot creation
- Validation:
  - Ran `swift test` in `ios/MeowCore` successfully (9 tests passing).

## 2026-04-05 - iOS App Target Scaffold Added
- Added XcodeGen-based iOS target scaffold in `ios/MeowApp`:
  - `ios/MeowApp/project.yml`
  - `ios/MeowApp/Sources/App/MeowApp.swift`
  - `ios/MeowApp/Sources/App/RootView.swift`
  - `ios/MeowApp/Sources/App/Info.plist`
  - `ios/MeowApp/README.md`
- App flow now includes baseline runtime wiring:
  - auth screen -> onboarding screen -> placeholder world screen
  - bootstrap simulation snapshot trigger after onboarding
- Environment note:
  - `xcodegen` was later installed and project generation has now been executed.

## 2026-04-05 - Supabase Runtime Wiring and Build Verification
- Added Supabase-backed runtime implementations in `MeowCore`:
  - `SupabaseSessionStore` for shared auth/session token state
  - `SupabaseHTTPClient` for authenticated PostgREST/Auth requests
  - `SupabaseAuthService` for Email + Apple auth flows
  - `SupabaseProfileRepository`, `SupabaseHomeRepository`, `SupabaseTimeSnapshotRepository`
- Updated app dependency composition in `ios/MeowApp/Sources/App/MeowApp.swift`:
  - If `SUPABASE_URL` + `SUPABASE_ANON_KEY` are present, app uses Supabase services.
  - Otherwise app falls back to in-memory services for local development.
- Improved auth flow state:
  - `AuthViewModel` now tracks `currentUserID` after sign-in and restore.
- Added data-layer tests:
  - `ios/MeowCore/Tests/MeowDataTests/SupabaseConfigLoaderTests.swift`
- Tooling/build verification:
  - Installed `xcodegen` via Homebrew.
  - Generated `ios/MeowApp/MeowApp.xcodeproj` from `project.yml`.
  - Built `MeowApp` scheme successfully for iOS Simulator (`iPhone 17`).
  - `swift test` in `ios/MeowCore` passing.

## 2026-04-05 - Encounter Eligibility Foundation Added
- Added `EncounterEligibilityService` in `ios/MeowCore/Sources/MeowFeatures/EncounterEligibilityService.swift`.
- Service behavior now evaluates:
  - Home presence mode (`home` / `outside` / `uncertain`)
  - Cooldown window gating
  - Current region geohash generation for eligible encounters
- Added test coverage:
  - `ios/MeowCore/Tests/MeowFeaturesTests/EncounterEligibilityServiceTests.swift`
- Validation:
  - `swift test` in `ios/MeowCore` passing (13 tests).

## 2026-04-05 - Apple Sign-In UI + Session Persistence Upgrade
- Replaced placeholder Apple sign-in flow in `AuthScreen` with native `SignInWithAppleButton` (iOS path) and credential token extraction.
- Added persistent Supabase session storage:
  - `SupabaseSessionStore` now serializes/restores session data through `UserDefaults`.
- Added refresh-capable auth hook:
  - `SupabaseAuthService.refreshSessionIfPossible()`.
- Added test coverage:
  - `ios/MeowCore/Tests/MeowDataTests/SupabaseSessionStoreTests.swift`.
- Validation:
  - `swift test` in `ios/MeowCore` passing (14 tests).
  - `xcodebuild` iOS simulator build for `MeowApp` passing.

## 2026-04-05 - Region Activation RPC + Explore Pipeline
- Added backend RPC migration:
  - `backend/migrations/0003_region_activation_rpc.sql`
  - Implements `activate_region_and_roll_encounter(input_geohash, input_precision)` with:
    - region lazy activation/init
    - encounter cooldown enforcement
    - weighted encounter roll using active balance config
    - persistent stray selection/creation
    - encounter event creation
- Added domain/data contracts for encounter pipeline:
  - `ios/MeowCore/Sources/MeowDomain/EncounterModels.swift`
  - `EncounterRepository` protocol and in-memory implementation
  - `SupabaseEncounterRepository` RPC + latest encounter query implementation
- Added feature-layer explore flow:
  - `ExploreViewModel` for eligibility + RPC orchestration
  - `ExploreScreen` for first outside-mode interaction UI
  - `RootView` now routes authenticated/onboarded users to Explore mode
- Updated app dependency graph:
  - `MeowApp` now wires `encounterRepository` for Supabase and in-memory runtime modes
- Validation:
  - `swift test` passing in `ios/MeowCore` (16 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Encounter Notification Scheduling Path
- Added notification domain model:
  - `ios/MeowCore/Sources/MeowDomain/NotificationModels.swift`
- Added notification repository contract + implementations:
  - `NotificationRepository` protocol and in-memory implementation
  - `SupabaseNotificationRepository` writing to `notification_events`
- Wired explore encounter success path to schedule notifications:
  - `ExploreViewModel` now writes a medium-severity encounter notification when a cat is rolled.
- App dependency graph now includes `notificationRepository` for both Supabase and in-memory runtime modes.
- Validation:
  - `swift test` in `ios/MeowCore` passing (16 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Account Link + Keychain Session Storage
- Added account-link capability in auth service layer:
  - `AuthService.linkEmailCredentialToCurrentUser(email,password)`
  - Implemented in both `InMemoryAuthService` and `SupabaseAuthService`
  - Supabase path updates current authenticated user credentials through `/auth/v1/user`
- Upgraded session persistence strategy:
  - `SupabaseSessionStore` now prefers Keychain storage and falls back to `UserDefaults` when unavailable
  - Added opt-out flag for tests (`preferKeychain: false`)
- Added test coverage:
  - `ios/MeowCore/Tests/MeowDataTests/AuthServiceLinkingTests.swift`
  - updated session store tests for deterministic non-Keychain mode
- Validation:
  - `swift test` in `ios/MeowCore` passing (18 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Account Linking UI Surface
- Added account linking feature UI in `MeowFeatures`:
  - `AccountLinkViewModel`
  - `AccountLinkScreen`
- Wired account management entry point from explore flow:
  - `RootView` now exposes an `Account` navigation action in Explore mode.
  - `MeowApp` dependency wiring now injects `AccountLinkViewModel`.
- Added feature tests:
  - `ios/MeowCore/Tests/MeowFeaturesTests/AccountLinkViewModelTests.swift`
- Validation:
  - `swift test` in `ios/MeowCore` passing (20 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Live Location Explore Integration
- Added location service abstraction and implementations:
  - `LocationService` protocol
  - `AppleLocationService` (CoreLocation-backed)
  - `InMemoryLocationService` (test/dev stub)
- Explore flow now supports live location mode:
  - `ExploreViewModel` starts/stops location updates and consumes live readings
  - `ExploreScreen` has live/manual mode toggle and location status display
- App dependency wiring now injects a location service into Explore.
- Validation:
  - `swift test` in `ios/MeowCore` passing (20 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Telemetry Pipeline Foundation
- Added telemetry domain and repository layer:
  - `TelemetryEventDraft` domain model
  - `TelemetryRepository` protocol
  - `InMemoryTelemetryRepository` and `SupabaseTelemetryRepository`
- Added backend telemetry table migration and RLS:
  - `backend/migrations/0004_app_telemetry.sql`
- Wired telemetry into key user flows:
  - Explore eligibility/cooldown/success/error events
  - Account linking success/failure events
- App dependency graph now injects telemetry repository into Explore and AccountLink view models.
- Validation:
  - `swift test` in `ios/MeowCore` passing (20 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Provider Management UX and Safeguards
- Added provider management support in auth service contracts:
  - list linked providers
  - re-authenticate current session
  - unlink provider with safeguards (cannot unlink last provider; re-auth window check)
- Added provider management UI flow:
  - `AccountProvidersViewModel`
  - `AccountProvidersScreen`
  - wired from account settings via `AccountLinkScreen`
- Supabase behavior:
  - linked provider discovery uses `/auth/v1/user` identities
  - provider unlink was initially scaffolded as unsupported before backend workflow was added
- Added telemetry instrumentation for account-link and encounter funnels.
- Added telemetry storage migration:
  - `backend/migrations/0004_app_telemetry.sql`
- Validation:
  - `swift test` in `ios/MeowCore` passing (23 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Region Enrichment and Country Overrides
- Added region enrichment migration with country-level overrides:
  - `backend/migrations/0005_region_enrichment_and_rpc_upgrade.sql`
  - introduces `region_country_overrides` and seeded examples
- Upgraded encounter activation RPC to accept optional inputs:
  - `input_country_code`
  - `input_density_tier`
  - applies country override multipliers and density fallback during region activation
- Extended client contracts for richer activation context:
  - `RegionActivationRollResult` now includes `countryCode` and `densityTier`
  - encounter repository activation now accepts optional country/density hints
- Explore flow now sends locale region code when rolling encounters.
- Validation:
  - `swift test` in `ios/MeowCore` passing (23 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Supabase Provider Unlink Workflow
- Replaced placeholder unsupported unlink path with a Supabase-backed workflow:
  - `SupabaseAuthService.unlinkProvider` now:
    - fetches identities from `/auth/v1/user`
    - enforces safeguards (provider exists, not last provider, recent re-auth window)
    - calls `DELETE /auth/v1/user/identities/{identity_id}`
    - updates local session provider fallback when current provider is removed
- Added provider-management coverage in tests:
  - `AuthProviderManagementTests` now includes unlink-success path for in-memory auth service.
- Validation:
  - `swift test` in `ios/MeowCore` passing (24 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Supabase Integration-Path Tests Added
- Added URLSession stub harness for deterministic HTTP testing in `MeowDataTests`.
- Added integration-path tests that validate request/response contracts without live network:
  - `SupabaseEncounterRepository.activateRegionAndRollEncounter` request body, auth header, and parsed response
  - `SupabaseAuthService.unlinkProvider` identity lookup + delete workflow + session fallback
- Added constructor injection support for testable networking:
  - `SupabaseAuthService` now accepts optional `URLSession`
  - `SupabaseEncounterRepository` now accepts optional `URLSession`
- Validation:
  - `swift test` in `ios/MeowCore` passing (26 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Notification Delivery Worker Path
- Added backend delivery-worker migration:
  - `backend/migrations/0006_notification_delivery_worker.sql`
  - adds delivery lifecycle columns to `notification_events`
  - adds RPC functions:
    - `claim_due_notifications`
    - `mark_notification_delivered`
    - `mark_notification_failed`
- Extended notification repositories:
  - `NotificationRepository` now supports claim/mark-delivered/mark-failed
  - `SupabaseNotificationRepository` now implements RPC delivery lifecycle operations
  - `InMemoryNotificationRepository` now supports queue claim and mark paths for tests
- Added app-side delivery orchestrator:
  - `NotificationDeliveryService` processes claimed notifications and marks outcomes
  - wired into app root active flow to process due notifications after bootstrap
- Added tests:
  - integration-path coverage for notification RPC claim + mark-delivered
  - feature test for `NotificationDeliveryService` due-processing behavior
- Validation:
  - `swift test` in `ios/MeowCore` passing (28 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Local Notification Dispatch Bridge
- Added local-dispatch bridge abstraction in `MeowFeatures`:
  - `NotificationDispatching` protocol
  - `LocalNotificationDispatcher` (UserNotifications-backed)
  - `NoopNotificationDispatcher` for non-delivery contexts
- Updated `NotificationDeliveryService` to dispatch via injected dispatcher instead of placeholder no-op.
- Wired app runtime to use `LocalNotificationDispatcher` in `MeowApp` composition root.
- Added tests:
  - delivery service success and failure paths via test dispatcher
  - integration-path notification claim/mark tests remain passing
- Validation:
  - `swift test` in `ios/MeowCore` passing (29 tests)
  - `xcodebuild` simulator build for `MeowApp` passing

## 2026-04-05 - Automated Re-auth Prompt + Retry for Provider Unlink
- Improved provider-management UX for stale unlink sessions:
  - `AccountProvidersViewModel` now detects `AuthError.reauthenticationRequired` during unlink attempts
  - captures pending provider unlink intent and exposes `shouldPromptReauthentication` UI state
  - adds `reauthenticateAndRetryUnlink()` so one user action can refresh auth and re-attempt unlink
- Updated provider screen UX:
  - `AccountProvidersScreen` now presents an alert with `Re-authenticate & Unlink`
  - retry action triggers re-auth followed by unlink automatically
- Added feature tests:
  - prompt is shown when unlink freshness window is expired
  - re-auth + retry flow succeeds and unlinks the provider in one path
- Validation:
  - `swift test` in `ios/MeowCore` passing (34 tests)

## 2026-04-05 - Live Supabase Integration Test Coverage (Env-Gated)
- Added optional live integration test suite in `MeowDataTests`:
  - `LiveSupabaseIntegrationTests.swift`
  - validates real-network auth sign-in + encounter activation RPC path
  - validates notification schedule -> claim -> mark-delivered lifecycle
  - validates push bridge token registration RPC path
- Live tests are off by default and only run when:
  - `MEOW_RUN_LIVE_SUPABASE_TESTS=1`
  - required Supabase URL/key and test credentials are provided
- Updated package docs with live-test environment setup and run command example.
- Validation:
  - `swift test` in `ios/MeowCore` passing (37 tests total, live suite skipped by default unless env flag is enabled)

## 2026-04-05 - Map-Assisted Explore Debug Tooling
- Replaced manual fallback coordinate text fields in Explore mode with map-assisted controls:
  - map viewport with explore marker and optional home marker
  - `Use Map Center as Explore Point` for quick scenario setup
  - `Use Home Center` and `Set Outside Home (Debug)` shortcuts when a home area is configured
- Added view-model home context state for map overlays:
  - `ExploreViewModel.activeHomeArea`
  - `ExploreViewModel.refreshHomeContext(userID:)`
- Added feature test coverage for home-context loading used by map debug tools.
- Validation:
  - `swift test` in `ios/MeowCore` passing (38 tests)

## 2026-04-05 - Telemetry Dashboards + Provider Funnel Instrumentation
- Added backend analytics query pack:
  - `backend/analytics/telemetry_dashboard_queries.sql`
  - includes encounter funnel, eligibility-block reasons, provider-link funnel, unlink failure reasons, and retry-source split queries
- Updated backend docs:
  - `backend/README.md` now references telemetry dashboard query pack
- Expanded provider-management telemetry instrumentation in app feature layer:
  - `provider_unlink_attempt`
  - `provider_unlink_reauth_prompted`
  - `provider_reauth_success`
  - `provider_reauth_failed`
  - `provider_unlink_success`
  - `provider_unlink_failed`
- Updated app composition to inject telemetry repository into `AccountProvidersViewModel`.
- Added/updated test coverage to verify provider unlink + re-auth telemetry events in feature tests.
- Validation:
  - `swift test` in `ios/MeowCore` passing (38 tests)

## 2026-04-05 - Dynamic Country Override Live Ops Tools
- Added backend live-ops migration:
  - `backend/migrations/0008_country_override_live_ops_tools.sql`
  - introduces service-role-only RPCs for dynamic override management:
    - `list_region_country_overrides`
    - `upsert_region_country_override`
    - `delete_region_country_override`
  - adds normalization/validation guardrails and update timestamp trigger support
- Added operator runbook:
  - `backend/live_ops/COUNTRY_OVERRIDE_RUNBOOK.md`
  - includes Supabase service-role RPC usage example and safety constraints
- Updated backend docs with new migration/apply-order and live-ops reference links.

## 2026-04-05 - APNs Provider Worker Backend Integration
- Added push worker migration:
  - `backend/migrations/0009_push_delivery_provider_worker.sql`
  - extends `push_delivery_jobs` with retry/lock/provider response fields
  - adds service-role RPCs:
    - `claim_push_delivery_jobs`
    - `mark_push_delivery_job_sent`
    - `mark_push_delivery_job_failed`
  - includes role guardrails and bounded retry controls
- Added APNs worker operations runbook:
  - `backend/live_ops/APNS_PUSH_WORKER.md`
  - documents claim/send/mark loop and SQL examples for success/failure handling
- Updated backend docs and apply order for new migration.
- Validation:
  - `swift test` in `ios/MeowCore` passing (38 tests; backend-only migration changes did not impact app package tests)

## 2026-04-05 - APNs Worker Runtime Scaffold (Edge Function)
- Added deployable Supabase Edge Function scaffold:
  - `backend/functions/apns-push-worker/index.ts`
  - claims jobs with `claim_push_delivery_jobs`
  - sends APNs provider requests by token/environment
  - marks outcomes via `mark_push_delivery_job_sent` / `mark_push_delivery_job_failed`
  - applies simple retry-delay strategy based on APNs HTTP status classes
- Added function docs:
  - `backend/functions/apns-push-worker/README.md`
  - includes deploy and invoke examples
- Updated backend docs to reference the function scaffold.

## 2026-04-05 - APNs Scheduling + Token Rotation Strategy
- Upgraded APNs edge worker auth path in `backend/functions/apns-push-worker/index.ts`:
  - supports preferred key-based JWT minting (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY_P8`)
  - caches generated APNs auth token for configurable TTL (`APNS_AUTH_TOKEN_TTL_SECONDS`)
  - keeps static `APNS_AUTH_BEARER_TOKEN` as fallback
- Expanded worker/environment documentation:
  - `backend/.env.example` now includes APNs key/JWT rotation variables
  - `backend/functions/apns-push-worker/README.md` documents preferred and fallback auth strategies
  - `backend/live_ops/APNS_PUSH_WORKER.md` now includes scheduling and token-rotation guidance
  - added `backend/live_ops/APNS_PUSH_WORKER_SCHEDULING.md` with external scheduler + pg_cron patterns and rollout thresholds
- Updated backend index docs with new scheduling guide references.
- Validation:
  - `swift test` in `ios/MeowCore` passing (38 tests)
  - `deno check` unavailable in current environment (command not found), so TS static check should be run in CI/runtime container

## 2026-04-05 - Push Worker Observability Pack
- Added analytics query set:
  - `backend/analytics/push_worker_observability_queries.sql`
  - includes queue depth, backlog age, outcome windows, terminal failure rate, APNs reason breakdown, and alert-check queries
- Updated backend docs to include push worker observability query pack.

## 2026-04-05 - Stale Lock Recovery for Push Worker
- Added migration `backend/migrations/0010_push_delivery_stale_lock_recovery.sql`:
  - introduces service-role RPC `recover_stale_push_delivery_jobs`
  - recovers stuck `processing` jobs based on lock age timeout
  - requeues recoverable jobs and marks terminal failures when max attempts already reached
- Updated edge worker runtime:
  - `backend/functions/apns-push-worker/index.ts` now calls stale-lock recovery before claim
  - function response now includes `recovered` count for operations visibility
- Updated runbooks/docs:
  - `backend/functions/apns-push-worker/README.md`
  - `backend/live_ops/APNS_PUSH_WORKER.md`
  - `backend/live_ops/APNS_PUSH_WORKER_SCHEDULING.md`
  - `backend/README.md` migration apply order

## 2026-04-05 - Dead Token Remediation for APNs
- Added migration `backend/migrations/0011_push_dead_token_remediation.sql`:
  - introduces service-role RPC `deactivate_push_token_for_job`
  - deactivates invalid APNs device token tied to a failed job
  - marks queued/processing jobs on that token as terminal failed to reduce repeated retries/noise
- Updated edge worker runtime:
  - `backend/functions/apns-push-worker/index.ts` now detects permanent token errors (`410`, `Unregistered`, `BadDeviceToken`, `DeviceTokenNotForTopic`)
  - forces terminal failure for those events and invokes token deactivation RPC
- Updated runbooks/docs:
  - `backend/functions/apns-push-worker/README.md`
  - `backend/live_ops/APNS_PUSH_WORKER.md`
  - `backend/README.md` migration apply order

## 2026-04-05 - Push Worker Utility Test Coverage
- Refactored reusable worker logic into:
  - `backend/functions/apns-push-worker/worker_utils.ts`
- Added Deno tests:
  - `backend/functions/apns-push-worker/worker_utils_test.ts`
  - coverage includes:
    - permanent-token error detection
    - retry-delay policy mapping
    - APNs payload shaping defaults
    - private key newline normalization
    - error normalization
- Updated worker README with Deno test command.
- Validation:
  - Deno tooling unavailable in current environment (`deno` command not found), so tests are ready for CI/runtime toolchain execution.

## 2026-04-05 - P1 CI + Staging Smoke Wiring
- Added CI workflow:
  - `.github/workflows/p1-validation.yml`
  - runs `swift test` in `ios/MeowCore` on macOS
  - runs `deno test backend/functions/apns-push-worker/worker_utils_test.ts` on Ubuntu
  - supports manual dispatch staging smoke invocation (`run_staging_smoke` input)
- Added staging smoke helper script:
  - `backend/live_ops/apns_worker_smoke.sh`
  - validates APNs worker endpoint response shape (`claimed/sent/failed`)
- Updated runbooks/docs for workflow + secret requirements:
  - `backend/functions/apns-push-worker/README.md`
  - `backend/live_ops/APNS_PUSH_WORKER_SCHEDULING.md`

## 2026-04-05 - Staging DB Check Automation for Push Worker Migrations
- Extended `.github/workflows/p1-validation.yml` with manual dispatch input:
  - `run_staging_db_checks`
  - runs migration apply/verify helper against staging DB
- Added staging scripts:
  - `backend/live_ops/run_push_worker_staging_checks.sh`
    - applies migrations `0009` -> `0011` with `psql`
  - `backend/live_ops/push_worker_staging_verify.sql`
    - verifies required push worker RPC registrations
- Updated backend docs/runbooks with staging DB-check secret and script references.

## 2026-04-05 - Push Worker Cycle Testability Expansion
- Extracted orchestration logic to `backend/functions/apns-push-worker/worker_core.ts`:
  - recover stale locks -> claim jobs -> mark sent/failed -> dead-token remediation path
  - preserves runtime behavior while enabling targeted branch testing
- Added `backend/functions/apns-push-worker/worker_core_test.ts` to validate:
  - success flow summary/counters
  - permanent token failure path triggers terminal handling and token deactivation RPC call
  - claim failure path returns typed cycle error
- Updated edge entrypoint (`index.ts`) to call `runWorkerCycle`.
- Updated CI workflow Deno test step and worker README test command to include both worker utility and cycle tests.

## 2026-04-05 - One-shot P1 Staging Closeout Runner
- Added combined staging runner script:
  - `backend/live_ops/p1_closeout_staging.sh`
  - executes DB migration verification (`0009`-`0011`) then APNs worker smoke invocation
- Extended workflow dispatch controls in `.github/workflows/p1-validation.yml`:
  - new input `run_staging_closeout`
  - new job `staging-p1-closeout` using combined script
- Updated docs/runbooks:
  - `backend/live_ops/APNS_PUSH_WORKER_SCHEDULING.md`
  - `backend/README.md`

## 2026-04-05 - P1 Closeout Checklist Added
- Added closeout documentation to avoid scope drift and make final signoff deterministic:
  - `docs/P1_CLOSEOUT.md`
  - `backend/live_ops/p1_closeout_dispatch.md`
- Includes exact workflow dispatch input (`run_staging_closeout=true`), pass criteria, and evidence checklist.

## 2026-04-09 - Scope Cleanup (Removed Accidental Web Module)
- Removed accidental `web/` Next.js module that was created during a Supabase web detour.
- Re-aligned repository scope to iOS (`ios/*`) + backend (`backend/*`) only for current delivery.
- Validation:
  - `swift test` in `ios/MeowCore` passing (38 tests)

## 2026-04-09 - Staging Migration Checks Executed + Push Claim RPC Fix
- Updated staging DB-check runner to use Supabase Management API linked mode:
  - `backend/live_ops/run_push_worker_staging_checks.sh` now uses `supabase db query --linked`.
  - CI workflow now relies on `SUPABASE_ACCESS_TOKEN` + `STAGING_PROJECT_REF` instead of raw DB URL secret.
- Executed staging DB-check runner successfully against linked project ref `zgousowildxaebuyqwhl` for migrations `0009` -> `0011`.
- Added migration `backend/migrations/0012_fix_push_claim_rpc_ambiguity.sql`:
  - resolves `claim_push_delivery_jobs` ambiguity error (`column reference \"id\" is ambiguous`) observed during smoke path.
- Updated staging runner target set to `0009` -> `0012` (assumes core baseline migrations are already applied in target env).

## 2026-04-09 - APNs Worker Deployment + P1 Closeout Completed
- Deployed edge function to linked staging project:
  - `supabase/functions/apns-push-worker/*` -> project `zgousowildxaebuyqwhl`
- Set required function runtime secrets for smoke execution:
  - `APNS_TOPIC`
  - `APNS_AUTH_BEARER_TOKEN` (dev smoke placeholder)
- Ran and passed:
  - `backend/live_ops/run_push_worker_staging_checks.sh`
  - `backend/live_ops/apns_worker_smoke.sh`
  - `backend/live_ops/p1_closeout_staging.sh`
- Closeout result:
  - Staging push-worker DB checks + smoke pass confirmed
  - P1 roadmap status moved to `done`

## 2026-04-09 - P2 Start: Multi-domain Timeline Progression Hooks
- Upgraded bootstrap timeline service in `MeowFeatures`:
  - `AppBootstrapService` now advances multiple entity timelines on app active (`user`, `home` when present)
  - added `BootstrapTimelineUpdate` output with per-entity snapshots and per-entity `SimulationAdvance`
  - added monotonic progression validation guard (`invalidTimelineProgression`) and previous-state normalization for real-world clock skew
- Added shared entity type constants in `MeowDomain`:
  - `TimeEntityType.user`
  - `TimeEntityType.home`
- Updated app composition wiring to pass `homeRepository` into bootstrap service in `MeowApp`.
- Added tests:
  - persists home-domain snapshot when active home exists
  - advances both user/home domains from prior snapshots with expected 5x simulation progression
- Validation:
  - `swift test` in `ios/MeowCore` passing (40 tests)

## 2026-04-09 - P2 Region Dormancy Lifecycle Hardening
- Added migration `backend/migrations/0013_region_dormancy_lifecycle.sql`:
  - formal lifecycle state on `region_activation_state`: `active`, `dormant`, `archived`
  - lifecycle metadata columns: `dormant_at`, `archived_at`, `retention_until`, `activation_count`, `last_reactivated_at`
  - service-role RPCs:
    - `resolve_region_dormancy_retention_days`
    - `mark_stale_regions_dormant`
    - `mark_expired_dormant_regions_archived`
  - upgraded `activate_region_and_roll_encounter` to restore active state and return lifecycle context (`region_state`, `was_reactivated`)
- Added live ops and analytics support:
  - `backend/live_ops/REGION_DORMANCY_RUNBOOK.md`
  - `backend/analytics/region_dormancy_queries.sql`
- Updated architecture decision log:
  - `docs/DECISIONS.md` adds D-008 for region dormancy retention policy.
- Applied migration on linked staging project (`zgousowildxaebuyqwhl`) via `supabase db query --linked`.

## 2026-04-09 - P2 Encounter Ecology Persistence (Familiarity + Adjacency Roaming)
- Added migration `backend/migrations/0014_encounter_ecology_familiarity_and_roaming.sql`:
  - adds/tunes spawn config keys:
    - `spawn.familiar_reencounter_probability_multiplier`
    - `spawn.adjacent_roam_probability`
  - upgrades `activate_region_and_roll_encounter` encounter selection:
    - boosts encounter roll probability when familiar candidates exist
    - prefers familiar local strays before novel local candidates
    - allows adjacent-cell roaming candidates under roam probability gate
    - moves selected adjacent candidate into active region when roaming is used
  - persists ecology metadata into `encounter_events.metadata`:
    - `cat_source`
    - `familiar_encounter_count`
    - `adjacent_roam_used`
  - returns new response fields for client/telemetry usage:
    - `cat_source`, `familiar_encounter_count`, `adjacent_roam_used`
- Extended iOS domain/data models:
  - `RegionActivationRollResult` now includes optional ecology/lifecycle context fields
  - `SupabaseEncounterRepository` decodes and maps new response fields
  - in-memory encounter repository updated to emit consistent defaults
- Applied migration on linked staging project via `supabase db query --linked`.
- Validation:
  - `swift test` in `ios/MeowCore` passing (40 tests)
  - `xcodebuild` `MeowApp` simulator build passing

## 2026-04-09 - Encounter Ecology Mapping Test Coverage
- Expanded `SupabaseIntegrationPathTests` for encounter RPC mapping:
  - validates lifecycle fields: `region_state`, `was_reactivated`
  - validates ecology fields: `cat_source`, `familiar_encounter_count`, `adjacent_roam_used`
  - added dedicated test for reactivated + adjacent-roam response payload path
- Validation:
  - `swift test` in `ios/MeowCore` passing (41 tests)

## 2026-04-10 - Explore Telemetry Enriched with Ecology Context
- Updated `ExploreViewModel` telemetry properties for encounter outcomes:
  - now includes optional ecology context from RPC result:
    - `cat_source`
    - `familiar_encounter_count`
    - `adjacent_roam_used`
    - `region_state`
    - `was_reactivated`
- Applied telemetry enrichment to both:
  - `encounter_success`
  - `encounter_roll_empty`
- Added feature test coverage in `ExploreViewModelTests`:
  - validates telemetry payload mapping for familiar-adjacent-roam scenario
  - validates default in-memory encounter source metadata path
- Extended analytics SQL pack:
  - `backend/analytics/telemetry_dashboard_queries.sql` now includes ecology context split and region reactivation split queries.
- Validation:
  - `swift test` in `ios/MeowCore` passing (42 tests)

## 2026-04-10 - Timeline Consumer Orchestration for Care/Region Signals
- Added `TimelineSimulationOrchestrator` in `MeowFeatures`:
  - consumes `AppBootstrapService.BootstrapTimelineUpdate`
  - emits timeline progression telemetry (`timeline_user_advanced`)
  - schedules care-cycle due notifications (`care_cycle_due`) when home elapsed care-cycle crosses threshold
  - emits dormancy-candidate telemetry (`timeline_region_dormancy_candidate`) when home real elapsed crosses idle threshold
- Integrated orchestrator into app bootstrap task flow in `RootView`:
  - app active -> bootstrap timeline update -> orchestrator consume -> notification delivery processing
- Added test coverage:
  - `TimelineSimulationOrchestratorTests` for long-home-elapsed path and no-home path
  - exposed `InMemoryNotificationRepository.scheduledDrafts()` test helper for notification assertions
- Validation:
  - `swift test` in `ios/MeowCore` passing (44 tests)
  - `xcodebuild` `MeowApp` simulator build passing

## 2026-04-10 - Region Dormancy RPC Integration-path Coverage
- Added `RegionLifecycleRepository` abstraction in `MeowData` with implementations:
  - `SupabaseRegionLifecycleRepository`
  - `InMemoryRegionLifecycleRepository`
- Added Supabase path test:
  - `supabaseRegionLifecycleRepositoryCallsDormancyTransitionRpcs`
  - validates request payload mapping for:
    - `mark_stale_regions_dormant`
    - `mark_expired_dormant_regions_archived`
  - validates returned transition counts are decoded and propagated
- Validation:
  - `swift test` in `ios/MeowCore` passing (45 tests)
  - `xcodebuild` `MeowApp` simulator build passing

## 2026-04-10 - Scheduled Region Lifecycle Worker Path
- Added deployable Supabase edge function:
  - `supabase/functions/region-lifecycle-worker/index.ts`
  - invokes `mark_stale_regions_dormant` and `mark_expired_dormant_regions_archived` RPCs in one cycle
  - supports configurable `idleHours`, `batchSize`, reasons, and optional retention override
- Deployed function to staging project `zgousowildxaebuyqwhl` and validated invocation response.
- Added scheduler operational tooling:
  - `.github/workflows/region-lifecycle-worker.yml` (hourly cron + manual dispatch)
  - `backend/live_ops/region_lifecycle_worker_smoke.sh`
  - `backend/live_ops/REGION_LIFECYCLE_WORKER_SCHEDULING.md`
- Updated backend index docs for new worker path and scheduling references.

## 2026-04-10 - Region Lifecycle Worker Observability + Alerts Baseline
- Added migration `backend/migrations/0015_region_lifecycle_worker_runs.sql`:
  - creates `region_lifecycle_worker_runs` with status/count/error fields
  - enables RLS with service-role read/insert policies for worker-only access
- Updated worker runtime (`supabase/functions/region-lifecycle-worker/index.ts`):
  - logs success and failure runs into `region_lifecycle_worker_runs`
  - captures failure stage (`dormancy_sweep`/`archive_sweep`) and error message
- Added query pack `backend/analytics/region_lifecycle_worker_observability_queries.sql`:
  - hourly run outcomes
  - latest run snapshot
  - failure-stage breakdown
  - alert checks (no success in 2h, failure rate > 10% in 24h)
- Applied migration and redeployed worker on staging project `zgousowildxaebuyqwhl`.
- Validation:
  - `backend/live_ops/region_lifecycle_worker_smoke.sh` passing
  - direct SQL check confirmed latest `region_lifecycle_worker_runs` success record inserted

## 2026-04-10 - Consolidated Ops Alert Checks + Runbook
- Added consolidated alert SQL:
  - `backend/analytics/ops_alert_checks.sql`
  - includes boolean checks for:
    - lifecycle worker run gap / failure rate
    - timeline telemetry gap
    - encounter success gap
- Added operational response documentation:
  - `backend/live_ops/ANALYTICS_ALERT_RUNBOOK.md`
  - covers query packs, minimum alerts, and response playbook actions
- Updated backend index docs to include new alert SQL and runbook references.

## 2026-04-10 - Automated Ops Alert Workflow
- Added scheduled workflow:
  - `.github/workflows/ops-alert-checks.yml`
  - runs hourly (minute 15) and supports manual dispatch
- Added execution script:
  - `backend/live_ops/run_ops_alert_checks.sh`
  - links staging project, executes `ops_alert_checks.sql`, fails job on any `true` alert flag
  - optionally posts alert JSON payload to `OPS_ALERT_WEBHOOK_URL`
- Local validation run against staging project `zgousowildxaebuyqwhl`:
  - script returned active alerts for telemetry gaps (expected in low-traffic window)

## 2026-04-10 - GitHub Incident Auto-create for Active Alerts
- Extended `.github/workflows/ops-alert-checks.yml`:
  - captures alert payload from script outputs
  - optional issue creation step via `actions/github-script` when:
    - alert is active
    - `CREATE_GITHUB_INCIDENT_ON_ALERT=true`
  - creates labeled issue (`incident`, `ops-alert`) with alert payload and runbook reference
- Updated alert script to expose `alert_active` and `alert_payload` through `GITHUB_OUTPUT`.
