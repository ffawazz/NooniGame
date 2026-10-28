# Nooni's Tactical Guide to Everyday Life: Godot version

Godot 4.4 (GDScript). One-room greybox stealth prototype: Nooni sneaks past Yasser using crouch and cover.
Everything in the room is built in code, so there is no scene to assemble by hand.

## Run it
1. Download **Godot 4.4.x (standard, not .NET)** from https://godotengine.org/download. It is a single `.exe`, with no installer.
2. Start Godot, click **Import**, pick `godot/project.godot` in this repo, and press **F5** (Play).

| Key | Action |
|---|---|
| WASD / Mouse | Move / look |
| Ctrl or C | Toggle crouch |
| Shift | Sprint |
| Space | Jump |
| Esc, then click | Free / re-capture the mouse |

Reach the green pad. Crouch inside the blue cover boxes to be invisible; crouching in the open only halves his sight range.

## Automated tests
```
godot --headless --path godot -s res://tests/run_tests.gd
```
Checks the vision-cone maths and runs five detection scenarios in the real room (standing vs crouched in cover, range, and behind him). Prints PASS/FAIL per check and exits non-zero on failure.

## Layout
- `scenes/main.tscn`: tiny scene that runs `prototype/greybox_room.gd`
- `scripts/characters/nooni.gd`: movement, crouch-stealth, third-person camera
- `scripts/ai/brother_ai.gd`: patrol / suspicious / investigate / caught, vision cone and awareness
- `scripts/ai/vision_math.gd`: cone maths (unit-tested)
- `scripts/stealth/cover_volume.gd`: hiding boxes
- `scripts/core/input_actions.gd`: input map, registered in code
- `tests/run_tests.gd`: headless checks
