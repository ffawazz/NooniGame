using System.Collections.Generic;
using Nooni.Characters;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace Nooni.UI
{
    /// <summary>
    /// The radial Cat-ical Wheel. Purely presentational: it reports which slice the pointer is
    /// over and leaves the decision to CatIcalWheelManager.
    /// </summary>
    public sealed class CatWheelUI : MonoBehaviour
    {
        [System.Serializable]
        public sealed class Slice
        {
            public Image background;
            public Image portrait;
            public TMP_Text label;
        }

        [SerializeField] CanvasGroup group;
        [SerializeField] RectTransform center;
        [SerializeField] Slice[] slices;
        [SerializeField, Tooltip("Pixels from centre in which nothing is selected (cancel zone).")]
        float deadZone = 60f;
        [SerializeField] Color normalColor = new Color(0.1f, 0.1f, 0.12f, 0.75f);
        [SerializeField] Color hoverColor = new Color(0.95f, 0.8f, 0.2f, 0.95f);
        [SerializeField] Color currentColor = new Color(0.3f, 0.6f, 1f, 0.9f);

        CharacterId _current;
        int _hovered = -1;

        void Awake() => SetVisible(false);

        public void Show(IReadOnlyList<PlayableCharacter> roster, CharacterId current)
        {
            _current = current;
            _hovered = -1;
            for (int i = 0; i < slices.Length; i++)
            {
                bool has = i < roster.Count;
                slices[i].background.gameObject.SetActive(has);
                if (!has) continue;
                slices[i].portrait.sprite = roster[i].Portrait;
                slices[i].label.text = roster[i].DisplayName;
            }
            Refresh();
            SetVisible(true);
        }

        public void Hide() => SetVisible(false);

        /// <summary>Returns the hovered slice index, or -1 in the dead zone.</summary>
        public int UpdateSelection(Vector2 pointerScreenPosition)
        {
            Vector2 c = RectTransformUtility.WorldToScreenPoint(null, center.position);
            int index = WheelMath.SelectSlice(pointerScreenPosition - c, slices.Length, deadZone);
            if (index != _hovered)
            {
                _hovered = index;
                Refresh();
            }
            return _hovered;
        }

        void Refresh()
        {
            for (int i = 0; i < slices.Length; i++)
            {
                slices[i].background.color =
                    i == _hovered ? hoverColor :
                    i == (int)_current ? currentColor : normalColor;
            }
        }

        void SetVisible(bool visible)
        {
            group.alpha = visible ? 1f : 0f;
            group.blocksRaycasts = visible;
            group.interactable = visible;
        }
    }
}
