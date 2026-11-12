import { find, settled, triggerEvent } from "@ember/test-helpers";

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
 * Like {@link stubPointerCapture}, but models the browser's one pending
 * capture override per pointer across a set of elements.
 *
 * The per-element stub gives each element an independent record, so it cannot
 * express displacement: in a real browser a second element's
 * `setPointerCapture` during the same dispatch replaces the first's pending
 * override, and a release by the displacing element clears the override
 * entirely. Tests about contested claims on one bubbling press need exactly
 * that shape — who ends up owning the pointer is the assertion.
 *
 * @param targets - The elements contending for capture, or selectors for them.
 * @returns Per-element records in input order, and `ownerOf` to ask which
 *   element currently holds a pointer's capture.
 */
export function stubSharedPointerCapture(targets: (string | HTMLElement)[]) {
  const owners = new Map<number, HTMLElement>();
  const stubs = targets.map((target) => {
    const element = (
      typeof target === "string" ? find(target) : target
    ) as HTMLElement;
    const released: number[] = [];
    element.setPointerCapture = (pointerId) => owners.set(pointerId, element);
    element.hasPointerCapture = (pointerId) =>
      owners.get(pointerId) === element;
    element.releasePointerCapture = (pointerId) => {
      // A release only clears the override the caller holds, as in the spec: a
      // displaced claimant releasing changes nothing.
      if (owners.get(pointerId) === element) {
        owners.delete(pointerId);
      }
      released.push(pointerId);
    };
    return { element, released };
  });

  return {
    stubs,
    ownerOf: (pointerId: number) => owners.get(pointerId) ?? null,
  };
}

interface DragPointerOptions {
  /** The client coordinate the press lands on, along the axis. */
  from: number;
  /** The client coordinate the pointer moves to. */
  to: number;
  /** Which client coordinate the gesture reads. Defaults to `"vertical"`. */
  axis?: "vertical" | "horizontal";
  /** Distinguishes concurrent gestures, and reused IDs across sequential ones. */
  pointerId?: number;
  /**
   * Whether to release at the end. Pass `false` to leave the gesture open, for
   * tests about what happens while one is still held.
   */
  release?: boolean;
}

/**
 * Presses, moves and releases a pointer over one element.
 *
 * Capture is stubbed here rather than left to the caller, because a drag whose
 * capture was never stubbed stops at the press without saying so: the assertions
 * that follow then describe a gesture that never ran.
 *
 * @param target - The element to drag, or a selector for it.
 * @param options - Where the gesture starts and ends, and how it is identified.
 */
export async function dragPointer(
  target: string | HTMLElement,
  {
    from,
    to,
    axis = "vertical",
    pointerId = 1,
    release = true,
  }: DragPointerOptions
) {
  const { element } = stubPointerCapture(target);
  const coordinate = (value: number) =>
    axis === "vertical" ? { clientY: value } : { clientX: value };

  await triggerEvent(element, "pointerdown", {
    button: 0,
    pointerId,
    ...coordinate(from),
  });
  await triggerEvent(element, "pointermove", {
    button: 0,
    pointerId,
    ...coordinate(to),
  });
  await settleGestureFrame();

  if (release) {
    await triggerEvent(element, "pointerup", {
      button: 0,
      pointerId,
      ...coordinate(to),
    });
  }

  return element;
}

/**
 * Waits for a gesture's pending report to land.
 *
 * Pointer moves are coalesced into an animation frame, so the size or position a
 * gesture computes is reported on the next frame rather than during the move that
 * caused it. `settled` does not await frames, so a test that presses, moves, and
 * asserts reads the value from before the move and quietly passes or fails on the
 * wrong basis. Await this between a move and any assertion about what the move did.
 */
export async function settleGestureFrame() {
  await new Promise((resolve) => requestAnimationFrame(resolve));
  await settled();
}
