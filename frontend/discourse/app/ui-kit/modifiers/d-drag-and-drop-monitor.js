// @ts-check
import { monitorForElements } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import { modifier } from "ember-modifier";

/**
 * Wraps PDND's `monitorForElements` behind one shape. Used by the
 * default-exported modifier below, and exported so consumers can register a
 * monitor imperatively (when a template modifier doesn't fit) without importing
 * PDND — parallel to `registerDragAndDropAutoScroll`.
 *
 * Library-agnostic by design: PDND is imported only here.
 *
 * @param {() => Object} getArgsRef - Closure returning the latest args.
 *   PDND callbacks read this on every invocation. Args shape:
 *   `types` (string | string[] | undefined — only drags whose source `type`
 *   matches are observed; omit to observe any drag), and the optional
 *   `onDragStart` / `onDrag` / `onDrop` callbacks.
 * @returns {() => void} Cleanup function. Caller invokes it once on teardown.
 */
export function registerDragAndDropMonitor(getArgsRef) {
  const matchesType = ({ source }) => {
    const types = getArgsRef().types;
    const list = Array.isArray(types) ? types : types ? [types] : [];
    if (list.length === 0) {
      return true;
    }
    return list.includes(source.data?.type);
  };

  return monitorForElements({
    canMonitor: matchesType,
    onDragStart: (event) => getArgsRef().onDragStart?.(event),
    onDrag: (event) => getArgsRef().onDrag?.(event),
    onDrop: (event) => getArgsRef().onDrop?.(event),
  });
}

/**
 * @typedef {Object} MonitorNamedArgs
 * @property {string | string[]} [types]
 * @property {(event: Object) => void} [onDragStart]
 * @property {(event: Object) => void} [onDrag]
 * @property {(event: Object) => void} [onDrop]
 */

/**
 * Observes the in-flight element drag, regardless of drop targets — PDND's
 * `monitorForElements`. Use it to react to a drag's progress without making
 * an element droppable (e.g. paging a scroll container when the cursor hovers
 * a navigation control mid-drag).
 *
 * A monitor is global, so the host element is irrelevant — attach to any
 * always-present sentinel for the lifecycle, the same way `dDragAndDropAutoScroll`
 * with `target="window"` does:
 *
 * ```hbs
 * <div {{dDragAndDropMonitor types=this.dragTypes onDrag=this.onDrag}}></div>
 * ```
 *
 * Args (named):
 *  - `types` — string or array of strings. Only drags whose source `type`
 *    matches are observed. Omit to observe any drag.
 *  - `onDragStart` / `onDrag` / `onDrop` — PDND monitor callbacks, each
 *    receiving `{ source, location }`.
 */
export default modifier(
  /**
   * @param {HTMLElement} _element
   * @param {unknown[]} _positional
   * @param {MonitorNamedArgs} args
   */
  (_element, _positional, args) =>
    // Read args INSIDE the closure, not via destructure in the body — a
    // destructure here would mark the args' tags consumed and force the
    // modifier to re-run (re-registering the monitor) on every change.
    registerDragAndDropMonitor(() => ({
      types: args.types,
      onDragStart: args.onDragStart,
      onDrag: args.onDrag,
      onDrop: args.onDrop,
    }))
);
