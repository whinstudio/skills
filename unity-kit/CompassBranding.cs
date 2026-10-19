using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEngine;

/// <summary>
/// Compass unity-kit — do not edit in projects. Compass runs <see cref="Apply"/> in batchmode after the import: it
/// writes the app icons and the splash colour from <see cref="SettingsPath"/> into the player settings and turns the
/// "Made with Unity" splash off. The outcome is one log line: <c>COMPASS_BRANDING ok</c>, or
/// <c>COMPASS_BRANDING failed: &lt;reason&gt;</c> and exit code 1.
/// Unity 6 has no public player setting for the Android 12+ system splash or the iOS launch screen colour: Android
/// draws its system splash from the adaptive icon, iOS keeps the template's launch screen.
/// </summary>
public static class CompassBranding
{
    public const string SettingsPath = "Assets/_Project/Compass/compass-branding.json";
    private const string Ok = "COMPASS_BRANDING ok";
    private const string Failed = "COMPASS_BRANDING failed: ";

    [Serializable]
    private class BrandingSettings
    {
        public string splashBackground;
        public string iconBackground;
        public Icons icons;
    }

    [Serializable]
    private class Icons
    {
        public string @default;
        public string androidForeground;
        public string androidBackground;
        public string androidLegacy;
        public string androidRound;
    }

    private class BrandingException : Exception
    {
        public BrandingException(string message) : base(message) { }
    }

    public static void Apply()
    {
        string failure;
        try
        {
            failure = ApplySettings();
        }
        catch (BrandingException e)
        {
            failure = e.Message;
        }
        catch (Exception e)
        {
            failure = $"{e.GetType().Name}: {e.Message}";
        }
        if (failure == null)
        {
            Debug.Log(Ok);
            return;
        }
        Debug.LogError(Failed + failure);
        EditorApplication.Exit(1);
    }

    /// <summary>Returns null when everything was written, else the reason.</summary>
    private static string ApplySettings()
    {
        if (!File.Exists(SettingsPath)) return $"{SettingsPath} is missing";
        var settings = JsonUtility.FromJson<BrandingSettings>(File.ReadAllText(SettingsPath));
        if (settings == null) return $"{SettingsPath} is empty";

        // The splash goes off first and is saved even when an icon fails below
        PlayerSettings.SplashScreen.show = false;
        PlayerSettings.SplashScreen.showUnityLogo = false;
        string failure = null;
        if (!string.IsNullOrEmpty(settings.splashBackground))
        {
            if (ColorUtility.TryParseHtmlString(settings.splashBackground, out var background))
                PlayerSettings.SplashScreen.backgroundColor = background;
            else
                failure = $"splashBackground '{settings.splashBackground}' is not a colour";
        }
        try
        {
            ApplyIcons(settings.icons);
        }
        catch (BrandingException e)
        {
            failure ??= e.Message;
        }
        AssetDatabase.SaveAssets();
        // Read back: an editor or licence that keeps the Unity splash on must not pass silently
        if (PlayerSettings.SplashScreen.show || PlayerSettings.SplashScreen.showUnityLogo) return "unity splash still on";
        return failure;
    }

    private static void ApplyIcons(Icons icons)
    {
        if (icons == null || string.IsNullOrEmpty(icons.@default)) return;
        var icon = Texture(icons.@default);
        PlayerSettings.SetIcons(NamedBuildTarget.Unknown, new[] { icon }, IconKind.Any);
        // iOS asks for one texture per size; the 1024 icon fills them all and Xcode scales it down
        var iosSizes = PlayerSettings.GetIconSizes(NamedBuildTarget.iOS, IconKind.Any);
        PlayerSettings.SetIcons(NamedBuildTarget.iOS, iosSizes.Select(_ => icon).ToArray(), IconKind.Any);
        ApplyAndroidIcons(icons);
    }

    private static void ApplyAndroidIcons(Icons icons)
    {
        // The kinds come from the Android module by name, so this file compiles without it
        var kinds = PlayerSettings.GetSupportedIconKinds(NamedBuildTarget.Android);
        if (kinds.Length == 0) throw new BrandingException("Android support is not installed");
        if (!string.IsNullOrEmpty(icons.androidForeground) && !string.IsNullOrEmpty(icons.androidBackground))
        {
            // Adaptive icon layers: [background, foreground]
            SetAndroid(kinds, "Adaptive", Texture(icons.androidBackground), Texture(icons.androidForeground));
        }
        if (!string.IsNullOrEmpty(icons.androidLegacy)) SetAndroid(kinds, "Legacy", Texture(icons.androidLegacy));
        if (!string.IsNullOrEmpty(icons.androidRound)) SetAndroid(kinds, "Round", Texture(icons.androidRound));
    }

    private static void SetAndroid(PlatformIconKind[] kinds, string name, params Texture2D[] layers)
    {
        var kind = kinds.FirstOrDefault(k => k.ToString().StartsWith(name, StringComparison.Ordinal))
            ?? throw new BrandingException($"no Android {name} icon kind");
        var slots = PlayerSettings.GetPlatformIcons(NamedBuildTarget.Android, kind);
        foreach (var slot in slots) slot.SetTextures(layers);
        PlayerSettings.SetPlatformIcons(NamedBuildTarget.Android, kind, slots);
    }

    private static Texture2D Texture(string path)
    {
        return AssetDatabase.LoadAssetAtPath<Texture2D>(path)
            ?? throw new BrandingException($"icon {path} is not an imported texture");
    }
}
