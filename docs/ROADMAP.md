# Roadmap

Status legend: `planned`, `in_progress`, `done`, `blocked`

## P1 - Foundation and Platform Setup (`done`)
- SwiftUI iOS 17+ app skeleton with modular boundaries (`App`, `Domain`, `Simulation`, `Data`, `Features`)
- Supabase project setup and environment wiring
- Postgres schema baseline + migrations + RLS
- Auth flows: Apple Sign-In + Email
- Onboarding baseline with home-location setup

## P2 - Core Simulation Time and Region Model (`in_progress`)
- Time domains: real time, simulation time (5x for long-horizon systems), care-cycle time
- Geohash region partition model
- Home vs outside classifier (with GPS drift tolerance)
- Region activation and dormancy rules
- Simulation event and snapshot storage

## P3 - Encounter and Persistent Stray Ecology (`planned`)
- Encounter eligibility and cooldown logic
- Weighted spawn selection by configurable factors
- Territorial anchor and roaming adjacency behavior
- First encounter and repeat/familiar encounter handling
- Notification event pipeline for encounter prompts

## P4 - Cat Entity Depth and Adoption Flow (`planned`)
- Persistent cat model and identity lifecycle
- Traits, temperament, appearance generation, ownership states
- Lineage links and ancestry query support
- Adoption flow (stray -> owned home pet)
- Ownership and state transition history

## P5 - Home Care and Absence Systems (`planned`)
- Core care actions: feeding, water, litter, play, affection, medicine
- Home welfare progression and neglect consequences
- Long-absence workflows: sitter, prepared supplies, pet hotel
- Trust, mood, and health effects from care quality

## P6 - Medical, Incidents, and End-of-Life (`planned`)
- Hidden true medical state vs player-known medical state
- Symptom reveal, diagnosis, treatment, recurrence probabilities
- Incident categories and urgency tiers
- Night emergency notification preference controls
- Death records, memorials, archival continuity

## P7 - Economy, Services, and Community Stations (`planned`)
- Economy ledger: token + mission + real-money-compatible service model
- Store, vet, helper, hotel service records
- Stray station lifecycle, maintenance, and pooled funding
- Ecology effects from station support and coverage

## P8 - Hardening, Telemetry, and Rollout (`planned`)
- Feature flags across major systems
- Telemetry, balancing support, and ops observability
- Performance/load testing for lazy simulation and hotspot regions
- Global tuning defaults with optional region-specific overrides

## First Playable Milestone (Architecture-Preserving)
- Onboarding + home setup
- Outdoor encounter + persistent re-encounter
- Adoption + basic home care loop
- One hidden medical arc + one incident path
- Death + memorial record persistence
- Sterilization effect on reproduction odds
