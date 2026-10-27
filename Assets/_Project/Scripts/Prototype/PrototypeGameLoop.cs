using Nooni.AI;
using Nooni.Characters;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Nooni.Prototype
{
    /// <summary>
    /// Greybox-only glue: win zone, lose-on-caught, auto-restart and a debug HUD (IMGUI).
    /// Delete once real UI and mission flow exist.
    /// The scene must be in Build Settings for the restart to work.
    /// </summary>
    public sealed class PrototypeGameLoop : MonoBehaviour
    {
        [SerializeField] NooniController nooni;
        [SerializeField] BrotherAI[] brothers;
        [SerializeField] Transform goal;
        [SerializeField] float goalRadius = 1.2f;
        [SerializeField] float restartDelay = 2.5f;

        bool _finished;
        string _message;
        float _restartAt;
        GUIStyle _bigStyle;

        void OnEnable()
        {
            foreach (var b in brothers) b.Caught += OnCaught;
        }

        void OnDisable()
        {
            foreach (var b in brothers) if (b) b.Caught -= OnCaught;
        }

        void Update()
        {
            if (_finished)
            {
                if (Time.unscaledTime >= _restartAt)
                    SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);
                return;
            }

            if (goal)
            {
                Vector3 d = nooni.transform.position - goal.position;
                d.y = 0f;
                if (d.magnitude <= goalRadius) Finish("MISSION COMPLETE\nSnack acquired. Nobody suspects a thing.");
            }
        }

        void OnCaught(BrotherAI brother) =>
            Finish($"SPOTTED BY {brother.name.ToUpperInvariant()}\nThis changes everything.");

        void Finish(string message)
        {
            if (_finished) return;
            _finished = true;
            _message = message;
            _restartAt = Time.unscaledTime + restartDelay;
            nooni.enabled = false;
        }

        void OnGUI()
        {
            float y = 12f;
            GUI.Label(new Rect(16f, y, 420f, 22f), "Nooni: " + nooni.StealthStatus);
            y += 24f;

            foreach (var b in brothers)
            {
                GUI.Label(new Rect(16f, y, 420f, 22f), $"{b.name}: {b.StateName}");
                DrawBar(new Rect(16f, y + 22f, 200f, 10f), b.Awareness);
                y += 40f;
            }

            GUI.Label(new Rect(16f, y, 520f, 22f), "WASD move | Mouse look | Ctrl/C crouch | Shift sprint | Space jump");

            if (!_finished) return;
            _bigStyle ??= new GUIStyle(GUI.skin.label) { fontSize = 36, alignment = TextAnchor.MiddleCenter };
            GUI.Label(new Rect(0f, 0f, Screen.width, Screen.height), _message, _bigStyle);
        }

        static void DrawBar(Rect r, float value)
        {
            Color previous = GUI.color;
            GUI.color = new Color(0f, 0f, 0f, 0.6f);
            GUI.DrawTexture(r, Texture2D.whiteTexture);
            GUI.color = Color.Lerp(Color.yellow, Color.red, value);
            GUI.DrawTexture(new Rect(r.x, r.y, r.width * value, r.height), Texture2D.whiteTexture);
            GUI.color = previous;
        }
    }
}
