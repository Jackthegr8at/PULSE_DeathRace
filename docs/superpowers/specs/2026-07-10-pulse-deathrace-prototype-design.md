# PULSE_DeathRace — Prototype Design

**Date:** 2026-07-10 (updated 2026-07-11)  
**Status:** Living spec — reflects the shipped 3D prototype direction  
**Engine:** Godot 4.7 (3D, GDScript, Jolt Physics)  
**Base:** Kenney Starter Kit Racing (GridMap + sphere vehicles) + DeathRace combat modes  
**Scope:** Solo prototype — player + AI, combat racing; no blockchain/XPR

---

## 1. Vision

Flash-era (1998–2002) **car combat racing**, now in **3D arcade** form: Kenney trucks on painted GridMap tracks, pick up missile crates, shoot while racing, last standing / race / hybrid win rules.

An earlier **2D top-down** prototype remains in the repo under `scenes/cars/`, `scenes/tracks/`, etc., but is **not** the main entry. Main scene is `Setup.tscn` → `Race3D.tscn`.

---

## 2. Goals & Non-Goals

### Goals (current)
- Playable **3D** tracks (Starter Circuit + hand-painted Figure-8 Chaos)
- Shared `Vehicle` physics for player and AI (Kenney sphere rigidbody)
- Missiles with explosion FX; **ammo from road crates** only (no free fire)
- Setup: mode, laps, track, AI count, **crate count**, **missiles per crate**
- Hybrid / race / last-standing win conditions
- AI: path follow + short fair “point at target then fire”
- HUD3D + end screen

### Non-Goals (still deferred)
- Blockchain / XPR / multiplayer networking
- Advanced AI (overtake, rubber-banding, full pathfinding off-track)
- Weapons beyond the single missile type
- Production art pass beyond Kenney + missile GLB

---

## 3. Architecture

**MatchConfig autoload + Setup → Race3D + track scenes + shared Vehicle.**

### Project layout (3D-focused)

```
PULSE_DeathRace/
├── project.godot                 # main: Setup.tscn; MatchConfig autoload
├── models/                       # Kenney meshes + mesh-library.tres
│   └── Library/mesh-library.tres
├── scenes/
│   ├── Setup.tscn
│   ├── race/Race3D.tscn
│   ├── vehicle.tscn              # Kenney truck + RigidBody sphere
│   ├── combat/
│   │   ├── Missile3D.tscn        # instances missile.glb
│   │   ├── missile.glb
│   │   └── MissilePickup.tscn    # wood crate + mini missile
│   ├── tracks_3d/
│   │   ├── TrackDefault.tscn     # starter GridMap circuit
│   │   └── TrackFigure8.tscn     # hand-painted GridMap (editor source of truth)
│   └── ui/                       # legacy 2D HUD assets still present
├── scripts/
│   ├── autoload/MatchConfig.gd
│   ├── vehicle.gd                # drive, HP, fire, AI, laps
│   ├── race/Race3D.gd
│   ├── tracks_3d/
│   │   ├── Track3DBase.gd        # path from GridMap, crates, finish
│   │   └── TrackFigure8.gd
│   ├── combat/
│   │   ├── Missile3D.gd
│   │   └── MissilePickup.gd
│   └── ui/
│       ├── Setup.gd
│       ├── HUD3D.gd
│       └── EndScreen.gd
└── docs/superpowers/specs/
```

### Responsibilities

| Unit | Role |
|------|------|
| `MatchConfig` | Mode, laps, AI count, track id, crate_count, missiles_per_crate |
| `Setup` | Pre-match UI → writes MatchConfig → `Race3D` |
| `Race3D` | Load track, spawn player + AI, camera, HUD, win rules |
| `Track3DBase` | RacePath from road GridMap cells, SpawnPoint packing, finish Area3D, random crates |
| `TrackFigure8` | Hand-painted only — **does not** wipe/rebuild GridMap |
| `Vehicle` | Sphere physics, combat, path AI, player input, world HP bar |
| `Missile3D` | Forward projectile, layer hits, explosion on impact |
| `MissilePickup` | Area3D crate; grants ammo; uses MatchConfig missiles_per_crate |
| `HUD3D` / `EndScreen` | In-race and post-race UI |

### Extensibility
- New track = scene under `scenes/tracks_3d/` with GridMap + `Track3DBase` (or subclass) + SpawnPoint
- Road mesh library items: **3 corner, 4 finish, 5 ramp, 6 straight** (`ROAD_ITEMS`)
- Win logic stays in Race3D / MatchConfig, not in missiles

---

## 4. Vehicles, Physics & Combat

### Vehicle (`vehicle.tscn` + `vehicle.gd`)
Kenney arcade setup:
- Visual truck under `Container`; physics **RigidBody3D sphere** (layer **8**, mask **1|8**)
- Throttle / reverse / steer via angular impulse on the sphere; continuous CD on
- Ground raycast for lean/alignment
- Collision with GridMap / static world on layer 1

**Combat exports (representative):**  
`max_health` (100), `fire_cooldown` (~0.85s), `missile_damage` (15), `missile_speed` (~32),  
`starting_missile_ammo` (**0**), `max_missile_ammo` (3)

**Input**
- Player: WASD / arrows; **Space** = fire (`bounce` action)
- AI: path follow + combat aim (below)

**Health**
- HP bar billboard above vehicle
- HP ≤ 0 → died signal; removed from contention

**Signals:** `health_changed`, `ammo_changed`, `died`, `lap_completed`, `race_finished`

### Missiles (`Missile3D`)
- Mesh: `scenes/combat/missile.glb` (scale **0.25**, yaw **180°** so nose leads)
- Spawn along **vehicle forward (+Z model)**; straight-line flight only
- On hit (world or vehicles): damage, **explosion** particles/light/sound, free
- Ammo required — no infinite fire

### Missile crates (`MissilePickup`)
- Spawned along RacePath (`Track3DBase`), count = `MatchConfig.crate_count` (default **5**)
- Random offsets along path with minimum spacing
- Pickup grants `MatchConfig.missiles_per_crate` (default **2**), up to max ammo
- Visual: crate + small missile preview

### AI driving
- Follow `Path3D` / `Curve3D` built from connected **road** GridMap cells (cell centers, densified)
- Pure-pursuit look-ahead (~5–6); light centerline correction; mild corner throttle
- Tunables: `path_look_ahead`, `ai_throttle`, `ai_corner_throttle`, `ai_steer_gain`
- Race3D staggers throttle/look-ahead slightly per AI

### AI combat (fair aim — no missile cheating)
1. **Acquire** — living vehicle in range (`detect_range` ~22) and wide forward cone (`fire_acquire_dot_min` ~0.55)
2. **Point** — for up to `ai_aim_time_max` (~0.4s), blend steering toward that car (`ai_aim_steer_weight`)
3. **Fire** — only if nose alignment ≥ `fire_dot_min` (~0.93)
4. Missile still flies **straight along car forward** (same as player)
5. If not lined up in time → cancel aim, no wasted shot

Not implemented: homing missiles, auto-aim projectile direction, player-only rules.

---

## 5. Tracks (3D GridMap)

### Mesh library notes (`models/Library/mesh-library.tres`)

| Item | Name | Collision (baked) | Notes |
|------|------|-------------------|--------|
| 0 | decoration-empty | none | Ground fill |
| 1 | decoration-forest | none | Visual trees |
| 2 | decoration-tents | none | Visual tents |
| 3 | track-corner | Concave walls | Outer curve rails |
| 4 | track-finish | Concave side walls | Same wall shape family as straight |
| 5 | track-ramp | **none** | Mesh currently **identical** to straight; **not** a real ramp — using as “straight” means **no side walls** (pass-through). Prefer **track-straight (6)** for normal road. Source `track-ramp.glb` missing; `track-bump.glb` exists but is not library item. |
| 6 | track-straight | Concave side walls | Normal road piece |

GridMap scale is typically **0.75**; `cell_size` ~ **9.99**. Physics engine: **Jolt**.

### TrackDefault
- Kenney starter circuit GridMap + SpawnPoint + Track3DBase logic

### TrackFigure8 (“Figure-8 Chaos”)
- **Hand-painted** GridMap in the editor is the source of truth
- Script must **not** clear or procedurally repaint the map
- Place **SpawnPoint** on asphalt (start/finish area); cars pack along centerline
- RacePath auto-built by walking connected road cells from finish/spawn

### Track3DBase runtime
- `_ensure_race_path()` — walk road graph; densify midpoints; optional outward nudge on sharp bends
- `_ensure_finish_line()` — Area3D, mask vehicles layer 8
- `_spawn_missile_pickups()` — random along path using MatchConfig crate settings
- `get_spawn_transforms(count)` — row behind SpawnPoint facing forward

### Editor tips
- Edit **`TrackFigure8.tscn`**, not `main.tscn` / Setup
- Select the **GridMap** node to paint
- **A / S** rotate tiles (visual + baked collision orientation for pieces that have shapes)

---

## 6. Match Modes & UI

### MatchConfig
```gdscript
enum Mode { HYBRID, RACE, LAST_STANDING }
enum TrackId { KENNEY_DEFAULT, FIGURE_8 }

var mode: Mode = Mode.HYBRID
var lap_count: int = 5          # ignored in LAST_STANDING
var ai_count: int = 3
var track_id: TrackId = TrackId.KENNEY_DEFAULT
var crate_count: int = 5
var missiles_per_crate: int = 2
```

### Setup.tscn
- Title / mode / laps / track picker / AI count
- **Crate count** and **missiles per crate**
- START → Race3D

### HUD3D
- Comic stat card: outlined timer, mode/track chips, ink-bordered HP bar with damage flash, missile pip icons (drawn silhouettes, pulse on pickup), lap counter + bar
- Top-right: race position ("2ND of 4", hidden in Last Standing) + ALIVE badge
- Bottom-right: `Minimap3D` — RacePath outline (world x,z) with live vehicle dots, player highlighted gold
- Race position computed in `Race3D` every 0.25s from `laps_completed` + lap progress ratio

### End screen
- Outlined comic title (YOU WIN! / WRECKED!) + stat rows (race time, laps done, cars left)
- Rematch (same MatchConfig) / back to Setup

### Win / lose rules

| Mode | Player wins | Player loses |
|------|-------------|--------------|
| Last Standing | Only living car | Player dies |
| Race | Reaches lap_count first | Dies **or** AI finishes first |
| Hybrid | Race-finish first **or** last standing | Dies **or** AI race-finishes first |

On match end: `match_over`, stop scoring, show EndScreen.

---

## 7. Data Flow

```
Setup UI → MatchConfig (mode, laps, track, crates, ammo/crate)
                ↓
             Race3D
                ↓
     Instance TrackDefault | TrackFigure8
                ↓
   Track3DBase: path + crates + finish
                ↓
     Spawn Vehicle×(1 + ai_count)
                ↓
  Vehicle signals / finish → Race3D rules
                ↓
          HUD3D live
                ↓
     EndScreen → Rematch | Setup
```

---

## 8. Visual Style

- Kenney colormap trucks and track tiles
- Missile GLB + cartoon-ish explosion on impact
- Crates: slatted wooden crate (corner posts + plank slats + dark interior, flat Kenney-style two-tone wood) + mini missile preview, glow ring and omni light
- UI: vibrant painterly toon (BotW color + Borderlands comic ink) via `GameStyle.gd` — thick black ink borders (3–4px), hard offset comic shadows (`comic_panel`), outlined titles (`apply_title`), saturated gold/green/red palette; concept mockups under `docs/mockups/` and `assets/concept/`

---

## 9. Testing Checklist (manual)

1. Setup: modes, laps hide in Last Standing, both tracks, crate settings, START
2. Drive: WASD, reverse, walls on **straight/corner/finish**, camera follow
3. **Ramp tiles** have no walls — use straight (6) for solid rails
4. Combat: pick up crates, ammo limited, fire, damage, self-hit blocked, explosion
5. AI: follow path at usable speed; short nose-point then fire when lined up; no homing
6. Death / last standing / race laps / hybrid outcomes
7. Figure-8: spawn on asphalt, crates on path, AI path follows painted road
8. EndScreen: Rematch and Setup

---

## 10. Future Next Steps

- Fix ramp item: real bump mesh + collision, or alias ramp to straight collision
- Stronger AI (avoidance, difficulty tiers)
- Power-ups / alternate weapons
- More tracks + richer editor workflow
- Audio polish, screen shake
- Local multiplayer / online
- Blockchain / XPR (still deferred)

---

## 11. Decisions Log

| Topic | Decision |
|-------|----------|
| Presentation | **3D Kenney base** (pivoted from 2D top-down prototype) |
| Entry | `Setup.tscn` → `Race3D.tscn` |
| Tracks | Keep **both** Starter Circuit and hand-painted Figure-8 |
| Figure-8 paint | Editor GridMap is source of truth; no procedural wipe |
| Path / crates | Built per-map from each GridMap’s road cells — no per-map AI files |
| Missile ammo | **Pickups only**; start empty |
| Crate defaults | **5** crates, **2** missiles each; Setup-configurable |
| Missile mesh | `missile.glb`, scale ¼, nose flipped 180° Y; explode on hit |
| AI fire | Fair **point-then-shoot**; missile direction = car forward only |
| Wall pass-through | Prefer **track-straight** over **track-ramp** (ramp has empty shapes) |
| Physics | Jolt 3D; vehicle sphere layer 8 |
| Win model | Hybrid default; Race and Last Standing selectable |
| Laps | Default 5; disabled in Last Standing |
| AI count | Default 3 (Setup adjustable) |
| Missile damage | Default 15 |
| UI style | Vibrant toon/comic: thick ink outlines, comic panels, outlined titles (GameStyle) |
| HUD extras | Minimap3D from RacePath, missile pips, race position ranking in Race3D |
| Blockchain | Deferred |

---

## 12. Legacy 2D prototype

Still in repo for reference (`Car.gd`, `Figure8.tscn` 2D, etc.) but **not** the active design target. Prefer extending the 3D stack above.
