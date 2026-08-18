import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { next } from "@ember/runloop";
import Service from "@ember/service";
import {
  type ElementDragPayload,
  monitorForElements,
} from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import { isTesting } from "discourse/lib/environment";
import { reportClientError } from "discourse/lib/report-client-error";

/** The in-flight element drag, as the source described it. */
export interface DragPayload {
  /** Discriminator string set by the source. */
  type: string;

  /** Arbitrary payload the source attached to the drag. */
  data: Record<string, unknown>;

  /**
   * The element that originated the drag. The service's own monitor always
   * supplies one; `setCurrentDrag` is public and validates nothing, so a caller
   * driving the service by hand may not.
   */
  element: HTMLElement | null;
}

/**
 * Where the dragged body travels when a source registered a drag handle.
 *
 * The handle is what the underlying library registers, so that the row keeps
 * neither `draggable="true"` nor the unselectable text that attribute brings.
 * The body is the row the handle stands for, and it is what a target reports as
 * `source.element` and compares for `acceptsSelf`.
 *
 * Lives here with the rest of the shared vocabulary because both the source and
 * the target need it, and importing one modifier from the other would close a
 * cycle.
 */
export const DRAG_BODY = "discourse:dragBody";

/**
 * The type a drag answers to in an `accepts` / `types` filter.
 *
 * @param data - A drag payload's `data`, as the underlying library carries it.
 */
export function dragTypeOf(data?: Record<string, unknown>) {
  return data?.type as string | undefined;
}

/**
 * Calls a consumer callback that is allowed to throw, so nothing it throws reaches the
 * caller.
 *
 * The library calls us from inside its own event dispatch and reaches its end-of-drag
 * cleanup on the next statement, unguarded. An escaping exception skips that cleanup and
 * is reported as uncaught, where nothing in the application can handle it.
 *
 * The source's deferred end-of-drag pair needs the same guard: its second callback and its
 * waiting teardown both still have to run.
 *
 * Reported through `discourse-error`, which attributes it to whichever theme or plugin it
 * came from. Under test it is raised as well, so a consumer's mistake fails the test it
 * happened in rather than passing quietly.
 *
 * @param run - The consumer callback.
 * @param fallback - Returned when it throws. Omit for a callback returning nothing. Give a
 *   gate the conservative answer, since a gate that threw has decided nothing.
 */
export function consumerMayThrow<T>(run: () => T, fallback?: T): T | undefined {
  try {
    return run();
  } catch (error) {
    reportClientError(error, "broken_drag_and_drop_alert");
    if (isTesting()) {
      // Thrown here, the library would skip the cleanup that ends the drag, and
      // it starts no new drag while it still thinks one is running.
      next(() => {
        throw error;
      });
    }
    return fallback;
  }
}

/**
 * A drag source as consumers read it: routing keys lifted out and the dragged
 * body in place of the grip that carried it.
 */
export interface NormalizedDragSource {
  /** The source's discriminator, or `null` when the drag carries none. */
  type: string | null;

  /** The payload the source attached to the drag. */
  data: Record<string, unknown>;

  /** The dragged element, or `null` when the drag has none. */
  element: Element | null;
}

/**
 * Resolves a raw payload into the shape every reader reports.
 *
 * This is the single place the routing vocabulary above is interpreted. The
 * drop target, the monitor modifier, and this service all consume it, so a
 * payload reads identically wherever a consumer meets it — a shape one of them
 * derived by hand drifted once already.
 *
 * @param source - The payload as the underlying library carries it.
 * @param fallbackElement - Reported as `element` when the drag itself has none;
 *   a drop target passes itself here.
 */
export function normalizeDragSource(
  source: ElementDragPayload,
  fallbackElement?: Element
): NormalizedDragSource {
  // Lifted out first: the body is routing, not payload, so no consumer should
  // ever iterate onto it.
  const { [DRAG_BODY]: body, ...data } = source.data ?? {};

  return {
    // The underlying library types every payload value as `unknown`, because
    // anything registering a draggable with it can put anything there.
    // `dDragAndDropSource` always stamps its discriminator as a string.
    type: (data.type ?? null) as string | null,
    data,
    // A source that registered a handle publishes the body it stands for, so a
    // consumer receives the element the user is moving rather than the grip
    // they happened to press.
    element: (body as Element) ?? source.element ?? fallbackElement ?? null,
  };
}

/**
 * Tracks the in-flight `dDragAndDropSource` / `dDragAndDropTarget` element
 * drag pair.
 *
 * Element drag state is populated first-hand by the singleton monitor this
 * service registers on construction. Per-element modifiers do not each carry
 * their own monitor; this is the observer.
 *
 * Lives as a service rather than a module slot so test setup
 * (`setupTest` / `setupRenderingTest`) gets a fresh instance per test.
 *
 * Use this to READ drag state for rendering. Use `dDragAndDropMonitor` to
 * RESPOND to a drag imperatively — rendering from its callbacks means
 * hand-maintaining state this service already keeps.
 */
export default class DragAndDropService extends Service {
  @tracked currentDrag: DragPayload | null = null;

  constructor(...args: ConstructorParameters<typeof Service>) {
    super(...args);
    // Registering a monitor subscribes to the library's drag stream. It does
    // NOT mount the element adapter: only registering a draggable does that, so
    // a page with targets and monitors but no draggable has no element drag
    // listener bound at all.
    //
    // The monitor is the sole observer of in-flight element drags — the source
    // modifier does not push state here, the service derives it first-hand.
    // Only drags carrying a `type` are tracked, so a foreign draggable with
    // none of its own stays invisible here.
    const cleanup = monitorForElements({
      canMonitor: ({ source }) =>
        !this.isDestroying &&
        !this.isDestroyed &&
        dragTypeOf(source.data) != null,
      onDragStart: ({ source }) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        const normalized = normalizeDragSource(source);
        this.setCurrentDrag({
          // `canMonitor` above only admits sources whose `type` is set, so the
          // `null` a typeless drag would normalize to cannot reach here.
          type: normalized.type as string,
          data: normalized.data,
          element: normalized.element as HTMLElement,
        });
      },
      onDrop: () => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        this.clearCurrentDrag();
      },
    });
    registerDestructor(this, cleanup);
  }

  /** Whether an element drag is in flight. */
  get isDragging() {
    return !!this.currentDrag;
  }

  /**
   * Stores the in-flight drag's payload. Called by the service's own
   * `monitorForElements` on drag start.
   */
  setCurrentDrag(payload: DragPayload) {
    this.currentDrag = payload;
  }

  /**
   * Clears the in-flight drag. Called by the service's own
   * `monitorForElements` on drop — fires regardless of whether the drop
   * landed on a target or was cancelled.
   */
  clearCurrentDrag() {
    this.currentDrag = null;
  }

  /**
   * Does the in-flight drag's `type` match the supplied `accepts` filter?
   *
   * The opposite default from the drop target and the monitor, on purpose. There an
   * omitted filter accepts every drag, because a target that filters nothing is a real
   * configuration.
   *
   * Here a nullish filter means the caller has not decided, so it matches nothing.
   *
   * @param accepts - Single type string or array. Nullish matches nothing.
   */
  accepts(accepts?: string | string[] | null) {
    if (!this.currentDrag || !accepts) {
      return false;
    }
    if (Array.isArray(accepts)) {
      return accepts.includes(this.currentDrag.type);
    }
    return this.currentDrag.type === accepts;
  }
}

/**
 * Test-only: end any drag the underlying library still considers in flight.
 *
 * If a test starts a drag (`dragstart`) but the matching `dragend` / `drop`
 * never reaches the library — e.g. the source element is torn down first, or an
 * assertion throws mid-drag — its global drag state stays active and the next
 * test's `dragstart` is silently ignored. Dispatching a `dragend` lets the
 * lifecycle listener tear the drag down. A no-op when nothing is in flight.
 * Call from the global test teardown.
 */
export function resetDragAndDropForTesting() {
  // The library binds its drag-phase listeners on `window` (capture) only
  // while a drag is active, and both dispatches are no-ops when nothing is in
  // flight.
  //
  // The order is load-bearing. `dragend` clears the target stack before
  // dispatching its cancellation, so no target `onDrop` runs; a bare `drop`
  // takes the cancel path only when no drop target is under the cursor, and with
  // one it dispatches a real drop, running target callbacks during teardown.
  // Sending `dragend` first leaves the following `drop` a no-op, because the
  // listeners are unbound by then.
  //
  // This does not silence everything: the library still dispatches its own
  // `onDrop` to the source and to monitors. A source wrapper deferring its
  // consumer callbacks is what would then schedule them during teardown, and
  // guarding that is its job rather than this function's —
  // `registerDragAndDropSource` cancels the pending task from its own cleanup.
  const make = (type: string) =>
    typeof DragEvent === "function"
      ? new DragEvent(type, { bubbles: true })
      : new Event(type, { bubbles: true });
  for (const type of ["dragend", "drop"]) {
    window.dispatchEvent(make(type));
  }
}
