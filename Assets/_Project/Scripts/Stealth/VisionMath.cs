using UnityEngine;

namespace Nooni.Stealth
{
    public static class VisionMath
    {
        /// <summary>True when <paramref name="point"/> is within range and inside the cone of total width fullAngleDegrees.</summary>
        public static bool IsInCone(Vector3 eye, Vector3 forward, Vector3 point, float range, float fullAngleDegrees)
        {
            Vector3 to = point - eye;
            float sqr = to.sqrMagnitude;
            if (sqr > range * range) return false;
            if (sqr < 1e-6f) return true;
            return Vector3.Angle(forward, to) <= fullAngleDegrees * 0.5f;
        }
    }
}
