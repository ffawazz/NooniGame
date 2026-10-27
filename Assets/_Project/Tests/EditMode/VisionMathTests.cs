using NUnit.Framework;
using Nooni.Stealth;
using UnityEngine;

namespace Nooni.Tests
{
    public class VisionMathTests
    {
        static readonly Vector3 Eye = Vector3.zero;
        static readonly Vector3 Fwd = Vector3.forward;

        [Test]
        public void Point_ahead_and_in_range_is_seen()
        {
            Assert.IsTrue(VisionMath.IsInCone(Eye, Fwd, new Vector3(0f, 0f, 5f), 9f, 90f));
        }

        [Test]
        public void Point_inside_half_angle_is_seen()
        {
            Assert.IsTrue(VisionMath.IsInCone(Eye, Fwd, new Vector3(4f, 0f, 5f), 9f, 90f)); // ~38.7 degrees
        }

        [Test]
        public void Point_outside_half_angle_is_not_seen()
        {
            Assert.IsFalse(VisionMath.IsInCone(Eye, Fwd, new Vector3(5f, 0f, 4f), 9f, 90f)); // ~51.3 degrees
        }

        [Test]
        public void Point_behind_is_not_seen()
        {
            Assert.IsFalse(VisionMath.IsInCone(Eye, Fwd, new Vector3(0f, 0f, -2f), 9f, 90f));
        }

        [Test]
        public void Point_beyond_range_is_not_seen()
        {
            Assert.IsFalse(VisionMath.IsInCone(Eye, Fwd, new Vector3(0f, 0f, 10f), 9f, 90f));
        }

        [Test]
        public void Shrunken_range_hides_a_crouched_target()
        {
            // Same point; range scaled by 0.5 visibility (9 -> 4.5).
            Assert.IsFalse(VisionMath.IsInCone(Eye, Fwd, new Vector3(0f, 0f, 6f), 4.5f, 90f));
        }
    }
}
