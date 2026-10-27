using Nooni.CameraSystem;
using Nooni.Controls;
using UnityEngine;

namespace Nooni.Characters
{
    /// <summary>
    /// Base for Nooni, Bruce and Semba. A character only reads input while possessed;
    /// when released it must stop moving and cancel anything in flight.
    /// Subclasses own their own movement/ability state machines.
    /// </summary>
    public abstract class PlayableCharacter : MonoBehaviour
    {
        [SerializeField] CharacterId id;
        [SerializeField] string displayName;
        [SerializeField] Sprite portrait;
        [SerializeField] CameraRig cameraRig;

        public CharacterId Id => id;
        public string DisplayName => displayName;
        public Sprite Portrait => portrait;
        public bool IsControlled { get; private set; }
        protected InputReader Input { get; private set; }

        /// <summary>
        /// Return false while the character is committed to something that must not be
        /// interrupted: Nooni mid-grapple, Bruce mid Bat-Nap, Semba mid-roar.
        /// </summary>
        public virtual bool CanRelease => true;

        public void Possess(InputReader input)
        {
            Input = input;
            IsControlled = true;
            if (cameraRig) cameraRig.Activate();
            OnPossessed();
        }

        public void Release()
        {
            IsControlled = false;
            OnReleased();
            if (cameraRig) cameraRig.Deactivate();
            Input = null;
        }

        protected virtual void OnPossessed() { }
        protected virtual void OnReleased() { }
    }
}
