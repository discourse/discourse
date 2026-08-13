import { triggerEvent } from "@ember/test-helpers";

/** A point on the viewport, in the shape every drag event has to carry. */
interface ClientPoint {
  clientX: number;
  clientY: number;
}

/**
 * Returns the center-point client coordinates of an element, for realistic
 * synthetic drag events.
 *
 * Every drag event dispatched in a test must carry finite `clientX` /
 * `clientY`: the drag monitor resolves the pointer via `elementsFromPoint`,
 * which throws on non-finite values. A real drag always has coordinates, so the
 * test must supply them too.
 *
 * @param selector - CSS selector for the element to measure.
 * @returns The element's center point.
 */
export function centerOf(selector: string): ClientPoint {
  // A selector matching nothing is a test bug; failing on the next line names it
  // directly, where a guard here would report a missing coordinate instead.
  const rect = (
    document.querySelector(selector) as Element
  ).getBoundingClientRect();
  return {
    clientX: rect.left + rect.width / 2,
    clientY: rect.top + rect.height / 2,
  };
}

/**
 * Throws unless both ends of a drag are really registered with the primitives.
 *
 * Dispatching a drag at an element that is not a source, or at one that is not a
 * target, does nothing at all. A test whose assertion is that nothing happened
 * then passes for the wrong reason, and keeps passing after the registration is
 * removed outright. Failing loudly here names which end was unwired instead.
 *
 * @param sourceSelector - CSS selector for the element the drag starts on.
 * @param targetSelector - CSS selector for the element it is dropped on.
 */
export function assertDragRegistered(
  sourceSelector: string,
  targetSelector: string
) {
  const source = document.querySelector(sourceSelector);
  const target = document.querySelector(targetSelector);

  if (!source?.hasAttribute("data-drag-source")) {
    throw new Error(
      `${sourceSelector} is not a registered drag source, so this drag would do nothing`
    );
  }
  if (!target?.hasAttribute("data-drop-target")) {
    throw new Error(
      `${targetSelector} is not a registered drop target, so this drag would do nothing`
    );
  }
}

/**
 * Dispatches one synthetic drag event and then waits a single animation frame
 * before resolving.
 *
 * The frame wait is the whole point of this wrapper. The underlying drag
 * library batches its `onDragStart` / `onDrag` consumer callbacks through
 * `requestAnimationFrame` (via `raf-schd`), and Ember's `settled()` does not
 * pump animation frames. So immediately after a synthetic `dragstart` /
 * `dragover` those callbacks have not fired yet. Awaiting a real frame lets the
 * batched callback run before the caller's next step or assertion — our frame
 * resolves after the library's already-queued one, so the queued callback is
 * guaranteed to have fired. Bundling the wait here keeps it out of the test
 * bodies.
 *
 * @param target - CSS selector for the event target, or the element itself when
 *   the caller has already resolved it.
 * @param type - The drag event type (e.g. `"dragstart"`, `"drop"`).
 * @param options - Forwarded to `triggerEvent`; must include the shared
 *   `dataTransfer` and finite client coordinates (see {@link centerOf}).
 */
export async function dragEvent(
  target: string | Element,
  type: string,
  options?: Record<string, unknown>
) {
  await triggerEvent(target as Element, type, options);
  await new Promise((resolve) => requestAnimationFrame(resolve));
}

/**
 * Drives a complete HTML5 drag/drop cycle from a source element to a target
 * element through the test runner.
 *
 * The drag library wraps the native DnD events, so its callbacks fire when the
 * matching DOM events are dispatched. Each event is sent via {@link dragEvent},
 * so a frame is flushed after every step. That single rule covers both timing
 * traps at once: the rAF-batched `onDragStart` fires before the move, and the
 * rAF-batched `onDrag` fires before the `drop` (which would otherwise cancel a
 * still-pending `onDrag` and never let it be observed). The source and target
 * center coordinates are computed via {@link centerOf}, then independently
 * overridden when a test needs a more precise pointer location. A bare center
 * only exercises the `after` branch of strict midpoint comparisons.
 *
 * `sourceSelector` names the row, the way a consumer and a reader both think of
 * it. A row that scopes its drag to a handle registers the handle rather than
 * itself, so the browser would dispatch `dragstart` there — this resolves that
 * and dispatches on whichever element the registration actually sits on, so a
 * caller never has to know which shape a surface used.
 *
 * @param sourceSelector - CSS selector for the source element.
 * @param targetSelector - CSS selector for the target element.
 */
export async function simulateDrag(
  sourceSelector: string,
  targetSelector: string,
  {
    dataTransfer,
    sourceCoordinates,
    targetCoordinates,
  }: {
    /**
     * Shared payload that must travel across every event so the drag library can
     * correlate them.
     */
    dataTransfer: DataTransfer;

    /** Coordinates merged over the source element's center. */
    sourceCoordinates?: Partial<ClientPoint>;

    /** Coordinates merged over the target element's center. */
    targetCoordinates?: Partial<ClientPoint>;
  }
) {
  const source = { ...centerOf(sourceSelector), ...sourceCoordinates };
  const target = { ...centerOf(targetSelector), ...targetCoordinates };
  const registered = registeredElementFor(sourceSelector);
  await dragEvent(registered, "dragstart", { dataTransfer, ...source });
  await dragEvent(targetSelector, "dragenter", { dataTransfer, ...target });
  await dragEvent(targetSelector, "dragover", { dataTransfer, ...target });
  await dragEvent(targetSelector, "drop", { dataTransfer, ...target });
  await dragEvent(registered, "dragend", { dataTransfer, ...source });
}

/**
 * The element a row's drag registration sits on: its handle when the row scopes
 * the drag to one, and the row itself otherwise.
 *
 * The browser dispatches `dragstart` at the element carrying `draggable`, and
 * the drag library looks the registration up by exactly that element, so a
 * synthetic drag aimed anywhere else routes nowhere and silently does nothing.
 */
function registeredElementFor(rowSelector: string) {
  const row = document.querySelector(rowSelector);
  return (row?.querySelector("[draggable]") ?? row) as Element;
}

/** How an external drag is aimed at its target. */
interface ExternalDragOptions {
  /**
   * Shared payload that must travel across every event so the drag library can
   * correlate them.
   */
  dataTransfer: DataTransfer;

  /** Coordinates merged over the target element's center. */
  coordinates?: Partial<ClientPoint>;
}

/**
 * Brings an external drag over a target and leaves it hovering there, without
 * dropping.
 *
 * Deliberately no `dragstart`: a drag that began outside the page never fires
 * one, and its absence is exactly what routes the drag to the external adapter
 * rather than the element one. A test that starts with `dragstart` is testing
 * the wrong adapter.
 *
 * Stops short of the drop so a caller can assert on the hovering state — the
 * indicator classes, or what a lifecycle callback was told — which a completed
 * drop would already have cleared. Use {@link simulateExternalDrag} when the
 * drop itself is the subject.
 *
 * @param targetSelector - CSS selector for the target element.
 * @param options - The shared payload and any coordinate override.
 */
export async function externalDragOver(
  targetSelector: string,
  { dataTransfer, coordinates }: ExternalDragOptions
) {
  const target = { ...centerOf(targetSelector), ...coordinates };
  await dragEvent(targetSelector, "dragenter", { dataTransfer, ...target });
  await dragEvent(targetSelector, "dragover", { dataTransfer, ...target });
}

/**
 * Drives a complete external drag onto a target and drops it there.
 *
 * The external counterpart to {@link simulateDrag}, and the same frame-per-event
 * rule applies. Coordinates matter here as much as they do for an element drag:
 * a target resolving a drop position from the pointer reads them, and a bare
 * center only ever exercises the `after` branch of a midpoint comparison.
 *
 * @param targetSelector - CSS selector for the target element.
 * @param options - The shared payload and any coordinate override.
 */
export async function simulateExternalDrag(
  targetSelector: string,
  { dataTransfer, coordinates }: ExternalDragOptions
) {
  const target = { ...centerOf(targetSelector), ...coordinates };
  await externalDragOver(targetSelector, { dataTransfer, coordinates });
  await dragEvent(targetSelector, "drop", { dataTransfer, ...target });
}
