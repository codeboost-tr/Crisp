using System.Linq;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using Crisp.Services;

namespace Crisp.Views;

public partial class SettingsWindow : Window
{
    public SettingsWindow() => InitializeComponent();

    private void OnDone(object? sender, RoutedEventArgs e) => Close();

    private void OnRevealLogs(object? sender, RoutedEventArgs e)
    {
        var dir = System.IO.Path.Combine(
            System.Environment.GetFolderPath(System.Environment.SpecialFolder.UserProfile), ".crisp", "logs");
        try
        {
            System.IO.Directory.CreateDirectory(dir);
            if (System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows))
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("explorer.exe", $"\"{dir}\"") { UseShellExecute = true });
            else if (System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.OSX))
                System.Diagnostics.Process.Start("open", new[] { dir });
            else
                System.Diagnostics.Process.Start("xdg-open", new[] { dir });
        }
        catch { /* best effort */ }
    }

    private async void OnPickWatchFolder(object? sender, RoutedEventArgs e)
    {
        try
        {
            var folders = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
            {
                Title = "Choose a folder to watch",
                AllowMultiple = false,
            });
            if (folders.FirstOrDefault()?.TryGetLocalPath() is { } path && DataContext is EngineSettings s)
                s.WatchFolderPath = path;
        }
        catch { /* picker cancelled / failed */ }
    }
}
