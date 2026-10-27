using System;
using Nooni.Core;
using Nooni.Controls;
using Nooni.UI;
using UnityEngine;

namespace Nooni.Characters
{
    /// <summary>
    /// The Cat-ical Wheel. Owns "who is possessed right now".
    ///
    /// Hold Tab: time slows, gameplay input is suspended, the wheel opens and the mouse picks a slice.
    /// Release Tab: commit the hovered slice (dead zone = cancel). A quick tap cycles to the next cat.
    /// 1/2/3: instant switch with no slow-mo.
    ///
    /// Flow: FreeRoam -> WheelOpen -> Blending -> FreeRoam. Blending locks input for the camera blend
    /// so a character never receives input while the camera is still travelling to them.
    /// </summary>
    public sealed class CatIcalWheelManager : MonoBehaviour
    {
        [Header("Scene references")]
        [SerializeField] InputReader input;
        [SerializeField] CatWheelUI wheelUI;
        [SerializeField, Tooltip("Index must match CharacterId: Nooni, Bruce, Semba.")]
        PlayableCharacter[] roster;
        [SerializeField] CharacterId startingCharacter = CharacterId.Nooni;

        [Header("Tuning")]
        [SerializeField, Range(0.01f, 1f)] float slowTimeScale = 0.1f;
        [SerializeField, Tooltip("Match the CinemachineBrain blend time.")]
        float blendSeconds = 0.6f;
        [SerializeField, Tooltip("Tab released faster than this (real seconds) counts as a tap.")]
        float tapSeconds = 0.18f;

        readonly StateMachine _fsm = new StateMachine();
        IState _freeRoam, _wheelOpen, _blending;
        float _baseFixedDelta;
        float _wheelOpenedAt;
        float _blendEndsAt;
        int _hovered = -1;

        public PlayableCharacter Current { get; private set; }

        /// <summary>(previous, next). Previous is null for the initial possession.</summary>
        public event Action<PlayableCharacter, PlayableCharacter> CharacterChanged;
        /// <summary>Fired when the wheel is refused because the current character cannot be released.</summary>
        public event Action<PlayableCharacter> SwitchDenied;

        void Awake()
        {
            _baseFixedDelta = Time.fixedDeltaTime;
            _freeRoam = new FreeRoamState(this);
            _wheelOpen = new WheelOpenState(this);
            _blending = new BlendingState(this);
        }

        void OnEnable()
        {
            input.WheelPressed += OnWheelPressed;
            input.WheelReleased += OnWheelReleased;
            input.QuickSwitch += OnQuickSwitch;
        }

        void OnDisable()
        {
            input.WheelPressed -= OnWheelPressed;
            input.WheelReleased -= OnWheelReleased;
            input.QuickSwitch -= OnQuickSwitch;
            SetTimeScale(1f);
        }

        void Start()
        {
            Possess(roster[(int)startingCharacter]);
            _fsm.Set(_freeRoam);
        }

        void Update() => _fsm.Tick();

        /// <summary>Entry point for scripted switches (cutscenes, puzzle triggers). Respects CanRelease.</summary>
        public bool RequestSwitch(CharacterId target)
        {
            if (_fsm.Current != _freeRoam || Current.Id == target) return false;
            if (!Current.CanRelease) { SwitchDenied?.Invoke(Current); return false; }
            BeginSwitch(roster[(int)target]);
            return true;
        }

        // ---- Input handlers -------------------------------------------------------------

        void OnWheelPressed()
        {
            if (_fsm.Current != _freeRoam) return;
            if (!Current.CanRelease) { SwitchDenied?.Invoke(Current); return; }
            _fsm.Set(_wheelOpen);
        }

        void OnWheelReleased()
        {
            if (_fsm.Current != _wheelOpen) return;

            int pick = _hovered;
            bool tapped = Time.unscaledTime - _wheelOpenedAt < tapSeconds;
            if (pick < 0 && tapped) pick = ((int)Current.Id + 1) % roster.Length;

            if (pick >= 0 && pick != (int)Current.Id) BeginSwitch(roster[pick]);
            else _fsm.Set(_freeRoam);
        }

        void OnQuickSwitch(int index)
        {
            if (index < 0 || index >= roster.Length) return;
            RequestSwitch(roster[index].Id);
        }

        // ---- Switching ------------------------------------------------------------------

        void BeginSwitch(PlayableCharacter next)
        {
            PlayableCharacter previous = Current;

            // Activate the new camera before deactivating the old one so Cinemachine always has a
            // live camera to blend to; otherwise the brain would cut instead of blend.
            Possess(next);
            previous.Release();

            CharacterChanged?.Invoke(previous, next);
            _fsm.Set(_blending);
        }

        void Possess(PlayableCharacter character)
        {
            Current = character;
            character.Possess(input);
        }

        void SetTimeScale(float scale)
        {
            Time.timeScale = scale;
            Time.fixedDeltaTime = _baseFixedDelta * scale;
        }

        // ---- States ---------------------------------------------------------------------

        sealed class FreeRoamState : IState
        {
            readonly CatIcalWheelManager _m;
            public FreeRoamState(CatIcalWheelManager m) => _m = m;

            public void Enter()
            {
                _m.SetTimeScale(1f);
                _m.input.SetMode(InputMode.Gameplay);
                Cursor.lockState = CursorLockMode.Locked;
                Cursor.visible = false;
            }

            public void Tick() { }
            public void Exit() { }
        }

        sealed class WheelOpenState : IState
        {
            readonly CatIcalWheelManager _m;
            public WheelOpenState(CatIcalWheelManager m) => _m = m;

            public void Enter()
            {
                _m._wheelOpenedAt = Time.unscaledTime;
                _m._hovered = -1;
                _m.SetTimeScale(_m.slowTimeScale);
                _m.input.SetMode(InputMode.Wheel);
                Cursor.lockState = CursorLockMode.None;
                Cursor.visible = true;
                _m.wheelUI.Show(_m.roster, _m.Current.Id);
            }

            public void Tick()
            {
                _m._hovered = _m.wheelUI.UpdateSelection(_m.input.Point.ReadValue<Vector2>());
            }

            public void Exit()
            {
                _m.wheelUI.Hide();
                _m.SetTimeScale(1f);
            }
        }

        sealed class BlendingState : IState
        {
            readonly CatIcalWheelManager _m;
            public BlendingState(CatIcalWheelManager m) => _m = m;

            public void Enter()
            {
                _m.input.SetMode(InputMode.Locked);
                Cursor.lockState = CursorLockMode.Locked;
                Cursor.visible = false;
                _m._blendEndsAt = Time.unscaledTime + _m.blendSeconds;
            }

            public void Tick()
            {
                if (Time.unscaledTime >= _m._blendEndsAt) _m._fsm.Set(_m._freeRoam);
            }

            public void Exit() { }
        }
    }
}
