import { triggerEvent } from "@ember/test-helpers";

/**
 * Returns the center-point client coordinates of an element, for realistic
 * synthetic drag events.
 *
 * Every drag event dispatched in a test must carry finite `clientX` /
 * `clientY`: the drag monitor resolves the pointer via `elementsFromPoint`,
 * which throws on non-finite values. A real drag always has coordinates, so the
 * test must supply them too.
 *
 * @param {string} selector - CSS selector for the element to measure.
 * @returns {{ clientX: number, clientY: number }} The element's center point.
 */
export function centerOf(selector) {
  const rect = document.querySelector(selector).getBoundingClientRect();
  return {
    clientX: rect.left + rect.width / 2,
    clientY: rect.top + rect.height / 2,
  };
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
 * @param {string} selector - CSS selector for the event target.
 * @param {string} type - The drag event type (e.g. `"dragstart"`, `"drop"`).
 * @param {Object} [options] - Forwarded to `triggerEvent`; must include the
 *   shared `dataTransfer` and finite client coordinates (see {@link centerOf}).
 * @returns {Promise<void>}
 */
export async function dragEvent(selector, type, options) {
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
 * center coordinates are computed via {@link centerOf}.
 *
 * @param {string} sourceSelector - CSS selector for the source element.
 * @param {string} targetSelector - CSS selector for the target element.
 * @param {{ dataTransfer: DataTransfer }} options - Shared payload that must
 *   travel across every event so the drag library can correlate them.
 * @returns {Promise<void>}
 */
export async function simulateDrag(
  sourceSelector,
  targetSelector,
  { dataTransfer }
) {
  const source = centerOf(sourceSelector);
  const target = centerOf(targetSelector);
  await dragEvent(sourceSelector, "dragstart", { dataTransfer, ...source });
  await dragEvent(targetSelector, "dragenter", { dataTransfer, ...target });
  await dragEvent(targetSelector, "dragover", { dataTransfer, ...target });
  await dragEvent(targetSelector, "drop", { dataTransfer, ...target });
  await dragEvent(sourceSelector, "dragend", { dataTransfer, ...source });
}
