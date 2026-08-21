import { destroy } from "@ember/destroyable";
import { monitorForElements } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import { monitorForExternal } from "@atlaskit/pragmatic-drag-and-drop/external/adapter";
import type { CleanupFn } from "@atlaskit/pragmatic-drag-and-drop/types";
import { modifier } from "ember-modifier";
import { consumerMayThrow } from "discourse/lib/-internals/drag-and-drop/consumer-may-throw";
import createDragDwell, {
  type DragDwell,
} from "discourse/lib/-internals/drag-and-drop/drag-dwell";
import type {
  DragInput,
  DragLocation,
} from "discourse/lib/-internals/drag-and-drop/drop-target-kernel";
import {
  decorateExternalSource,
  type ExternalDragKind,
  type ExternalDragPayload,
  matchesExternalKind,
} from "discourse/lib/-internals/drag-and-drop/external-vocabulary";
import {
  matchesDragType,
  type NormalizedDragSource,
  normalizeDragSource,
} from "discourse/lib/-internals/drag-and-drop/vocabulary";

export {
  default as createDragDwell,
  type DragDwell,
  type DragDwellOptions,
} from "discourse/lib/-internals/drag-and-drop/drag-dwell";

/** Which adapter the observed drag arrived through. */
export type DragDwellFamily = "element" | "external";

/** The dragged payload a dwell observes, from either adapter. */
export type DragDwellSource = NormalizedDragSource | ExternalDragPayload;

/**
 * What {@link DragDwellArgs.canDwell} receives — structurally what a drop
 * target's `canDrop` receives, so one gating function can serve both.
 */
export interface DragDwellFeedback {
  /** Which adapter the drag arrived through; narrows `source`. */
  family: DragDwellFamily;

  /** The dragged payload. */
  source: DragDwellSource;

  /** The pointer, with `clientX`/`clientY`. */
  input: DragInput;

  /** The dwell host element. */
  element: HTMLElement;
}

/** What {@link DragDwellArgs.onDwell} receives. */
export interface DragDwellEvent {
  /** Which adapter the drag arrived through; narrows `source`. */
  family: DragDwellFamily;

  /** The dragged payload. */
  source: DragDwellSource;

  /** The drag's positions: `initial`, `previous`, and `current`. */
  location: DragLocation;

  /** The dwell host element. */
  element: HTMLElement;
}

/** Why a candidacy ended. */
export type DragDwellEndReason = "left" | "drag-ended";

/** What {@link DragDwellArgs.onDwellEnd} receives. */
export interface DragDwellEndEvent extends DragDwellEvent {
  /**
   * `"left"` when the drag stopped hovering the element or stopped
   * qualifying; `"drag-ended"` when the drag finished anywhere — dropped,
   * abandoned, or cancelled.
   */
  reason: DragDwellEndReason;

  /** Whether `onDwell` had fired for this candidacy — the undo predicate. */
  fired: boolean;

  /**
   * On `"drag-ended"`: whether the drop landed on this element or inside it.
   * Always `false` for `"left"`.
   */
  droppedHere: boolean;
}

interface DDragDwellSignature {
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Element drag types to watch. Omit to watch every element drag.
       * Consulted as each drag starts.
       */
      types?: string | string[];

      /**
       * External drag kinds to watch. Omitting it refuses every external
       * drag: the dwell only reacts to drags from outside the window when a
       * consumer asks for them.
       */
      externalKinds?: ExternalDragKind | ExternalDragKind[];

      /**
       * Milliseconds of qualifying hover before `onDwell` fires. Defaults to
       * `500`. Sampled when the first candidacy arms.
       */
      delay?: number;

      /**
       * Whether a drag hovering the element may start or continue a pending
       * candidacy. Same feedback shape as a drop target's `canDrop`, so the
       * two MAY share one function. Only a literal `false` refuses; it runs
       * after `types`/`externalKinds` filtering, and is not consulted again once
       * the dwell has fired.
       */
      canDwell?: (feedback: DragDwellFeedback) => boolean | void;

      /**
       * Whether a drag whose source element is this element, or inside it,
       * may dwell. Defaults to `true`.
       */
      acceptsSelf?: boolean;

      /** The dwell fired: the drag hovered long enough. */
      onDwell: (event: DragDwellEvent) => void;

      /**
       * The candidacy ended — the drag left, stopped qualifying, or
       * finished. The place to undo what `onDwell` did.
       */
      onDwellEnd?: (event: DragDwellEndEvent) => void;
    };
    Positional: [];
  };
}

/**
 * Every named arg of {@link dDragDwell}, for a consumer driving
 * {@link registerDragDwell} imperatively rather than through the modifier.
 */
export type DragDwellArgs = DDragDwellSignature["Args"]["Named"];

function isWithin(input: DragInput, clientRect: DOMRect) {
  return (
    // is within horizontal bounds
    input.clientX >= clientRect.x &&
    input.clientX <= clientRect.x + clientRect.width &&
    // is within vertical bounds
    input.clientY >= clientRect.y &&
    input.clientY <= clientRect.y + clientRect.height
  );
}

function matchesNormalizedDragType(
  types: DragDwellArgs["types"],
  source: NormalizedDragSource
) {
  // matchesDragType reads only `data`; normalization omits the unrelated
  // adapter-only `dragHandle` field from its consumer-facing shape.
  return matchesDragType(
    types,
    source as unknown as Parameters<typeof matchesDragType>[1]
  );
}

/**
 * Watches drags the way a monitor does and reports dwells on one element.
 *
 * This uses rectangle containment, which does not account for another element
 * occluding the host. An element drag leaving the window can also leave one
 * stale in-rectangle input until the drag ends. Registering the external
 * monitor mounts that adapter page-wide, as the drag-and-drop service does.
 *
 * The delay is sampled when the first candidacy arms. Every other argument is
 * read lazily from monitor or timer callbacks.
 *
 * @param element - The dwell host.
 * @param getArgsRef - Closure returning the latest arguments.
 * @returns Cleanup; call it once on teardown.
 */
export function registerDragDwell(
  element: HTMLElement,
  getArgsRef: () => DragDwellArgs
): CleanupFn {
  const lifetime = {};
  let dwell: DragDwell<DragDwellEvent> | null = null;
  let hovering = false;
  let fired = false;
  let lastEvent: DragDwellEvent | null = null;
  let isDestroying = false;

  const passesGate = (event: DragDwellEvent) => {
    const callback = getArgsRef().canDwell;
    if (!callback) {
      return true;
    }
    return consumerMayThrow(
      () =>
        callback({
          family: event.family,
          source: event.source,
          input: event.location.current.input,
          element,
        }) !== false,
      false
    );
  };

  const getDwell = () => {
    if (dwell) {
      return dwell;
    }

    const { delay } = getArgsRef();
    dwell = createDragDwell<DragDwellEvent>({
      destroyable: lifetime,
      delay,
      identity: () => element,
      onDwell: () => {
        if (isDestroying || !hovering || !lastEvent) {
          return;
        }
        const event = lastEvent;
        if (!passesGate(event)) {
          dwell?.reset();
          hovering = false;
          fired = false;
          lastEvent = null;
          return;
        }

        fired = true;
        const consumerOnDwell = getArgsRef().onDwell;
        // A throw from a runloop timer would bypass the normal client-error
        // reporting path without this boundary.
        consumerMayThrow(() => consumerOnDwell(event));
      },
    });
    return dwell;
  };

  const reportCandidate = (event: DragDwellEvent, adapterMatches: boolean) => {
    if (isDestroying) {
      return;
    }

    const inRect = isWithin(
      event.location.current.input,
      element.getBoundingClientRect()
    );
    const qualifies = adapterMatches && inRect && (fired || passesGate(event));

    if (!qualifies) {
      if (!hovering) {
        return;
      }

      dwell?.update(null);
      if (lastEvent) {
        consumerMayThrow(() =>
          getArgsRef().onDwellEnd?.({
            ...lastEvent,
            reason: "left",
            fired,
            droppedHere: false,
          })
        );
      }
      hovering = false;
      fired = false;
      lastEvent = null;
      return;
    }

    if (!hovering) {
      hovering = true;
      fired = false;
    }
    lastEvent = event;
    getDwell().update(event);
  };

  const reportDragEnded = (location: DragLocation) => {
    if (isDestroying || !hovering || !lastEvent) {
      return;
    }

    const event = lastEvent;
    const droppedHere = location.current.dropTargets.some(
      (target) => element === target.element || element.contains(target.element)
    );
    // make-adapter.js dispatches source -> drop targets -> monitors, so a
    // target's onDrop is guaranteed to run before this monitor callback.
    consumerMayThrow(() =>
      getArgsRef().onDwellEnd?.({
        ...event,
        reason: "drag-ended",
        fired,
        droppedHere,
      })
    );
    dwell?.reset();
    hovering = false;
    fired = false;
    lastEvent = null;
  };

  const cleanupElements = monitorForElements({
    onDrag: ({ source, location }) => {
      const args = getArgsRef();
      const normalizedSource = normalizeDragSource(source);
      const acceptsSelf =
        args.acceptsSelf !== false ||
        (normalizedSource.element !== element &&
          !element.contains(normalizedSource.element));
      reportCandidate(
        { family: "element", source: normalizedSource, location, element },
        matchesNormalizedDragType(args.types, normalizedSource) && acceptsSelf
      );
    },
    onDropTargetChange: ({ source, location }) => {
      const args = getArgsRef();
      const normalizedSource = normalizeDragSource(source);
      const acceptsSelf =
        args.acceptsSelf !== false ||
        (normalizedSource.element !== element &&
          !element.contains(normalizedSource.element));
      reportCandidate(
        { family: "element", source: normalizedSource, location, element },
        matchesNormalizedDragType(args.types, normalizedSource) && acceptsSelf
      );
    },
    onDrop: ({ location }) => reportDragEnded(location),
  });

  const cleanupExternal = monitorForExternal({
    onDrag: ({ source, location }) => {
      const { externalKinds } = getArgsRef();
      reportCandidate(
        {
          family: "external",
          source: decorateExternalSource(source),
          location,
          element,
        },
        externalKinds != null && matchesExternalKind(externalKinds, source)
      );
    },
    onDrop: ({ location }) => reportDragEnded(location),
  });

  return () => {
    isDestroying = true;
    cleanupElements();
    cleanupExternal();
    destroy(lifetime);
    hovering = false;
    fired = false;
    lastEvent = null;
  };
}

/**
 * Fires a callback once a drag has hovered the element for a delay, without
 * making the element a drop target. Every arg is documented on
 * {@link DragDwellArgs}.
 *
 * ```hbs
 * <div {{dDragDwell types="card" onDwell=this.open onDwellEnd=this.close}}>
 * ```
 */
export default modifier<DDragDwellSignature>((element, _positional, args) =>
  // Read args inside the closure: reading them here would track them and
  // re-run the modifier, tearing down a live candidacy.
  registerDragDwell(element, () => args)
);
