# Architecture: Nooni's Tactical Guide to Everyday Life

Engine: **Unity 6 (6000.0 LTS), C#, URP**. Packages: Input System, Cinemachine 3, TextMeshPro, Test Framework.
Why Unity: URP Shader Graph makes cel-shading and the "glasses glint" and detective-vision effects straightforward. Cinemachine gives character-to-character camera blends for free, and the Input System gives action maps and rebinding.

## Folder structure

```
Assets/_Project/
  Art/            Characters/ Environments/ Materials/ Shaders/ (toon, outline, cloth)  VFX/
  Animation/      Nooni/ Bruce/ Semba/ Brothers/
  Audio/
  Input/          NooniControls.inputactions
  Prefabs/        Characters/ Props/ Devices/ UI/
  Scenes/         Boot/ Hub/ Home_Level01.../ PNU_Level01.../ Drive_KingFahdRd/
  ScriptableObjects/  Characters/ Abilities/ Missions/ Dialogue/ Config/
  Scripts/
    Core/         StateMachine, GameStateMachine, ServiceLocator, EventChannels
    Input/        InputReader (only class that touches the InputActionAsset)
    Characters/   PlayableCharacter, CatIcalWheelManager, Nooni/ Bruce/ Semba/ (per-character states + abilities)
    Camera/       CameraRig, detective-vision post-process controller
    Stealth/      Sightline (vision cone), Noticeable, StressMeter, GlassesSmudge
    AI/           BrotherAI (Yasser, Ahmed), patrol routes, Distractable / Freezable
    Puzzle/       PressurePlate, Hackable, GrappleAnchor, Climbable (curtains/shelves)
    Driving/      CarController (Mazda CX-5), TrafficSpawner, HackableStoplight
    UI/           CatWheelUI, StressUI, Dialogue, Pause
  Tests/          EditMode/ PlayMode/
Packages/  ProjectSettings/  docs/
```

Assemblies: `Nooni.Runtime` for gameplay code, `Nooni.Tests.*` for tests. Split further (Stealth/AI/Driving) once compile times matter.

## Design patterns

| Concern | Pattern | Notes |
|---|---|---|
| Character switching | **Possession + FSM** | `CatIcalWheelManager` has states FreeRoam, WheelOpen and Blending. Exactly one `PlayableCharacter` is possessed. |
| Per-character movement/abilities | **Hierarchical state machines** | Nooni: Locomotion, Crouch, Grapple, Vision. Bruce: Walk, BatNap. Semba: Run, Climb, Roar. Reuse `StateMachine`/`IState`. |
| Character data | **ScriptableObjects** | Speed, noise radius, ability cooldowns, and so on, tuned without touching code. |
| Input | **Reader + action maps** | `InputReader` toggles maps by mode (Gameplay, Wheel, Locked, Drive). Characters never read raw devices. |
| Cross-system events | **C# events / SO event channels** | e.g. `CharacterChanged`, `PlayerSpotted`, `StressChanged`. Keeps UI, audio and AI decoupled from characters. |
| Brother AI | **Behaviour tree or FSM** (Patrol, Suspicious, Investigate, Frozen) | Implement `IDistractable` (Semba's roar), `IFreezable` (Bruce's petting) and `ISpotter` (sightline). |
| Puzzle objects | **Small interfaces** | `IWeightActivated` (Bruce), `IHackable` (Nooni vision), `IGrappleAnchor`, `IClimbable` (Semba). Characters query interfaces, so each cat's role stays data-driven. |
| Stress | **Single component + events** | `StressMeter` raises thresholds; `GlassesSmudge` listens and requires `WipeGlasses` to clear. |
| Game flow | **Top-level GameStateMachine** | Boot, Hub, OnFoot, Driving, Paused, Cutscene. Swaps `InputReader` maps. |

## Character-switching rules

- One possessed character at a time; others are *parked* (input off, AI-idle, still physical so Bruce stays on his plate).
- `CanRelease` lets a character veto a switch (Nooni mid-grapple, Bruce mid Bat-Nap, Semba mid-roar).
- Camera: one Cinemachine vcam per character; only the possessed character's vcam is active, and the `CinemachineBrain` blends. Brain needs **Ignore Time Scale** on.
- Wheel slows time via `Time.timeScale` and scales `fixedDeltaTime`; all wheel timing uses unscaled time.
- Blending state locks input for the blend duration.

## Scene setup for the wheel (what the scripts expect)

1. `Managers` object with `InputReader` (assign `NooniControls`) and `CatIcalWheelManager`.
2. Three characters, each a `PlayableCharacter` subclass with its own `CameraRig` pointing at a child Cinemachine camera (start disabled).
3. Camera with `CinemachineBrain` (Ease In Out 0.6s, Ignore Time Scale).
4. Canvas with `CatWheelUI`: CanvasGroup, centre RectTransform and three slices (Image, portrait, TMP label). Radial fill 120 degrees each works well.
5. Enable **Active Input Handling = Input System Package (New)** in Player settings.

## Status

Scripts under `Scripts/` were written without a Unity editor available and have **not** been compiled or play-tested. Expect minor fix-ups on first import. `WheelMath` has EditMode tests.
