using System;
using System.IO;
using UnityEditor;
using UnityEngine;

/// <summary>
/// Compass unity-kit — do not edit in projects. Imports every texture under <see cref="ArtRoot"/> as a single
/// sprite, uncompressed and without mipmaps, with the pixels-per-unit and filtering Compass wrote to
/// <see cref="SettingsPath"/> for the staged art packs. Without that file (or if it cannot be read) the sprites
/// get 100 pixels per unit and bilinear filtering.
/// </summary>
public class CompassArtImporter : AssetPostprocessor
{
    public const string ArtRoot = "Assets/_Project/Resources/Art/";
    public const string SettingsPath = "Assets/_Project/Compass/compass-art.json";
    private const int DefaultPixelsPerUnit = 100;

    [Serializable]
    private class ArtSettings
    {
        public int pixelsPerUnit;
        public bool pixel;
        public string[] packs;
    }

    private void OnPreprocessTexture()
    {
        if (!assetPath.Replace('\\', '/').StartsWith(ArtRoot, StringComparison.Ordinal)) return;

        var importer = (TextureImporter)assetImporter;
        var settings = ReadSettings();
        var pixelArt = settings != null && settings.pixel;
        var pixelsPerUnit = settings != null && settings.pixelsPerUnit > 0
            ? settings.pixelsPerUnit
            : DefaultPixelsPerUnit;

        importer.textureType = TextureImporterType.Sprite;
        importer.spriteImportMode = SpriteImportMode.Single;
        importer.mipmapEnabled = false;
        importer.textureCompression = TextureImporterCompression.Uncompressed;
        importer.filterMode = pixelArt ? FilterMode.Point : FilterMode.Bilinear;
        importer.spritePixelsPerUnit = pixelsPerUnit;
    }

    private static ArtSettings ReadSettings()
    {
        try
        {
            if (!File.Exists(SettingsPath)) return null;
            return JsonUtility.FromJson<ArtSettings>(File.ReadAllText(SettingsPath));
        }
        catch (Exception e)
        {
            Debug.LogWarning(
                $"CompassArtImporter: could not read {SettingsPath} ({e.GetType().Name}); using defaults.");
            return null;
        }
    }
}
