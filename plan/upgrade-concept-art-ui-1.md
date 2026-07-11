---
goal: Upgrade PULSE DeathRace visuals toward the approved painterly cel-shaded countryside concept
version: 1.0
date_created: 2026-07-10
last_updated: 2026-07-10
owner: Codex
status: 'In progress'
tags: [upgrade, ui, art, godot, local-only]
---

# Introduction

![Status: In progress](https://img.shields.io/badge/status-In%20progress-yellow)

Implement the approved gameplay concept in the Godot prototype without changing gameplay rules: replace placeholder-feeling visual treatment with a warm, painterly, cel-shaded countryside arena, expressive vehicle sprites, and illustrated HUD panels.

## 1. Requirements & Constraints

- **REQ-001**: Preserve the existing solo figure-eight gameplay, controls, match modes, lap logic, and combat behavior.
- **REQ-002**: Use bold near-black outlines, vibrant painted colors, warm dirt, grassy fields, rocks, trees, and expressive cartoon vehicles.
- **REQ-003**: Upgrade the in-race HUD to match the approved concept composition: top-left health/speed/weapons, top-right minimap/lead, bottom-left alive/place, bottom-right nitro.
- **REQ-004**: Keep all UI readable at the configured 1280x720 viewport and responsive under canvas-item stretch.
- **CON-001**: Use only project-local assets and local validation; do not add external services or CI.
- **CON-002**: Do not introduce new gameplay systems that are not already represented by the prototype HUD.

## 2. Implementation Steps

### Implementation Phase 1

- GOAL-001: Create and register visual assets for cars and environment props.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Generate or replace the five top-down car textures under `assets/sprites/` with bold-outlined, expressive, color-distinct vehicles matching the approved concept. | Partial: refreshed player sprite; existing AI sprites retained | 2026-07-10 |
| TASK-002 | Generate or replace tree and rock prop textures under `assets/sprites/` with painterly outlined countryside props. | Existing project assets retained; already concept-aligned | 2026-07-10 |
| TASK-003 | Update `scripts/cars/CarVisuals.gd` so every spawned car resolves to a valid project-local texture and the player remains green. | ✅ | 2026-07-10 |

### Implementation Phase 2

- GOAL-002: Bring the arena rendering closer to the approved concept.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-004 | Update `scripts/tracks/Track.gd` palette, track ribbon layers, center markings, field patches, prop scatter, and boundary visuals to use warm painted earth, saturated meadow greens, and comic-outline contrast. | Superseded by painted playfield backdrop | 2026-07-10 |
| TASK-005 | Add lightweight painted arena accents in `scripts/tracks/Track.gd` such as fence posts, flags, signboards, grass tufts, or dust-colored surface marks without affecting collisions. | ✅ fence rails/posts | 2026-07-10 |

### Implementation Phase 3

- GOAL-003: Upgrade the race HUD visual system while preserving existing data wiring.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-006 | Update `scripts/ui/GameStyle.gd` with concept palette tokens and reusable wood/metal/comic panel styles, including readable focus and pressed states. | ✅ | 2026-07-10 |
| TASK-007 | Update `scripts/ui/HUD.gd` to use illustrated badge-like panels, stronger labels, icon-like vector primitives, and concept-aligned layout spacing while keeping the current HUD methods and signals intact. | ✅ shared panels/title treatment | 2026-07-10 |
| TASK-008 | Update `scripts/ui/Minimap.gd` so the map frame and track rendering match the warm illustrated arena. | ✅ | 2026-07-10 |
| TASK-009 | Update `scripts/ui/Setup.gd` and `scripts/ui/EndScreen.gd` styling so setup and results screens share the same visual language as the race HUD. | ✅ | 2026-07-10 |

### Implementation Phase 4

- GOAL-004: Validate locally and record deviations.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-010 | Run Godot headless import/startup validation and inspect for script parse errors. | Blocked: Godot executable not available in environment | 2026-07-10 |
| TASK-011 | Run the project locally, verify setup-to-race transition, car visibility, HUD data updates, minimap, and end-screen navigation. | Blocked: Godot executable not available in environment | 2026-07-10 |
| TASK-012 | Update this plan with completed tasks and any visual deviations caused by the procedural track or generated asset limitations. | ✅ | 2026-07-10 |

## 3. Alternatives

- **ALT-001**: Replace the procedural track with a baked concept-art background. Not chosen because it would break collision alignment and current gameplay behavior.
- **ALT-002**: Build all visuals as a single large raster background. Not chosen because the game needs independently moving cars, health bars, missiles, minimap data, and reusable props.

## 4. Dependencies

- **DEP-001**: Godot 4.3+ project already present in `project.godot`.
- **DEP-002**: Existing `Car`, `Track`, `HUD`, `Minimap`, `Setup`, and `EndScreen` APIs.
- **DEP-003**: Local raster assets under `assets/sprites/`.

## 5. Files

- **FILE-001**: `assets/sprites/car_*.png` vehicle textures.
- **FILE-002**: `assets/sprites/prop_*.png` environment textures.
- **FILE-003**: `scripts/cars/CarVisuals.gd` texture registry.
- **FILE-004**: `scripts/tracks/Track.gd` procedural arena visuals.
- **FILE-005**: `scripts/ui/GameStyle.gd` shared visual tokens.
- **FILE-006**: `scripts/ui/HUD.gd` in-race overlay.
- **FILE-007**: `scripts/ui/Minimap.gd`, `scripts/ui/Setup.gd`, `scripts/ui/EndScreen.gd` supporting UI.

## 6. Testing

- **TEST-001**: Godot headless project import/startup succeeds with no parse errors.
- **TEST-002**: Setup mode selection and lap controls retain their current behavior.
- **TEST-003**: Race starts with one green player car and four distinct outlined AI cars.
- **TEST-004**: Track collisions, missiles, health updates, lap progress, alive count, and end-screen actions remain functional.
- **TEST-005**: Visual review at 1280x720 confirms no HUD overlap obscures the race lane and no unreadable low-contrast text is introduced.

## 7. Risks & Assumptions

- **RISK-001**: Generated raster assets may vary in exact silhouette or transparent-edge quality; keep the existing textures as a fallback until replacements validate in-game.
- **RISK-002**: Procedural Line2D rendering cannot exactly reproduce painted concept-art texture; approximate with layered colors, outlines, props, and accents.
- **ASSUMPTION-001**: The approved concept art is the visual target, while the current gameplay camera and world dimensions remain authoritative.

## 8. Audit Findings / Notes (Optional)

- **NOTE-001**: The prototype already contains separate cel-shaded car and prop textures plus a concept-aligned HUD scaffold, so the upgrade can be incremental rather than a scene rewrite.
- **NOTE-002**: Generated player texture is intentionally retained at high resolution and rendered with a small scene scale so its painted outline remains crisp; Godot should import it automatically on project open.
- **NOTE-003**: Runtime validation remains outstanding until the project is opened with a local Godot 4.x executable.
- **NOTE-004**: The implementation now uses `assets/concept/figure8_playfield_painted.png` as the art foundation and keeps procedural geometry for collisions, pathing, spawn points, checkpoints, and lap logic. This directly addresses the fidelity gap between runtime primitives and the approved concept.
- **NOTE-005**: Backdrop alignment uses the painted image's world mapping: left loop `(635, 550)`, right loop `(1410, 550)`, centerline radius `280`, road half-width `110`, backdrop center `(1023, 520)`, scale `(1.15, 1.106)`.

## 9. Related Specifications / Further Reading

- `docs/superpowers/specs/2026-07-10-pulse-deathrace-prototype-design.md`
- `docs/mockups/2.jpg`
- `docs/mockups/VISION.md`
