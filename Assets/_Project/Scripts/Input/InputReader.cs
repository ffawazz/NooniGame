using System;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Nooni.Controls
{
    public enum InputMode
    {
        Gameplay,
        Wheel,
        Locked,
    }

    /// <summary>
    /// Single owner of the InputActionAsset. Characters read actions from here and never touch
    /// the asset directly, so switching characters never rebinds or double-enables anything.
    /// The Global map (wheel, quick-switch, pause) stays enabled in every mode.
    /// </summary>
    public sealed class InputReader : MonoBehaviour
    {
        [SerializeField] InputActionAsset asset;

        InputActionMap _global, _gameplay, _wheel, _drive;

        public InputMode Mode { get; private set; } = InputMode.Locked;

        // Global
        public event Action WheelPressed;
        public event Action WheelReleased;
        /// <summary>Zero-based roster index (key 1 = 0).</summary>
        public event Action<int> QuickSwitch;
        public event Action PausePressed;

        // Gameplay
        public InputAction Move { get; private set; }
        public InputAction Look { get; private set; }
        public InputAction Jump { get; private set; }
        public InputAction Sprint { get; private set; }
        public InputAction Crouch { get; private set; }
        public InputAction Interact { get; private set; }
        public InputAction Grapple { get; private set; }
        public InputAction DetectiveVision { get; private set; }
        public InputAction CharacterAbility { get; private set; }
        public InputAction WipeGlasses { get; private set; }

        // Wheel
        public InputAction Point { get; private set; }

        // Drive
        public InputAction Steer { get; private set; }
        public InputAction Throttle { get; private set; }
        public InputAction Brake { get; private set; }
        public InputAction Handbrake { get; private set; }
        public InputAction HackLight { get; private set; }
        public InputAction Horn { get; private set; }

        void Awake()
        {
            _global = asset.FindActionMap("Global", true);
            _gameplay = asset.FindActionMap("Gameplay", true);
            _wheel = asset.FindActionMap("Wheel", true);
            _drive = asset.FindActionMap("Drive", true);

            Move = _gameplay.FindAction("Move", true);
            Look = _gameplay.FindAction("Look", true);
            Jump = _gameplay.FindAction("Jump", true);
            Sprint = _gameplay.FindAction("Sprint", true);
            Crouch = _gameplay.FindAction("Crouch", true);
            Interact = _gameplay.FindAction("Interact", true);
            Grapple = _gameplay.FindAction("Grapple", true);
            DetectiveVision = _gameplay.FindAction("DetectiveVision", true);
            CharacterAbility = _gameplay.FindAction("CharacterAbility", true);
            WipeGlasses = _gameplay.FindAction("WipeGlasses", true);

            Point = _wheel.FindAction("Point", true);

            Steer = _drive.FindAction("Steer", true);
            Throttle = _drive.FindAction("Throttle", true);
            Brake = _drive.FindAction("Brake", true);
            Handbrake = _drive.FindAction("Handbrake", true);
            HackLight = _drive.FindAction("HackLight", true);
            Horn = _drive.FindAction("Horn", true);
        }

        void OnEnable()
        {
            _global.FindAction("OpenWheel", true).started += OnWheelStarted;
            _global.FindAction("OpenWheel", true).canceled += OnWheelCanceled;
            _global.FindAction("QuickSwitch1", true).performed += OnQuick1;
            _global.FindAction("QuickSwitch2", true).performed += OnQuick2;
            _global.FindAction("QuickSwitch3", true).performed += OnQuick3;
            _global.FindAction("Pause", true).performed += OnPause;
            _global.Enable();
            SetMode(Mode);
        }

        void OnDisable()
        {
            _global.FindAction("OpenWheel", true).started -= OnWheelStarted;
            _global.FindAction("OpenWheel", true).canceled -= OnWheelCanceled;
            _global.FindAction("QuickSwitch1", true).performed -= OnQuick1;
            _global.FindAction("QuickSwitch2", true).performed -= OnQuick2;
            _global.FindAction("QuickSwitch3", true).performed -= OnQuick3;
            _global.FindAction("Pause", true).performed -= OnPause;
            _global.Disable();
            _gameplay.Disable();
            _wheel.Disable();
            _drive.Disable();
        }

        public void SetMode(InputMode mode)
        {
            Mode = mode;
            if (mode == InputMode.Gameplay) _gameplay.Enable(); else _gameplay.Disable();
            if (mode == InputMode.Wheel) _wheel.Enable(); else _wheel.Disable();
        }

        /// <summary>Driving segments swap the on-foot map for the Drive map.</summary>
        public void SetDrivingEnabled(bool enabled)
        {
            if (enabled) { _gameplay.Disable(); _drive.Enable(); }
            else { _drive.Disable(); SetMode(Mode); }
        }

        void OnWheelStarted(InputAction.CallbackContext _) => WheelPressed?.Invoke();
        void OnWheelCanceled(InputAction.CallbackContext _) => WheelReleased?.Invoke();
        void OnQuick1(InputAction.CallbackContext _) => QuickSwitch?.Invoke(0);
        void OnQuick2(InputAction.CallbackContext _) => QuickSwitch?.Invoke(1);
        void OnQuick3(InputAction.CallbackContext _) => QuickSwitch?.Invoke(2);
        void OnPause(InputAction.CallbackContext _) => PausePressed?.Invoke();
    }
}
