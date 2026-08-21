import type { ElementDragPayload } from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import type { ExternalDragPayload as NativeExternalDragPayload } from "@atlaskit/pragmatic-drag-and-drop/adapter/external-adapter-types";
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
import type { Axis } from "discourse/lib/geometry";

/** Which direction the container is allowed to scroll while a drag is in flight. */
export type AutoScrollAxis = Axis | "all";

/** What gets scrolled: the element the modifier sits on, or the window. */
export type AutoScrollTarget = "element" | "window";

interface DDragAndDropAutoScrollSignature {
  /** The scroll container, or a sentinel when `target` is `"window"`. */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Only drags whose `type` matches engage the auto-scroll; an adopted drag
       * answers to the adoption's declared type. Omit to engage on any element
       * drag.
       */
      types?: string | string[];

      /**
       * Also auto-scroll for drags from outside the window, engaging on these
       * external kinds. Omit it and an external drag scrolls nothing.
       */
      externalKinds?: ExternalDragKind | ExternalDragKind[];

      /** Defaults to `"vertical"`. */
      axis?: AutoScrollAxis;

      /**
       * `"element"` (default) scrolls the host element; `"window"` scrolls the
       * window and ignores the element.
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
 * Imperative auto-scroll registration; the `dDragAndDropAutoScroll` modifier
 * below wraps it.
 *
 * @param getArgsRef - Closure returning the latest args. `types`, `axis` and
 *   `externalKinds` are re-read on every scroll attempt; `target`, `element` and
 *   whether `externalKinds` is set are read once here and need a fresh registration.
 * @returns Cleanup; call it once on teardown.
 */
export function registerDragAndDropAutoScroll(
  getArgsRef: () => DragAndDropAutoScrollArgs
) {
  const matchesType = ({ source }: { source: ElementDragPayload }) =>
    matchesDragType(getArgsRef().types, source);

  const matchesKind = ({ source }: { source: NativeExternalDragPayload }) =>
    matchesExternalKind(getArgsRef().externalKinds, source);

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

  // An absent `externalKinds` would match every external drag, so the external
  // registration is made only when the consumer asked for one.
  if (args.externalKinds) {
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
 * On a scroll container:
 *
 * ```hbs
 * <div class="scroll-container"
 *   {{dDragAndDropAutoScroll types=(array "card") axis="vertical"}}
 * >
 * ```
 *
 * On a sentinel with `target="window"` to scroll the window instead:
 *
 * ```hbs
 * <span class="visually-hidden"
 *   {{dDragAndDropAutoScroll target="window" types=this.acceptedTypes}}
 * ></span>
 * ```
 *
 * With `externalKinds`, for payloads dragged in from outside the window too:
 *
 * ```hbs
 * <div class="scroll-container"
 *   {{dDragAndDropAutoScroll types=(array "card") externalKinds="urls"}}
 * >
 * ```
 */
export default modifier<DDragAndDropAutoScrollSignature>(
  (element, _positional, args) =>
    // Every arg read here is tracked, so a change re-runs the modifier and
    // replaces the registration; cheap between drags, and args rarely change.
    registerDragAndDropAutoScroll(() => ({
      types: args.types,
      externalKinds: args.externalKinds,
      axis: args.axis,
      target: args.target,
      element,
    }))
);
