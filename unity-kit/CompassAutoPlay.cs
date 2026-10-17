using System.IO;
using UnityEngine;

/// <summary>
/// Compass unity-kit — do not edit in projects. The auto-play switch that screenshots, delivery videos and the
/// gameplay test use: when it is on, the game plays itself through the project's AutoPlayer.
/// It turns on in three ways: the deep link &lt;scheme&gt;://autoplay (Android), a file named
/// <see cref="FlagFile"/> in Application.persistentDataPath at start-up (iOS simulator), or <see cref="ForTests"/>.
/// </summary>
public static class CompassAutoPlay
{
    public const string FlagFile = "compass-autoplay";
    public const string StartedMarker = "CMPOSE_AUTOPLAY started";

    public static bool Requested { get; private set; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    private static void ReadFlagFile()
    {
        Requested = File.Exists(Path.Combine(Application.persistentDataPath, FlagFile));
    }

    /// <summary>Called by the "autoplay" deep link route.</summary>
    public static void Request() => Requested = true;

    /// <summary>PlayMode tests switch auto-play on and off directly.</summary>
    public static void ForTests(bool on) => Requested = on;

    /// <summary>Log once when the AutoPlayer actually starts playing; Compass waits for this line.</summary>
    public static void LogStarted() => Debug.Log(StartedMarker);
}
