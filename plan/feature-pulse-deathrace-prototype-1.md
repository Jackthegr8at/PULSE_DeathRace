---
goal: Build PULSE_DeathRace phase-1 solo prototype (Godot 4.3+ 2D)
version: 1.0
date_created: 2026-07-10
last_updated: 2026-07-10
owner: PULSE
status: 'Completed'
tags: [feature, godot, prototype, racing, combat]
---

# Introduction

![Status: Completed](https://img.shields.io/badge/status-Completed-brightgreen)

Implement the approved phase-1 design: figure-8 deathrace with 1 player + 4 AI, missiles, match setup (Hybrid / Race / Last Standing + lap select), HUD, and win/lose screens. Spec: `docs/superpowers/specs/2026-07-10-pulse-deathrace-prototype-design.md`.

## 1. Requirements & Constraints

- **REQ-001**: Godot 4.3+ 2D project with `project.godot`, main loop Setup → Main → End
- **REQ-002**: Shared `Car` (CharacterBody2D) with arcade physics, HP 100, HP bar, wall slowdown
- **REQ-003**: Player input WASD/Arrows + Space fire; Camera2D follows player
- **REQ-004**: Missile Area2D, default damage 15, no self-hit, free on wall/lifetime
- **REQ-005**: 4 AI cars follow Path2D + shoot targets in forward cone
- **REQ-006**: Figure-8 track with walls, Path2D, 5 spawns, checkpoints, start/finish
- **REQ-007**: MatchConfig autoload: mode HYBRID|RACE|LAST_STANDING, lap_count default 5, ai_count 4
- **REQ-008**: Setup UI for mode + laps (laps disabled in LAST_STANDING)
- **REQ-009**: Win rules per mode; EndScreen You Win / Game Over; Rematch + Setup
- **REQ-010**: HUD: timer, player HP, alive count, laps when applicable
- **REQ-011**: All tuneables `@export`; well-commented GDScript
- **CON-001**: Placeholder visuals only; no blockchain; local-only validation
- **CON-002**: No GitHub Actions / external CI
- **GUD-001**: Controllers call `set_throttle` / `set_steer` / `try_fire` only
- **PAT-001**: Approach 2 — shared car + track scenes + MatchConfig
- **PAT-002**: Win evaluation lives in Main (or MatchRules), not in Missile/AI

## 2. Implementation Steps

### Implementation Phase 1 — Project skeleton

- GOAL-001: Create Godot project structure, autoload, empty scenes/scripts wiring

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Create `project.godot` (Godot 4.3, 2D, window 1280x720, main scene Setup, autoload MatchConfig) | ✅ | 2026-07-10 |
| TASK-002 | Create directory tree: `scenes/`, `scenes/ui/`, `scenes/cars/`, `scenes/tracks/`, `scripts/autoload/`, `scripts/cars/`, `scripts/tracks/`, `scripts/ui/` | ✅ | 2026-07-10 |
| TASK-003 | Implement `scripts/autoload/MatchConfig.gd` with Mode enum, lap_count=5, ai_count=4, track_scene_path | ✅ | 2026-07-10 |

### Implementation Phase 2 — Car & combat

- GOAL-002: Shared vehicle, missile, player/AI controller scripts and scenes

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-004 | Implement `scripts/cars/Car.gd` + player/AI scenes (CharacterBody2D, collision, visual rect, HP bar, physics, try_fire, death particles, signals) | ✅ | 2026-07-10 |
| TASK-005 | Implement `scripts/cars/Missile.gd` + `scenes/cars/Missile.tscn` (Area2D, damage, owner ignore, lifetime) | ✅ | 2026-07-10 |
| TASK-006 | Implement `scripts/cars/PlayerCar.gd` (input → throttle/steer/fire) | ✅ | 2026-07-10 |
| TASK-007 | Implement `scripts/cars/AICar.gd` (path look-ahead, combat cone, try_fire) | ✅ | 2026-07-10 |

### Implementation Phase 3 — Track

- GOAL-003: Figure-8 track with walls, path, spawns, lap areas

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-008 | Implement `scripts/tracks/Track.gd` API: get_race_path, get_spawn_transforms, lap helpers | ✅ | 2026-07-10 |
| TASK-009 | Build `scenes/tracks/Figure8.tscn`: procedural walls, Path2D figure-8, 5 spawns, checkpoints, StartFinish | ✅ | 2026-07-10 |

### Implementation Phase 4 — Match loop & UI

- GOAL-004: Setup, Main spawn/rules, HUD, EndScreen

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-010 | Implement `scripts/ui/Setup.gd` + `scenes/Setup.tscn` (mode, lap control, START) | ✅ | 2026-07-10 |
| TASK-011 | Implement `scripts/ui/HUD.gd` + `scenes/ui/HUD.tscn` (timer, HP, alive, laps) | ✅ | 2026-07-10 |
| TASK-012 | Implement `scripts/ui/EndScreen.gd` + `scenes/ui/EndScreen.tscn` (win/lose, Rematch, Setup) | ✅ | 2026-07-10 |
| TASK-013 | Implement `scripts/Main.gd` + `scenes/Main.tscn`: load track, spawn cars, camera, win/lose | ✅ | 2026-07-10 |
| TASK-014 | Wire lap tracking via Track checkpoints/finish; integrate MatchConfig modes | ✅ | 2026-07-10 |

### Implementation Phase 5 — Validation & docs

- GOAL-005: Ensure project opens cleanly; document run steps and next steps

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-015 | Add `README.md` with open-in-Godot instructions and controls | ✅ | 2026-07-10 |
| TASK-016 | Mark plan tasks complete; list logical next steps for post-prototype | ✅ | 2026-07-10 |

## 3. Alternatives

- **ALT-001**: Monolithic Main only — rejected (blocks multi-map)
- **ALT-002**: Full component ECS from day one — deferred (option 3 later)
- **ALT-003**: TileMap track — optional; procedural polygons used for figure-8 in v1

## 4. Dependencies

- **DEP-001**: Godot 4.3+ editor installed on developer machine
- **DEP-002**: Design spec at `docs/superpowers/specs/2026-07-10-pulse-deathrace-prototype-design.md`

## 5. Files

- **FILE-001**: `project.godot`
- **FILE-002**: `scripts/autoload/MatchConfig.gd`
- **FILE-003**: `scripts/cars/Car.gd`, `scenes/cars/PlayerCar.tscn`, `scenes/cars/AICar.tscn`
- **FILE-004**: `scripts/cars/Missile.gd`, `scenes/cars/Missile.tscn`
- **FILE-005**: `scripts/cars/PlayerCar.gd`, `scripts/cars/AICar.gd`
- **FILE-006**: `scripts/tracks/Track.gd`, `scenes/tracks/Figure8.tscn`
- **FILE-007**: `scripts/Main.gd`, `scenes/Main.tscn`
- **FILE-008**: `scripts/ui/Setup.gd`, `scenes/Setup.tscn`
- **FILE-009**: `scripts/ui/HUD.gd`, `scenes/ui/HUD.tscn`
- **FILE-010**: `scripts/ui/EndScreen.gd`, `scenes/ui/EndScreen.tscn`
- **FILE-011**: `README.md`

## 6. Testing

- **TEST-001**: Manual — Setup mode/laps → START loads Main
- **TEST-002**: Manual — Drive, reverse, wall slowdown, camera
- **TEST-003**: Manual — Missile damage, no self-hit, death removes car
- **TEST-004**: Manual — Last Standing wipeout win; player death lose
- **TEST-005**: Manual — Hybrid/Race lap win and AI finish-first lose
- **TEST-006**: Manual — Rematch and Setup from EndScreen

## 7. Risks & Assumptions

- **RISK-001**: Figure-8 Path2D/checkpoints need careful ordering; invalid order breaks laps
- **RISK-002**: `.tscn` text format must match Godot 4.x loaders exactly
- **ASSUMPTION-001**: Developer has Godot 4.3+ to open and play-test
- **ASSUMPTION-002**: Physics layers default (world/cars/missiles) is enough for v1

## 8. Audit Findings / Notes (Optional)

- **NOTE-001**: Figure-8 geometry is built procedurally in `Track.gd` for reproducible text-authored scenes.
- **NOTE-002**: Godot binary was not available in CI/agent PATH; play-test must be done locally in the editor.

## 9. Related Specifications / Further Reading

- `docs/superpowers/specs/2026-07-10-pulse-deathrace-prototype-design.md`
- Godot 4 CharacterBody2D, Area2D, Path2D documentation
