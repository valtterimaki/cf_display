// Self-check of the screen flow logic (timer, presence, visits). Runs at startup when debug is on.

void flowSelfCheck() {
  // Knob steps: 5 s up to 1 min, 1 min up to 60 min, 5 min above, max 10 h
  selfCheck(CoreTimer.stepUp(55) == 60 && CoreTimer.stepUp(60) == 120, "timer steps around 1 min");
  selfCheck(CoreTimer.stepUp(3600) == 3900 && CoreTimer.stepDown(3900) == 3600, "timer steps above 60 min");
  selfCheck(CoreTimer.stepDown(3600) == 3540 && CoreTimer.stepDown(60) == 55, "timer steps down");
  selfCheck(CoreTimer.stepDown(3) == 0 && CoreTimer.stepUp(CoreTimer.MAX) == CoreTimer.MAX, "timer limits");

  // Starts 3 s after the last turn; turning while running pauses and adjusts the remaining time
  CoreTimer t = new CoreTimer();
  t.turn(1, 0);
  t.update(2.9);
  selfCheck(t.state() == CoreTimer.State.ADJUSTING, "timer waits for the delay");
  t.update(3);
  selfCheck(t.state() == CoreTimer.State.RUNNING && t.remaining(5) == 3, "timer runs after the delay");
  t.turn(1, 5);
  selfCheck(t.state() == CoreTimer.State.ADJUSTING && t.remaining(6) == 8, "turning pauses and adjusts");
  t.update(8);
  selfCheck(!t.update(15.9) && t.update(16) && t.isRinging(), "timer rings at zero");
  t.clearAlarm();
  t.turn(1, 20);
  t.turn(-1, 21);
  t.update(30);
  selfCheck(t.state() == CoreTimer.State.IDLE, "turning to zero resets");

  // Days start at 04:00
  CorePresence p = new CorePresence();
  LocalDateTime day = LocalDateTime.of(2026, 11, 9, 0, 0);
  selfCheck(p.wake(day.plusHours(3), 0), "first wake ever");
  selfCheck(p.wake(day.plusHours(5), 10), "04:00 starts a new day");
  selfCheck(!p.wake(day.plusHours(12), 20), "later wake the same day");
  selfCheck(p.presentFor(80) == 60 && p.awayFor(80) == 60, "presence times count from the wake");

  // Bus timetables only from 14:00
  CoreTriggers rules = new CoreTriggers(new DataStore(), new CoreScheduler(), new CorePresence(), new CoreTimer());
  selfCheck(!rules.rotationNow(day.plusHours(13).plusMinutes(59)).contains("bus"), "no bus before 14:00");
  selfCheck(rules.rotationNow(day.plusHours(14)).contains("bus"), "bus from 14:00");

  // Event alert from 15 min before an event until 10 min after it started; all-day events don't count
  DataStore calendarStore = new DataStore();
  LocalDateTime meeting = day.plusHours(10);
  java.util.List<DataCalendar.Event> events = new ArrayList<DataCalendar.Event>();
  events.add(new DataCalendar.Event("", meeting, meeting.plusHours(1), false, false));
  events.add(new DataCalendar.Event("", day, day.plusDays(1), true, false));
  calendarStore.setCalendar(new DataCalendar(events));
  CoreTriggers alerts = new CoreTriggers(calendarStore, new CoreScheduler(), new CorePresence(), new CoreTimer());
  selfCheck(!alerts.eventAlertDue(meeting.minusMinutes(16)), "no alert 16 min before");
  selfCheck(alerts.eventAlertDue(meeting.minusMinutes(14)), "alert 14 min before");
  selfCheck(alerts.eventAlertDue(meeting.plusMinutes(9)), "alert 9 min after start");
  selfCheck(!alerts.eventAlertDue(meeting.plusMinutes(11)), "no alert 11 min after start");

  println("[flow] self-check ok");
}
