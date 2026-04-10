# MeowCore

Shared Swift package for core product logic.

## Targets
- `MeowDomain`: cross-feature data models and shared domain primitives.
- `MeowSimulation`: time-domain clock and simulation progression helpers.
- `MeowLocation`: location math, geohash encoding, and home/outside classification.
- `MeowData`: auth/repository protocols, in-memory implementations, and Supabase config loading.
- `MeowFeatures`: onboarding/auth/bootstrap/explore/account-link view models and SwiftUI screens.

## Explore Location Mode
- `LocationService` abstraction supports live location in app runtime and deterministic stubs in tests.
- `AppleLocationService` uses CoreLocation updates.
- `InMemoryLocationService` supports tests and manual simulation.
- Explore screen includes map-assisted debug tools for non-live mode:
  - set explore point from current map center
  - jump to home center
  - jump to an automatically computed point just outside home radius

## Supabase Data Layer
- `SupabaseAuthService` supports Email and Apple token auth against Supabase Auth.
- `SupabaseProfileRepository`, `SupabaseHomeRepository`, and `SupabaseTimeSnapshotRepository` provide PostgREST-backed persistence.
- `SupabaseEncounterRepository` provides latest-encounter reads and region-activation encounter RPC calls.
- `SupabaseNotificationRepository` writes scheduled notifications and manages claim/delivery lifecycle RPC calls.
- `SupabaseTelemetryRepository` records client telemetry events for behavior analysis and tuning.
- `SupabaseSessionStore` shares and persists active session tokens across app launches (Keychain-first with fallback).

Encounter activation requests can include locale/country context so backend country overrides can tune density/spawn behavior.

## Auth Linking
- `AuthService` supports linking email credentials to the current authenticated user via `linkEmailCredentialToCurrentUser`.
- This enables Apple-authenticated users to attach email/password sign-in for account recovery and multi-provider access.
- Provider-management helpers are available for linked-provider listing, re-auth, and unlink safeguards.
- Provider-management telemetry events are emitted for unlink attempts, re-auth prompts, re-auth outcomes, and unlink outcomes.

## Run Tests
```bash
swift test
```

Run from: `ios/MeowCore`

`MeowDataTests` includes HTTP-stubbed integration-path tests for Supabase auth and encounter RPC contracts.
`MeowFeatures` includes `NotificationDeliveryService` to process due notifications and mark delivery outcomes.
`NotificationDispatching` bridges delivery to runtime channels (currently local notifications via UserNotifications).

### Optional Live Supabase Tests
- Disabled by default. Enable with `MEOW_RUN_LIVE_SUPABASE_TESTS=1`.
- Required env vars when enabled:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_TEST_EMAIL`
  - `SUPABASE_TEST_PASSWORD`
- Optional env vars:
  - `SUPABASE_TEST_GEOHASH` (default: `9q9hvum`)
  - `SUPABASE_TEST_COUNTRY_CODE`

Example:

```bash
MEOW_RUN_LIVE_SUPABASE_TESTS=1 \
SUPABASE_URL=https://<project>.supabase.co \
SUPABASE_ANON_KEY=<anon_key> \
SUPABASE_TEST_EMAIL=<email> \
SUPABASE_TEST_PASSWORD=<password> \
swift test
```
