import {
  type ElementDragPayload,
  type ElementEventBasePayload,
  monitorForElements,
} from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import { modifier } from "ember-modifier";
import {
  dragTypeOf,
  type NormalizedDragSource,
  normalizeDragSource,
} from "discourse/services/drag-and-drop";

/**
 * Whether a drag's type is one the consumer asked for.
 *
 * Shared because the monitor and the auto-scroll ask the same question in the
 * same way, and a copy of it in each drifted once already elsewhere in this set.
 *
 * @param types - One type, several, or nothing at all to match every drag.
 * @param source - The dragged source, compared by the type it answers to
 *   ({@link dragTypeOf}) rather than the raw `data.type`, so an adopted drag is
 *   reachable by the adoption's own vocabulary.
 */
export function matchesDragType(
  types: string | string[] | undefined,
  source: ElementDragPayload
) {
  const list = Array.isArray(types) ? types : types ? [types] : [];
  if (list.length === 0) {
    return true;
  }
  return list.includes(dragTypeOf(source.data) as string);
}

/**
 * What a monitor callback is told: the dragged source and where it has been.
 * The source arrives normalized ({@link normalizeDragSource}), so a monitor
 * reads the same shape a drop target reports and never meets a routing key.
 */
export type DragMonitorEvent = Omit<ElementEventBasePayload, "source"> & {
  source: NormalizedDragSource;
};

interface DDragAndDropMonitorSignature {
  /**
   * Irrelevant — a monitor is global. Attach to any always-present sentinel for
   * the lifecycle.
   */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Only drags whose `type` matches are observed — the adoption's own type
       * for a drag a target adopted. Omit to observe any drag.
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
  const normalized = (event: ElementEventBasePayload): DragMonitorEvent => ({
    ...event,
    source: normalizeDragSource(event.source),
  });
  return monitorForElements({
    canMonitor: ({ source }) => matchesDragType(getArgsRef().types, source),
    onDragStart: (event) => getArgsRef().onDragStart?.(normalized(event)),
    onDrag: (event) => getArgsRef().onDrag?.(normalized(event)),
    onDrop: (event) => getArgsRef().onDrop?.(normalized(event)),
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
