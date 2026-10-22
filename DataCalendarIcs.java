import java.io.IOException;
import java.io.StringReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.Temporal;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.CompletableFuture;

import net.fortuna.ical4j.data.CalendarBuilder;
import net.fortuna.ical4j.model.Calendar;
import net.fortuna.ical4j.model.Component;
import net.fortuna.ical4j.model.Period;
import net.fortuna.ical4j.model.Property;
import net.fortuna.ical4j.model.component.VEvent;
import net.fortuna.ical4j.model.property.RecurrenceId;

import processing.data.JSONArray;
import processing.data.JSONObject;

/**
 * Calendar events from published calendar links (ICS feeds).
 *
 * Works with Outlook ("Publish a calendar" → ICS link) and Google
 * ("Secret address in iCal format"). The links are listed in config.json:
 *
 *   "calendars": [
 *     { "name": "Work",   "url": "https://outlook.office365.com/owa/calendar/.../calendar.ics" },
 *     { "name": "Google", "url": "https://calendar.google.com/calendar/ical/.../basic.ics" }
 *   ]
 *
 * The links are secret (anyone who has one can read that calendar), so they
 * only go in config.json, never in the example file or the code.
 *
 * Parsing uses the ical4j library (jars in code/). Recurring events are
 * expanded into single events for the next DAYS_AHEAD days. If one feed fails,
 * its previous events are kept, so one broken link doesn't empty the screen.
 *
 * All feeds download at the same time, and each one updates the store as soon as
 * it arrives: Outlook sometimes doesn't answer for a minute or more, and that
 * shouldn't keep the other calendars off the screen.
 */
public class DataCalendarIcs extends DataSource {

  private static final int DAYS_AHEAD = 7;
  // Outlook usually answers in ~3 s, but the first request after a quiet period
  // took 18 s (it rebuilds the feed). Downloads run in the background, so be generous.
  private static final Duration TIMEOUT = Duration.ofSeconds(60);

  static {
    // ical4j settings. They must be set before ical4j is used for the first time.
    // Keep time zone data in memory (the default cache needs one more library).
    System.setProperty("net.fortuna.ical4j.timezone.cache.impl", "net.fortuna.ical4j.util.MapTimeZoneCache");
    // Accept small format mistakes; real feeds (Outlook especially) have them.
    System.setProperty("ical4j.unfolding.relaxed", "true");
    System.setProperty("ical4j.parsing.relaxed", "true");
    System.setProperty("ical4j.compatibility.outlook", "true");
  }

  /** One calendar link from config, with its last good events. */
  private static class Feed {
    final String name;
    final String url;
    List<DataCalendar.Event> events = new ArrayList<>();

    Feed(String name, String url) {
      this.name = name;
      this.url = url;
    }
  }

  private final DataStore store;
  private final List<Feed> feeds = new ArrayList<>();
  private final HttpClient http = HttpClient.newBuilder()
    .connectTimeout(TIMEOUT)
    .followRedirects(HttpClient.Redirect.NORMAL)
    .build();

  /** `calendars` is the "calendars" list from config.json. */
  public DataCalendarIcs(DataStore store, JSONArray calendars) {
    super("calendar", 300);   // every 5 minutes
    this.store = store;

    for (int i = 0; i < calendars.size(); i++) {
      JSONObject calendar = calendars.getJSONObject(i);
      String name = calendar.getString("name", "Calendar " + (i + 1));
      feeds.add(new Feed(name, calendar.getString("url", "")));
    }
    if (feeds.isEmpty()) {
      System.out.println("[data] WARNING: calendar source is \"ics\" but config.json has no \"calendars\" list");
    }
  }

  protected void fetch() throws Exception {
    ZonedDateTime from = LocalDate.now().atStartOfDay(ZoneId.systemDefault());
    ZonedDateTime to = from.plusDays(DAYS_AHEAD);

    // Start every download at once. Each feed is parsed and stored as soon as it arrives,
    // on the HTTP client's threads.
    List<String> errors = java.util.Collections.synchronizedList(new ArrayList<>());
    List<CompletableFuture<Void>> pending = new ArrayList<>();
    for (Feed feed : feeds) {
      pending.add(download(feed.url)
        .thenAccept(body -> feedArrived(feed, body, from, to))
        .exceptionally(e -> {
          // Just the error type and message: never log the link, it's a secret.
          Throwable cause = e.getCause() != null ? e.getCause() : e;
          String message = cause.getMessage() == null ? "" : " " + cause.getMessage();
          errors.add(feed.name + ": " + cause.getClass().getSimpleName() + message);
          return null;
        }));
    }
    CompletableFuture.allOf(pending.toArray(new CompletableFuture[0])).join();

    if (feeds.isEmpty()) store.setCalendar(new DataCalendar(new ArrayList<>()));
    // Thrown after storing, so the feeds that worked still update.
    if (!errors.isEmpty()) throw new Exception(String.join("; ", errors));
  }

  /** One feed's download finished: parse it and update the store with all feeds' events. */
  private synchronized void feedArrived(Feed feed, String icsText, ZonedDateTime from, ZonedDateTime to) {
    try {
      feed.events = parseEvents(icsText, feed.name, from, to);
    } catch (Exception e) {
      throw new java.util.concurrent.CompletionException(e);   // recorded by fetch() like a failed download
    }
    store.setCalendar(new DataCalendar(mergeFeeds()));
    System.out.println("[data] calendar events: " + feed.name + " " + feed.events.size());
  }

  /**
   * Turns ICS text into single events that overlap `from`..`to`, with recurring
   * events expanded. Separate from downloading, so it can be tested with a file.
   */
  public static List<DataCalendar.Event> parseEvents(String icsText, String calendarName,
                                                     ZonedDateTime from, ZonedDateTime to) throws Exception {
    Calendar ics = new CalendarBuilder().build(new StringReader(icsText));
    List<VEvent> vevents = ics.getComponents(Component.VEVENT);

    // When one occurrence of a recurring event is changed (moved, renamed),
    // the feed has it as a separate VEVENT with the same UID and a RECURRENCE-ID
    // telling which original start it replaces. Collect those, so the original
    // occurrence can be left out below.
    Set<String> replacedOccurrences = new HashSet<>();
    for (VEvent vevent : vevents) {
      LocalDateTime replaces = recurrenceId(vevent);
      if (replaces != null) replacedOccurrences.add(property(vevent, Property.UID) + "@" + replaces);
    }

    Period<ZonedDateTime> window = new Period<>(from, to);
    List<DataCalendar.Event> events = new ArrayList<>();

    for (VEvent vevent : vevents) {
      if (property(vevent, Property.STATUS).equals("CANCELLED")) continue;

      String title = property(vevent, Property.SUMMARY).trim();
      if (title.isEmpty()) title = "(no title)";
      boolean isReplacement = recurrenceId(vevent) != null;

      // One period for a normal event, one per occurrence for a recurring one.
      Set<Period<Temporal>> occurrences = vevent.calculateRecurrenceSet(window);
      for (Period<Temporal> occurrence : occurrences) {
        LocalDateTime start = toLocal(occurrence.getStart());
        String occurrenceKey = property(vevent, Property.UID) + "@" + start;
        if (!isReplacement && replacedOccurrences.contains(occurrenceKey)) continue;

        boolean allDay = occurrence.getStart() instanceof LocalDate;
        events.add(new DataCalendar.Event(calendarName, title, start, toLocal(occurrence.getEnd()),
          allDay, mentionsCall(vevent)));
      }
    }
    return events;
  }

  // --- helpers ---

  /** Starts downloading a feed. Completes with the ICS text, or fails (timeout, HTTP error...). */
  private CompletableFuture<String> download(String url) {
    if (url.isEmpty()) return CompletableFuture.failedFuture(new IOException("no url in config.json"));
    // Some apps hand out webcal:// links; they are plain https underneath.
    if (url.startsWith("webcal://")) url = "https://" + url.substring("webcal://".length());

    HttpRequest request = HttpRequest.newBuilder(URI.create(url)).timeout(TIMEOUT).GET().build();
    return http.sendAsync(request, HttpResponse.BodyHandlers.ofString()).thenApply(response -> {
      if (response.statusCode() != 200) {
        throw new java.util.concurrent.CompletionException(new IOException("HTTP " + response.statusCode()));
      }
      return response.body();
    });
  }

  /** All feeds' events together. The same meeting in two calendars is kept once. */
  private List<DataCalendar.Event> mergeFeeds() {
    Map<String, DataCalendar.Event> byKey = new LinkedHashMap<>();
    for (Feed feed : feeds) {
      for (DataCalendar.Event event : feed.events) byKey.putIfAbsent(event.key(), event);
    }
    return new ArrayList<>(byKey.values());
  }

  /** A property's text, e.g. the SUMMARY. Empty if the event doesn't have it. */
  private static String property(VEvent vevent, String name) {
    Optional<Property> property = vevent.getProperty(name);
    return property.map(Property::getValue).orElse("");
  }

  /**
   * True if a Teams or Meet call is attached. Outlook puts the Teams link in DESCRIPTION
   * and LOCATION, Google the Meet link in DESCRIPTION and X-GOOGLE-CONFERENCE.
   */
  private static boolean mentionsCall(VEvent vevent) {
    String text = property(vevent, Property.DESCRIPTION) + " " + property(vevent, Property.LOCATION)
      + " " + property(vevent, "X-MICROSOFT-SKYPETEAMSMEETINGURL") + " " + property(vevent, "X-GOOGLE-CONFERENCE");
    return text.contains("teams.microsoft.com") || text.contains("meet.google.com");
  }

  /** The original start this event replaces, or null if it isn't a replacement. */
  private static LocalDateTime recurrenceId(VEvent vevent) {
    Optional<RecurrenceId<Temporal>> id = vevent.getProperty(Property.RECURRENCE_ID);
    return id.map(value -> toLocal(value.getDate())).orElse(null);
  }

  /** Any iCalendar date or time → local time on this machine. */
  private static LocalDateTime toLocal(Temporal time) {
    ZoneId here = ZoneId.systemDefault();
    if (time instanceof ZonedDateTime) return ((ZonedDateTime) time).withZoneSameInstant(here).toLocalDateTime();
    if (time instanceof OffsetDateTime) return ((OffsetDateTime) time).atZoneSameInstant(here).toLocalDateTime();
    if (time instanceof Instant) return LocalDateTime.ofInstant((Instant) time, here);
    if (time instanceof LocalDate) return ((LocalDate) time).atStartOfDay();   // all-day event
    return LocalDateTime.from(time);   // "floating" time with no zone: already local
  }
}
