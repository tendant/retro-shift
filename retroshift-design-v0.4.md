# RetroShift — Game Design & Implementation Plan

**Game name:** RetroShift (working title; trademark check pending)
**Tagline:** Race. Earn. Upgrade. Repeat.
**Status:** Draft v0.4 (2026-10-18)
**Inspiration:** Classic 16-bit pseudo-3D racers. Original IP and assets only; reference specific titles in internal docs only, never in marketing.
**Engine:** Godot 4.x / GDScript; custom 2D pseudo-3D renderer
**Platforms:** macOS/Windows first; Linux/iOS/Android next; consoles via approved partners later.

### Changes since v0.3

- **Renderer:** Road geometry is now integrated **relative to the camera** each frame. The world-space closed centerline, closure validator, and seam handling are gone; world-space positions are used only for the minimap.
- **Occlusion:** One strategy: far-to-near painter's order with full-width terrain bands, and each segment's sprites drawn right after that segment's road strip. The per-column clipping envelope was removed.
- **Physics ↔ AI:** Maximum cornering speed `v_max(k)` is derived from the physics model, and AI uses it as its target speed.
- **Upgrades:** Armor is replaced by **Nitro**. Damage and fuel are moved to Later and removed from `VehicleState`.
- **Input:** `pause_pressed` is moved out of `DrivingInput` into UI/game-state input; `nitro_pressed` is added.
- **Laps:** `lap = floor(s / L)`, because `s` only increases. The start-line debounce is removed; the grid starts at negative `s`.
- **New §2 Game design:** core loop, nitro, failure/retry rules, AI rubber-banding policy, HUD, field size, audio.
- **Tooling:** GUT is the test framework; a 320×240 `SubViewport` with nearest filtering is used for low-res rendering.
- **Estimates:** revised; placeholder engine audio moved into Milestone 2.

---

## 1. Vision and scope

Build a fast, accessible 16-bit-inspired arcade racer centered on **race → earn credits → upgrade → race again**. Keep the recognizable pseudo-3D road, readable hills and curves, responsive controls, and meaningful car progression, without copying any existing game's name, art, audio, track layouts, or code.

**First playable:** one track, one player, one AI opponent, three laps, keyboard/gamepad, debug HUD, placeholder engine sound.

**Vertical slice:** up to five opponents, nitro, race results, two events, garage, four upgrade lines, persistent saves.

**Later:** larger fields (target ~12–20 cars), damage + armor, fuel/pit stops, weather, championships, split-screen, mobile controls, console ports.

**Out of scope for the MVP:** network multiplayer, licensed vehicles, full 3D physics.

## 2. Game design

**Core loop:** pick event → race (3 laps) → results and credits → garage (buy upgrades) → next event.

**Nitro:** The signature risk/reward mechanic. The player starts each race with a limited number of boosts (base 3). A boost gives a few seconds of extra acceleration and a higher speed cap. Using one before a sharp curve is a mistake the player learns quickly, because cornering speed is limited (§5).

**Advancement:** Finishing in the **top 3** unlocks the next event. Any finish earns credits, so a struggling player can retry, upgrade, and progress; grinding is allowed but should rarely be needed. There is no game-over in the slice.

**AI fairness:** Mild, capped rubber-banding. AI cars more than ~150 m behind the player gain up to +5% top speed; AI cars far ahead never slow down artificially. It can be toggled off for testing, and difficulty settings scale its strength.

**HUD:** speed, position (e.g. 2/6), lap (e.g. 2/3), nitro remaining, minimap, race timer. Minimal, readable at 320×240.

**Audio:** Engine pitch follows speed from Milestone 2 onward, because it is core to driving feel. Add tire squeal on high lateral slip, a nitro whoosh, and a collision thud. Music comes in Polish.

**Handling stance:** retro-inspired but forgiving. Off-road excursions slow you down but are always recoverable; there are no spin-outs in the slice.

## 3. Technical decisions

| Decision | Choice | Reason |
|---|---|---|
| Rendering | `Node2D` + custom `_draw()` in a 320×240 `SubViewport` (nearest filter) | Retro look, lightweight and portable |
| Geometry | Segment list (length, curvature, elevation); integrated **camera-relative** each frame | No closure constraint, no seams, trivial track authoring |
| Simulation | Fixed 60 Hz `_physics_process()` | Consistent tuning independent of draw rate |
| Rendering state | Two preallocated snapshot buffers (previous/current) + interpolation | No rendering side effects; no per-tick allocation |
| Vehicle physics | Track-relative arcade model, SI units | Easy to tune and test |
| AI | Target speed from `v_max(k)` + lane selection | Physics and AI stay consistent automatically |
| Content | Godot `Resource` data | Designers can tune without code changes |
| Input | Normalized `DrivingInput` + separate UI actions | Keyboard, gamepad, and touch share gameplay logic |
| Display | Fixed-height logical game view; width adapts to aspect ratio; UI scales separately | Pixel feel without stretching or clipped mobile HUD |
| Tests | GUT (headless) + visual test scenes | Standard Godot tooling, CI-friendly |

**Determinism caveat:** A fixed timestep improves repeatability but does not guarantee bit-identical results across hardware. Do not promise cross-platform deterministic replay until it has been validated.

## 4. Track model

Every car uses `s_m` (unwrapped forward distance), `x_m` (signed lateral offset from the road center; positive = right), and `speed_mps`. Rendering, AI, collision, and ranking sample the **same** segment data. Convert to a wrapped distance only when sampling segments: `s_wrapped = fposmod(s_m, lap_length_m)`.

```gdscript
class_name TrackSegment
extends Resource

@export var length_m: float = 20.0
# Signed heading change per meter (radians / meter). Positive = curves right.
@export var curvature_rad_per_m: float = 0.0
# Height difference from segment start to end (meters).
@export var elevation_delta_m: float = 0.0
@export var road_half_width_m: float = 5.0
@export var scenery_id: StringName
```

On load, validate positive lengths and widths, finite values, and curvature within a sane bound. Precompute cumulative segment start distances for fast `s → segment` lookup. Elevation is smoothed across segment boundaries (ease in/out of grade changes) so crests do not look like sharp kinks.

**No geometric closure required.** The road is always built forward from the camera (§5), so a track whose curvature doesn't sum to exactly 2π, or whose elevation doesn't net to zero, renders without a seam. Lap length is simply the sum of segment lengths.

**Minimap:** Integrate the segments once into world space and distribute any closure error linearly along the loop so it draws as a closed shape. The minimap is cosmetic only and is never used by physics or AI.

## 5. Pseudo-3D rendering

**Camera:** A chase camera sits a configurable distance behind the player at a configurable height, with configurable FOV and lateral smoothing. Its track position is `s_cam = s_player - back_offset`.

**Camera-relative road integration (per frame):**

```text
heading = 0; pos = (x = 0, y = -cam_height, z = 0)
s = s_cam
for step in visible_steps (e.g. 200–300 steps of ~2–5 m):
    seg = segment_at(fposmod(s, lap_length))
    heading += seg.curvature * step_len
    pos.x   += sin(heading) * step_len
    pos.z   += cos(heading) * step_len
    pos.y   += seg.grade_at(s) * step_len
    store point (pos, heading, half_width, seg) in a preallocated buffer
    s += step_len
```

Subtract the camera's lateral offset and yaw smoothing, then project each stored point.

For a camera-space point `(X, Y, Z)` with `Z > near_clip`:

```text
f = (viewport_height / 2) / tan(vertical_fov / 2)
screen_x = cx + f * X / Z
screen_y = cy - f * Y / Z
```

Road edges are `pos ± perpendicular(heading) * half_width`. A car's `x_m` places it relative to the centerline at its own `s`. Curvature affects handling separately (§6), so the visuals and the physics agree on every curve.

**Draw order: one far-to-near pass, interleaved.**

1. Sky/background, with horizontal parallax driven by the camera heading.
2. For each step from farthest to nearest:
   - a full-width terrain band (grass) between this step's screen Y and the next one's,
   - shoulders/rumble strips, then the road polygon and lane markings,
   - **sprites belonging to this step** (scenery, AI cars), scaled by `f / Z`.
3. Player car sprite.
4. HUD.

Nearer terrain bands and road strips paint over anything behind a hill crest, so road and sprites beyond a crest are hidden automatically, with no clipping buffer. If road sections ever overlap horizontally on screen and show artifacts, add per-step clip-Y as a fallback; don't build it pre-emptively.

The renderer reads only the interpolated snapshot and never advances simulation state. Profile `_draw()` before considering batching or a shader-based renderer.

**Sprites:** Car sprites have left/center/right turning frames (plus hard-turn frames later). Scale them with integer-snapped rects to keep pixels crisp.

**Debug modes:** centerline, step/segment IDs, projected edge points, Z depth, camera axes, car `(s, x, speed)`, and current `v_max` per curve. Visual test tracks: straight, S-curve, hillcrest, valley, crest-into-curve.

## 6. Arcade vehicle physics

```gdscript
class_name VehicleState
extends RefCounted

var s_m: float = 0.0
var x_m: float = 0.0
var speed_mps: float = 0.0
var lateral_speed_mps: float = 0.0
var nitro_remaining: int = 3
var nitro_timer_s: float = 0.0
```

```gdscript
class_name DrivingInput
extends RefCounted

var throttle: float = 0.0  # [0, 1]
var brake: float = 0.0     # [0, 1]
var steer: float = 0.0     # [-1, 1]
var nitro_pressed: bool = false
```

All devices map into `DrivingInput`; the simulation knows nothing about keys or touch widgets. Pause, menu, and other UI actions are handled by game state, not the simulation.

**Update at `dt = 1/60`:**

```text
boost = nitro_timer > 0
forward_accel = throttle * engine_accel * (boost ? nitro_accel_mult : 1)
              - brake * brake_decel
              - rolling_drag - aero_drag(speed)
              - (off_road ? off_road_drag : 0)
cap   = max_speed * (boost ? nitro_speed_mult : 1)
speed = clamp(speed + forward_accel * dt, 0, cap)   # if over cap, decay toward it

# The road bends under a forward-moving car, pushing it outward.
curve_accel   = -curvature(s) * speed^2
steer_accel   = steer * steer_max_accel(speed) * grip
lateral_accel = steer_accel + curve_accel - lateral_damping * lateral_speed
lateral_speed = clamp(lateral_speed + lateral_accel * dt, -lat_cap, lat_cap)
x += lateral_speed * dt
s += speed * dt
```

**Derived cornering limit:** A car can hold a curve of curvature `k` only while `steer_max_accel * grip ≥ |k| * v²`, so:

```text
v_max(k) = sqrt(steer_max_accel * grip / |k|)
```

This is a key design lever. Every curve has a known safe speed, Tires upgrades visibly raise it, and AI targets it directly (§7). Expose it in the debug overlay.

**Deliberate simplifications (documented, not bugs):**

- `s` advances at `speed` regardless of lane. The real inside-lane advantage (`ds = v·dt / (1 − k·x)`) is ignored for now; revisit if racing lines feel flat.
- Elevation grade does not affect speed.
- No heading angle relative to the road; the sprite frame is chosen from `steer` and `lateral_speed`.
- Off-road: extra drag and reduced grip, always recoverable.

**Collisions:** These are resolved in track-relative space. Longitudinal separation uses the shortest wrapped difference, `fposmod(Δs + L/2, L) − L/2`; lateral overlap uses car half-widths. The rear car loses speed (bounded) and both cars get an opposite lateral impulse. Collisions never move `s` backward or across a lap boundary. There is no damage in the slice.

**Tuning targets:** responsive steering at low/mid speeds, readable drift on curves, recoverable off-road, and each upgrade level visibly changing lap time.

## 7. AI, race rules, and ranking

Each opponent stores `s_m`, `x_m`, speed, a skill factor (0.85–1.0), preferred lane, target lane, overtake cooldown, and nitro count.

**Target speed** = the minimum of `v_max(k) * skill * margin` over the curvature in a look-ahead window sized to its braking distance, capped by its own `max_speed`. Rubber-banding (§2) adjusts the cap only.

**States:** Cruise → Follow → Pass → Recover.

- **Follow:** a slower car is ahead in the same lane, so match its speed and look for a free lane.
- **Pass:** move to the free lane, hold it until clear, then cool down.
- **Recover:** return to the preferred lane.

AI uses nitro on long straights when the next `v_max` is far above its current speed. Add one AI first; scale to five only after passing and collisions are stable.

**Laps:** Speed is ≥ 0 and `s` is unwrapped, so `s` only increases. `lap = floor(s / lap_length)`. Grid positions start at small negative `s` (behind the line), so lap 1 begins as each car crosses `s = 0`. No debounce is needed.

**Ranking:** Sort by `s` (total distance); finished cars keep their finishing order. A car finishes when `s ≥ laps * lap_length`. When the player finishes, finish order for the remaining AI is projected from current `s` and speed so results appear immediately.

## 8. Upgrades, economy, and persistence

Four permanent upgrade lines, each with **three levels** in the vertical slice. The values are initial tuning examples.

| Upgrade | Affects | Level bonuses | Prices (credits) |
|---|---|---|---|
| Engine | Acceleration | +10%, +20%, +35% | 200, 450, 800 |
| Gearbox | Max speed | +5%, +12%, +20% | 200, 450, 800 |
| Tires | Grip (raises `v_max` on every curve), off-road recovery | +8%, +16%, +25% | 150, 350, 650 |
| Nitro | Boosts per race / boost strength | 4, 5, 6 boosts; +10% strength at L3 | 150, 350, 650 |

**Rewards (per event, scaled by event tier):** 1st 400, 2nd 250, 3rd 150, other finishes 75. The player starts with 0 credits. The cheapest upgrade (150) needs a 3rd place or two weak finishes; validate this with playtests against real lap times, not percentages alone.

**Events:** Event 1 (easy AI, gentle track) → Event 2 (harder AI, hills + S-curves). Top 3 unlocks the next event.

**Purchases** are atomic, never make credits negative, and are capped at level 3. Upgrade levels change stat parameters at race start, never live `VehicleState`.

**Saves** go to `user://` and hold `schema_version`, credits, upgrade levels, unlocked events, best results, and settings. Validate on load, back up before migration, and fall back to defaults on corruption. Storage sits behind an interface so console user profiles can plug in later.

## 9. Architecture and project layout

```text
retroshift/
├── project.godot
├── addons/gut/            # test framework
├── scenes/                # menu, race, garage, results
├── scripts/
│   ├── core/              # game state, input adapters, save service
│   ├── simulation/        # RaceSimulation, VehicleState, physics, collisions
│   ├── track/             # TrackSegment, segment lookup, validator, minimap
│   ├── ai/                # opponent controller and lane planning
│   ├── rendering/         # road integration/projection, sprites, HUD, debug
│   ├── audio/             # engine pitch, event sounds
│   └── progression/       # economy, upgrades, event unlocks
├── resources/             # original tracks, cars, upgrade tables
├── assets/                # original art/audio only
└── tests/                 # GUT tests and visual test scenes
```

```text
Input adapters → DrivingInput ─┐
UI actions → GameState         │
                               ▼
               RaceSimulation (60 Hz) ← Track segments (immutable)
                     │ prev/current snapshot buffers + events
                     ▼
        RoadRenderer / HUD / Audio (read-only)

Race results → ProgressionService → versioned SaveService
```

The simulation owns authoritative race state and emits events (lap completed, collision, nitro, finish). The renderer interpolates between the previous and current snapshots using the render fraction. Audio and UI react to snapshots and events and never mutate simulation state.

## 10. Platforms and performance

**Desktop P0:** macOS and Windows exports; Linux P1. Keyboard and gamepad are tested from Milestone 0.

**Mobile P1:** iOS/Android exports, touch controls (steer zones or tilt, plus throttle/brake/nitro buttons), safe-area UI, multiple aspect ratios, lifecycle pause/resume, thermal/performance QA. iOS needs Apple's signing workflow.

**Consoles P2:** platform-holder approval, SDKs, porting partner, certification. Godot has no public console export.

The game view renders at 240 px logical height; its width follows the aspect ratio, so widescreen shows more roadside rather than stretching. The HUD uses an independent scalable layout. Target 60 FPS on representative desktop and mobile devices, profiled on real hardware. Platform services (storage, achievements, profiles, lifecycle) sit behind interfaces.

## 11. Implementation plan and gates

| Milestone | Scope | Exit criteria | Solo estimate |
|---|---|---|---|
| **0 — Foundation** | Project, fixed tick, input adapters, GUT, debug overlay | Launches on desktop; gamepad works; headless tests run in CI | 1 day |
| **1 — Road renderer** | Segment model, camera-relative integration, projection, interleaved far-to-near draw, hills | Straight/S-curve/crest/valley test tracks render correctly; sprites hidden behind crests; lap wrap invisible | 2–4 days |
| **2 — Driving feel** | Vehicle model, `v_max`, off-road, nitro, player sprite frames, placeholder engine audio | One complete lap feels good; stable across render FPS | 3–4 days |
| **3 — Complete race** | One AI → five AI, passing, collisions, laps, ranking, results, minimap | Three-lap race can be won/lost; ranking and wrap tests pass | 3–5 days |
| **4 — Progression** | Two events, credits, upgrades, garage, unlocks, saves | Race → buy → race; upgrade visibly changes lap time; persists | 2–4 days |
| **5 — Polish** | Original pixel art, audio/music, HUD art, tuning | 15-minute loop playable without instructions | 5–10 days (art-dependent) |
| **6 — Mobile** | Touch UI, safe areas, profiling, pause/resume | Core loop works on one iOS and one Android device | 5–10 days |
| **7 — Console readiness** | Platform abstraction, partner feasibility, cert plan | Porting path and budget validated; not an MVP deliverable | Separate estimate |

Estimates exclude substantial original art and music; car sprites with turning frames are expected to be the largest content cost. Build no menus or extra content before the first smooth playable lap.

## 12. Tests and acceptance criteria

**Automated (GUT, headless):**

- Segment validation: positive lengths/widths, finite values, curvature bounds; `s → segment` lookup is correct at boundaries and across the wrap.
- Physics: stable at fixed step; results are materially consistent across render FPS; no NaN, no negative speed, lateral speed stays within its cap.
- `v_max`: a car at `0.95 · v_max(k)` holds a constant curve; at `1.2 · v_max(k)` it drifts outward.
- AI: stays on the road on all test tracks; passes a slower car without permanent oscillation.
- Collisions: never reduce `s` and never corrupt lap counts.
- Laps/ranking: negative grid start, overtakes just before/after the line, lapped cars, finish-order freeze.
- Economy: purchases enforce balance and caps; save/load survives corruption and schema migration.

**Visual / manual:**

- Road edges and car positions line up through straight, S-curve, crest, valley, and crest-into-curve.
- Road and sprites beyond crests are hidden without flicker; no visible seam at the lap wrap.
- A three-lap race can be completed and results shown.
- Each upgrade produces a perceptible, measurable lap-time change.
- Nitro feels rewarding on straights and punishing before sharp curves.
- Target frame rate on representative devices; keyboard, gamepad (and later touch) work.
- The full race → results → garage → next event loop needs no developer intervention.

## 13. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Projection artifacts on crests/curves | Debug overlays, visual test tracks, clip-Y fallback only if needed |
| Floaty or unfair handling | `v_max`-driven tuning, short repeated playtests from Milestone 2 |
| AI stuck or oscillating | Simple states, cooldowns, one-opponent-first development |
| Races feel sparse with five AI | Accept for the slice; plan the field-size increase and profile its cost early |
| Art cost underestimated | Placeholder sprites until Milestone 5; lock the sprite frame spec early |
| Mobile draw cost | Profile early; limit visible steps; optimize only on evidence |
| Console portability surprises | Isolated services; consult a porting partner before committing |
| IP / trademark conflicts | Original title, tracks, art, audio; trademark search on the final name |

## 14. Immediate first coding task

Create the Godot project with GUT, a `RaceSimulation` ticking at 60 Hz, and a `RoadRenderer` drawing into a 320×240 `SubViewport` from snapshot buffers. Author a test track with one straight, one S-curve, and one hill. Implement camera-relative road integration and the interleaved far-to-near draw, with debug overlays. Add a placeholder player sprite, keyboard throttle/brake/steer, and the curve force.

**First checkpoint:** one smooth lap with no visible wrap seam, where the road visuals and the handling agree on every curve.
