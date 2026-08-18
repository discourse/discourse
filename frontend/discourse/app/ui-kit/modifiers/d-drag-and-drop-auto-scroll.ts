import type { ElementDragPayload } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import type { ExternalDragPayload as NativeExternalDragPayload } from "@atlaskit/pragmatic-drag-and-drop/external/adapter";
import {
  autoScrollForElements,
  autoScrollWindowForElements,
} from "@atlaskit/pragmatic-drag-and-drop-auto-scroll/element";
import {
  autoScrollForExternal,
  autoScrollWindowForExternal,
} from "@atlaskit/pragmatic-drag-and-drop-auto-scroll/external";
import { modifier } from "ember-modifier";
import {
  type ExternalDragKind,
  matchesExternalKind,
} from "discourse/lib/-internals/drag-and-drop/external-vocabulary";
import { matchesDragType } from "discourse/lib/-internals/drag-and-drop/vocabulary";

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
       * Only drags whose resolved `type` matches engage the auto-scroll. Omit to
       * engage on any element drag (rare).
       */
      types?: string | string[];

      /**
       * Also auto-scroll for drags coming from outside the window, engaging on
       * these external kinds. Opt-in and separate from `types` because the two
       * describe different drags: `types` names a discriminator our own sources
       * stamp, which a payload dragged in from another application has no way of
       * carrying. Omit it and an external drag scrolls nothing.
       */
      accepts?: ExternalDragKind | ExternalDragKind[];

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
 * Wraps element and window auto-scroll behind one shape. Used by the
 * default-exported modifier below, and exported so a consumer can register
 * auto-scroll imperatively when a template modifier does not fit — parallel to
 * `registerDragAndDropMonitor`.
 *
 * Library-agnostic by design: the auto-scroll dependency is imported only here.
 *
 * @param getArgsRef - Closure returning the latest args. `types` and `axis` are
 *   re-read on every callback, so a caller driving this imperatively can change
 *   what its closure returns and have the change take without re-registering.
 *   `target` and `element` are read once, here, to decide which registration to
 *   make, so changing either needs a fresh one.
 *
 *   Through the modifier below that distinction does not arise: the closure is
 *   invoked in the modifier body, which consumes every arg it reads, so changing
 *   any of them re-runs the modifier and replaces the registration. That is
 *   accepted rather than worked around — auto-scroll args rarely change, and a
 *   replacement between drags costs nothing.
 * @returns Cleanup function. Caller invokes it once on teardown.
 */
export function registerDragAndDropAutoScroll(
  getArgsRef: () => DragAndDropAutoScrollArgs
) {
  const matchesType = ({ source }: { source: ElementDragPayload }) =>
    matchesDragType(getArgsRef().types, source);

  const matchesKind = ({ source }: { source: NativeExternalDragPayload }) =>
    matchesExternalKind(getArgsRef().accepts, source);

  const getAllowedAxis = () => getArgsRef().axis ?? "vertical";

  const args = getArgsRef();
  const scrollsWindow = args.target === "window";

  const cleanups = [
    scrollsWindow
      ? autoScrollWindowForElements({ canScroll: matchesType, getAllowedAxis })
      : autoScrollForElements({
          element: args.element,
          canScroll: matchesType,
          getAllowedAxis,
        }),
  ];

  // The two adapters are independent registrations, so an external drag scrolls
  // only where a consumer asked for it. Registering one unconditionally would
  // start scrolling every container for every file dragged over the window.
  if (args.accepts) {
    cleanups.push(
      scrollsWindow
        ? autoScrollWindowForExternal({
            canScroll: matchesKind,
            getAllowedAxis,
          })
        : autoScrollForExternal({
            element: args.element,
            canScroll: matchesKind,
            getAllowedAxis,
          })
    );
  }

  return () => cleanups.forEach((cleanup) => cleanup());
}

/**
 * Enables auto-scroll while a compatible drag is in flight. Every arg is
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
 * Add `accepts` to scroll for payloads dragged in from outside the window too,
 * which is a separate registration and does not happen without it:
 *
 * ```hbs
 * <div class="scroll-container"
 *   {{dDragAndDropAutoScroll types=(array "card") accepts="urls"}}
 * >
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
    // The closure is the shape the registrar reads args through, not a way of
    // avoiding consumption: it is invoked in the body, so every arg it reads is
    // consumed here and any change re-runs this modifier. See the note on
    // `registerDragAndDropAutoScroll` for why that is fine.
    registerDragAndDropAutoScroll(() => ({
      types: args.types,
      accepts: args.accepts,
      axis: args.axis ?? "vertical",
      target: args.target ?? "element",
      element,
    }))
);
