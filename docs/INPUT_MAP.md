# PC Input Map (Keyboard + Mouse)

Source of truth: `Assets/_Project/Input/NooniControls.inputactions`. All keys are rebindable via the Input System.

## Global (always active)

| Action | Binding |
|---|---|
| **Cat-ical Wheel** | Hold `Tab` (time slows, move mouse to pick, release to confirm; tap to cycle) |
| Quick switch Nooni / Bruce / Semba | `1` / `2` / `3` |
| Pause | `Esc` |

## On foot: shared

| Action | Binding |
|---|---|
| Move | `W` `A` `S` `D` |
| Look / aim | Mouse |
| Jump | `Space` |
| Sprint | `Left Shift` |
| Crouch / stealth | `Left Ctrl` or `C` |
| Interact / hack highlighted device | `E` |
| Character ability | `Q` |
| Wipe glasses (stress smudge) | `R` (quick tap) |

## Per-character

| | Nooni | Bruce | Semba |
|---|---|---|---|
| `LMB` | ODM-Grapple at the aimed anchor | (unused) | (unused) |
| `RMB` (hold) | AR glasses glint, then Scout-Detective Vision | (unused) | (unused) |
| `Q` | Tie hair into bun (hide pose; also happens automatically on idle while crouched) | Bat-Nap (flop; a passing brother is frozen for 10s) | Mighty Roar (only at a high point; draws all NPCs in the room) |
| `Space` | Jump, or release grapple | Heavy hop | Jump, chains into wall/curtain climb |
| `Ctrl`/`C` | Crouch-stealth | Low-profile sneak | Crouch |

Detective Vision is on `RMB` for Nooni only, so other characters leave it free for future use.

## Driving (Mazda CX-5)

| Action | Binding |
|---|---|
| Steer | `A` / `D` |
| Accelerate | `W` |
| Brake / reverse | `S` |
| Handbrake | `Space` |
| Hack stoplight | `E` (while a stoplight is highlighted) |
| Horn | `H` |

## Design notes

- The wheel needs the cursor, so `Wheel` mode unlocks it while the rest of the time it stays locked for mouse-look.
- Wipe Glasses is on `R` rather than a face button on purpose: it has to be reachable with the left hand while WASD is held.
- Gamepad scheme intentionally deferred; add a second control scheme to the asset later.
