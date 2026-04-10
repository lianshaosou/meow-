# Decisions

This document records product and technical decisions that are currently locked.

## D-001 Backend Platform
- Date: 2026-04-05
- Decision: Use Supabase with Postgres as the core backend.
- Why: Strong fit for relational and history-heavy domain requirements (lineage, medical records, ownership history, memorial continuity, transactions).
- Impact:
  - Schema-first modeling with migrations
  - RLS and auth-integrated data access
  - Edge functions and event workflows for simulation triggers

## D-002 Region Partition Strategy
- Date: 2026-04-05
- Decision: Use Geohash-based region cells.
- Why: Practical partitioning and query ergonomics for location-driven activation and encounter logic.
- Impact:
  - Region activation on first user entry
  - Dormant regions remain lightweight
  - Cell-level ecology and spawn balancing

## D-003 Authentication at Launch
- Date: 2026-04-05
- Decision: Launch with Apple Sign-In and Email auth.
- Why: Balances platform-native trust path (Apple) with broader access and account recovery flexibility (Email).
- Impact:
  - Need account linking and identity merge safeguards
  - Auth states must be supported in onboarding and restore flows

## D-004 Launch Scope
- Date: 2026-04-05
- Decision: Global launch scope.
- Why: Product intent is location-based ecology worldwide from initial release.
- Impact:
  - Default global balancing set required
  - Optional country/region overrides should be data-driven
  - Avoid hardcoded locale assumptions in simulation rules

## D-005 Simulation Engine Behavior
- Date: 2026-04-05
- Decision: Use lazy, event-driven simulation forward (no continuous global ticking).
- Why: Preserves realism while containing backend cost.
- Impact:
  - Store last known state and last simulation timestamp
  - Compute elapsed outcomes on relevant read/write/trigger
  - Keep inactive regions and entities cheap

## D-006 Persistent Entity Principle
- Date: 2026-04-05
- Decision: Encountered cats are persistent entities, not stateless random results.
- Why: Required for emotional continuity, lineage, recurring encounters, and ecology realism.
- Impact:
  - Entity lifecycle tables are first-class
  - Encounter system selects from persistent or newly initialized region pools

## D-007 Balancing Configuration Model
- Date: 2026-04-05
- Decision: Keep balancing in data/config tables, not UI code.
- Why: Enables safe tuning, regional overrides, and long-term live ops.
- Impact:
  - Versioned config strategy needed
  - Simulation engine consumes config snapshots

## D-008 Region Dormancy Retention
- Date: 2026-04-09
- Decision: Regions transition `active -> dormant -> archived`; archived state is retained (no hard delete in current policy).
- Why: Preserve long-horizon ecological continuity while still controlling active simulation load.
- Impact:
  - Dormancy and archive transitions are service-role lifecycle sweeps.
  - Retention window is data-driven via `simulation.region_dormancy_retention_days` config key.
  - Activation RPC can reactivate dormant/archived regions on user entry.

## Pending Decision
- Death retention policy default:
  - Option A (recommended): retain dead-cat records indefinitely (archive/memorial first)
  - Option B: auto-archive then purge after retention window
