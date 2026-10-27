using UnityEngine;

namespace Nooni.UI
{
    public static class WheelMath
    {
        /// <summary>
        /// Maps a pointer offset from the wheel centre (pixels) to a slice index, or -1 inside
        /// the dead zone. Slice 0 is centred at 12 o'clock and slices run clockwise.
        /// </summary>
        public static int SelectSlice(Vector2 offset, int sliceCount, float deadZone)
        {
            if (sliceCount <= 0 || offset.sqrMagnitude < deadZone * deadZone) return -1;

            // Clockwise degrees from "up", normalised to [0, 360).
            float angle = Mathf.Atan2(offset.x, offset.y) * Mathf.Rad2Deg;
            if (angle < 0f) angle += 360f;

            float size = 360f / sliceCount;
            return Mathf.FloorToInt((angle + size * 0.5f) % 360f / size);
        }
    }
}
