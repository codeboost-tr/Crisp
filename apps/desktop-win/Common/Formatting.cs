using System;
using System.Globalization;

namespace Crisp;

/// Small shared formatters (port of macOS Common/Formatting).
public static class Formatting
{
    /// "3:21" for a minute or more, else "4.2s" — for time-saved labels.
    public static string Duration(double seconds)
    {
        if (seconds <= 0) return "0s";
        if (seconds >= 60)
        {
            var t = TimeSpan.FromSeconds(Math.Round(seconds));
            return t.Hours > 0
                ? $"{t.Hours}:{t.Minutes:00}:{t.Seconds:00}"
                : $"{t.Minutes}:{t.Seconds:00}";
        }
        return seconds.ToString("0.#", CultureInfo.InvariantCulture) + "s";
    }
}
