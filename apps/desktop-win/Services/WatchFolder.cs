using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;

namespace Crisp.Services;

/// Watches a folder and reports new video files (in-app port of the macOS watch
/// agent). Waits for each file to finish writing before reporting it. The full
/// background-when-closed agent is a Windows-service follow-up.
public sealed class WatchFolder : IDisposable
{
    private static readonly HashSet<string> VideoExts = new(StringComparer.OrdinalIgnoreCase)
    {
        ".mp4", ".mov", ".mkv", ".m4v", ".webm", ".avi", ".flv", ".ts", ".mpg", ".mpeg", ".wmv", ".m2ts",
    };

    private readonly Action<string> _onVideo;
    private readonly HashSet<string> _seen = new(StringComparer.OrdinalIgnoreCase);
    private FileSystemWatcher? _watcher;

    public WatchFolder(Action<string> onVideo) => _onVideo = onVideo;

    public bool IsWatching => _watcher is not null;

    public void Start(string folder)
    {
        Stop();
        if (string.IsNullOrWhiteSpace(folder) || !Directory.Exists(folder)) return;
        _watcher = new FileSystemWatcher(folder)
        {
            IncludeSubdirectories = false,
            NotifyFilter = NotifyFilters.FileName | NotifyFilters.Size,
            EnableRaisingEvents = true,
        };
        _watcher.Created += (_, e) => OnAppeared(e.FullPath);
        _watcher.Renamed += (_, e) => OnAppeared(e.FullPath);
    }

    private async void OnAppeared(string path)
    {
        if (!VideoExts.Contains(Path.GetExtension(path))) return;
        lock (_seen) { if (!_seen.Add(path)) return; }
        if (await WaitStableAsync(path)) _onVideo(path);
    }

    /// True once the file has stopped growing and can be opened for reading (i.e. the
    /// copy/recording finished). Gives up after ~15s.
    private static async Task<bool> WaitStableAsync(string path)
    {
        long last = -1;
        for (var i = 0; i < 30; i++)
        {
            try
            {
                var len = new FileInfo(path).Length;
                if (len > 0 && len == last)
                {
                    using var f = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.Read);
                    return true;
                }
                last = len;
            }
            catch (IOException) { /* still being written */ }
            await Task.Delay(500);
        }
        return false;
    }

    public void Stop()
    {
        if (_watcher is not null)
        {
            _watcher.EnableRaisingEvents = false;
            _watcher.Dispose();
            _watcher = null;
        }
        lock (_seen) _seen.Clear();
    }

    public void Dispose() => Stop();
}
