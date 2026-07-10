# PULSE_DeathRace

Top-down car combat racing prototype (Godot **4.3+**). Flash-era deathrace vibes: figure-8 track, missiles, and hybrid win conditions.

## Requirements

- [Godot 4.3+](https://godotengine.org/download) (4.3 or 4.4 recommended)

## Run

1. Open Godot → **Import** → select this folder (`project.godot`)
2. Press **F5** (or Play). Main scene is `scenes/Setup.tscn`.

## Controls

| Action | Keys |
|--------|------|
| Accelerate | `W` / `↑` |
| Brake / reverse | `S` / `↓` |
| Steer | `A` `D` / `←` `→` |
| Fire missile | `Space` |

## Match setup

- **Hybrid** — win by finishing the set laps **or** being last car standing  
- **Race** — win only by finishing laps first  
- **Last Standing** — no laps; eliminate everyone else  
- **Laps** — choosable (default 5); disabled in Last Standing  

## Project layout

See `docs/superpowers/specs/2026-07-10-pulse-deathrace-prototype-design.md` and `plan/feature-pulse-deathrace-prototype-1.md`.

```
scenes/Setup.tscn     → pre-match menu
scenes/Main.tscn      → race
scenes/tracks/Figure8 → procedural figure-8
scenes/cars/          → Player, AI, Missile
scripts/autoload/MatchConfig.gd
```

## Tweaking

Select a car scene / script in the inspector for `@export` values: speed, turn rate, damage, fire cooldown, AI look-ahead, detect range, etc.

## Phase 1 status

Playable solo prototype: 1 player + 4 AI, combat, modes, HUD, end screen. Placeholder art only. No blockchain / multiplayer yet.
