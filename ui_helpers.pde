// Shared drawing and formatting helpers used by screens.
//
// Formatting always uses the same style (dot as decimal separator, 24 h clock),
// so the display looks identical regardless of each machine's regional settings.

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.Duration;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("HH:mm");
final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("d.M.yyyy");

/** 12.345 with 1 decimal → "12.3" */
String fmtDecimal(float value, int decimals) {
  return String.format(Locale.ROOT, "%." + decimals + "f", value);
}

/** Temperature rounded to whole degrees, e.g. "-3°" */
String fmtTemperature(float celsius) {
  return round(celsius) + "°";
}

/** "09:30" */
String fmtTime(LocalDateTime time) {
  return time.format(TIME_FORMAT);
}

/** "21.10.2026" */
String fmtDate(LocalDate date) {
  return date.format(DATE_FORMAT);
}

/** Length of an event: "45 min", "1 h", "1 h 30 min" */
String fmtDuration(LocalDateTime start, LocalDateTime end) {
  long minutes = Duration.between(start, end).toMinutes();
  if (minutes < 60) return minutes + " min";
  if (minutes % 60 == 0) return (minutes / 60) + " h";
  return (minutes / 60) + " h " + (minutes % 60) + " min";
}

/** Timer time: "4:05", "1:02:03", with tenths "4:05.3" */
String fmtTimer(float seconds, boolean tenths) {
  int totalTenths = (int) (seconds * 10);
  int total = totalTenths / 10;
  int h = total / 3600;
  int m = (total / 60) % 60;
  int s = total % 60;
  String text = h > 0 ? h + ":" + nf(m, 2) + ":" + nf(s, 2) : m + ":" + nf(s, 2);
  if (tenths) text += "." + (totalTenths % 10);
  return text;
}
