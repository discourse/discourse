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
 * @param selector - CSS selector for the event target.
 * @param type - The drag event type (e.g. `"dragstart"`, `"drop"`).
 * @param options - Forwarded to `triggerEvent`; must include the shared
 *   `dataTransfer` and finite client coordinates (see {@link centerOf}).
 */
export async function dragEvent(
  selector: string,
  type: string,
  options?: Record<string, unknown>
) {
  await triggerEvent(selector, type, options);
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
 * only exercises the `after` branch of strict midpoint comparisons, and a drag
 * handle needs the event dispatched on its registered row while carrying the
 * handle's coordinates.
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
  await dragEvent(sourceSelector, "dragstart", { dataTransfer, ...source });
  await dragEvent(targetSelector, "dragenter", { dataTransfer, ...target });
  await dragEvent(targetSelector, "dragover", { dataTransfer, ...target });
  await dragEvent(targetSelector, "drop", { dataTransfer, ...target });
  await dragEvent(sourceSelector, "dragend", { dataTransfer, ...source });
}
