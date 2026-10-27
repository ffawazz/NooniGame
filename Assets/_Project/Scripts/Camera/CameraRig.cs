using UnityEngine;

namespace Nooni.CameraSystem
{
    /// <summary>
    /// One Cinemachine virtual camera per character, toggled by activating its GameObject.
    /// Only the active vcam is live, so the CinemachineBrain blends between characters with
    /// no dependency on a particular Cinemachine version's priority API.
    ///
    /// Brain setup: Default Blend = Ease In Out ~0.6s, and tick "Ignore Time Scale" so the
    /// blend plays at full speed while the Cat-ical Wheel has time slowed.
    /// </summary>
    public sealed class CameraRig : MonoBehaviour
    {
        [SerializeField] GameObject virtualCamera;

        public bool IsLive => virtualCamera != null && virtualCamera.activeSelf;

        public void Activate() => virtualCamera.SetActive(true);
        public void Deactivate() => virtualCamera.SetActive(false);
    }
}
