using System;
using System.IO;
using System.Reflection;
using Nooni.AI;
using Nooni.Characters;
using Nooni.Controls;
using Nooni.Prototype;
using Nooni.Stealth;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.AI;
using UnityEngine.InputSystem;
using UnityEngine.Rendering;

namespace Nooni.EditorTools
{
    /// <summary>
    /// Nooni > Build Greybox Room: builds the whole stealth test room described in docs/SCENE_SETUP.md.
    /// Cinemachine and AI Navigation are reached by reflection / SerializedObject so a version difference
    /// there degrades to a console warning instead of a compile error that would block Play mode.
    /// </summary>
    public static class GreyboxRoomBuilder
    {
        const string ScenePath = "Assets/_Project/Scenes/GreyboxRoom.unity";
        const string MaterialsDir = "Assets/_Project/Art/Materials";
        const string InputAssetPath = "Assets/_Project/Input/NooniControls.inputactions";

        [MenuItem("Nooni/Build Greybox Room")]
        static void Build()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode)
            {
                EditorUtility.DisplayDialog("Nooni", "Stop Play mode first.", "OK");
                return;
            }

            var input = AssetDatabase.LoadAssetAtPath<InputActionAsset>(InputAssetPath);
            if (input == null)
            {
                EditorUtility.DisplayDialog("Nooni", "Couldn't find " + InputAssetPath, "OK");
                return;
            }

            if (!EditorUtility.DisplayDialog("Build Greybox Room",
                    "This creates (and overwrites) " + ScenePath + " and replaces the open scene.", "Build", "Cancel"))
                return;
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;

            Directory.CreateDirectory("Assets/_Project/Scenes");
            Directory.CreateDirectory(MaterialsDir);

            var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);

            // ---- Materials ----
            var floorMat = Mat("Grey_Floor", new Color(0.55f, 0.55f, 0.58f));
            var wallMat = Mat("Grey_Wall", new Color(0.8f, 0.78f, 0.72f));
            var sofaMat = Mat("Grey_Sofa", new Color(0.45f, 0.3f, 0.6f));
            var counterMat = Mat("Grey_Counter", new Color(0.6f, 0.45f, 0.3f));
            var tableMat = Mat("Grey_Table", new Color(0.35f, 0.25f, 0.2f));
            var nooniMat = Mat("Grey_Nooni", new Color(0.2f, 0.45f, 0.9f));
            var yasserMat = Mat("Grey_Yasser", new Color(0.85f, 0.35f, 0.3f));
            var lampMat = Mat("Grey_Lamp", Color.white);
            var coverMat = Mat("Grey_CoverZone", new Color(0.2f, 0.6f, 1f, 0.18f), transparent: true);
            var goalMat = Mat("Grey_Goal", new Color(0.2f, 0.9f, 0.3f, 0.8f), transparent: true);

            // ---- Level (the only thing baked into the NavMesh) ----
            var level = new GameObject("Level").transform;
            Cube("Floor", level, new Vector3(0, -0.05f, 0), new Vector3(12, 0.1f, 10), floorMat);
            Cube("Wall_N", level, new Vector3(0, 1.25f, 5.05f), new Vector3(12.2f, 2.5f, 0.1f), wallMat);
            Cube("Wall_S", level, new Vector3(0, 1.25f, -5.05f), new Vector3(12.2f, 2.5f, 0.1f), wallMat);
            Cube("Wall_E", level, new Vector3(6.05f, 1.25f, 0), new Vector3(0.1f, 2.5f, 10), wallMat);
            Cube("Wall_W", level, new Vector3(-6.05f, 1.25f, 0), new Vector3(0.1f, 2.5f, 10), wallMat);
            Cube("Sofa", level, new Vector3(-2, 0.4f, -3), new Vector3(3, 0.8f, 1), sofaMat);
            Cube("Counter", level, new Vector3(4.5f, 0.5f, -1), new Vector3(1, 1, 3), counterMat);
            Cube("CoffeeTable", level, new Vector3(-0.5f, 0.25f, 0), new Vector3(1.6f, 0.5f, 0.8f), tableMat);

            // ---- Cover zones ----
            var cover = new GameObject("Cover").transform;
            CoverZone("CoverZone_Sofa", cover, new Vector3(-2, 0.9f, -3), new Vector3(3.6f, 1.8f, 2.4f), coverMat);
            CoverZone("CoverZone_Counter", cover, new Vector3(4.5f, 0.9f, -1), new Vector3(2.2f, 1.8f, 3.6f), coverMat);

            // ---- Nooni ----
            var nooni = new GameObject("Nooni");
            nooni.transform.position = new Vector3(-5, 0, -4);
            nooni.transform.rotation = Quaternion.Euler(0, 45, 0);
            var cc = nooni.AddComponent<CharacterController>();
            cc.center = new Vector3(0, 0.9f, 0);
            cc.height = 1.8f;
            cc.radius = 0.35f;
            cc.stepOffset = 0.3f;

            var body = GameObject.CreatePrimitive(PrimitiveType.Capsule);
            body.name = "Body";
            body.transform.SetParent(nooni.transform, false);
            body.transform.localPosition = new Vector3(0, 0.9f, 0);
            body.transform.localScale = new Vector3(0.7f, 0.9f, 0.7f);
            body.GetComponent<Renderer>().sharedMaterial = nooniMat;
            UnityEngine.Object.DestroyImmediate(body.GetComponent<Collider>());

            var nooniFace = Cube("Face", body.transform, new Vector3(0, 0.4f, 0.5f), new Vector3(0.4f, 0.25f, 0.4f), lampMat, collider: false);

            var pivot = new GameObject("CameraPivot");
            pivot.transform.position = nooni.transform.position + Vector3.up * 1.5f;

            var nooniCtrl = nooni.AddComponent<NooniController>();
            Set(nooniCtrl, so =>
            {
                so.FindProperty("displayName").stringValue = "Nooni";
                so.FindProperty("body").objectReferenceValue = body.transform;
                so.FindProperty("cameraPivot").objectReferenceValue = pivot.transform;
            });

            // ---- Yasser ----
            var yasser = GameObject.CreatePrimitive(PrimitiveType.Capsule);
            yasser.name = "Yasser";
            yasser.transform.position = new Vector3(-3, 1, 1.5f);
            yasser.transform.rotation = Quaternion.Euler(0, 90, 0);
            yasser.GetComponent<Renderer>().sharedMaterial = yasserMat;

            var agent = yasser.AddComponent<NavMeshAgent>();
            agent.baseOffset = 1f;
            agent.radius = 0.5f;
            agent.height = 2f;
            agent.speed = 1.8f;
            agent.stoppingDistance = 0.3f;

            var yasserFace = Cube("Face", yasser.transform, new Vector3(0, 0.5f, 0.5f), new Vector3(0.3f, 0.2f, 0.3f), lampMat, collider: false);

            var points = new GameObject("PatrolPoints").transform;
            Vector3[] route =
            {
                new Vector3(-3, 0, 1.5f), new Vector3(2, 0, 1.5f),
                new Vector3(2, 0, -1.5f), new Vector3(-3, 0, -1.5f),
            };
            var waypoints = new Transform[route.Length];
            for (int i = 0; i < route.Length; i++)
            {
                var p = new GameObject("P" + (i + 1)).transform;
                p.SetParent(points, false);
                p.position = route[i];
                waypoints[i] = p;
            }

            var brother = yasser.AddComponent<BrotherAI>();
            Set(brother, so =>
            {
                var arr = so.FindProperty("patrolPoints");
                arr.arraySize = waypoints.Length;
                for (int i = 0; i < waypoints.Length; i++)
                    arr.GetArrayElementAtIndex(i).objectReferenceValue = waypoints[i];
                so.FindProperty("indicator").objectReferenceValue = yasserFace.GetComponent<Renderer>();
            });

            // ---- Camera (Cinemachine, via reflection) ----
            BuildCamera(pivot.transform);

            // ---- Exit + managers ----
            var exit = Cube("ExitPad", null, new Vector3(5, 0.05f, 4), new Vector3(1.5f, 0.1f, 1.5f), goalMat, collider: false);

            var managers = new GameObject("Managers");
            var reader = managers.AddComponent<InputReader>();
            Set(reader, so => so.FindProperty("asset").objectReferenceValue = input);

            var loop = managers.AddComponent<PrototypeGameLoop>();
            Set(loop, so =>
            {
                so.FindProperty("nooni").objectReferenceValue = nooniCtrl;
                var arr = so.FindProperty("brothers");
                arr.arraySize = 1;
                arr.GetArrayElementAtIndex(0).objectReferenceValue = brother;
                so.FindProperty("goal").objectReferenceValue = exit.transform;
            });

            // ---- Save, register in Build Settings, bake ----
            EditorSceneManager.SaveScene(scene, ScenePath);
            RegisterInBuildSettings(ScenePath);

            var surface = AddByName(level.gameObject, "Unity.AI.Navigation.NavMeshSurface");
            if (surface == null)
            {
                Debug.LogWarning("[Nooni] AI Navigation package not found; Yasser won't walk. Install 'AI Navigation' in Package Manager, then add NavMesh Surface to Level and Bake.");
                Finish(scene, false);
                return;
            }

            var surfaceSo = new SerializedObject(surface);
            var collect = surfaceSo.FindProperty("m_CollectObjects");
            if (collect != null)
            {
                collect.enumValueIndex = 2; // Children: only bake Level, not characters or cover zones
                surfaceSo.ApplyModifiedPropertiesWithoutUndo();
            }
            else
            {
                Debug.LogWarning("[Nooni] Couldn't set NavMesh Surface to 'Current Object Hierarchy'. Set it manually on Level and Bake.");
            }

            Selection.activeGameObject = yasser;
            BakeNavMesh(surface, () => Finish(scene, true));
        }

        // ---- Building blocks ---------------------------------------------------------------

        static GameObject Cube(string name, Transform parent, Vector3 pos, Vector3 scale, Material mat, bool collider = true)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            if (parent) go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            if (!collider) UnityEngine.Object.DestroyImmediate(go.GetComponent<Collider>());
            return go;
        }

        static void CoverZone(string name, Transform parent, Vector3 pos, Vector3 scale, Material mat)
        {
            var go = Cube(name, parent, pos, scale, mat);
            go.GetComponent<Collider>().isTrigger = true;
            go.AddComponent<CoverVolume>();
        }

        static void Set(UnityEngine.Object target, Action<SerializedObject> apply)
        {
            var so = new SerializedObject(target);
            apply(so);
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        static Material Mat(string name, Color color, bool transparent = false)
        {
            string path = MaterialsDir + "/" + name + ".mat";
            var m = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (m == null)
            {
                Shader shader = transparent
                    ? Shader.Find("Sprites/Default")
                    : Shader.Find(GraphicsSettings.currentRenderPipeline != null ? "Universal Render Pipeline/Lit" : "Standard");
                m = new Material(shader != null ? shader : Shader.Find("Standard"));
                AssetDatabase.CreateAsset(m, path);
            }
            m.color = color;
            EditorUtility.SetDirty(m);
            return m;
        }

        static void RegisterInBuildSettings(string path)
        {
            var scenes = EditorBuildSettings.scenes;
            foreach (var s in scenes) if (s.path == path) return;

            var next = new EditorBuildSettingsScene[scenes.Length + 1];
            Array.Copy(scenes, next, scenes.Length);
            next[scenes.Length] = new EditorBuildSettingsScene(path, true);
            EditorBuildSettings.scenes = next;
        }

        // ---- Cinemachine / NavMesh (reflection) --------------------------------------------

        static Type FindType(string fullName)
        {
            foreach (var asm in AppDomain.CurrentDomain.GetAssemblies())
            {
                var t = asm.GetType(fullName, false);
                if (t != null) return t;
            }
            return null;
        }

        static Component AddByName(GameObject go, string typeName)
        {
            var t = FindType(typeName);
            return t == null ? null : go.AddComponent(t);
        }

        static void SetProp(Component c, string path, Action<SerializedProperty> apply)
        {
            if (c == null) return;
            var so = new SerializedObject(c);
            var p = so.FindProperty(path);
            if (p == null) { Debug.LogWarning($"[Nooni] {c.GetType().Name} has no property '{path}'; adjust it by hand."); return; }
            apply(p);
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        static void BuildCamera(Transform pivot)
        {
            var cam = Camera.main;
            if (cam == null)
            {
                Debug.LogWarning("[Nooni] No Main Camera found.");
                return;
            }

            var brain = AddByName(cam.gameObject, "Unity.Cinemachine.CinemachineBrain");
            var vcamGo = new GameObject("CM Player Camera");
            var vcam = AddByName(vcamGo, "Unity.Cinemachine.CinemachineCamera");

            if (brain == null || vcam == null)
            {
                UnityEngine.Object.DestroyImmediate(vcamGo);
                Debug.LogWarning("[Nooni] Cinemachine 3 not found; the camera won't follow Nooni. Install 'Cinemachine' in Package Manager, then follow step 4 of docs/SCENE_SETUP.md.");
                return;
            }

            SetProp(vcam, "Target.TrackingTarget", p => p.objectReferenceValue = pivot);

            var tpf = AddByName(vcamGo, "Unity.Cinemachine.CinemachineThirdPersonFollow");
            AddByName(vcamGo, "Unity.Cinemachine.CinemachineRotateWithFollowTarget");
            SetProp(tpf, "CameraDistance", p => p.floatValue = 4f);
            SetProp(tpf, "ShoulderOffset", p => p.vector3Value = new Vector3(0.5f, 0f, 0f));
            SetProp(tpf, "VerticalArmLength", p => p.floatValue = 0.3f);
            if (tpf == null)
                Debug.LogWarning("[Nooni] CinemachineThirdPersonFollow not found; set Position Control = Third Person Follow on 'CM Player Camera' by hand.");
        }

        const BindingFlags AnyMember = BindingFlags.Public | BindingFlags.NonPublic |
                                       BindingFlags.Instance | BindingFlags.Static | BindingFlags.FlattenHierarchy;

        static void BakeNavMesh(Component surface, Action done)
        {
            var mgrType = FindType("Unity.AI.Navigation.Editor.NavMeshAssetManager");
            object manager = mgrType?.GetProperty("instance", AnyMember)?.GetValue(null);
            var start = mgrType?.GetMethod("StartBakingSurfaces", AnyMember, null, new[] { typeof(UnityEngine.Object[]) }, null);

            if (manager == null || start == null)
            {
                surface.GetType().GetMethod("BuildNavMesh", AnyMember, null, Type.EmptyTypes, null)?.Invoke(surface, null);
                done();
                return;
            }

            start.Invoke(manager, new object[] { new UnityEngine.Object[] { surface } });

            var isBaking = mgrType.GetMethod("IsSurfaceBaking", AnyMember);
            double minUntil = EditorApplication.timeSinceStartup + 1.0;
            double deadline = EditorApplication.timeSinceStartup + 60.0;

            void Poll()
            {
                double now = EditorApplication.timeSinceStartup;
                bool baking = isBaking != null && (bool)isBaking.Invoke(manager, new object[] { surface });
                if ((baking || now < minUntil) && now < deadline) return;

                EditorApplication.update -= Poll;
                done();
            }
            EditorApplication.update += Poll;
        }

        static void Finish(UnityEngine.SceneManagement.Scene scene, bool baked)
        {
            EditorSceneManager.MarkSceneDirty(scene);
            EditorSceneManager.SaveScene(scene);
            AssetDatabase.SaveAssets();

            Debug.Log("[Nooni] Greybox room built and saved to " + ScenePath +
                      (baked ? "" : " (NavMesh NOT baked)") + ". Press Play, then click the Game view.");
            EditorUtility.DisplayDialog("Greybox room ready",
                "Press Play, then click inside the Game view.\n\nWASD move | Mouse look | Ctrl/C crouch | Shift sprint | Space jump" +
                (baked ? "" : "\n\nNavMesh was not baked. See the Console."), "OK");
        }
    }
}
