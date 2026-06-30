using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace Crisp.Services;

/// A video editor found on this machine — the target of an editor handoff.
public sealed record VideoEditor(string Name, string LaunchPath);

/// Port of macOS EditorDetector: after an editor-handoff clean, Crisp opens a detected
/// editor and reveals the .fcpxml project (free editors can't auto-import — opening is
/// the whole job). On Windows it probes the standard install locations; on macOS it
/// probes the app bundles too, so the handoff is testable on the dev's Mac.
public static class EditorDetector
{
    public static IReadOnlyList<VideoEditor> Installed()
    {
        var found = new List<VideoEditor>();
        foreach (var (name, path) in Candidates())
            if ((File.Exists(path) || Directory.Exists(path)) && found.All(e => e.Name != name))
                found.Add(new VideoEditor(name, path));
        return found;
    }

    /// The editor we offer to open into (most-capable-import first); null if none found.
    public static VideoEditor? First() => Installed().FirstOrDefault();

    private static IEnumerable<(string Name, string Path)> Candidates()
    {
        if (OperatingSystem.IsWindows())
        {
            var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            // DaVinci Resolve — the FCPXML-import target whose free edition works.
            yield return ("DaVinci Resolve", Path.Combine(pf, "Blackmagic Design", "DaVinci Resolve", "Resolve.exe"));
            // Premiere Pro lives in year-stamped folders ("Adobe Premiere Pro 2025", …) —
            // discover whichever version(s) are installed rather than guessing the year.
            var adobe = Path.Combine(pf, "Adobe");
            if (Directory.Exists(adobe))
                foreach (var dir in SafeDirs(adobe, "Adobe Premiere Pro *"))
                {
                    var exe = Path.Combine(dir, "Adobe Premiere Pro.exe");
                    if (File.Exists(exe)) yield return ("Adobe Premiere Pro", exe);
                }
            yield return ("Shotcut", Path.Combine(pf, "Shotcut", "shotcut.exe"));
            yield return ("Kdenlive", Path.Combine(pf, "kdenlive", "bin", "kdenlive.exe"));
        }
        else if (OperatingSystem.IsMacOS())
        {
            yield return ("DaVinci Resolve", "/Applications/DaVinci Resolve.app");
            yield return ("Final Cut Pro", "/Applications/Final Cut Pro.app");
        }
    }

    private static IEnumerable<string> SafeDirs(string root, string pattern)
    {
        try { return Directory.EnumerateDirectories(root, pattern); }
        catch { return Array.Empty<string>(); }
    }

    public static void Launch(VideoEditor editor)
    {
        try
        {
            if (OperatingSystem.IsMacOS())
                Process.Start("open", new[] { editor.LaunchPath });
            else
                Process.Start(new ProcessStartInfo(editor.LaunchPath) { UseShellExecute = true });
        }
        catch { /* best effort — the row still reveals the project folder */ }
    }
}
