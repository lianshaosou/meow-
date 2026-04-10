# MeowApp (iOS Target Scaffold)

This folder contains an XcodeGen project definition for a SwiftUI iOS 17 app target wired to `MeowCore` package products.

## Generate Project
```bash
xcodegen generate
```

Run from: `ios/MeowApp`

## What is wired
- `AuthScreen` from `MeowFeatures`
- `OnboardingScreen` from `MeowFeatures`
- `AppBootstrapService` snapshot trigger after onboarding
- `ExploreScreen` with eligibility + encounter checks
- `AccountLinkScreen` reachable from Explore navigation
- `AccountProvidersScreen` for linked provider management and re-auth flow

Explore now supports live CoreLocation mode with manual fallback.
Core explore/account actions also emit telemetry events when Supabase telemetry storage is configured.
On app active, due notifications are claimed and processed through the delivery service path.
Runtime delivery currently dispatches local notifications through the `UserNotifications` bridge.

## Runtime Data Source
- If `SUPABASE_URL` and `SUPABASE_ANON_KEY` are present in the app environment, MeowApp uses Supabase-backed auth and repositories.
- If they are not present, MeowApp falls back to in-memory services for local development.
