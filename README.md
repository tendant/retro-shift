# RetroShift

Race. Earn. Upgrade. Repeat. A 16-bit-inspired pseudo-3D arcade racer in
Godot 4 / GDScript. Design: [retroshift-design-v0.4.md](retroshift-design-v0.4.md).

## Run

`make help` lists the shortcuts (`make run TRACK=s_curve`, `make debug`, `make test`, ...).
Or call Godot directly:

```sh
godot --path .                          # play (opens the race scene)
godot --path . -- --track=s_curve       # pick a test track
godot --path . -- --opponents=1         # field size, 0-5 AI (default 5)
godot --path . -- --autodrive --debug   # hands-off drive with debug overlay
```

Tracks: `basic`, `straight`, `s_curve`, `hillcrest`, `valley`, `crest_into_curve`.

| Action | Keyboard | Gamepad |
|---|---|---|
| Throttle / brake | ↑ / ↓ (W / S) | RT or A / LT or B |
| Steer | ← → (A D) | Left stick, D-pad |
| Nitro | Space | X or RB |
| Pause / restart | Esc or P / R | Start / Back |
| Debug overlay / next track | F1 or Tab / F2 | |

## Test

```sh
tools/run_tests.sh   # GUT, headless; same command CI runs
```

## Layout

- `scripts/track/` – `TrackSegment`, `Track` (lookup, continuous heading/height), test tracks, minimap
- `scripts/simulation/` – 60 Hz `RaceSimulation` (collisions, ranking, results), vehicle model, snapshots
- `scripts/rendering/` – camera-relative `RoadProjector`, far-to-near `RoadRenderer`, HUD
- `scripts/core/` – race scene wiring, input bindings/adapter
- `scripts/ai/` – opponent AI (v_max target speed, follow/pass lanes); also drives `--autodrive`
- `tests/` – GUT tests
