using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Media.Immutable;
using Crisp.Models;

namespace Crisp.Views.Controls;

/// Draws the cut-preview waveform: audio peaks as vertical bars, with the ranges the
/// clean will remove shaded in a "cut" colour. Read-only (the interactive keep/cut
/// editor builds on this). Bars are coloured per-bucket by whether their time falls in
/// a removed range, so the user sees exactly what disappears.
public sealed class WaveformView : Control
{
    public static readonly StyledProperty<CutPreview?> PreviewProperty =
        AvaloniaProperty.Register<WaveformView, CutPreview?>(nameof(Preview));

    public CutPreview? Preview
    {
        get => GetValue(PreviewProperty);
        set => SetValue(PreviewProperty, value);
    }

    static WaveformView()
    {
        AffectsRender<WaveformView>(PreviewProperty);
        AffectsMeasure<WaveformView>(PreviewProperty);
    }

    public override void Render(DrawingContext context)
    {
        base.Render(context);
        var p = Preview;
        var bounds = Bounds;
        if (p is null || p.Peaks.Count == 0 || bounds.Width <= 0 || bounds.Height <= 0 || p.Duration <= 0)
            return;

        var keep = new ImmutableSolidColorBrush(Color.FromRgb(0x5A, 0x9C, 0xF8)); // accent-ish
        var cut = new ImmutableSolidColorBrush(Color.FromArgb(0xCC, 0xE0, 0x66, 0x66)); // red
        var n = p.Peaks.Count;
        var w = bounds.Width;
        var h = bounds.Height;
        var mid = h / 2;
        var barW = Math.Max(1.0, w / n - 1);

        for (var i = 0; i < n; i++)
        {
            var x = i / (double)n * w;
            // The time at this bucket's centre decides keep vs cut.
            var t = (i + 0.5) / n * p.Duration;
            var amp = Math.Clamp(p.Peaks[i], 0, 1);
            var barH = Math.Max(1.0, amp * (h - 2));
            var rect = new Rect(x, mid - barH / 2, barW, barH);
            context.FillRectangle(InRemoved(p, t) ? cut : keep, rect);
        }
    }

    private static bool InRemoved(CutPreview p, double t)
    {
        foreach (var r in p.Removed)
            if (t >= r.Start && t <= r.End) return true;
        return false;
    }
}
