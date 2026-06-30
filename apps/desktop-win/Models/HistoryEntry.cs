using System;
using System.IO;
using System.Text.Json.Serialization;

namespace Crisp.Models;

/// One past clean, for the History window. Port of CrispCore/Models/HistoryEntry.swift —
/// persisted as one JSON object per line in ~/.crisp/history.jsonl.
public sealed record HistoryEntry
{
    public DateTime Date { get; init; }
    public string InputPath { get; init; } = "";
    public string OutputPath { get; init; } = "";
    public double OrigSeconds { get; init; }
    public double SavedSeconds { get; init; }
    public int Fillers { get; init; }
    public int Pauses { get; init; }
    public int Retakes { get; init; }

    [JsonIgnore] public string InputName => Path.GetFileName(InputPath);
    [JsonIgnore] public string SavedText => Formatting.Duration(SavedSeconds);
    [JsonIgnore] public string DateText => Date.ToLocalTime().ToString("MMM d, h:mm tt");

    [JsonIgnore]
    public string CutsText
    {
        get
        {
            var parts = new System.Collections.Generic.List<string>();
            if (Fillers > 0) parts.Add($"{Fillers} filler{(Fillers == 1 ? "" : "s")}");
            if (Retakes > 0) parts.Add($"{Retakes} retake{(Retakes == 1 ? "" : "s")}");
            if (Pauses > 0) parts.Add($"{Pauses} pause{(Pauses == 1 ? "" : "s")}");
            return parts.Count > 0 ? string.Join(" · ", parts) : "";
        }
    }
}
