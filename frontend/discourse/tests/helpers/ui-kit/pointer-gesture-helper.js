import { find, settled } from "@ember/test-helpers";

/**
 * Makes an element accept pointer capture for a pointer that was never real.
 *
 * The gesture engine captures the pointer before telling anyone a drag started, and
 * aborts if that fails — deliberately, since a gesture that cannot receive its own
 * release would strand itself. A browser rejects `setPointerCapture` for a synthetic
 * pointer ID, so without this every synthetic drag stops at the press, silently and
 * with nothing to indicate why.
 *
 * `captured` and `released` are exposed for the tests that assert the capture itself
 * was taken and given back; most callers only need the side effect.
 *
 * @param {string|HTMLElement} target - The element that will receive the press, or a
 *   selector for it.
 * @returns {{element: HTMLElement, captured: Set<number>, released: number[]}} The
 *   element, the pointer IDs it currently holds, and those it has given back in
 *   order.
 */
export function stubPointerCapture(target) {
  const element = typeof target === "string" ? find(target) : target;
  const captured = new Set();
  const released = [];

  element.setPointerCapture = (pointerId) => captured.add(pointerId);
  element.hasPointerCapture = (pointerId) => captured.has(pointerId);
  element.releasePointerCapture = (pointerId) => {
    captured.delete(pointerId);
    released.push(pointerId);
  };

  return { element, captured, released };
}

/**
 * Waits for a gesture's pending report to land.
 *
 * Pointer moves are coalesced into an animation frame, so the size or position a
 * gesture computes is reported on the next frame rather than during the move that
 * caused it. `settled` does not await frames, so a test that presses, moves, and
 * asserts reads the value from *before* the move and quietly passes or fails on the
 * wrong basis. Await this between a move and any assertion about what the move did.
 *
 * Not needed after a release: ending a gesture cancels the pending frame and reports
 * synchronously, precisely so the committed value cannot be overtaken by a stale one.
 *
 * @returns {Promise<void>} Resolves once the frame has run and the app has settled.
 */
export async function settleGestureFrame() {
  await new Promise((resolve) => requestAnimationFrame(resolve));
  await settled();
}
