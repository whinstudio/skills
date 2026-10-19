using System;
using System.Collections;
using System.IO;
using System.Reflection;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

/// <summary>
/// Compass unity-kit — do not edit in projects. Compass's menu background: the game plays itself from Boot and,
/// <see cref="SettleSeconds"/> after the game scene opens, the main camera is drawn without any Canvas into a PNG.
/// Explicit, so the gameplay test run skips it; Compass runs it alone with
/// <c>-testCategory CompassMenuShot -compassShotOut &lt;png&gt; -compassShotSize &lt;width&gt;x&lt;height&gt;</c>.
/// </summary>
[Explicit, Category("CompassMenuShot")]
public class CompassMenuShotTests
{
    private const string GameScene = "Game";
    private const float SettleSeconds = 3f;
    private const float TimeoutSeconds = 90f;

    [TearDown]
    public void TurnOff() => SetAutoPlay(false);

    [UnityTest]
    public IEnumerator Game_scene_is_drawn_without_its_canvases()
    {
        var output = Argument("-compassShotOut");
        Assert.That(output, Is.Not.Empty, "-compassShotOut <png path> is missing");
        var (width, height) = Size(Argument("-compassShotSize"));

        SetAutoPlay(true);
        SceneManager.LoadScene("Boot");
        var deadline = Time.realtimeSinceStartup + TimeoutSeconds;
        while (SceneManager.GetActiveScene().name != GameScene && Time.realtimeSinceStartup < deadline) yield return null;
        Assert.That(SceneManager.GetActiveScene().name, Is.EqualTo(GameScene), $"the game scene did not open within {TimeoutSeconds} s");
        yield return new WaitForSecondsRealtime(SettleSeconds);

        foreach (var canvas in UnityEngine.Object.FindObjectsByType<Canvas>(FindObjectsSortMode.None)) canvas.enabled = false;
        // One frame for the hidden canvases; WaitForEndOfFrame never comes in batchmode
        yield return null;
        var camera = Camera.main;
        Assert.That(camera, Is.Not.Null, "the game scene has no main camera");

        var target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
        var image = new Texture2D(width, height, TextureFormat.RGB24, false);
        var previous = camera.targetTexture;
        var active = RenderTexture.active;
        var size = camera.orthographicSize;
        try
        {
            // Pixel-perfect games size the camera from Screen.height, which in batchmode is not the shot's height:
            // scale it as if the screen were the shot
            if (camera.orthographic && Screen.height > 0) camera.orthographicSize = size * height / Screen.height;
            camera.targetTexture = target;
            camera.Render();
            RenderTexture.active = target;
            image.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            image.Apply();
        }
        finally
        {
            camera.targetTexture = previous;
            camera.orthographicSize = size;
            RenderTexture.active = active;
            target.Release();
            UnityEngine.Object.Destroy(target);
        }
        var directory = Path.GetDirectoryName(output);
        if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
        File.WriteAllBytes(output, image.EncodeToPNG());
        UnityEngine.Object.Destroy(image);
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
