using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

/// <summary>
/// Compass unity-kit — do not edit in projects. Compass's menu background: the game plays itself from Boot and,
/// from <see cref="SettleSeconds"/> after the game scene opens, the main camera is drawn without any Canvas
/// <see cref="Candidates"/> times; the frame with the most colours becomes the PNG (a floor change or a fade can
/// hide the world for a moment). The camera is drawn as the game sized it: games fit their zoom to
/// <c>Screen</c>, so rescaling it to the shot's height zoomed the world out (KeyKnight, 20 Oct).
/// Explicit, so the gameplay test run skips it; Compass runs it alone with
/// <c>-testCategory CompassMenuShot -compassShotOut &lt;png&gt; -compassShotSize &lt;width&gt;x&lt;height&gt;</c>.
/// </summary>
[Explicit, Category("CompassMenuShot")]
public class CompassMenuShotTests
{
    private const string GameScene = "Game";
    private const float SettleSeconds = 4f;
    private const int Candidates = 3;
    private const float CandidateGapSeconds = 2f;
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

        byte[] best = null;
        var bestColours = -1;
        for (var i = 0; i < Candidates; i++)
        {
            if (i > 0) yield return new WaitForSecondsRealtime(CandidateGapSeconds);
            // The game may open new canvases (floating text, dialogs) between candidates
            foreach (var canvas in UnityEngine.Object.FindObjectsByType<Canvas>(FindObjectsSortMode.None)) canvas.enabled = false;
            // One frame for the hidden canvases; WaitForEndOfFrame never comes in batchmode
            yield return null;
            var camera = Camera.main;
            Assert.That(camera, Is.Not.Null, "the game scene has no main camera");
            var image = Render(camera, width, height);
            var colours = DistinctColours(image);
            if (colours > bestColours)
            {
                best = image.EncodeToPNG();
                bestColours = colours;
            }
            UnityEngine.Object.Destroy(image);
        }
        var directory = Path.GetDirectoryName(output);
        if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
        File.WriteAllBytes(output, best);
    }

    private static Texture2D Render(Camera camera, int width, int height)
    {
        var target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
        var image = new Texture2D(width, height, TextureFormat.RGB24, false);
        var previous = camera.targetTexture;
        var active = RenderTexture.active;
        try
        {
            camera.targetTexture = target;
            camera.Render();
            RenderTexture.active = target;
            image.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            image.Apply();
        }
        finally
        {
            camera.targetTexture = previous;
            RenderTexture.active = active;
            target.Release();
            UnityEngine.Object.Destroy(target);
        }
        return image;
    }

    /// <summary>Distinct colours at 4 bits per channel, every 4th pixel: a frame with the world hidden has few.</summary>
    private static int DistinctColours(Texture2D image)
    {
        var pixels = image.GetPixels32();
        var seen = new HashSet<int>();
        for (var i = 0; i < pixels.Length; i += 4)
        {
            var p = pixels[i];
            seen.Add(((p.r >> 4) << 8) | ((p.g >> 4) << 4) | (p.b >> 4));
        }
        return seen.Count;
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
