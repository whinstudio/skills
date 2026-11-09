using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEngine;

/// <summary>
/// Compass unity-kit — do not edit in projects. Compass runs <see cref="Apply"/> in batchmode after the import: it
/// writes the app icons, the splash colour, the launch screen logo and the app orientation from <see cref="SettingsPath"/>
/// into the player settings and turns the "Made with Unity" splash off. The outcome is one log line: <c>COMPASS_BRANDING ok</c>, or
/// <c>COMPASS_BRANDING failed: &lt;reason&gt;</c> and exit code 1.
/// With a logo, the iOS launch screen and the Android static splash show it centred on the splash colour while the
/// engine loads; without one they stay as the template has them. Android 12+ still draws its system splash from the
/// adaptive icon first.
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
        public string logo;
        public Icons icons;
        // "portrait" or "landscape"; empty keeps the template's orientation
        public string orientation;
        // optional; written into the template's AppConfig asset
        public Links links;
    }

    [Serializable]
    private class Links
    {
        public string privacy;
        public string support;
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
            ApplyOrientation(settings.orientation);
        }
        catch (BrandingException e)
        {
            failure ??= e.Message;
        }
        try
        {
            ApplyIcons(settings.icons);
        }
        catch (BrandingException e)
        {
            failure ??= e.Message;
        }
        try
        {
            if (!string.IsNullOrEmpty(settings.logo)) ApplyLaunchScreen(settings.logo, settings.orientation);
        }
        catch (BrandingException e)
        {
            failure ??= e.Message;
        }
        try
        {
            ApplyLinks(settings.links);
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

    /// <summary>
    /// The logo centred on the splash colour, shown by the OS before the first Unity frame. The launch screen colours,
    /// sizes and the Android image have no public setter, so they are written to the serialized player settings.
    /// </summary>
    private static void ApplyLaunchScreen(string logoPath, string orientation)
    {
        var logo = Texture(logoPath);
        var landscape = orientation == "landscape";
        var aspect = (float)logo.width / logo.height;
        PlayerSettings.iOS.SetiPhoneLaunchScreenType(iOSLaunchScreenType.ImageAndBackgroundRelative);
        PlayerSettings.iOS.SetiPadLaunchScreenType(iOSLaunchScreenType.ImageAndBackgroundRelative);
        PlayerSettings.iOS.SetLaunchScreenImage(logo, iOSLaunchScreenImageType.iPhonePortraitImage);
        PlayerSettings.iOS.SetLaunchScreenImage(logo, iOSLaunchScreenImageType.iPhoneLandscapeImage);
        PlayerSettings.iOS.SetLaunchScreenImage(logo, iOSLaunchScreenImageType.iPadImage);
        PlayerSettings.Android.splashScreenScale = AndroidSplashScreenScale.Center;

        var asset = AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset").FirstOrDefault()
            ?? throw new BrandingException("ProjectSettings.asset is not loaded");
        var settings = new SerializedObject(asset);
        var background = PlayerSettings.SplashScreen.backgroundColor;
        Property(settings, "iOSLaunchScreenBackgroundColor").colorValue = background;
        Property(settings, "iOSLaunchScreeniPadBackgroundColor").colorValue = background;
        Property(settings, "iOSLaunchScreenFillPct").floatValue = IPhoneFillPercent(landscape, aspect);
        Property(settings, "iOSLaunchScreeniPadFillPct").floatValue = IPadFillPercent(landscape, aspect);
        Property(settings, "androidSplashScreen").objectReferenceValue = PaddedAndroidSplash(logoPath);
        settings.ApplyModifiedPropertiesWithoutUndo();
    }

    // The logo's share of the screen width on every platform
    private const float LogoWidthPercent = 70f;
    private const float PhoneLandscapeWidthOverHeight = 2.16f;
    private const float TabletLandscapeWidthOverHeight = 4f / 3f;
    private const string AndroidSplashPath = "Assets/_Project/Branding/android-splash.png";

    /// <summary>A portrait iPhone's fill is a share of the width; a landscape iPhone's is a share of the height.</summary>
    private static float IPhoneFillPercent(bool landscape, float logoAspect) =>
        landscape ? HeightFillPercent(PhoneLandscapeWidthOverHeight, logoAspect) : LogoWidthPercent;

    /// <summary>The iPad's fill is a share of the height in both orientations.</summary>
    private static float IPadFillPercent(bool landscape, float logoAspect) =>
        HeightFillPercent(landscape ? TabletLandscapeWidthOverHeight : 1f / TabletLandscapeWidthOverHeight, logoAspect);

    private static float HeightFillPercent(float widthOverHeight, float logoAspect) =>
        Mathf.Clamp(LogoWidthPercent * widthOverHeight / logoAspect, 1f, 100f);

    /// <summary>
    /// Android's centred splash scales a large image down to fit the screen, which puts a wide logo edge to edge. A
    /// transparent margin on both sides leaves the logo at <see cref="LogoWidthPercent"/> of the width.
    /// </summary>
    private static Texture2D PaddedAndroidSplash(string logoPath)
    {
        var source = new Texture2D(2, 2);
        if (!source.LoadImage(File.ReadAllBytes(logoPath))) throw new BrandingException($"{logoPath} is not an image");
        var width = Mathf.RoundToInt(source.width * 100f / LogoWidthPercent);
        var canvas = new Texture2D(width, source.height, TextureFormat.RGBA32, false);
        canvas.SetPixels32(new Color32[width * source.height]);
        canvas.SetPixels32((width - source.width) / 2, 0, source.width, source.height, source.GetPixels32());
        Directory.CreateDirectory(Path.GetDirectoryName(AndroidSplashPath));
        File.WriteAllBytes(AndroidSplashPath, canvas.EncodeToPNG());
        AssetDatabase.ImportAsset(AndroidSplashPath, ImportAssetOptions.ForceSynchronousImport);
        return Texture(AndroidSplashPath);
    }

    /// <summary>
    /// The whole app's orientation, from launch: a landscape game turns with the phone between the two landscape
    /// sides and never shows a portrait menu; a portrait game stays upright. Games must not switch it per scene.
    /// </summary>
    private static void ApplyOrientation(string orientation)
    {
        switch (orientation)
        {
            case null:
            case "":
                return;
            case "landscape":
                PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
                PlayerSettings.allowedAutorotateToPortrait = false;
                PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
                PlayerSettings.allowedAutorotateToLandscapeLeft = true;
                PlayerSettings.allowedAutorotateToLandscapeRight = true;
                return;
            case "portrait":
                PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
                return;
            default:
                throw new BrandingException($"orientation '{orientation}' is not portrait or landscape");
        }
    }

    /// <summary>
    /// The privacy and support addresses go into the template's AppConfig asset (found by type, so the kit does not
    /// reference it). Blank fields are left alone; no links or no AppConfig (an older template) is not an error.
    /// </summary>
    private static void ApplyLinks(Links links)
    {
        if (links == null) return;
        if (string.IsNullOrEmpty(links.privacy) && string.IsNullOrEmpty(links.support)) return;
        var guid = AssetDatabase.FindAssets("t:AppConfig").FirstOrDefault();
        if (guid == null) return;
        var config = AssetDatabase.LoadMainAssetAtPath(AssetDatabase.GUIDToAssetPath(guid));
        if (config == null) return;

        var serialized = new SerializedObject(config);
        WriteLink(serialized, "privacyUrl", links.privacy);
        WriteLink(serialized, "supportUrl", links.support);
        serialized.ApplyModifiedPropertiesWithoutUndo();
        EditorUtility.SetDirty(config);
        AssetDatabase.SaveAssets();

        // Read back: a field that did not stick must not pass silently
        var check = new SerializedObject(config);
        CheckLink(check, "privacyUrl", links.privacy);
        CheckLink(check, "supportUrl", links.support);
    }

    private static void WriteLink(SerializedObject config, string field, string value)
    {
        if (string.IsNullOrEmpty(value)) return;
        // A field this template's AppConfig does not have (older templates) is skipped
        var property = config.FindProperty(field);
        if (property != null) property.stringValue = value;
    }

    private static void CheckLink(SerializedObject config, string field, string value)
    {
        if (string.IsNullOrEmpty(value)) return;
        var property = config.FindProperty(field);
        if (property != null && property.stringValue != value)
            throw new BrandingException($"links {field} was not written to AppConfig");
    }

    private static SerializedProperty Property(SerializedObject settings, string name)
    {
        return settings.FindProperty(name) ?? throw new BrandingException($"player setting {name} not found");
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
            ?? throw new BrandingException($"{path} is not an imported texture");
    }
}
