# Greybox Room: Scene Setup Guide

Goal: a one-room stealth test. Nooni starts in the south-west corner, Yasser patrols the middle of the room, and Nooni must reach the green exit pad in the north-east using the sofa and counter as cover.

Units are metres. Everything is built from default 3D Objects (Cube, Capsule). Positions below are `(x, y, z)`.

## 0. One-time project setup
1. Unity Hub > **Add project from disk** > the `NooniGame` folder. Use Unity 6 (6000.0.x). Let packages import (Input System, Cinemachine, AI Navigation).
2. **Edit > Project Settings > Player > Other Settings > Active Input Handling** = `Input System Package (New)`, then accept the restart.
3. Wait until the console shows no compile errors. If there are, send me the first few lines; these scripts have not been compiled yet.
4. **File > New Scene** (Basic template), then **Save As** `Assets/_Project/Scenes/GreyboxRoom.unity`.
5. **File > Build Profiles > Scene List > Add Open Scenes.** The prototype restarts by reloading the scene, which needs this.
6. Delete the template's `Directional Light` if you like; keep `Main Camera`.

## 1. The room (everything under one `Level` parent)
Create an empty GameObject `Level` at `(0,0,0)`. Create these Cubes as its children:

| Name | Position | Scale |
|---|---|---|
| Floor | 0, -0.05, 0 | 12, 0.1, 10 |
| Wall_N | 0, 1.25, 5.05 | 12.2, 2.5, 0.1 |
| Wall_S | 0, 1.25, -5.05 | 12.2, 2.5, 0.1 |
| Wall_E | 6.05, 1.25, 0 | 0.1, 2.5, 10 |
| Wall_W | -6.05, 1.25, 0 | 0.1, 2.5, 10 |
| Sofa | -2, 0.4, -3 | 3, 0.8, 1 |
| Counter | 4.5, 0.5, -1 | 1, 1, 3 |
| CoffeeTable | -0.5, 0.25, 0 | 1.6, 0.5, 0.8 |

Tint the Floor and furniture with different materials (right-click in Project > Create > Material) so you can tell them apart.

## 2. Cover zones (outside `Level`, at the scene root)
Create an empty `Cover` parent. Add two Cubes as its children and set them up as follows:
1. **Remove the Mesh Renderer** or leave it, but give it a transparent blue material to see it. Tick **Is Trigger** on the Box Collider.
2. Add the **CoverVolume** component to each.

| Name | Position | Scale |
|---|---|---|
| CoverZone_Sofa | -2, 0.9, -3 | 3.6, 1.8, 2.4 |
| CoverZone_Counter | 4.5, 0.9, -1 | 2.2, 1.8, 3.6 |

These zones deliberately stick out about 0.7 m past the furniture so Nooni can crouch beside it and still be inside. Keep them outside `Level` so they don't get baked into the NavMesh.

## 3. Nooni
1. Create an empty GameObject `Nooni` at `(-5, 0, -4)`. The pivot must be at her feet.
2. **Add Component > Character Controller**: Center `(0, 0.9, 0)`, Height `1.8`, Radius `0.35`, Step Offset `0.3`.
3. Child **Capsule** named `Body`: Position `(0, 0.9, 0)`, Scale `(0.7, 0.9, 0.7)`. **Remove its Capsule Collider** (the Character Controller is her collider).
4. Child of `Body`: a **Cube** `Face`, Position `(0, 0.4, 0.5)`, Scale `(0.4, 0.25, 0.4)`, collider removed. This shows which way she's facing (+Z is forward).
5. On `Nooni` add the **NooniController** script and set:
   - `Id` = Nooni, `Display Name` = Nooni (leave Portrait and Camera Rig empty).
   - `Body` = the `Body` child.
   - `Camera Pivot` = the object from step 4 below.
   - `Standalone` stays ticked.

## 4. Camera
1. Create an empty GameObject `CameraPivot` at the scene root (not a child of Nooni; the script moves and rotates it).
2. **GameObject > Cinemachine > Cinemachine Camera.** This also adds a `CinemachineBrain` to `Main Camera`.
3. On the new Cinemachine Camera: **Tracking Target** = `CameraPivot`; **Position Control** = `Third Person Follow`; **Rotation Control** = `Same As Follow Target`. Set **Camera Distance** `4`, **Shoulder Offset** `(0.5, 0, 0)` and **Vertical Arm Length** `0.3`. (Field names can differ a little between Cinemachine versions.)

## 5. Yasser
1. Create a **Capsule** `Yasser` at `(-3, 1, 1.5)`, kept at **scale 1**. Leave its Capsule Collider on.
2. **Add Component > Nav Mesh Agent**: **Base Offset `1`**, Radius `0.5`, Height `2`, Speed `1.8`, Stopping Distance `0.3`.
3. Child **Cube** `Face`, Position `(0, 0.5, 0.5)`, Scale `(0.3, 0.2, 0.3)`, collider removed. It also serves as the alert-colour lamp.
4. Create four empty objects as waypoints under a `PatrolPoints` parent, at `(-3,0,1.5)`, `(2,0,1.5)`, `(2,0,-1.5)`, `(-3,0,-1.5)`. Name them `P1` to `P4`.
5. Add the **BrotherAI** script: `Patrol Points` = P1..P4 in order; `Indicator` = Yasser's `Face` renderer. Defaults for the rest are fine to start.
6. Select Yasser in the Scene view with Gizmos on. The cone appears as a wire fan (cyan, then green to red during play).

## 6. Bake the NavMesh
1. Select `Level`, **Add Component > Navigation > NavMesh Surface**.
2. Set **Collect Objects** to `Current Object Hierarchy` (so characters and cover zones aren't baked in).
3. Click **Bake**. You should see a blue walkable area with holes where the sofa, counter and table are.

## 7. Managers, exit and loop
1. Empty GameObject `Managers`: add **InputReader** and drag `Assets/_Project/Input/NooniControls` into its `Asset` slot.
2. Cube `ExitPad` at `(5, 0.05, 4)`, Scale `(1.5, 0.1, 1.5)`, green material, collider removed. Keep it outside `Level`.
3. On `Managers` also add **PrototypeGameLoop**: `Nooni` = Nooni, `Brothers` = size 1 with Yasser, `Goal` = ExitPad.
4. **Save the scene** (Ctrl+S) and press **Play**.

## 8. Controls
| Key | Action |
|---|---|
| WASD / Mouse | Move (camera-relative) / look |
| Left Ctrl or C | Toggle crouch (can't stand up under the sofa) |
| Left Shift | Sprint |
| Space | Jump |
| Esc, then click the Game view | Release / re-lock the cursor |

The HUD shows Nooni's status (STANDING / CROUCHED exposed / HIDDEN in cover) and Yasser's state with his awareness bar.

## 9. What to check
- [ ] Standing in his cone fills the bar in about 1.2 s and you're caught; the room restarts after 2.5 s.
- [ ] Crouched in the open: he only sees you within about 4.5 m (half range).
- [ ] Crouched inside `CoverZone_Sofa`: he never sees you, even while walking past.
- [ ] Standing behind the sofa: the sofa blocks line of sight, but standing up above it exposes you.
- [ ] A brief glimpse sends him to Investigate at your last position, then back to Patrol.
- [ ] Reaching the ExitPad shows MISSION COMPLETE.

## 10. Tuning and troubleshooting
- **Yasser doesn't move**: the NavMesh isn't baked, or his Base Offset isn't `1`. He must be standing on the blue area.
- **He sees through the sofa**: `Obstruction Mask` must include the layer the Sofa is on (default: Everything).
- **Nooni falls through the floor or doesn't move**: the Character Controller must be on the root `Nooni`, and `Body` must have no collider.
- **Camera doesn't move with the mouse**: check `Camera Pivot` is assigned and the Cinemachine camera's `Tracking Target` is the same pivot.
- **Nothing responds to keys**: confirm Active Input Handling is the new Input System, and `InputReader` has the asset assigned.
- **Crouching alone should hide her**: set `Crouched Visibility` to 0 on Nooni.
- Key tuning values: `View Distance`, `View Angle`, `Detection Seconds` (Yasser) and `Crouch Speed` (Nooni).

## Scripts involved
`NooniController`, `BrotherAI`, `CoverVolume`, `IDetectable`, `VisionMath`, `InputReader`, `PrototypeGameLoop`. The cat wheel isn't used in this room yet; `NooniController` self-possesses in `Standalone` mode.
