using System;
using System.Diagnostics;
using System.IO;

namespace Crisp.Services;

/// Explorer right-click "Clean with Crisp" on video files — the Windows port of the
/// macOS Quick Action. Registered per-user via reg.exe (no extra dependency, no admin),
/// pointing at the app's existing "Open With" path (a file path on the command line is
/// queued, see App.OnFrameworkInitializationCompleted). No-op off Windows.
public static class ShellIntegration
{
    private static readonly string[] Extensions = { ".mp4", ".mov", ".mkv", ".m4v", ".webm", ".avi", ".ts", ".wmv" };
    private const string Verb = "CleanWithCrisp";

    private static string KeyFor(string ext) =>
        $@"HKCU\Software\Classes\SystemFileAssociations\{ext}\shell\{Verb}";

    public static bool IsInstalled()
    {
        if (!OperatingSystem.IsWindows()) return false;
        return Reg("query", KeyFor(Extensions[0])) == 0;
    }

    public static void Install()
    {
        if (!OperatingSystem.IsWindows()) return;
        var exe = Environment.ProcessPath ?? Path.Combine(AppContext.BaseDirectory, "Crisp.exe");
        foreach (var ext in Extensions)
        {
            var key = KeyFor(ext);
            Reg("add", key, "/ve", "/d", "Clean with Crisp", "/f");
            Reg("add", key, "/v", "Icon", "/d", exe, "/f");
            Reg("add", $@"{key}\command", "/ve", "/d", $"\"{exe}\" \"%1\"", "/f");
        }
    }

    public static void Uninstall()
    {
        if (!OperatingSystem.IsWindows()) return;
        foreach (var ext in Extensions)
            Reg("delete", KeyFor(ext), "/f");
    }

    private static int Reg(params string[] args)
    {
        try
        {
            var psi = new ProcessStartInfo("reg.exe") { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
            foreach (var a in args) psi.ArgumentList.Add(a);
            using var p = Process.Start(psi);
            if (p is null) return -1;
            p.WaitForExit(5000);
            return p.HasExited ? p.ExitCode : -1;
        }
        catch { return -1; }
    }
}
