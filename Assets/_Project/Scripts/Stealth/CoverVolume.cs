using System.Collections.Generic;
using UnityEngine;

namespace Nooni.Stealth
{
    /// <summary>
    /// Trigger volume marking "hiding space" (behind the sofa, under the table). A crouched character
    /// inside one is invisible. Uses a registry and ClosestPoint rather than physics trigger callbacks,
    /// so it works regardless of Rigidbody/CharacterController quirks.
    /// </summary>
    [RequireComponent(typeof(Collider))]
    public sealed class CoverVolume : MonoBehaviour
    {
        static readonly List<CoverVolume> _all = new List<CoverVolume>();

        Collider _collider;

        void Awake()
        {
            _collider = GetComponent<Collider>();
            _collider.isTrigger = true;
        }

        void OnEnable() => _all.Add(this);
        void OnDisable() => _all.Remove(this);

        public static bool IsCovered(Vector3 point)
        {
            for (int i = 0; i < _all.Count; i++)
            {
                Vector3 closest = _all[i]._collider.ClosestPoint(point);
                if ((closest - point).sqrMagnitude < 1e-6f) return true;
            }
            return false;
        }
    }
}
