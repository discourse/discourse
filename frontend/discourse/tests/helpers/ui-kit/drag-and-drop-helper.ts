import { triggerEvent } from "@ember/test-helpers";

/** A point on the viewport, in the shape every drag event has to carry. */
interface ClientPoint {
  clientX: number;
  clientY: number;
}

/**
 * The center-point client coordinates of an element.
 *
 * Every synthetic drag event must carry finite `clientX` / `clientY`: the
 * underlying library resolves the pointer with `elementsFromPoint`, which
 * throws on non-finite values.
 *
 * @param selector - CSS selector for the element to measure.
 * @returns The element's center point.
 */
export function centerOf(selector: string): ClientPoint {
  const rect = (
    document.querySelector(selector) as Element
  ).getBoundingClientRect();
  return {
    clientX: rect.left + rect.width / 2,
    clientY: rect.top + rect.height / 2,
  };
}

/**
 * A `DataTransfer` carrying plain text, the way a selection dragged in from
 * another window arrives.
 *
 * @param text - The `text/plain` payload.
 */
export function textTransfer(text = "dropped text") {
  const dataTransfer = new DataTransfer();
  dataTransfer.setData("text/plain", text);
  return dataTransfer;
}

/**
 * A `DataTransfer` carrying one file, the way a drag from the OS file manager
 * arrives.
 *
 * @param name - The file's name, as `getFiles()` reports it.
 */
export function fileTransfer(name = "a.txt") {
  const dataTransfer = new DataTransfer();
  dataTransfer.items.add(new File(["payload"], name, { type: "text/plain" }));
  return dataTransfer;
}

/**
 * Throws unless both ends of a drag are registered with the primitives.
 *
 * A drag dispatched at an unregistered source or target does nothing, so a
 * test asserting that nothing happened would pass for the wrong reason and
 * keep passing after the registration was removed outright.
 *
 * @param sourceSelector - CSS selector for the element the drag starts on.
 * @param targetSelector - CSS selector for the element it is dropped on.
 */
function assertDragRegistered(sourceSelector: string, targetSelector: string) {
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
 * Throws unless the element is registered as an external drop target; the
 * external counterpart of {@link assertDragRegistered}.
 *
 * @param targetSelector - CSS selector for the element the drag is aimed at.
 */
export function assertExternalTargetRegistered(targetSelector: string) {
  const target = document.querySelector(targetSelector);

  if (!target?.hasAttribute("data-drop-target-external")) {
    throw new Error(
      `${targetSelector} is not a registered external drop target, so this drag would do nothing`
    );
  }
}

/**
 * Dispatches one synthetic drag event, then waits one animation frame.
 *
 * The frame wait is the point of this wrapper; every other helper here
 * dispatches through it. The underlying library runs `onDragStart` in a
 * `requestAnimationFrame` and throttles `onDrag` to a frame.
 *
 * Ember's `settled()` does not pump animation frames, so without the wait
 * those callbacks have not fired when the caller's next step runs. One frame
 * is enough: ours is queued after the library's.
 *
 * A drop cancels a still-pending `onDrag`, so a frame after every `dragover`
 * is also what lets `onDrag` be observed. Use {@link dragEventNow} when a test
 * needs two events in one task, with no frame between them.
 *
 * @param target - CSS selector for the event target, or the element itself.
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
 * Dispatches one native drag event synchronously, with no frame wait.
 *
 * The counterpart of {@link dragEvent} for the timing it hides. The underlying
 * library reports a hierarchy change synchronously but throttles the drag
 * update that follows to a frame, and a drop cancels that frame.
 *
 * The source likewise defers its consumer callbacks past the drop into the
 * next runloop task. A test probing either window lands a second event, or a
 * teardown, in the same task as the first, so nothing here may yield.
 *
 * @param target - CSS selector for the event target, or the element itself.
 * @param type - The drag event type (e.g. `"dragenter"`, `"drop"`).
 * @param options - The shared `dataTransfer` and finite client coordinates.
 */
export function dragEventNow(
  target: string | Element,
  type: string,
  {
    dataTransfer,
    clientX,
    clientY,
  }: { dataTransfer: DataTransfer } & ClientPoint
) {
  const element =
    typeof target === "string"
      ? (document.querySelector(target) as Element)
      : target;
  element.dispatchEvent(
    new DragEvent(type, {
      bubbles: true,
      cancelable: true,
      dataTransfer,
      clientX,
      clientY,
    })
  );
}

/** How a drag event, or a short run of them, is aimed at one element. */
interface AimedDragOptions {
  /** Shared payload every event of one drag must carry. */
  dataTransfer: DataTransfer;

  /** Coordinates merged over the addressed element's center. */
  coordinates?: Partial<ClientPoint>;
}

/**
 * Begins an element drag on a source and leaves it in flight, without moving
 * it anywhere.
 *
 * `sourceSelector` names the row. A row that scopes its drag to a handle is
 * registered on the handle, so `dragstart` is dispatched on whichever element
 * the registration sits on; the coordinates are the row's center either way.
 *
 * @param sourceSelector - CSS selector for the source row.
 * @param options - The shared payload and any coordinate override.
 */
export async function startDrag(
  sourceSelector: string,
  { dataTransfer, coordinates }: AimedDragOptions
) {
  const source = { ...centerOf(sourceSelector), ...coordinates };
  await dragEvent(registeredElementFor(sourceSelector), "dragstart", {
    dataTransfer,
    ...source,
  });
}

/**
 * Brings an in-flight element drag over a target and leaves it hovering,
 * without dropping, so a caller can assert on state a completed drop would
 * already have cleared.
 *
 * @param targetSelector - CSS selector for the target element.
 * @param options - The shared payload and any coordinate override.
 */
export async function dragOver(
  targetSelector: string,
  { dataTransfer, coordinates }: AimedDragOptions
) {
  const target = { ...centerOf(targetSelector), ...coordinates };
  await dragEvent(targetSelector, "dragenter", { dataTransfer, ...target });
  await dragEvent(targetSelector, "dragover", { dataTransfer, ...target });
}

/**
 * Drives a complete element drag from a source to a target: `dragstart`,
 * `dragenter`, `dragover`, `drop`, `dragend`, each through {@link dragEvent}.
 *
 * Coordinates default to each element's center. Override them when the
 * pointer position matters: a bare center only ever exercises the `after`
 * branch of a midpoint comparison.
 *
 * `sourceSelector` names the row; see {@link startDrag}.
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
    /** Shared payload every event of one drag must carry. */
    dataTransfer: DataTransfer;

    /** Coordinates merged over the source element's center. */
    sourceCoordinates?: Partial<ClientPoint>;

    /** Coordinates merged over the target element's center. */
    targetCoordinates?: Partial<ClientPoint>;
  }
) {
  assertDragRegistered(sourceSelector, targetSelector);
  const source = { ...centerOf(sourceSelector), ...sourceCoordinates };
  const target = { ...centerOf(targetSelector), ...targetCoordinates };
  await startDrag(sourceSelector, { dataTransfer, coordinates: source });
  await dragOver(targetSelector, { dataTransfer, coordinates: target });
  await dragEvent(targetSelector, "drop", { dataTransfer, ...target });
  await dragEvent(registeredElementFor(sourceSelector), "dragend", {
    dataTransfer,
    ...source,
  });
}

/**
 * The element a row's drag registration sits on: the row itself, or its
 * handle when the row scopes the drag to one.
 *
 * The underlying library looks a registration up by the element carrying
 * `draggable`, so a synthetic `dragstart` aimed anywhere else does nothing.
 */
function registeredElementFor(rowSelector: string) {
  const row = document.querySelector(rowSelector) as Element;
  if (row.matches('[draggable="true"]')) {
    return row;
  }
  return row.querySelector('[draggable="true"]') ?? row;
}

/**
 * Brings an external drag over a target and leaves it hovering there, without
 * dropping.
 *
 * Deliberately no `dragstart`: a drag that began outside the page never fires
 * one, and its absence is what routes the drag to the external adapter rather
 * than the element one.
 *
 * Stops short of the drop so a caller can assert on state a completed drop
 * would already have cleared. Use {@link simulateExternalDrag} when the drop
 * itself is the subject.
 *
 * @param targetSelector - CSS selector for the target element.
 * @param options - The shared payload and any coordinate override.
 */
export async function externalDragOver(
  targetSelector: string,
  { dataTransfer, coordinates }: AimedDragOptions
) {
  assertExternalTargetRegistered(targetSelector);
  const target = { ...centerOf(targetSelector), ...coordinates };
  await dragEvent(targetSelector, "dragenter", { dataTransfer, ...target });
  await dragEvent(targetSelector, "dragover", { dataTransfer, ...target });
}

/**
 * Drives a complete external drag onto a target and drops it there; the
 * external counterpart of {@link simulateDrag}.
 *
 * Override the coordinates when the pointer position matters: a bare center
 * only ever exercises the `after` branch of a midpoint comparison.
 *
 * @param targetSelector - CSS selector for the target element.
 * @param options - The shared payload and any coordinate override.
 */
export async function simulateExternalDrag(
  targetSelector: string,
  { dataTransfer, coordinates }: AimedDragOptions
) {
  const target = { ...centerOf(targetSelector), ...coordinates };
  await externalDragOver(targetSelector, { dataTransfer, coordinates });
  await dragEvent(targetSelector, "drop", { dataTransfer, ...target });
}
