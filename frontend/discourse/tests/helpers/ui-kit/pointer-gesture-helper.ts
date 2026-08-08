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
 * @param target - The element that will receive the press, or a selector for it.
 * @returns The element, the pointer IDs it currently holds, and those it has given
 *   back in order.
 */
export function stubPointerCapture(target: string | HTMLElement) {
  // `find` is typed as possibly missing the element; a test naming one that is
  // not rendered is a test bug, and failing on the next line says so directly.
  const element = (
    typeof target === "string" ? find(target) : target
  ) as HTMLElement;
  const captured = new Set<number>();
  const released: number[] = [];

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
 */
export async function settleGestureFrame() {
  await new Promise((resolve) => requestAnimationFrame(resolve));
  await settled();
}
