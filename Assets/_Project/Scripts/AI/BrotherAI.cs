using System;
using Nooni.Core;
using Nooni.Stealth;
using UnityEngine;
using UnityEngine.AI;

namespace Nooni.AI
{
    /// <summary>
    /// Yasser / Ahmed. Patrols waypoints on a NavMesh with a vision cone.
    ///
    /// Detection: a target is perceived when it is inside the cone, within (viewDistance * its Visibility)
    /// and a raycast from the eyes reaches it unobstructed. While perceived, Awareness fills (faster when
    /// close); when not, it drains. Awareness reaching 1 = Caught.
    ///
    /// States: Patrol -> Suspicious (sees her, freezes and stares) -> Investigate (lost her, walks to last
    /// seen spot and looks around) -> back to Patrol. Caught is terminal.
    /// </summary>
    [RequireComponent(typeof(NavMeshAgent))]
    public sealed class BrotherAI : MonoBehaviour
    {
        [Header("Patrol")]
        [SerializeField] Transform[] patrolPoints;
        [SerializeField] float patrolSpeed = 1.8f;
        [SerializeField] float waitAtPoint = 1.5f;

        [Header("Vision")]
        [SerializeField] float viewDistance = 9f;
        [SerializeField, Tooltip("Total cone width in degrees.")] float viewAngle = 90f;
        [SerializeField, Tooltip("Eye position above the transform pivot (0.6 for a capsule pivoted at its centre).")]
        float eyeHeight = 0.6f;
        [SerializeField, Tooltip("What blocks line of sight. Trigger colliders are ignored.")]
        LayerMask obstructionMask = ~0;

        [Header("Detection")]
        [SerializeField, Tooltip("Seconds of continuous sight at base rate to fill awareness.")] float detectionSeconds = 1.2f;
        [SerializeField, Tooltip("Seconds for full awareness to drain when she is out of sight.")] float awarenessDecaySeconds = 3f;

        [Header("Investigate")]
        [SerializeField] float investigateSpeed = 3f;
        [SerializeField] float lookAroundSeconds = 2.5f;
        [SerializeField] float lookAroundDegreesPerSecond = 90f;
        [SerializeField, Tooltip("Degrees per second when turning to stare at a sighting.")] float stareTurnSpeed = 240f;

        [Header("Feedback")]
        [SerializeField, Tooltip("Optional renderer tinted by alert state (green / yellow / orange / red).")]
        Renderer indicator;

        readonly StateMachine _fsm = new StateMachine();
        NavMeshAgent _agent;
        IState _patrol, _suspicious, _investigate, _caught;
        Vector3 _lastKnownPosition;
        int _patrolIndex;
        string _stateName = "-";

        public float Awareness { get; private set; }
        public bool CanSeeTarget { get; private set; }
        public string StateName => _stateName;
        public Vector3 EyePosition => transform.position + Vector3.up * eyeHeight;

        /// <summary>Raised once when awareness fills.</summary>
        public event Action<BrotherAI> Caught;

        void Awake()
        {
            _agent = GetComponent<NavMeshAgent>();
            _patrol = new PatrolState(this);
            _suspicious = new SuspiciousState(this);
            _investigate = new InvestigateState(this);
            _caught = new CaughtState(this);
        }

        void Start() => _fsm.Set(_patrol);

        void Update()
        {
            if (_fsm.Current != _caught)
            {
                UpdatePerception();
                if (Awareness >= 1f) _fsm.Set(_caught);
            }
            _fsm.Tick();
        }

        // ---- Perception -----------------------------------------------------------------

        void UpdatePerception()
        {
            float best = 0f;
            Vector3 seenAt = default;

            var all = Detectables.All;
            for (int i = 0; i < all.Count; i++)
            {
                float strength = Perceive(all[i]);
                if (strength > best)
                {
                    best = strength;
                    seenAt = all[i].Root.position;
                }
            }

            CanSeeTarget = best > 0f;
            if (CanSeeTarget)
            {
                Awareness = Mathf.Min(1f, Awareness + best * Time.deltaTime / detectionSeconds);
                _lastKnownPosition = seenAt;
            }
            else
            {
                Awareness = Mathf.Max(0f, Awareness - Time.deltaTime / awarenessDecaySeconds);
            }
        }

        /// <summary>0 = not perceived, otherwise a fill-rate multiplier in [1, 2] (closer = faster).</summary>
        float Perceive(IDetectable target)
        {
            float visibility = target.Visibility;
            if (visibility <= 0f) return 0f;

            float range = viewDistance * visibility;
            Vector3 eye = EyePosition;
            Vector3 point = target.DetectionPoint;

            if (!VisionMath.IsInCone(eye, transform.forward, point, range, viewAngle)) return 0f;

            Vector3 to = point - eye;
            float dist = to.magnitude;
            if (dist < 0.01f) return 2f;

            if (Physics.Raycast(eye, to / dist, out RaycastHit hit, dist, obstructionMask, QueryTriggerInteraction.Ignore)
                && !hit.transform.IsChildOf(target.Root)
                && !hit.transform.IsChildOf(transform))
            {
                return 0f;
            }

            return 1f + (1f - dist / range);
        }

        // ---- Helpers --------------------------------------------------------------------

        void Announce(string stateName, Color color)
        {
            _stateName = stateName;
            if (indicator) indicator.material.color = color;
        }

        void FaceToward(Vector3 worldPoint, float degreesPerSecond)
        {
            Vector3 flat = worldPoint - transform.position;
            flat.y = 0f;
            if (flat.sqrMagnitude < 0.0001f) return;
            transform.rotation = Quaternion.RotateTowards(
                transform.rotation, Quaternion.LookRotation(flat), degreesPerSecond * Time.deltaTime);
        }

        bool HasArrived() => !_agent.pathPending && _agent.remainingDistance <= _agent.stoppingDistance + 0.05f;

        // ---- States ---------------------------------------------------------------------

        sealed class PatrolState : IState
        {
            readonly BrotherAI _b;
            float _waitTimer;
            bool _waiting;

            public PatrolState(BrotherAI b) => _b = b;

            public void Enter()
            {
                _b.Announce("Patrol", Color.green);
                _b._agent.isStopped = false;
                _b._agent.updateRotation = true;
                _b._agent.speed = _b.patrolSpeed;
                _waiting = false;
                GoToCurrent();
            }

            public void Tick()
            {
                if (_b.CanSeeTarget) { _b._fsm.Set(_b._suspicious); return; }
                if (_b.patrolPoints == null || _b.patrolPoints.Length == 0) return;

                if (_waiting)
                {
                    _waitTimer -= Time.deltaTime;
                    if (_waitTimer > 0f) return;
                    _waiting = false;
                    _b._patrolIndex = (_b._patrolIndex + 1) % _b.patrolPoints.Length;
                    GoToCurrent();
                }
                else if (_b.HasArrived())
                {
                    _waiting = true;
                    _waitTimer = _b.waitAtPoint;
                }
            }

            public void Exit() { }

            void GoToCurrent()
            {
                if (_b.patrolPoints == null || _b.patrolPoints.Length == 0) return;
                _b._agent.SetDestination(_b.patrolPoints[_b._patrolIndex].position);
            }
        }

        sealed class SuspiciousState : IState
        {
            readonly BrotherAI _b;
            public SuspiciousState(BrotherAI b) => _b = b;

            public void Enter()
            {
                _b.Announce("Suspicious", Color.yellow);
                _b._agent.isStopped = true;
            }

            public void Tick()
            {
                _b.FaceToward(_b._lastKnownPosition, _b.stareTurnSpeed);
                if (!_b.CanSeeTarget) _b._fsm.Set(_b._investigate);
            }

            public void Exit() { }
        }

        sealed class InvestigateState : IState
        {
            readonly BrotherAI _b;
            float _lookTimer;
            bool _arrived;

            public InvestigateState(BrotherAI b) => _b = b;

            public void Enter()
            {
                _b.Announce("Investigating", new Color(1f, 0.55f, 0f));
                _b._agent.isStopped = false;
                _b._agent.updateRotation = true;
                _b._agent.speed = _b.investigateSpeed;
                _b._agent.SetDestination(_b._lastKnownPosition);
                _lookTimer = _b.lookAroundSeconds;
                _arrived = false;
            }

            public void Tick()
            {
                if (_b.CanSeeTarget) { _b._fsm.Set(_b._suspicious); return; }

                if (!_arrived)
                {
                    if (_b.HasArrived())
                    {
                        _arrived = true;
                        _b._agent.updateRotation = false;
                    }
                    return;
                }

                _b.transform.Rotate(0f, _b.lookAroundDegreesPerSecond * Time.deltaTime, 0f);
                _lookTimer -= Time.deltaTime;
                if (_lookTimer <= 0f) _b._fsm.Set(_b._patrol);
            }

            public void Exit() => _b._agent.updateRotation = true;
        }

        sealed class CaughtState : IState
        {
            readonly BrotherAI _b;
            public CaughtState(BrotherAI b) => _b = b;

            public void Enter()
            {
                _b.Announce("CAUGHT", Color.red);
                _b._agent.isStopped = true;
                _b.Caught?.Invoke(_b);
            }

            public void Tick() { }
            public void Exit() { }
        }

        // ---- Debug ----------------------------------------------------------------------

        void OnDrawGizmos()
        {
            Vector3 eye = EyePosition;
            float half = viewAngle * 0.5f;
            Gizmos.color = Application.isPlaying ? Color.Lerp(Color.green, Color.red, Awareness) : Color.cyan;

            Vector3 left = Quaternion.Euler(0f, -half, 0f) * transform.forward * viewDistance;
            Vector3 right = Quaternion.Euler(0f, half, 0f) * transform.forward * viewDistance;
            Gizmos.DrawLine(eye, eye + left);
            Gizmos.DrawLine(eye, eye + right);

            const int segments = 16;
            Vector3 prev = eye + left;
            for (int i = 1; i <= segments; i++)
            {
                float angle = Mathf.Lerp(-half, half, i / (float)segments);
                Vector3 next = eye + Quaternion.Euler(0f, angle, 0f) * transform.forward * viewDistance;
                Gizmos.DrawLine(prev, next);
                prev = next;
            }
        }
    }
}
