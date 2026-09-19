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
 * What a monitor callback is told: the normalized source and the drag's
 * location history.
 */
export type DragMonitorEvent = Omit<ElementEventBasePayload, "source"> & {
  source: NormalizedDragSource;
};

interface DDragAndDropMonitorSignature {
  /**
   * A monitor is global. The element only anchors the modifier's lifecycle.
   */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Only drags whose `type` matches are observed. Omit to observe any drag.
       */
      types?: string | string[];

      /** A drag started. */
      onDragStart?: (event: DragMonitorEvent) => void;

      /** The drag moved. */
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
 * Imperative monitor registration; the `dDragAndDropMonitor` modifier below
 * wraps it.
 *
 * @param getArgsRef - Closure returning the latest args. Callbacks read it on
 *   every invocation; `types` is consulted once as a drag starts, so a change
 *   applies from the next drag.
 * @returns Cleanup; call it once on teardown.
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
 * Observes the in-flight element drag regardless of drop targets, to react to
 * its progress without making an element droppable. Every arg is documented on
 * {@link DragAndDropMonitorArgs}.
 *
 * ```hbs
 * <div {{dDragAndDropMonitor types=this.dragTypes onDrag=this.onDrag}}></div>
 * ```
 *
 * @see The `dragAndDrop` service to read drag state reactively; rendering from
 *   these callbacks duplicates what it keeps.
 * @see `dDragDwell` for the packaged case of acting once a drag has hovered
 *   one element for a delay.
 */
export default modifier<DDragAndDropMonitorSignature>(
  (_element, _positional, args) =>
    // Read args inside the closure: reading them here would track them and
    // re-run the modifier, re-registering the monitor on every change.
    registerDragAndDropMonitor(() => ({
      types: args.types,
      onDragStart: args.onDragStart,
      onDrag: args.onDrag,
      onDrop: args.onDrop,
    }))
);
