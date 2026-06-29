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
