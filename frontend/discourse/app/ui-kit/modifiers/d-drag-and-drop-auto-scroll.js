// @ts-check
import {
  autoScrollForElements,
  autoScrollWindowForElements,
} from "@atlaskit/pragmatic-drag-and-drop-auto-scroll/element";
import { modifier } from "ember-modifier";

/**
 * Wraps PDND's `autoScrollForElements` / `autoScrollWindowForElements` behind
 * one shape. Used by the default-exported modifier below, and exported so a
 * consumer can register auto-scroll imperatively (when a template modifier
 * doesn't fit) without importing PDND — parallel to `registerDragAndDropMonitor`.
 *
 * Library-agnostic by design: PDND auto-scroll is imported only here.
 *
 * @param {() => Object} getArgsRef - Closure returning the latest args.
 *   PDND callbacks read this on every invocation. Args shape:
 *   `types` (string | string[] | undefined), `axis`
 *   (`"vertical"` / `"horizontal"` / `"all"`), `target`
 *   (`"element"` | `"window"`), `element` (required when
 *   `target === "element"`).
 * @returns {() => void} Cleanup function. Caller invokes it once on
 *   teardown.
 */
export function registerDragAndDropAutoScroll(getArgsRef) {
  const matchesType = ({ source }) => {
    const types = getArgsRef().types;
    const list = Array.isArray(types) ? types : types ? [types] : [];
    if (list.length === 0) {
      return true;
    }
    return list.includes(source.data?.type);
  };

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
 * @typedef {Object} AutoScrollNamedArgs
 * @property {string | string[]} [types]
 * @property {"vertical" | "horizontal" | "all"} [axis]
 * @property {"element" | "window"} [target]
 */

/**
 * Enables PDND auto-scroll while a compatible drag is in flight.
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
 * Args (named):
 *  - `types` — string or array of strings. Only drags whose source
 *    `type` matches engage the auto-scroll. Omit to engage on any
 *    drag (rare).
 *  - `axis` — `"vertical"` (default) / `"horizontal"` / `"all"`.
 *  - `target` — `"element"` (default — scroll the host element)
 *    or `"window"` (scroll the window; element is ignored).
 */
export default modifier(
  /**
   * @param {HTMLElement} element
   * @param {unknown[]} _positional
   * @param {AutoScrollNamedArgs} args
   */
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
