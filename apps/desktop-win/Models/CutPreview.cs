using System.Collections.Generic;

namespace Crisp.Models;

/// A time range (seconds) the clean will remove — drives the shaded regions in the
/// waveform preview.
public sealed record CutRange(double Start, double End);

/// The data behind the cut-preview waveform: the downsampled audio peaks (0…1, from
/// the engine's `--analyze`), the clip duration, and the ranges that will be cut at the
/// current strength. Computed without transcription or render.
public sealed class CutPreview
{
    public required double Duration { get; init; }
    public required IReadOnlyList<double> Peaks { get; init; }
    public required IReadOnlyList<CutRange> Removed { get; init; }

    public double RemovedSeconds
    {
        get
        {
            double t = 0;
            foreach (var r in Removed) t += r.End - r.Start;
            return t;
        }
    }
}
