import {
  type ElementEventBasePayload,
  monitorForElements,
} from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import { modifier } from "ember-modifier";
import { consumerMayThrow } from "discourse/lib/-internals/drag-and-drop/consumer-may-throw";
import {
  matchesDragType,
  type NormalizedDragSource,
  normalizeDragSource,
} from "discourse/lib/-internals/drag-and-drop/vocabulary";

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
       * Only drags whose `type` matches are observed. Omit to observe any drag.
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
 * Wraps the element-drag monitor behind one shape. Used by the
 * default-exported modifier below, and exported so consumers can register a
 * monitor imperatively (when a template modifier doesn't fit) without importing
 * the underlying library.
 *
 * Consumers remain library-agnostic: they use this helper instead of importing
 * the underlying library themselves.
 *
 * @param getArgsRef - Closure returning the latest args. Library callbacks read
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
    onDragStart: (event) =>
      consumerMayThrow(() => getArgsRef().onDragStart?.(normalized(event))),
    onDrag: (event) =>
      consumerMayThrow(() => getArgsRef().onDrag?.(normalized(event))),
    onDrop: (event) =>
      consumerMayThrow(() => getArgsRef().onDrop?.(normalized(event))),
  });
}

/**
 * Observes the in-flight element drag, regardless of drop targets. Use it to
 * react to a drag's progress without making
 * an element droppable (e.g. paging a scroll container when the cursor hovers
 * a navigation control mid-drag). Every arg is documented on
 * {@link DragAndDropMonitorArgs}.
 *
 * A monitor is global, so the host element is irrelevant — attach it to any
 * always-present sentinel for the lifecycle:
 *
 * ```hbs
 * <div {{dDragAndDropMonitor types=this.dragTypes onDrag=this.onDrag}}></div>
 * ```
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
