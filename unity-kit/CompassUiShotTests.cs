using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;
using VContainer.Unity;

/// <summary>
/// Compass unity-kit — do not edit in projects. The game's dressed UI screens for Compass's design review: settings,
/// paywall and an economy window from the menu, then the HUD, the pause panel and an end card from the game scene as
/// the game plays itself. Each screen is drawn with its canvases moved onto the camera, so the world stays behind the
/// HUD, and written as <c>ui-&lt;name&gt;.png</c>; one <c>COMPASS_UI_SHOT &lt;name&gt; ok|skipped: …|failed: …</c>
/// line is logged per screen. Game types are found by simple name: generated games rename the template's
/// namespaces, and this test assembly cannot reference Assembly-CSharp. Explicit, so the gameplay test run skips it;
/// Compass runs it alone with <c>-testCategory CompassUiShot -compassShotDir &lt;folder&gt;
/// -compassShotSize &lt;width&gt;x&lt;height&gt; [-compassShotLanguage &lt;code&gt;]</c>.
/// </summary>
[Explicit, Category("CompassUiShot")]
public class CompassUiShotTests
{
    private const string MenuScene = "Menu";
    private const string GameScene = "Game";
    private const float TimeoutSeconds = 90f;
    private const float MenuSettleSeconds = 2f;
    private const float GameSettleSeconds = 4f;
    private const float AutoStartSeconds = 8f;
    private const float PanelSeconds = 1.5f;
    private const float CardSeconds = 3f;
    private const string Marker = "COMPASS_UI_SHOT";
    private const float NearGap = 0.01f;

    private const float CloseSeconds = 1f;

    // The template's LanguageSelector stores the choice under this PlayerPrefs key
    private const string LanguagePreference = "lang.code";

    // Panels that stay above every scene once opened (the paywall, the economy's windows)
    private static readonly string[] OverlayViews =
        { "PaywallView", "SupplyWindowView", "WheelWindowView", "LoginBonusView", "ExtraWindowView" };

    private static readonly string[] EconomyViews = { "SupplyWindowView", "WheelWindowView", "LoginBonusView" };

    private readonly List<string> failedRequired = new List<string>();
    private readonly List<GameObject> hiddenInspectors = new List<GameObject>();
    private bool languageSet;
    private bool hadLanguage;
    private string previousLanguage;

    [TearDown]
    public void TurnOff()
    {
        SetAutoPlay(false);
        Time.timeScale = 1f;
        if (languageSet)
        {
            if (hadLanguage) PlayerPrefs.SetString(LanguagePreference, previousLanguage);
            else PlayerPrefs.DeleteKey(LanguagePreference);
            PlayerPrefs.Save();
            languageSet = false;
        }
        foreach (var inspector in hiddenInspectors)
        {
            if (inspector != null) inspector.SetActive(true);
        }
        hiddenInspectors.Clear();
    }

    [UnityTest]
    public IEnumerator Ui_screens_are_drawn_with_the_game_skin()
    {
        var folder = Argument("-compassShotDir");
        Assert.That(folder, Is.Not.Empty, "-compassShotDir <folder> is missing");
        var (width, height) = Size(Argument("-compassShotSize"));
        var language = Argument("-compassShotLanguage");
        Directory.CreateDirectory(folder);
        failedRequired.Clear();

        SetAutoPlay(false);
        yield return OpenFromBoot(MenuScene, MenuSettleSeconds);
        if (!string.IsNullOrEmpty(language)) SelectLanguage(language);

        yield return Shot(folder, "settings", true, Do(() => Raise(FindView("MenuView", false), "SettingsClicked")),
            PanelSeconds, () => Expect("SettingsView"), false, width, height);

        yield return Reload(MenuScene);
        yield return Shot(folder, "paywall", false, OpenPaywall, PanelSeconds, () => Expect("PaywallView"), true, width, height);

        yield return Reload(MenuScene);
        yield return Shot(folder, "economy", false, OpenEconomy, PanelSeconds, () => Expect(EconomyViews), true, width, height);

        SetAutoPlay(true);
        yield return OpenGame();
        yield return Shot(folder, "hud", true, null, 0f, null, false, width, height);

        yield return Shot(folder, "pause", true, Do(() => Raise(FindView("PauseView", true), "PauseClicked")),
            PanelSeconds, () => Expect("PauseView"), false, width, height);
        var resumed = Try(Do(() => Raise(FindView("PauseView", true), "ResumeClicked")));
        if (resumed != null) Debug.Log($"{Marker} resume: {resumed}");

        // Freezes the AutoPlayer; the shell's cards run on unscaled time
        Time.timeScale = 0f;
        var levels = EndCardName() == "level-complete";
        yield return Shot(folder, levels ? "level-complete" : "game-over", true, Do(ShowEndCard), CardSeconds,
            () => Expect(levels ? "LevelCompleteCard" : "GameOverCard"), false, width, height);

        Assert.That(failedRequired, Is.Empty, $"required UI screens failed: {string.Join(", ", failedRequired)}");
    }

    private IEnumerator OpenFromBoot(string scene, float settleSeconds)
    {
        SceneManager.LoadScene("Boot");
        var deadline = Time.realtimeSinceStartup + TimeoutSeconds;
        while (SceneManager.GetActiveScene().name != scene && Time.realtimeSinceStartup < deadline) yield return null;
        Assert.That(SceneManager.GetActiveScene().name, Is.EqualTo(scene), $"the {scene} scene did not open within {TimeoutSeconds} s");
        yield return new WaitForSecondsRealtime(settleSeconds);
    }

    /// <summary>
    /// Boot with AutoPlay on: the game's AutoPlayer opens the game scene from the menu. When it has not done so
    /// within <see cref="AutoStartSeconds"/> of the menu (no AutoPlayer, or a late one), the menu's first game is
    /// started as its Play button would.
    /// </summary>
    private IEnumerator OpenGame()
    {
        SceneManager.LoadScene("Boot");
        var deadline = Time.realtimeSinceStartup + TimeoutSeconds;
        while (SceneManager.GetActiveScene().name != MenuScene && SceneManager.GetActiveScene().name != GameScene
               && Time.realtimeSinceStartup < deadline) yield return null;
        if (SceneManager.GetActiveScene().name == MenuScene)
        {
            var autoStart = Mathf.Min(Time.realtimeSinceStartup + AutoStartSeconds, deadline);
            while (SceneManager.GetActiveScene().name != GameScene && Time.realtimeSinceStartup < autoStart) yield return null;
            if (SceneManager.GetActiveScene().name != GameScene)
            {
                Debug.Log($"{Marker} start: menu GameClicked(0)");
                var started = Try(Do(() => Raise(FindView("MenuView", true), "GameClicked", 0)));
                if (started != null) Debug.Log($"{Marker} start failed: {started}");
            }
        }
        while (SceneManager.GetActiveScene().name != GameScene && Time.realtimeSinceStartup < deadline) yield return null;
        Assert.That(SceneManager.GetActiveScene().name, Is.EqualTo(GameScene), $"the {GameScene} scene did not open within {TimeoutSeconds} s");
        yield return new WaitForSecondsRealtime(GameSettleSeconds);
    }

    private static IEnumerator Reload(string scene)
    {
        SceneManager.LoadScene(scene);
        // LoadScene takes effect on the next frame
        yield return null;
        yield return new WaitForSecondsRealtime(MenuSettleSeconds);
    }

    /// <summary>
    /// One screen: hides the network inspector, closes a paywall or economy window left open, runs
    /// <paramref name="open"/> (null: opened, "skip: …": skipped, else the failure), waits, checks with
    /// <paramref name="check"/> that the expected view is open, draws it and logs its line; a required screen that
    /// failed is kept for the final assertion.
    /// </summary>
    private IEnumerator Shot(string folder, string name, bool required, Func<string> open, float waitSeconds,
        Func<string> check, bool closeAfter, int width, int height)
    {
        HideInspector();
        var cleared = new bool[1];
        yield return CloseOverlays(cleared);
        var error = cleared[0] ? null : "overlay still open";
        if (error == null && open != null) error = Try(open);
        if (error == null)
        {
            if (waitSeconds > 0f) yield return new WaitForSecondsRealtime(waitSeconds);
            if (check != null) error = Try(check);
        }
        if (error == null)
        {
            var result = new string[1];
            yield return Draw(Path.Combine(folder, $"ui-{name}.png"), width, height, result);
            error = result[0];
        }
        if (closeAfter) yield return CloseOverlays(new bool[1]);
        if (error == null) Debug.Log($"{Marker} {name} ok");
        else if (error.StartsWith(SkipPrefix, StringComparison.Ordinal)) Debug.Log($"{Marker} {name} skipped: {error.Substring(SkipPrefix.Length)}");
        else
        {
            Debug.Log($"{Marker} {name} failed: {error}");
            if (required) failedRequired.Add(name);
        }
    }

    private const string SkipPrefix = "skip: ";

    private static string Try(Func<string> open)
    {
        try
        {
            return open();
        }
        catch (Exception e)
        {
            var inner = e is TargetInvocationException && e.InnerException != null ? e.InnerException : e;
            return $"{inner.GetType().Name}: {inner.Message}";
        }
    }

    private static Func<string> Do(Action action) => () =>
    {
        action();
        return null;
    };

    /// <summary>
    /// Closes every open overlay as its Close button would, then with SetOpen(false) after
    /// <see cref="CloseSeconds"/> if it is still open; <c>cleared[0]</c> is whether none is left open.
    /// </summary>
    private static IEnumerator CloseOverlays(bool[] cleared)
    {
        var open = OpenViews(OverlayViews);
        if (open.Count > 0)
        {
            foreach (var view in open)
            {
                Debug.Log($"{Marker} closing {view.GetType().Name}");
                var closed = Try(Do(() => Raise(view, "CloseClicked")));
                if (closed != null) Debug.Log($"{Marker} close {view.GetType().Name}: {closed}");
            }
            yield return new WaitForSecondsRealtime(CloseSeconds);
            foreach (var view in OpenViews(OverlayViews))
            {
                var closed = Try(Do(() => Invoke(view, "SetOpen", false)));
                if (closed != null) Debug.Log($"{Marker} SetOpen(false) {view.GetType().Name}: {closed}");
            }
            // One frame for the closing to settle
            yield return null;
        }
        cleared[0] = OpenViews(OverlayViews).Count == 0;
    }

    /// <summary>Null when a view of one of these types is open, else "&lt;view&gt; not open".</summary>
    private static string Expect(params string[] viewNames) =>
        OpenViews(viewNames).Count > 0 ? null : $"{string.Join("/", viewNames)} not open";

    private static List<Component> OpenViews(string[] viewNames)
    {
        var open = new List<Component>();
        foreach (var name in viewNames)
        {
            var type = FindComponentType(name);
            if (type == null) continue;
            foreach (var found in UnityEngine.Object.FindObjectsByType(type, FindObjectsInactive.Include, FindObjectsSortMode.None))
            {
                if (found is Component view && IsOpen(view)) open.Add(view);
            }
        }
        return open;
    }

    /// <summary>
    /// The template's views keep their root active and toggle a <c>panel</c> child; IsOpen/IsShown say so where the
    /// view has them.
    /// </summary>
    private static bool IsOpen(Component view)
    {
        if (view == null || !view.gameObject.activeInHierarchy) return false;
        foreach (var name in new[] { "IsOpen", "IsShown" })
        {
            var property = view.GetType().GetProperty(name, BindingFlags.Public | BindingFlags.Instance);
            if (property != null && property.PropertyType == typeof(bool)) return (bool)property.GetValue(view);
        }
        for (var type = view.GetType(); type != null; type = type.BaseType)
        {
            var field = type.GetField("panel", BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.DeclaredOnly);
            if (field != null && field.GetValue(view) is GameObject panel) return panel != null && panel.activeInHierarchy;
        }
        return true;
    }

    /// <summary>The network inspector's overlay (development builds) stays off for every shot; on again in TearDown.</summary>
    private void HideInspector()
    {
        var type = FindComponentType("InspectorView");
        if (type == null) return;
        foreach (var found in UnityEngine.Object.FindObjectsByType(type, FindObjectsInactive.Exclude, FindObjectsSortMode.None))
        {
            if (!(found is Component view) || !view.gameObject.activeSelf) continue;
            view.gameObject.SetActive(false);
            hiddenInspectors.Add(view.gameObject);
            Debug.Log($"{Marker} network inspector hidden");
        }
    }

    private static string OpenPaywall()
    {
        var paywall = Resolve("IPaywall");
        if (paywall == null) return SkipPrefix + "no purchases";
        var show = paywall.GetType().GetMethod("Show", BindingFlags.Public | BindingFlags.Instance);
        if (show == null || show.GetParameters().Length != 1) return "IPaywall.Show(source) is missing";
        show.Invoke(paywall, new[] { Enum.Parse(show.GetParameters()[0].ParameterType, "Menu") });
        return null;
    }

    private static string OpenEconomy()
    {
        var windows = Resolve("IEconomyWindows");
        if (windows == null) return SkipPrefix + "no economy";
        foreach (var open in new[] { "OpenSupply", "OpenWheel", "OpenLogin" })
        {
            var method = windows.GetType().GetMethod(open, BindingFlags.Public | BindingFlags.Instance, null, Type.EmptyTypes, null);
            if (method != null && method.Invoke(windows, null) is bool shown && shown) return null;
        }
        return SkipPrefix + "no economy window";
    }

    private static string EndCardName()
    {
        var shell = Resolve("IGameShell");
        var mode = shell?.GetType().GetProperty("Mode")?.GetValue(shell);
        return mode != null && mode.ToString() == "Levels" ? "level-complete" : "game-over";
    }

    private static void ShowEndCard()
    {
        var shell = Resolve("IGameShell");
        if (shell == null) throw new InvalidOperationException("IGameShell cannot be resolved");
        var levels = shell.GetType().GetProperty("Mode")?.GetValue(shell)?.ToString() == "Levels";
        // The returned UniTask is not awaited: the card stays open for the shot
        if (levels) Invoke(shell, "ShowLevelComplete", 1, 3, 120);
        else Invoke(shell, "ShowGameOver", 42, 128, true);
    }

    private static void Invoke(object target, string method, params object[] arguments)
    {
        var found = target.GetType().GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .FirstOrDefault(m => m.Name == method && m.GetParameters().Length == arguments.Length);
        if (found == null) throw new MissingMethodException(target.GetType().Name, method);
        found.Invoke(target, arguments);
    }

    /// <summary>
    /// Selects the language through the template's LanguageSelector, as the settings row would, so the row shows it
    /// too (setting the localizer alone leaves the row on the old name); it stores the choice, which TearDown
    /// restores. Without the selector the localizer is set directly.
    /// </summary>
    private void SelectLanguage(string code)
    {
        hadLanguage = PlayerPrefs.HasKey(LanguagePreference);
        previousLanguage = hadLanguage ? PlayerPrefs.GetString(LanguagePreference) : null;
        languageSet = true;
        var selector = Resolve("LanguageSelector");
        var index = selector == null ? -1 : SupportedIndex(selector.GetType(), code);
        var select = selector?.GetType().GetMethod("Select", new[] { typeof(int) });
        if (index >= 0 && select != null)
        {
            select.Invoke(selector, new object[] { index });
            return;
        }
        Debug.Log($"{Marker} language {code}: no LanguageSelector entry, setting the localizer");
        SetLanguage(code);
    }

    /// <summary>The index of <paramref name="code"/> in the selector's static Supported list of (Code, Name) pairs.</summary>
    private static int SupportedIndex(Type selector, string code)
    {
        if (!(selector.GetField("Supported", BindingFlags.Public | BindingFlags.Static)?.GetValue(null) is IEnumerable supported)) return -1;
        var index = 0;
        foreach (var entry in supported)
        {
            if (entry?.GetType().GetField("Item1")?.GetValue(entry) as string == code) return index;
            index++;
        }
        return -1;
    }

    private static void SetLanguage(string code)
    {
        var localizer = Resolve("ILocalizer");
        var set = localizer?.GetType().GetMethod("SetLanguage", new[] { typeof(string) });
        if (set == null)
        {
            Debug.Log($"{Marker} language {code}: the localizer has no SetLanguage");
            return;
        }
        if (!(set.Invoke(localizer, new object[] { code }) is bool ok) || !ok) Debug.Log($"{Marker} language {code}: not available");
    }

    /// <summary>Moves every overlay canvas onto the camera, renders it at the shot's size and restores the scene.</summary>
    private static IEnumerator Draw(string path, int width, int height, string[] result)
    {
        var temporary = Camera.main == null ? TemporaryCamera() : null;
        var camera = temporary != null ? temporary : Camera.main;
        var target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
        var previousTarget = camera.targetTexture;
        var moved = new List<(Canvas Canvas, RenderMode Mode, Camera Camera, float Distance)>();
        var overlays = UnityEngine.Object.FindObjectsByType<Canvas>(FindObjectsSortMode.None)
            .Where(c => c.isRootCanvas && c.renderMode == RenderMode.ScreenSpaceOverlay).ToList();
        var orders = overlays.Select(c => c.sortingOrder).Distinct().OrderByDescending(o => o).ToList();
        foreach (var canvas in overlays)
        {
            moved.Add((canvas, canvas.renderMode, canvas.worldCamera, canvas.planeDistance));
            canvas.renderMode = RenderMode.ScreenSpaceCamera;
            canvas.worldCamera = camera;
            // Just past the near plane, the top canvas nearest: a camera canvas is depth-tested, so one farther than
            // the world (the template's 50 units) would sit behind a 3D world or a 2D world's sprites
            canvas.planeDistance = camera.nearClipPlane + NearGap * (1 + orders.IndexOf(canvas.sortingOrder));
        }
        camera.targetTexture = target;
        try
        {
            // Canvas scalers lay out at the new size during this frame; WaitForEndOfFrame never comes in batchmode
            yield return null;
            result[0] = Capture(camera, target, path, width, height);
        }
        finally
        {
            foreach (var (canvas, mode, worldCamera, distance) in moved)
            {
                if (canvas == null) continue;
                canvas.renderMode = mode;
                canvas.worldCamera = worldCamera;
                canvas.planeDistance = distance;
            }
            if (camera != null) camera.targetTexture = previousTarget;
            target.Release();
            UnityEngine.Object.Destroy(target);
            if (temporary != null) UnityEngine.Object.Destroy(temporary.gameObject);
        }
    }

    private static string Capture(Camera camera, RenderTexture target, string path, int width, int height)
    {
        if (camera == null) return "the camera was destroyed";
        var image = new Texture2D(width, height, TextureFormat.RGB24, false);
        var active = RenderTexture.active;
        try
        {
            Canvas.ForceUpdateCanvases();
            camera.Render();
            RenderTexture.active = target;
            image.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            image.Apply();
            File.WriteAllBytes(path, image.EncodeToPNG());
            return null;
        }
        catch (Exception e)
        {
            return $"{e.GetType().Name}: {e.Message}";
        }
        finally
        {
            RenderTexture.active = active;
            UnityEngine.Object.Destroy(image);
        }
    }

    private static Camera TemporaryCamera()
    {
        var camera = new GameObject("CompassUiShotCamera").AddComponent<Camera>();
        camera.orthographic = true;
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = Color.black;
        return camera;
    }

    private static Type FindType(string simpleName) => FindType(simpleName, t => true);

    /// <summary>A view type: a game may also have a non-component type of the same simple name (an interface, a model).</summary>
    private static Type FindComponentType(string simpleName) => FindType(simpleName, t => typeof(Component).IsAssignableFrom(t));

    private static Type FindType(string simpleName, Func<Type, bool> accept)
    {
        foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
        {
            Type[] types;
            try
            {
                types = assembly.GetTypes();
            }
            catch (ReflectionTypeLoadException e)
            {
                types = e.Types.Where(t => t != null).ToArray();
            }
            var found = types.FirstOrDefault(t => t.Name == simpleName && accept(t));
            if (found != null) return found;
        }
        return null;
    }

    /// <summary>The service from the first loaded scope that can build it (scene scopes see the root's too).</summary>
    private static object Resolve(string simpleName)
    {
        var type = FindType(simpleName);
        if (type == null) return null;
        var scopes = UnityEngine.Object.FindObjectsByType<LifetimeScope>(FindObjectsSortMode.None)
            .OrderBy(s => s.gameObject.scene.name == "DontDestroyOnLoad" ? 1 : 0);
        foreach (var scope in scopes)
        {
            if (scope.Container == null) continue;
            try
            {
                return scope.Container.Resolve(type);
            }
            catch (Exception)
            {
                // Not registered in this scope: try the next
            }
        }
        return null;
    }

    private static Component FindView(string simpleName, bool includeInactive)
    {
        var type = FindComponentType(simpleName);
        Assert.That(type, Is.Not.Null, $"{simpleName} is missing from the project");
        var found = UnityEngine.Object.FindObjectsByType(type,
            includeInactive ? FindObjectsInactive.Include : FindObjectsInactive.Exclude, FindObjectsSortMode.None);
        return found.Length > 0 ? (Component)found[0] : null;
    }

    /// <summary>Invokes a field-like event's backing delegate, as the view's own button would.</summary>
    private static void Raise(object component, string eventName, params object[] args)
    {
        if (component == null) throw new InvalidOperationException($"no view for {eventName} in the scene");
        for (var type = component.GetType(); type != null; type = type.BaseType)
        {
            var field = type.GetField(eventName, BindingFlags.NonPublic | BindingFlags.Instance);
            if (field == null) continue;
            (field.GetValue(component) as Delegate)?.DynamicInvoke(args);
            return;
        }
        throw new MissingFieldException(component.GetType().Name, eventName);
    }

    private static string Argument(string name)
    {
        var args = Environment.GetCommandLineArgs();
        var index = Array.IndexOf(args, name);
        return index >= 0 && index + 1 < args.Length ? args[index + 1] : "";
    }

    private static (int, int) Size(string value)
    {
        var parts = value.Split('x');
        if (parts.Length == 2 && int.TryParse(parts[0], out var width) && int.TryParse(parts[1], out var height)
            && width > 0 && height > 0 && width <= 8192 && height <= 8192)
            return (width, height);
        Assert.Fail($"-compassShotSize '{value}' is not <width>x<height>");
        return (0, 0);
    }

    // CompassAutoPlay lives in Assembly-CSharp, which this test assembly cannot reference: it is found by name
    private static void SetAutoPlay(bool on)
    {
        foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
        {
            var type = assembly.GetType("CompassAutoPlay", false);
            var forTests = type?.GetMethod("ForTests", BindingFlags.Public | BindingFlags.Static);
            if (forTests == null) continue;
            forTests.Invoke(null, new object[] { on });
            return;
        }
        Assert.Fail("CompassAutoPlay is missing from the project");
    }
}
