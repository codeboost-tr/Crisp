using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Data.Core;
using Avalonia.Data.Core.Plugins;
using System.Linq;
using Avalonia.Markup.Xaml;
using Crisp.ViewModels;
using Crisp.Views;

namespace Crisp;

public partial class App : Application
{
    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var vm = new MainWindowViewModel();
            desktop.MainWindow = new MainWindow { DataContext = vm };

            // "Open With" / file-association: video paths on the command line are queued
            // (both Windows and macOS pass argv).
            var files = desktop.Args?.Where(a => !a.StartsWith('-') && System.IO.File.Exists(a)).ToList();
            if (files is { Count: > 0 }) vm.AddFiles(files);
        }

        base.OnFrameworkInitializationCompleted();
    }
}