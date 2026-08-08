import {
  type ElementDragPayload,
  type ElementEventBasePayload,
  monitorForElements,
} from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import { modifier } from "ember-modifier";

/**
 * Whether a drag's source `type` is one the consumer asked for.
 *
 * Shared because the monitor and the auto-scroll ask the same question in the
 * same way, and a copy of it in each drifted once already elsewhere in this set.
 *
 * @param types - One type, several, or nothing at all to match every drag.
 * @param source - The dragged source, whose `data.type` is compared.
 */
export function matchesDragType(
  types: string | string[] | undefined,
  source: ElementDragPayload
) {
  const list = Array.isArray(types) ? types : types ? [types] : [];
  if (list.length === 0) {
    return true;
  }
  return list.includes(source.data?.type as string);
}

/** What a monitor callback is told: the dragged source and where it has been. */
export type DragMonitorEvent = ElementEventBasePayload;

interface DDragAndDropMonitorSignature {
  /**
   * Irrelevant — a monitor is global. Attach to any always-present sentinel for
   * the lifecycle.
   */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Only drags whose source `type` matches are observed. Omit to observe any
       * drag.
       */
      types?: string | string[];

      /** The drag was confirmed. */
      onDragStart?: (event: DragMonitorEvent) => void;

      /** The drag progressed. */
      onDrag?: (event: DragMonitorEvent) => void;

      /** The drag ended, whether or not it landed on a target. */
      onDrop?: (event: DragMonitorEvent) => void;
    };
    Positional: [];
  };
}

/**
 * The monitor's named args, for a consumer driving
 * {@link registerDragAndDropMonitor} imperatively rather than through the
 * modifier.
 */
export type DragAndDropMonitorArgs =
  DDragAndDropMonitorSignature["Args"]["Named"];

/**
 * Wraps PDND's `monitorForElements` behind one shape. Used by the
 * default-exported modifier below, and exported so consumers can register a
 * monitor imperatively (when a template modifier doesn't fit) without importing
 * PDND — parallel to `registerDragAndDropAutoScroll`.
 *
 * Library-agnostic by design: PDND is imported only here.
 *
 * @param getArgsRef - Closure returning the latest args. PDND callbacks read
 *   this on every invocation.
 * @returns Cleanup function. Caller invokes it once on teardown.
 */
export function registerDragAndDropMonitor(
  getArgsRef: () => DragAndDropMonitorArgs
) {
  return monitorForElements({
    canMonitor: ({ source }) => matchesDragType(getArgsRef().types, source),
    onDragStart: (event) => getArgsRef().onDragStart?.(event),
    onDrag: (event) => getArgsRef().onDrag?.(event),
    onDrop: (event) => getArgsRef().onDrop?.(event),
  });
}

/**
 * Observes the in-flight element drag, regardless of drop targets — PDND's
 * `monitorForElements`. Use it to react to a drag's progress without making
 * an element droppable (e.g. paging a scroll container when the cursor hovers
 * a navigation control mid-drag). Every arg is documented on
 * {@link DragAndDropMonitorArgs}.
 *
 * A monitor is global, so the host element is irrelevant — attach to any
 * always-present sentinel for the lifecycle, the same way `dDragAndDropAutoScroll`
 * with `target="window"` does:
 *
 * ```hbs
 * <div {{dDragAndDropMonitor types=this.dragTypes onDrag=this.onDrag}}></div>
 * ```
 *
 * Guide to choosing between the gesture primitives:
 * `docs/developer-guides/docs/03-code-internals/29-drag-and-gesture-primitives.md`
 *
 * @see The `dragAndDrop` service to *read* drag state reactively. This modifier is
 *   for *responding* imperatively; rendering from it duplicates what the service keeps.
 */
export default modifier<DDragAndDropMonitorSignature>(
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
