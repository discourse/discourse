import type { ElementDragPayload } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import {
  autoScrollForElements,
  autoScrollWindowForElements,
} from "@atlaskit/pragmatic-drag-and-drop-auto-scroll/element";
import { modifier } from "ember-modifier";
import { matchesDragType } from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";

/** Which direction the container is allowed to scroll while a drag is in flight. */
export type AutoScrollAxis = "vertical" | "horizontal" | "all";

/** What gets scrolled: the element the modifier sits on, or the window. */
export type AutoScrollTarget = "element" | "window";

interface DDragAndDropAutoScrollSignature {
  /** The scroll container, or a sentinel when `target` is `"window"`. */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Only drags whose source `type` matches engage the auto-scroll. Omit to
       * engage on any drag (rare).
       */
      types?: string | string[];

      /** Defaults to `"vertical"`. */
      axis?: AutoScrollAxis;

      /**
       * `"element"` (default) scrolls the host element; `"window"` scrolls the
       * window and ignores the element.
       *
       * Decides which registration to make rather than being consulted per
       * callback, so changing it replaces the registration instead of taking
       * effect within it.
       */
      target?: AutoScrollTarget;
    };
    Positional: [];
  };
}

/**
 * The auto-scroll's named args, for a consumer driving
 * {@link registerDragAndDropAutoScroll} imperatively rather than through the
 * modifier.
 */
export type DragAndDropAutoScrollArgs =
  DDragAndDropAutoScrollSignature["Args"]["Named"] & {
    /** The scroll container. Required when `target` is `"element"`. */
    element?: HTMLElement;
  };

/**
 * Wraps PDND's `autoScrollForElements` / `autoScrollWindowForElements` behind
 * one shape. Used by the default-exported modifier below, and exported so a
 * consumer can register auto-scroll imperatively (when a template modifier
 * doesn't fit) without importing PDND — parallel to `registerDragAndDropMonitor`.
 *
 * Library-agnostic by design: PDND auto-scroll is imported only here.
 *
 * @param getArgsRef - Closure returning the latest args. The `types` and `axis`
 *   args are read on every callback, so changes to them take effect without
 *   re-registering. `target` and `element` are the exception: they are read once,
 *   here, to decide which registration to make, so changing either needs a fresh
 *   registration. Through the modifier that happens on its own, because this call
 *   reads the args inside the modifier's own tracking frame: changing any of them
 *   tears the registration down and makes a new one.
 * @returns Cleanup function. Caller invokes it once on teardown.
 */
export function registerDragAndDropAutoScroll(
  getArgsRef: () => DragAndDropAutoScrollArgs
) {
  const matchesType = ({ source }: { source: ElementDragPayload }) =>
    matchesDragType(getArgsRef().types, source);

  const getAllowedAxis = () => getArgsRef().axis ?? "vertical";

  const args = getArgsRef();
  if (args.target === "window") {
    return autoScrollWindowForElements({
      canScroll: matchesType,
      getAllowedAxis,
    });
  }
  return autoScrollForElements({
    element: args.element,
    canScroll: matchesType,
    getAllowedAxis,
  });
}

/**
 * Enables PDND auto-scroll while a compatible drag is in flight. Every arg is
 * documented on {@link DragAndDropAutoScrollArgs}.
 *
 * Attach to a scroll container to auto-scroll that container when
 * the cursor approaches its edges:
 *
 * ```hbs
 * <div class="scroll-container"
 *   {{dDragAndDropAutoScroll types=(array "card") axis="vertical"}}
 * >
 * ```
 *
 * Attach to a sentinel element with `target="window"`
 * to auto-scroll the document body / window instead:
 *
 * ```hbs
 * <span class="visually-hidden"
 *   {{dDragAndDropAutoScroll target="window" types=this.acceptedTypes}}
 * ></span>
 * ```
 *
 * Guide to choosing between the gesture primitives:
 * `docs/developer-guides/docs/03-code-internals/29-drag-and-gesture-primitives.md`
 *
 * @see The `dDragAndDropTarget` modifier, which this complements — auto-scroll moves the
 *   container, it never accepts a drop of its own.
 */
export default modifier<DDragAndDropAutoScrollSignature>(
  (element, _positional, args) =>
    // Read args INSIDE the closure, not via destructure in the body —
    // a destructure here would mark the args' tags consumed and force
    // the modifier to re-run (re-registering PDND) on every change.
    registerDragAndDropAutoScroll(() => ({
      types: args.types,
      axis: args.axis ?? "vertical",
      target: args.target ?? "element",
      element,
    }))
);
