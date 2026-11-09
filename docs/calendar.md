# Calendar

How the calendar data and screen work. Architecture rules are in [CLAUDE.md](../CLAUDE.md).

## Data

- `DataCalendarIcs` reads every link in `config.json` `calendars` (Outlook published ICS,
  Google secret iCal address), expands recurring events with ical4j, converts times to the
  machine's local time, and merges the feeds (same title + start = one event). A failing
  feed keeps its last events.
- `Event.hasCall`: a Teams or Meet link in the event's DESCRIPTION, LOCATION or Teams/Meet
  properties (the camera icon on the calendar).
- Never log or display a feed URL: it's a secret.
- To test without real links, parse a local `.ics` file with the static
  `DataCalendarIcs.parseEvents()`, or serve test files with `python3 -m http.server`.
  `DataCalendarFake` (config `"sources.calendar": "fake"`) places events relative to
  program start; with `"fakeTime": "08:45"` they land in the morning.
- Calendar access is decided: published ICS links. Microsoft Graph is only needed if a
  future account doesn't allow publishing; it would be another `DataCalendar<Provider>` source.

## Screen

- The intro starts with the rooster logo video centered; after a hold it moves to the top
  left corner at half size, and only then the list and timeline appear. It fades in the outro.
- The list shows `DataCalendar.remainingToday()`: today's not-ended, non-all-day events.
- Above the list, a timeline (plain shapes, not a Block) shows all of `today()` on an
  08:00–18:00 grid: ended events gray, overlaps red, events outside the grid drawn past its
  ends. Its intro starts once the list's Block is fully revealed.

## Open: fetch failure warning

- [ ] Design a warning graphic/pattern for the calendar screen when a feed failed. Today one
  failed feed at startup silently shows only the other feed's events (even "NO MORE EVENTS
  TODAY"), and a long outage shows old events as current. TODOs in `screen_calendar.pde`
  and `DataCalendarIcs.java`. A disk cache of the last ICS per feed (`data/cache/`,
  git-ignored) would also cover the startup case.
