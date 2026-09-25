import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.PriorityBlockingQueue;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Supplier;

/**
 * Decides what is on screen.
 *
 * - Screens are registered with an id and a way to create them.
 * - Anything (data sources, buttons, timers) can queue a screen with request().
 *   Requests never interrupt: the current screen always finishes first.
 * - When a screen is DONE, the optional transition plays, then the next screen starts:
 *     1. the highest-priority queued request, or
 *     2. the fallback rule: cycle through registered screens in order.
 *
 * request() is thread-safe, so background data sources can call it directly.
 */
public class CoreScheduler {

  public static final int PRIORITY_LOW = 0;
  public static final int PRIORITY_NORMAL = 1;
  public static final int PRIORITY_HIGH = 2;

  private final Map<String, Supplier<CoreScreen>> factories = new LinkedHashMap<>();
  private final Map<String, CoreScreen> keptInstances = new LinkedHashMap<>();
  private final PriorityBlockingQueue<Request> queue = new PriorityBlockingQueue<>();
  private final AtomicLong requestCounter = new AtomicLong();

  private CoreTransition transition = null;

  private CoreScreen current = null;
  private String currentId = null;
  private String nextId = null;
  private boolean inTransition = false;
  private int cycleIndex = -1;

  // --- setup ---

  /** Register a screen. Order of registration = order of the fallback cycle. */
  public void register(String id, Supplier<CoreScreen> factory) {
    factories.put(id, factory);
  }

  /** Set the animation played between screens. null = none. */
  public void setTransition(CoreTransition transition) {
    this.transition = transition;
  }

  /** Start showing screens. Call once after registering. */
  public void start(float now) {
    showScreen(pickNext(), now);
  }

  // --- control ---

  /** Queue a screen to be shown after the current one. Ignored if already queued. */
  public void request(String id, int priority) {
    if (!factories.containsKey(id)) {
      System.out.println("[scheduler] WARNING: unknown screen '" + id + "'");
      return;
    }
    for (Request r : queue) {
      if (r.id.equals(id)) return;
    }
    queue.add(new Request(id, priority, requestCounter.getAndIncrement()));
    System.out.println("[scheduler] queued " + id + " (priority " + priority + ")");
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

    if (current.isDone()) {
      nextId = pickNext();
      if (transition != null) {
        inTransition = true;
        transition.begin(now, currentId, nextId);
        System.out.println("[scheduler] transition " + currentId + " -> " + nextId);
      } else {
        showScreen(nextId, now);
      }
    }
  }

  /** Registered screen ids, in registration order. */
  public List<String> registeredIds() {
    return new ArrayList<>(factories.keySet());
  }

  /** Pass an action to the current screen (ignored during a transition). */
  public void sendToScreen(HwAction action) {
    if (current != null && !inTransition) current.onAction(action);
  }

  // --- info for the debug view ---

  public String currentId() {
    return currentId;
  }

  public CoreScreen currentScreen() {
    return current;
  }

  public boolean isInTransition() {
    return inTransition;
  }

  /** Queued screen ids, highest priority first. */
  public List<String> queuedIds() {
    List<Request> sorted = new ArrayList<>(queue);
    sorted.sort(null);
    List<String> ids = new ArrayList<>();
    for (Request r : sorted) ids.add(r.id);
    return ids;
  }

  // --- internals ---

  private String pickNext() {
    Request queued = queue.poll();
    if (queued != null) {
      System.out.println("[scheduler] next: " + queued.id + " (from queue)");
      return queued.id;
    }
    List<String> ids = new ArrayList<>(factories.keySet());
    if (ids.isEmpty()) throw new IllegalStateException("No screens registered");
    cycleIndex = (cycleIndex + 1) % ids.size();
    String id = ids.get(cycleIndex);
    System.out.println("[scheduler] next: " + id + " (cycle)");
    return id;
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

  /** A queued screen. Sorted by priority (high first), then by arrival (old first). */
  private static class Request implements Comparable<Request> {
    final String id;
    final int priority;
    final long order;

    Request(String id, int priority, long order) {
      this.id = id;
      this.priority = priority;
      this.order = order;
    }

    public int compareTo(Request other) {
      if (priority != other.priority) return other.priority - priority;
      return Long.compare(order, other.order);
    }
  }
}
