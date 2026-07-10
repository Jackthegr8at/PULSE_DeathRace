# PULSE DeathRace — Quality Vision Mockup

Concept pack for the next fidelity leap. Companion files:

- `ui-mockup.html` — interactive UI screens (open in a browser)
- `1.jpg` … `4.jpg` — art concepts (gameplay, cars, maps, weapons)

## Art direction

| Pillar | Direction |
|--------|-----------|
| Mood | Night arena, neon on asphalt, Flash deathrace energy |
| Readability | Bold silhouettes, unique car colors, clear projectile trails |
| UI | Dark glass chips, gold CTAs, purple mode tags, semantic HP colors |
| Motion | Sparks on walls, tire smoke on drift, short screen punch on hit |

## Physics (target)

Current prototype is arcade “speed along nose.” Target layer:

1. **Grip curve** — high grip at low speed (recovery), mild drift at high speed (skill expression).
2. **Surfaces** — asphalt default; oil = reduced grip; boost pads = impulse along path.
3. **Impact** — wall scrape damages only at high speed (optional); car–car bump transfers a little momentum.
4. **Camera** — zoom out slightly with speed; soft look-ahead toward velocity.

## Cars (target roster)

| ID | Role | Notes |
|----|------|--------|
| Pulse (player default) | Balanced | Green/gold |
| Aggressor | High damage, low armor | Red |
| Scout | High handling, low HP | Blue |
| Tank | High HP, slow turn | Violet |
| Rocket | High top speed, weak brakes | Orange |

Shared `Car` base; stats via `@export` resource (`CarStats.tres` per chassis).

## Maps (target pack)

| Map | Fantasy | Gameplay |
|-----|---------|----------|
| Figure-8 Chaos | Current, neon upgrade | Crossfire at X |
| Speed Bowl | Wide oval | Guns matter more than corners |
| City Blocks | Right-angle industrial | Ambush oil / short sightlines |
| Canyon Run | Narrow bridges | Positioning > pure speed |

Each map: `Track` scene + `Path2D` + spawn markers + power-up spawn points.

## Weapons (target kit)

| Weapon | Type | Notes |
|--------|------|--------|
| Missile | Primary | Cooldown, 15–25 dmg, optional soft home |
| Machine gun | Alt-fire | Heat limit, low dps, always available |
| Oil slick | Pickup / drop | Rear Area2D, grip debuff |
| Shield | Pickup | Timed absorb |
| Nitro | Pickup | Speed burst |
| EMP | Rare pickup | Short stun radius |

HUD weapon bar: selected primary + consumable charges.

## UI screens

1. **Setup** — mode pills, lap stepper, gold START (partially shipped).
2. **HUD** — timer/mode/lap bar, HP bar, alive, weapon slots (slots not shipped yet).
3. **End** — win/lose accent, Rematch / Setup, pop-in (shipped).
4. **Future** — pause, track select, car select, results stats (KOs, damage dealt).

## Suggested implementation order

1. Car sprites + simple tire smoke (visual identity)
2. Machine gun alt-fire + weapon HUD slots
3. Power-up pickups (oil, shield, nitro)
4. Second map (Speed Bowl) to prove multi-track
5. Drift grip blend polish
6. Car select / stats resources

## Not in this mockup

Blockchain / XPR, online multiplayer, full audio production.
