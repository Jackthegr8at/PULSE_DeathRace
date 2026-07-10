# PULSE_DeathRace

3D car combat racing built on [Kenney Starter Kit Racing](https://github.com/KenneyNL/Starter-Kit-Racing) (MIT / CC0 assets).

## Run

1. Open in **Godot 4.3+** (4.6/4.7 recommended for the kit)
2. Main scene: `scenes/Setup.tscn` (F5)
3. Pick **mode**, **track**, **laps** → **START RACE**
4. **Esc** returns to setup

### Tracks

| Track | Scene | Notes |
|--------|--------|--------|
| **Starter Circuit** | `scenes/tracks_3d/TrackDefault.tscn` | Original Kenney GridMap (unchanged layout) |
| **Figure-8 Chaos** | `scenes/tracks_3d/TrackFigure8.tscn` | New figure-8 built from the same tiles |

Original kit free-play scene still available: `scenes/main.tscn`.

### Controls

| Key | Action |
|-----|--------|
| W / ↑ | Accelerate |
| S / ↓ | Brake / reverse |
| A D / ← → | Steer |
| Esc | Back to setup |

## Project layout

```
scenes/Setup.tscn          → match setup (modes + tracks)
scenes/race/Race3D.tscn    → race host (loads track + vehicle)
scenes/tracks_3d/          → TrackDefault + TrackFigure8
scenes/vehicle.tscn        → Kenney arcade vehicle
scenes/main.tscn           → original kit demo (kept)
scripts/vehicle.gd         → Kenney vehicle physics
scripts/race/Race3D.gd     → race orchestration
scripts/autoload/MatchConfig.gd
legacy 2D prototype        → scenes/cars, scenes/Main.tscn, etc. (not main)
```

## Combat (current)

- **Space** fires missiles (15 dmg default)  
- **3 AI** trucks (colored models), path-follow + shoot  
- **HP 100**, explode on death  
- Modes: Hybrid / Race / Last Standing + lap progress on HUD  
- Rematch / Setup end screen  

Figure-8 layout still needs art pass (prefer **Starter Circuit** for playtests).  


## Credits

- **Kenney** — Starter Kit Racing (MIT code, CC0 models/audio)  
- **PULSE** — DeathRace design, multi-map setup, combat roadmap  
