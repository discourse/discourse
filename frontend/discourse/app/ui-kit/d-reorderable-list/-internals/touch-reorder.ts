import { getScrollParent } from "discourse/float-kit/lib/get-scroll-parent";
import {
  createPositionIndicator,
  type DropPosition,
  resolveDropPosition,
} from "discourse/lib/-internals/drag-and-drop/drop-target-kernel";
import {
  type DropTargetSource,
  registerDragAndDropTarget,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import {
  type DPointerDragArgs,
  registerPointerDrag,
} from "discourse/ui-kit/modifiers/d-pointer-drag";

type ReorderSource = Pick<DropTargetSource, "type" | "data">;
type TouchSource = ReorderSource & { row: Element | null };

/** The drop payload shared by native and touch reordering. */
export interface ReorderDrop {
  source: ReorderSource;
  position: DropPosition | null;
}

/** A movable row or an empty group member. */
interface ReorderTarget {
  element: Element;
  readonly accepts: string;
  position?: "inside";
  canDrop?: (event: { source: ReorderSource }) => boolean;
  onDrop: (event: ReorderDrop) => void;
}

const targets = new WeakMap<Element, ReorderTarget>();
const MAX_SCROLL_PX_PER_MS = 0.6;

/**
 * @param element - The keyed row or empty list root.
 * @param getDragType - Reads the list's current group token at event time.
 * @param options - The destination's drop rules.
 * @returns Cleanup for both the native and touch registrations.
 */
export function registerReorderTarget(
  element: Element,
  getDragType: () => string,
  options: Omit<ReorderTarget, "element" | "accepts">
) {
  const target = {
    element,
    get accepts() {
      return getDragType();
    },
    ...options,
  };
  targets.set(element, target);
  const cleanup = registerDragAndDropTarget(element, () => target);
  return () => {
    targets.delete(element);
    cleanup();
  };
}

function findTarget(doc: Document, event: PointerEvent, source: ReorderSource) {
  for (
    let element = doc.elementFromPoint(event.clientX, event.clientY);
    element;
    element = element.parentElement
  ) {
    const target = targets.get(element);
    if (
      target &&
      target.accepts === source.type &&
      target.canDrop?.({ source }) !== false
    ) {
      return target;
    }
  }
}

function positionAt(target: ReorderTarget, event: PointerEvent) {
  return resolveDropPosition(target.element, event, target, false);
}

function scrollAtEdge(
  parent: HTMLElement | Window,
  event: PointerEvent,
  elapsed: number
) {
  const scroller =
    parent instanceof HTMLElement ? parent : parent.document.scrollingElement;
  if (!scroller) {
    return false;
  }

  const rect =
    parent instanceof HTMLElement ? parent.getBoundingClientRect() : null;
  const top = Math.max(0, rect?.top ?? 0);
  const bottom = Math.min(
    window.innerHeight,
    rect?.bottom ?? window.innerHeight
  );
  const { clientX, clientY } = event;
  const fromTop = clientY - top;
  const fromBottom = bottom - clientY;
  const nearestEdge = Math.min(fromTop, fromBottom);
  const edgeZone = Math.min(40, (bottom - top) / 4);
  if (
    nearestEdge < 0 ||
    nearestEdge >= edgeZone ||
    (rect && (clientX < rect.left || clientX > rect.right))
  ) {
    return false;
  }

  const previous = scroller.scrollTop;
  const step = Math.ceil(
    (1 - nearestEdge / edgeZone) * MAX_SCROLL_PX_PER_MS * elapsed
  );
  scroller.scrollTop = previous + (fromTop < fromBottom ? -step : step);
  return scroller.scrollTop !== previous;
}

function startTouchDrag(doc: Document, source: TouchSource) {
  let pointer: PointerEvent;
  let pointerMoved = false;
  let frame: number | undefined;
  let lastFrameTime = 0;
  let scrollParent: ReturnType<typeof getScrollParent> | undefined;
  let hovered: ReorderTarget | undefined;
  let indicator: ReturnType<typeof createPositionIndicator> | undefined;

  function updateTarget() {
    const target = findTarget(doc, pointer, source);
    if (target !== hovered || scrollParent === undefined) {
      indicator?.clear();
      hovered = target;
      indicator = target && createPositionIndicator(target.element);
      scrollParent = getScrollParent(target?.element ?? source.row);
    }
  }

  function paint(time: number) {
    frame = undefined;
    if (pointerMoved) {
      updateTarget();
      pointerMoved = false;
    }
    const elapsed = Math.min(32, Math.max(1, time - lastFrameTime));
    if (scrollParent && scrollAtEdge(scrollParent, pointer, elapsed)) {
      updateTarget();
      lastFrameTime = time;
      frame = requestAnimationFrame(paint);
    }
    if (hovered) {
      indicator?.show(positionAt(hovered, pointer), "vertical", false);
    }
  }

  return {
    move(event: PointerEvent) {
      if (!pointer) {
        source.row?.classList.add("--touch-dragging");
      }
      pointer = event;
      pointerMoved = true;
      if (frame === undefined) {
        lastFrameTime = performance.now();
        frame = requestAnimationFrame(paint);
      }
    },
    finish(release?: PointerEvent) {
      if (!pointer) {
        return;
      }
      if (frame !== undefined) {
        cancelAnimationFrame(frame);
      }
      const target = release && findTarget(doc, release, source);
      const position = release && target ? positionAt(target, release) : null;
      indicator?.clear();
      source.row?.classList.remove("--touch-dragging");
      if (target) {
        target.onDrop({ source, position });
      }
    },
  };
}

/**
 * @param handle - The row's grip button.
 * @param getSource - Reads the row and its list identity when a touch begins.
 * @returns Cleanup to release capture, stop scrolling and clear drag feedback.
 */
export function registerTouchReorder(
  handle: HTMLElement,
  getSource: () => TouchSource
) {
  let drag: ReturnType<typeof startTouchDrag> | undefined;
  let suppressClick = false;

  function finish(release?: PointerEvent) {
    const active = drag;
    drag = undefined;
    active?.finish(release);
  }

  const gesture: DPointerDragArgs = {
    threshold: 5,
    onDragStart(event) {
      suppressClick = false;
      if (event.pointerType !== "touch" || !event.isPrimary) {
        return false;
      }
      drag = startTouchDrag(handle.ownerDocument, getSource());
    },
    onDrag(event) {
      drag?.move(event);
    },
    onDragEnd(event, { moved }) {
      // A small drag can produce a compatibility click in a later task.
      suppressClick = moved;
      finish(moved ? event : undefined);
    },
    onDragCancel() {
      finish();
    },
  };

  function onClick(event: MouseEvent) {
    if (suppressClick && event.detail > 0) {
      suppressClick = false;
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }

  function onNativeDragStart(event: DragEvent) {
    if (drag) {
      event.preventDefault();
    }
  }

  const cleanup = registerPointerDrag(handle, () => gesture);
  handle.addEventListener("click", onClick, true);
  handle.addEventListener("dragstart", onNativeDragStart);
  return () => {
    finish();
    cleanup();
    handle.removeEventListener("click", onClick, true);
    handle.removeEventListener("dragstart", onNativeDragStart);
  };
}
