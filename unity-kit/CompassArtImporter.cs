using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEngine;

/// <summary>
/// Compass unity-kit — do not edit in projects. Imports every texture under <see cref="ArtRoot"/> as a single
/// sprite, uncompressed and without mipmaps, with the pixels-per-unit and filtering Compass wrote to
/// <see cref="SettingsPath"/>: a pack's entry in <c>folders</c> when there is one, else the top-level values. A file
/// listed in <c>borders</c> (keyed by its path under <c>Assets/_Project/Resources/</c>) gets that nine-slice border and
/// a full-rect mesh, which tiled and sliced UI images need. Without the file (or if it cannot be read) the sprites get
/// 100 pixels per unit and bilinear filtering.
/// The game's logo and menu background under <see cref="BrandingRoot"/> import as sprites too; the app icons under
/// <see cref="IconsRoot"/> as plain uncompressed textures for the player settings.
/// </summary>
public class CompassArtImporter : AssetPostprocessor
{
    public const string ArtRoot = "Assets/_Project/Resources/Art/";
    public const string BrandingRoot = "Assets/_Project/Resources/Branding/";
    public const string IconsRoot = "Assets/_Project/Branding/Icons/";
    public const string SettingsPath = "Assets/_Project/Compass/compass-art.json";
    private const string ResourcesRoot = "Assets/_Project/Resources/";
    private const string MenuBackground = "menu-background";
    private const int DefaultPixelsPerUnit = 100;

    [Serializable]
    private class ArtSettings
    {
        public int pixelsPerUnit;
        public bool pixel;
        public string[] packs;
    }

    private class FolderSettings
    {
        public int PixelsPerUnit;
        public bool Pixel;
    }

    private class Settings
    {
        public ArtSettings Top;
        public readonly Dictionary<string, FolderSettings> Folders = new Dictionary<string, FolderSettings>();
        public readonly Dictionary<string, Vector4> Borders = new Dictionary<string, Vector4>();
    }

    private void OnPreprocessTexture()
    {
        var path = assetPath.Replace('\\', '/');
        var importer = (TextureImporter)assetImporter;
        if (path.StartsWith(IconsRoot, StringComparison.Ordinal))
        {
            importer.textureType = TextureImporterType.Default;
            importer.mipmapEnabled = false;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.alphaIsTransparency = true;
            return;
        }
        if (path.StartsWith(BrandingRoot, StringComparison.Ordinal))
        {
            var top = ReadSettings()?.Top;
            // The menu background is a render of the game scene: pixel games keep it crisp; the logo is smooth art
            var pixelArt = Path.GetFileNameWithoutExtension(path) == MenuBackground && top != null && top.pixel;
            ImportSprite(importer, pixelArt, DefaultPixelsPerUnit);
            return;
        }
        if (!path.StartsWith(ArtRoot, StringComparison.Ordinal)) return;

        var settings = ReadSettings();
        var slug = path.Substring(ArtRoot.Length).Split('/')[0];
        bool pixel;
        int pixelsPerUnit;
        if (settings != null && settings.Folders.TryGetValue(slug, out var folder))
        {
            pixel = folder.Pixel;
            pixelsPerUnit = folder.PixelsPerUnit;
        }
        else
        {
            pixel = settings?.Top != null && settings.Top.pixel;
            pixelsPerUnit = settings?.Top?.pixelsPerUnit ?? 0;
        }
        ImportSprite(importer, pixel, pixelsPerUnit > 0 ? pixelsPerUnit : DefaultPixelsPerUnit);

        if (settings == null || !settings.Borders.TryGetValue(path.Substring(ResourcesRoot.Length), out var border)) return;
        var textureSettings = new TextureImporterSettings();
        importer.ReadTextureSettings(textureSettings);
        textureSettings.spriteMeshType = SpriteMeshType.FullRect;
        importer.SetTextureSettings(textureSettings);
        importer.spriteBorder = border;
    }

    private static void ImportSprite(TextureImporter importer, bool pixelArt, int pixelsPerUnit)
    {
        importer.textureType = TextureImporterType.Sprite;
        importer.spriteImportMode = SpriteImportMode.Single;
        importer.mipmapEnabled = false;
        importer.textureCompression = TextureImporterCompression.Uncompressed;
        importer.filterMode = pixelArt ? FilterMode.Point : FilterMode.Bilinear;
        importer.spritePixelsPerUnit = pixelsPerUnit;
    }

    private static Settings ReadSettings()
    {
        try
        {
            if (!File.Exists(SettingsPath)) return null;
            var text = File.ReadAllText(SettingsPath);
            var settings = new Settings { Top = JsonUtility.FromJson<ArtSettings>(text) };
            // JsonUtility cannot read objects keyed by name: folders and borders go through the small reader below
            if (!(Json.Parse(text) is Dictionary<string, object> root)) return settings;
            if (root.TryGetValue("folders", out var folders) && folders is Dictionary<string, object> folderMap)
            {
                foreach (var entry in folderMap)
                {
                    if (!(entry.Value is Dictionary<string, object> values)) continue;
                    settings.Folders[entry.Key] = new FolderSettings
                    {
                        PixelsPerUnit = values.TryGetValue("pixelsPerUnit", out var ppu) && ppu is double d ? (int)d : 0,
                        Pixel = values.TryGetValue("pixel", out var pixel) && pixel is bool b && b,
                    };
                }
            }
            if (root.TryGetValue("borders", out var borders) && borders is Dictionary<string, object> borderMap)
            {
                foreach (var entry in borderMap)
                {
                    if (entry.Value is List<object> ltrb && ltrb.Count == 4 && ltrb.TrueForAll(v => v is double))
                    {
                        // [left, bottom, right, top], the order of Unity's spriteBorder
                        settings.Borders[entry.Key] =
                            new Vector4((float)(double)ltrb[0], (float)(double)ltrb[1], (float)(double)ltrb[2], (float)(double)ltrb[3]);
                    }
                }
            }
            return settings;
        }
        catch (Exception e)
        {
            Debug.LogWarning(
                $"CompassArtImporter: could not read {SettingsPath} ({e.GetType().Name}); using defaults.");
            return null;
        }
    }

    /// <summary>
    /// A minimal JSON reader: objects become <c>Dictionary&lt;string, object&gt;</c>, arrays <c>List&lt;object&gt;</c>,
    /// numbers <c>double</c>. Throws <see cref="FormatException"/> on malformed input.
    /// </summary>
    private sealed class Json
    {
        private readonly string text;
        private int at;

        private Json(string text) => this.text = text;

        public static object Parse(string text)
        {
            var reader = new Json(text);
            var value = reader.Value();
            reader.SkipSpace();
            if (reader.at != text.Length) throw new FormatException("trailing characters");
            return value;
        }

        private object Value()
        {
            SkipSpace();
            if (at >= text.Length) throw new FormatException("unexpected end");
            switch (text[at])
            {
                case '{': return Object();
                case '[': return Array();
                case '"': return String();
                case 't': return Word("true", true);
                case 'f': return Word("false", false);
                case 'n': return Word("null", null);
                default: return Number();
            }
        }

        private Dictionary<string, object> Object()
        {
            var map = new Dictionary<string, object>();
            at++;
            SkipSpace();
            if (Peek('}')) { at++; return map; }
            while (true)
            {
                SkipSpace();
                if (!Peek('"')) throw new FormatException("expected a key");
                var key = String();
                SkipSpace();
                Expect(':');
                map[key] = Value();
                SkipSpace();
                if (Peek(',')) { at++; continue; }
                Expect('}');
                return map;
            }
        }

        private List<object> Array()
        {
            var list = new List<object>();
            at++;
            SkipSpace();
            if (Peek(']')) { at++; return list; }
            while (true)
            {
                list.Add(Value());
                SkipSpace();
                if (Peek(',')) { at++; continue; }
                Expect(']');
                return list;
            }
        }

        private string String()
        {
            var sb = new StringBuilder();
            at++;
            while (at < text.Length)
            {
                var c = text[at++];
                if (c == '"') return sb.ToString();
                if (c != '\\') { sb.Append(c); continue; }
                if (at >= text.Length) break;
                var e = text[at++];
                switch (e)
                {
                    case 'b': sb.Append('\b'); break;
                    case 'f': sb.Append('\f'); break;
                    case 'n': sb.Append('\n'); break;
                    case 'r': sb.Append('\r'); break;
                    case 't': sb.Append('\t'); break;
                    case 'u':
                        if (at + 4 > text.Length) throw new FormatException("bad escape");
                        sb.Append((char)int.Parse(text.Substring(at, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture));
                        at += 4;
                        break;
                    default: sb.Append(e); break;
                }
            }
            throw new FormatException("unterminated string");
        }

        private double Number()
        {
            var start = at;
            while (at < text.Length && "+-0123456789.eE".IndexOf(text[at]) >= 0) at++;
            if (start == at) throw new FormatException("unexpected character");
            return double.Parse(text.Substring(start, at - start), NumberStyles.Float, CultureInfo.InvariantCulture);
        }

        private object Word(string word, object value)
        {
            if (string.CompareOrdinal(text, at, word, 0, word.Length) != 0) throw new FormatException("unexpected word");
            at += word.Length;
            return value;
        }

        private void SkipSpace()
        {
            while (at < text.Length && char.IsWhiteSpace(text[at])) at++;
        }

        private bool Peek(char c) => at < text.Length && text[at] == c;

        private void Expect(char c)
        {
            if (!Peek(c)) throw new FormatException($"expected '{c}'");
            at++;
        }
    }
}
