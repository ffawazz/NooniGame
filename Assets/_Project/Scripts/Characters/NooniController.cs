using Nooni.Controls;
using Nooni.Stealth;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Nooni.Characters
{
    /// <summary>
    /// Nooni on foot: camera-relative movement, toggled crouch-stealth, mouse-look.
    /// Expects the transform pivot at her feet and a CharacterController on the same object.
    ///
    /// Stealth rules (the brother reads these through IDetectable):
    ///   standing                -> Visibility 1
    ///   crouched in the open    -> Visibility crouchedVisibility (shorter sight range)
    ///   crouched inside cover   -> Visibility 0 (hidden)
    /// </summary>
    [RequireComponent(typeof(CharacterController))]
    public sealed class NooniController : PlayableCharacter, IDetectable
    {
        [Header("Movement")]
        [SerializeField] float walkSpeed = 3.5f;
        [SerializeField] float sprintSpeed = 6f;
        [SerializeField] float crouchSpeed = 1.6f;
        [SerializeField, Tooltip("Degrees per second.")] float turnSpeed = 720f;
        [SerializeField] float jumpHeight = 0.9f;
        [SerializeField] float gravity = -20f;

        [Header("Crouch / stealth")]
        [SerializeField] float crouchHeight = 1f;
        [SerializeField] float crouchTransitionSpeed = 6f;
        [SerializeField, Range(0f, 1f), Tooltip("Visibility when crouched but NOT in a CoverVolume. 0 makes crouching alone hide her.")]
        float crouchedVisibility = 0.5f;
        [SerializeField, Tooltip("Visual capsule; squashed while crouching. Optional.")] Transform body;

        [Header("Camera")]
        [SerializeField, Tooltip("Unparented empty object the Cinemachine camera follows. Rotated by mouse-look.")]
        Transform cameraPivot;
        [SerializeField] float pivotHeight = 1.5f;
        [SerializeField] float lookSensitivity = 3f;
        [SerializeField] float minPitch = -25f;
        [SerializeField] float maxPitch = 60f;

        [Header("Standalone greybox testing")]
        [SerializeField, Tooltip("Self-possess on Start so no CatIcalWheelManager is needed in the scene.")]
        bool standalone = true;

        CharacterController _cc;
        float _standHeight, _feetY, _currentHeight;
        Vector3 _bodyScale, _bodyPos;
        float _verticalVelocity, _yaw, _pitch;

        public bool IsCrouching { get; private set; }

        public bool IsInCover => CoverVolume.IsCovered(transform.position + Vector3.up * 0.5f);

        public string StealthStatus =>
            !IsCrouching ? "STANDING (visible)" :
            IsInCover ? "HIDDEN (crouched in cover)" :
            "CROUCHED (exposed)";

        // IDetectable
        public Transform Root => transform;
        public Vector3 DetectionPoint => transform.position + Vector3.up * (_currentHeight * 0.6f);
        public float Visibility => !IsCrouching ? 1f : IsInCover ? 0f : crouchedVisibility;

        void Awake()
        {
            _cc = GetComponent<CharacterController>();
            _standHeight = _cc.height;
            _currentHeight = _standHeight;
            _feetY = _cc.center.y - _cc.height * 0.5f;
            if (body)
            {
                _bodyScale = body.localScale;
                _bodyPos = body.localPosition;
            }
            _yaw = transform.eulerAngles.y;
        }

        void OnEnable() => Detectables.Register(this);
        void OnDisable() => Detectables.Unregister(this);

        void Start()
        {
            if (!standalone) return;

            var reader = FindFirstObjectByType<InputReader>();
            if (reader == null)
            {
                Debug.LogError("NooniController (standalone) needs an InputReader in the scene.", this);
                return;
            }
            reader.SetMode(InputMode.Gameplay);
            Possess(reader);
            LockCursor();
        }

        void Update()
        {
            Vector2 moveInput = Vector2.zero;
            bool sprint = false, jump = false;

            if (IsControlled)
            {
                if (standalone && Cursor.lockState != CursorLockMode.Locked && Mouse.current != null
                    && Mouse.current.leftButton.wasPressedThisFrame)
                {
                    LockCursor();
                }

                HandleCrouchToggle();
                HandleLook();
                moveInput = Input.Move.ReadValue<Vector2>();
                sprint = Input.Sprint.IsPressed();
                jump = Input.Jump.WasPressedThisFrame();
            }

            Move(moveInput, sprint, jump);
            AnimateHeight();
        }

        void LateUpdate()
        {
            if (!cameraPivot) return;
            cameraPivot.position = transform.position + Vector3.up * pivotHeight;
            cameraPivot.rotation = Quaternion.Euler(_pitch, _yaw, 0f);
        }

        void HandleCrouchToggle()
        {
            if (!Input.Crouch.WasPressedThisFrame()) return;

            if (!IsCrouching) IsCrouching = true;
            else if (HasHeadroom()) IsCrouching = false;
        }

        // Don't stand up inside the sofa: sweep a sphere from the crouched head up to full height.
        bool HasHeadroom()
        {
            float r = _cc.radius * 0.9f;
            Vector3 origin = transform.position + Vector3.up * (_currentHeight - r);
            float distance = _standHeight - _currentHeight;
            return !Physics.SphereCast(origin, r, Vector3.up, out _, distance, ~0, QueryTriggerInteraction.Ignore);
        }

        void HandleLook()
        {
            if (Cursor.lockState != CursorLockMode.Locked) return;
            Vector2 look = Input.Look.ReadValue<Vector2>() * lookSensitivity;
            _yaw += look.x;
            _pitch = Mathf.Clamp(_pitch - look.y, minPitch, maxPitch);
        }

        void Move(Vector2 moveInput, bool sprint, bool jump)
        {
            Vector3 dir = Quaternion.Euler(0f, _yaw, 0f) * new Vector3(moveInput.x, 0f, moveInput.y);
            dir = Vector3.ClampMagnitude(dir, 1f);

            float speed = IsCrouching ? crouchSpeed : sprint ? sprintSpeed : walkSpeed;

            if (_cc.isGrounded)
            {
                if (_verticalVelocity < 0f) _verticalVelocity = -2f;
                if (jump && !IsCrouching) _verticalVelocity = Mathf.Sqrt(-2f * gravity * jumpHeight);
            }
            _verticalVelocity += gravity * Time.deltaTime;

            _cc.Move((dir * speed + Vector3.up * _verticalVelocity) * Time.deltaTime);

            if (dir.sqrMagnitude > 0.01f)
            {
                Quaternion target = Quaternion.LookRotation(dir);
                transform.rotation = Quaternion.RotateTowards(transform.rotation, target, turnSpeed * Time.deltaTime);
            }
        }

        // Resize the capsule with the feet pinned, and squash the visual to match.
        void AnimateHeight()
        {
            float target = IsCrouching ? crouchHeight : _standHeight;
            _currentHeight = Mathf.MoveTowards(_currentHeight, target, crouchTransitionSpeed * Time.deltaTime);

            _cc.height = _currentHeight;
            _cc.center = new Vector3(_cc.center.x, _feetY + _currentHeight * 0.5f, _cc.center.z);

            if (!body) return;
            float k = _currentHeight / _standHeight;
            body.localScale = new Vector3(_bodyScale.x, _bodyScale.y * k, _bodyScale.z);
            body.localPosition = new Vector3(_bodyPos.x, _bodyPos.y * k, _bodyPos.z);
        }

        static void LockCursor()
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;
        }
    }
}
