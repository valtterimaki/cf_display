import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * Decides what is on screen.
 *
 * - Screens are registered with an id and a way to create them.
 * - One screen is home. When home is done, the visit planner (CoreTriggers) gives
 *   the list of screens for a visit. They play one after another, then home again.
 * - When a screen is DONE, the optional transition plays, then the next screen starts.
 * - interrupt() switches right away (hard cut, no transition) and drops the rest of
 *   the visit, so the display goes home after that screen. switchTo() does the same
 *   with the transition.
 *
 * Everything here runs on the draw thread.
 */
public class CoreScheduler {

  private final Map<String, Supplier<CoreScreen>> factories = new LinkedHashMap<>();
  private final Map<String, CoreScreen> keptInstances = new LinkedHashMap<>();
  private final List<String> visitPlan = new ArrayList<>();

  private String homeId = null;
  private Supplier<List<String>> visitPlanner = ArrayList::new;
  private CoreTransition transition = null;

  private CoreScreen current = null;
  private String currentId = null;
  private String nextId = null;
  private boolean inTransition = false;

  // --- setup ---

  public void register(String id, Supplier<CoreScreen> factory) {
    factories.put(id, factory);
  }

  /** The screen everything returns to. */
  public void setHome(String id) {
    homeId = id;
  }

  /** Called when home is done: returns the screens of the next visit, in order. */
  public void setVisitPlanner(Supplier<List<String>> planner) {
    visitPlanner = planner;
  }

  /** Set the animation played between screens. null = none. */
  public void setTransition(CoreTransition transition) {
    this.transition = transition;
  }

  /** Start showing screens, beginning with the given one. Call once after registering. */
  public void start(String id, float now) {
    showScreen(id, now);
  }

  // --- control ---

  /** Switch to a screen right away, without a transition. The rest of the visit is dropped. */
  public void interrupt(String id, float now) {
    if (!isRegistered(id)) return;
    visitPlan.clear();
    inTransition = false;
    System.out.println("[scheduler] interrupt: " + id);
    showScreen(id, now);
  }

  /** Like interrupt(), but plays the transition first. */
  public void switchTo(String id, float now) {
    if (!isRegistered(id)) return;
    visitPlan.clear();
    System.out.println("[scheduler] switch to: " + id);
    startTransition(id, now);
  }

  /** Show a screen after the current one, before anything else that is planned. */
  public void showNext(String id) {
    visitPlan.add(0, id);
  }

  /** Ask the current screen to wrap up early. Does nothing during a transition. */
  public void skip() {
    if (current != null && !inTransition) current.requestOutro();
  }

  // --- per frame ---

  /** Advance and draw. Call once per frame. */
  public void update(float now) {
    if (inTransition) {
      transition.update(now);
      if (transition.isDone()) {
        inTransition = false;
        showScreen(nextId, now);
      }
      return;
    }

    if (current == null) return;
    current.update(now);

    if (current.isDone()) startTransition(pickNext(), now);
  }

  /** Pass an action to the current screen (ignored during a transition). */
  public void sendToScreen(HwAction action) {
    if (current != null && !inTransition) current.onAction(action);
  }

  // --- info for the debug view and input routing ---

  public String currentId() {
    return currentId;
  }

  public CoreScreen currentScreen() {
    return current;
  }

  public boolean isInTransition() {
    return inTransition;
  }

  /** During a transition: the screen coming next. */
  public String nextId() {
    return nextId;
  }

  /** Screens still to come in this visit. */
  public List<String> plannedIds() {
    return new ArrayList<>(visitPlan);
  }

  // --- internals ---

  private String pickNext() {
    if (currentId.equals(homeId)) {
      visitPlan.addAll(visitPlanner.get());
      System.out.println("[scheduler] visit: " + String.join(", ", visitPlan));
    }
    if (visitPlan.isEmpty()) return homeId;
    return visitPlan.remove(0);
  }

  private boolean isRegistered(String id) {
    if (factories.containsKey(id)) return true;
    System.out.println("[scheduler] WARNING: unknown screen '" + id + "'");
    return false;
  }

  private void startTransition(String id, float now) {
    nextId = id;
    if (transition == null) {
      showScreen(id, now);
      return;
    }
    inTransition = true;
    transition.begin(now, currentId, id);
    System.out.println("[scheduler] transition " + currentId + " -> " + id);
  }

  private void showScreen(String id, float now) {
    CoreScreen screen = keptInstances.get(id);
    if (screen == null) {
      screen = factories.get(id).get();
      if (screen.keepsState()) keptInstances.put(id, screen);
    }
    current = screen;
    currentId = id;
    current.begin(now);
  }
}
