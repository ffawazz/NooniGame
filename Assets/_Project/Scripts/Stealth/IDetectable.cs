using System.Collections.Generic;
using UnityEngine;

namespace Nooni.Stealth
{
    /// <summary>Anything a brother's eyes can pick up. Implemented by Nooni; cats can opt in later.</summary>
    public interface IDetectable
    {
        Transform Root { get; }
        /// <summary>World point the vision ray is aimed at (roughly chest height).</summary>
        Vector3 DetectionPoint { get; }
        /// <summary>0 = invisible, 1 = fully exposed. Scales the brother's effective view distance.</summary>
        float Visibility { get; }
    }

    /// <summary>Registry so AI never needs a hard reference to a specific character.</summary>
    public static class Detectables
    {
        static readonly List<IDetectable> _all = new List<IDetectable>();

        public static IReadOnlyList<IDetectable> All => _all;

        public static void Register(IDetectable d)
        {
            if (!_all.Contains(d)) _all.Add(d);
        }

        public static void Unregister(IDetectable d) => _all.Remove(d);
    }
}
