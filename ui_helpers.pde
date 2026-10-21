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

/** "now", "in 4 min", "in 2 h 15 min" */
String fmtTimeUntil(LocalDateTime time) {
  long minutes = Duration.between(LocalDateTime.now(), time).toMinutes();
  if (minutes <= 0) return "now";
  if (minutes < 60) return "in " + minutes + " min";
  return "in " + (minutes / 60) + " h " + (minutes % 60) + " min";
}
