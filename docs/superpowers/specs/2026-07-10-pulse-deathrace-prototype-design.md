# PULSE_DeathRace — Phase 1 Prototype Design

**Date:** 2026-07-10  
**Status:** Approved for implementation planning  
**Engine:** Godot 4.3+ (2D, GDScript)  
**Scope:** Playable solo prototype — 1 player + 4 AI, combat racing, no blockchain/XPR

---

## 1. Vision

Flash-era (1998–2002) top-down car combat racing: small cars on a chaotic track, shooting missiles while racing. Phase 1 ships a solo prototype with core drive, shoot, die, and win loops. Visuals are placeholders. Multi-map and richer systems come later; architecture must not block them.

---

## 2. Goals & Non-Goals

### Goals
- Playable figure-8 track with wall collisions and camera follow
- Shared car physics for player and AI
- Missiles, health, explosion/removal on death
- Match setup: mode + lap count (including pure last-standing)
- Hybrid / race / last-standing win conditions
- Basic AI: follow race path + shoot when targets are in range
- Simple HUD and end screen

### Non-Goals (phase 1)
- Blockchain / XPR / multiplayer networking
- Polish art, audio, particles beyond a minimal death burst
- Advanced AI (overtake logic, rubber-banding, pathfinding off-track)
- Power-ups, weapons beyond single missile type
- Multiple tracks (structure only — one figure-8 ships)

---

## 3. Architecture (Approach 2)

**Shared car + track scenes + match config.** Can evolve toward component-style (option 3) by extracting physics, health, and weapon into child nodes without rewriting maps or modes.

### Project layout

```
PULSE_DeathRace/
├── project.godot
├── scenes/
│   ├── Setup.tscn
│   ├── Main.tscn
│   ├── ui/
│   │   ├── HUD.tscn
│   │   └── EndScreen.tscn
│   ├── cars/
│   │   ├── Car.tscn
│   │   └── Missile.tscn
│   └── tracks/
│       └── Figure8.tscn
├── scripts/
│   ├── autoload/
│   │   └── MatchConfig.gd
│   ├── cars/
│   │   ├── Car.gd
│   │   ├── PlayerCar.gd
│   │   ├── AICar.gd
│   │   └── Missile.gd
│   ├── tracks/
│   │   └── Track.gd
│   ├── ui/
│   │   ├── Setup.gd
│   │   ├── HUD.gd
│   │   └── EndScreen.gd
│   └── Main.gd
└── docs/superpowers/specs/
```

### Responsibilities

| Unit | Role |
|------|------|
| `MatchConfig` | Autoload session data: mode, lap_count, ai_count, track path |
| `Setup` | Pre-match UI; writes MatchConfig; loads Main |
| `Main` | Instances track, spawns cars, win evaluation, camera, HUD wiring |
| `Track` / `Figure8` | Walls, Path2D, spawns, checkpoints, start/finish |
| `Car` | Physics, health, fire, death; controller API |
| `PlayerCar` / `AICar` | Intent only (input or AI) → car API |
| `Missile` | Straight projectile damage |
| `HUD` / `EndScreen` | In-race and post-race UI |

### Extensibility notes
- New map = new scene under `scenes/tracks/` implementing the same Track API
- Option 3 migration: extract `VehiclePhysics`, `Health`, `Weapon` as children; keep `set_throttle` / `set_steer` / `try_fire` stable
- Avoid win logic inside Missile or AI scripts; Main (or a small MatchRules helper) owns outcomes

---

## 4. Cars, Physics & Combat

### Car (CharacterBody2D)
Arcade top-down vehicle:
- Accelerate, brake/reverse, rotate (prefer turning while moving for a car feel)
- Friction when coasting
- Collision with wall `StaticBody2D` → velocity slowdown only (no wall damage in v1)

**Exported tweaks (non-exhaustive):**  
`max_speed`, `acceleration`, `reverse_speed`, `turn_speed`, `friction`, `max_health`, `fire_cooldown`, `missile_damage`, `wall_slowdown_factor`

**Controller API:**
- `set_throttle(value: float)` — typically -1..1
- `set_steer(value: float)` — typically -1..1
- `try_fire()` — respects cooldown; spawns missile if ready

**Health:**
- Default `max_health = 100`
- HP bar above car (ProgressBar or simple rects)
- HP ≤ 0 → short particle burst, emit `died`, remove or disable car

**Signals:** `health_changed(current, max)`, `died`, `fired`

### Player
- Input: WASD or arrow keys (throttle / brake-reverse / steer)
- Space: `try_fire()`
- Camera2D follows player (child of player or Main-smoothed follow)

### AI (×4)
- Follow track `Path2D` with look-ahead point (`path_look_ahead` export)
- Steer toward look-ahead; high throttle on straights; ease turns if needed
- Combat: nearest living car in forward cone + range → `try_fire()` on cooldown
- No advanced collision avoidance in v1 (bumping is intentional chaos)

### Missile (Area2D)
- Spawn at car nose; constant velocity along car facing
- Default damage **15** (export; design range 10–20)
- On hit other car: apply damage, free self
- On wall or lifetime expiry: free self
- Ignore owner (reference and/or brief grace frames)

---

## 5. Track (Figure-8)

### Contents of `Figure8.tscn`
- **Walls:** `StaticBody2D` + `CollisionPolygon2D` (outer boundary + infield islands)
- **Visuals:** `Polygon2D` / colored placeholders
- **RacePath:** single continuous `Path2D`/`Curve2D` through both loops and the crossing
- **SpawnPoints:** five `Marker2D` nodes near start (player + 4 AI)
- **Checkpoints:** ordered `Area2D`s along the race direction
- **StartFinish:** `Area2D`; lap increments only if all checkpoints for the current loop were hit

### Track.gd API
- `get_race_path() -> Path2D`
- `get_spawn_transforms() -> Array[Transform2D]`
- Checkpoint / finish helpers as needed for lap tracking

### Lap tracking (per car, when mode uses laps)
- Current checkpoint index, laps completed
- Valid finish crossing → lap++
- Race completion: laps completed ≥ `MatchConfig.lap_count`

---

## 6. Match Modes & UI

### MatchConfig
```gdscript
enum Mode { HYBRID, RACE, LAST_STANDING }
var mode: Mode = Mode.HYBRID
var lap_count: int = 5          # ignored in LAST_STANDING
var ai_count: int = 4           # fixed in v1 UI; easy to expose later
var track_scene_path: String    # default Figure8
```

### Setup.tscn
- Title: PULSE DEATHRACE
- Mode: Hybrid | Race | Last Standing
- Laps: choosable (e.g. 3 / 5 / 7 or spinbox); default **5**; control disabled/hidden in Last Standing
- START → write MatchConfig → change scene to Main

### HUD (in race)
- Elapsed timer
- Player HP (numeric and/or bar; car also has world-space bar)
- Cars remaining (alive count)
- Lap `current / total` when mode is Race or Hybrid
- Optional small mode label

### End screen
- “You Win!” or “Game Over”
- **Rematch** → reload Main (same MatchConfig)
- **Setup** → return to Setup.tscn

### Win / lose rules

| Mode | Player wins | Player loses |
|------|-------------|--------------|
| Last Standing | Player is only living car | Player dies |
| Race | Player reaches lap_count first | Player dies **or** any AI reaches lap_count first |
| Hybrid | Player race-finishes first **or** last standing | Player dies **or** AI race-finishes first |

On match end: stop further scoring (pause tree or set match_over flag), show EndScreen.

### Main.gd
1. Instance track from `MatchConfig.track_scene_path`
2. Spawn player + `ai_count` AI at spawn markers
3. Connect car `died` and lap events → evaluate rules
4. Update HUD each frame / on signals
5. Attach or follow camera on player

---

## 7. Data Flow

```
Setup UI → MatchConfig (mode, laps, track)
                ↓
              Main
                ↓
        Instance Track (Figure8)
                ↓
     Spawn Car×5 (1 Player + 4 AI)
                ↓
    Car signals / lap events → Main rules
                ↓
         HUD live updates
                ↓
     EndScreen → Rematch | Setup
```

---

## 8. Visual Style (v1)

- Colored rectangles/polygons for cars (distinct colors: player green, AI varied)
- Grey walls, dark asphalt-like polygons
- Yellow missile rectangles or small sprites
- Default Godot UI theme acceptable for Setup/HUD/EndScreen
- No requirement for TileMap if polygons are clearer for figure-8 walls

---

## 9. Testing Checklist (manual)

1. Setup: switch modes; confirm laps disable in Last Standing; START loads race
2. Drive: WASD/arrows, reverse, wall slowdown, camera follow
3. Combat: fire missiles, damage AI, self-hit blocked, wall destroys missile
4. Death: HP 0 removes car, alive count updates; wipeout wins Hybrid/Last Standing
5. Laps: checkpoints required; finishing N laps wins Race/Hybrid
6. Loss: player death → Game Over; AI finishes first in Race/Hybrid → Game Over
7. EndScreen: Rematch and Setup both work

---

## 10. Future Next Steps (post phase 1)

Documented for later, not phase 1 scope:
- More tracks under `tracks/`, track picker in Setup
- Stronger AI (avoidance, rubber-band, difficulty)
- Power-ups, alternate weapons, gun vs missile
- Sounds, better art, screen shake
- Component extraction (option 3)
- Local multiplayer / online
- Blockchain / XPR integration

---

## 11. Decisions Log

| Topic | Decision |
|-------|----------|
| Track shape | Figure-8 (chaos); multi-map later |
| Architecture | Approach 2 (shared car + track scenes + MatchConfig) |
| Evolution | Option 2 can migrate to component style (option 3) |
| Win model | Hybrid default; Race and Last Standing selectable |
| Laps | Configurable at setup; default 5; disabled in Last Standing |
| AI count | 4 (5 cars total) |
| Missile damage | Default 15, exportable |
| Wall damage | None in v1 (slowdown only) |
| Blockchain | Deferred |
