using NUnit.Framework;
using Nooni.UI;
using UnityEngine;

namespace Nooni.Tests
{
    public class WheelMathTests
    {
        const float Dead = 50f;

        [TestCase(0f, 100f, 0)]     // up        -> Nooni
        [TestCase(87f, -50f, 1)]    // lower-right -> Bruce
        [TestCase(-87f, -50f, 2)]   // lower-left  -> Semba
        [TestCase(30f, 100f, 0)]    // still inside Nooni's 120-degree slice
        public void Three_slice_wheel_selects_expected_slice(float x, float y, int expected)
        {
            Assert.AreEqual(expected, WheelMath.SelectSlice(new Vector2(x, y), 3, Dead));
        }

        [Test]
        public void Inside_dead_zone_selects_nothing()
        {
            Assert.AreEqual(-1, WheelMath.SelectSlice(new Vector2(10f, 10f), 3, Dead));
        }
    }
}
