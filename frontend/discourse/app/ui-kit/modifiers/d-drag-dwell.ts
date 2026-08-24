import { destroy } from "@ember/destroyable";
import { cancel } from "@ember/runloop";
import type { ElementDragPayload } from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import type { ExternalDragPayload as NativeExternalDragPayload } from "@atlaskit/pragmatic-drag-and-drop/adapter/external-adapter-types";
import { monitorForElements } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import { monitorForExternal } from "@atlaskit/pragmatic-drag-and-drop/external/adapter";
import type { CleanupFn } from "@atlaskit/pragmatic-drag-and-drop/types";
import { modifier } from "ember-modifier";
import { consumerMayThrow } from "discourse/lib/-internals/drag-and-drop/consumer-may-throw";
import createDragDwell, {
  DEFAULT_DRAG_DWELL_DELAY,
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
import { makeArray } from "discourse/lib/helpers";
import discourseLater from "discourse/lib/later";

export {
  default as createDragDwell,
  DEFAULT_DRAG_DWELL_DELAY,
  type DragDwell,
  type DragDwellOptions,
} from "discourse/lib/-internals/drag-and-drop/drag-dwell";

/** Which adapter the observed drag arrived through. */
export type DragDwellFamily = "element" | "external";

/** The dragged payload a dwell observes, from either adapter. */
export type DragDwellSource = NormalizedDragSource | ExternalDragPayload;

/**
 * The observed drag: which adapter carried it, discriminating the payload
 * shape. Checking `family` narrows `source`.
 */
type DragDwellObservation =
  | {
      /** The drag came from a registered element source. */
      family: "element";

      /** The dragged payload, normalized. */
      source: NormalizedDragSource;
    }
  | {
      /** The drag came from outside the window. */
      family: "external";

      /** The decorated external payload. */
      source: ExternalDragPayload;
    };

/**
 * What {@link DragDwellArgs.canDwell} receives — structurally what a drop
 * target's `canDrop` receives, so one gating function can serve both.
 */
export type DragDwellFeedback = DragDwellObservation & {
  /** The pointer, with `clientX`/`clientY`. */
  input: DragInput;

  /** The dwell host element. */
  element: HTMLElement;
};

/** What {@link DragDwellArgs.onDwell} receives. */
export type DragDwellEvent = DragDwellObservation & {
  /** The drag's positions: `initial`, `previous`, and `current`. */
  location: DragLocation;

  /** The dwell host element. */
  element: HTMLElement;
};

/** Why a candidacy ended. */
export type DragDwellEndReason = "left" | "drag-ended";

/** What {@link DragDwellArgs.onDwellEnd} receives. */
export type DragDwellEndEvent = DragDwellEvent & {
  /**
   * `"left"` when the drag stopped hovering the element or stopped
   * qualifying; `"drag-ended"` when the drag finished anywhere — dropped,
   * abandoned, or cancelled.
   */
  reason: DragDwellEndReason;

  /** Whether `onDwell` had fired for this candidacy — the undo predicate. */
  fired: boolean;

  /**
   * On `"drag-ended"`: whether the drop landed on a drop target on this
   * element or on one of its descendants. Always `false` for `"left"`, and
   * `false` when the host subtree registers no drop target at all.
   */
  droppedHere: boolean;
};

interface DDragDwellSignature {
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Element drag types to watch. Omit to watch every element drag.
       * Re-read on every frame.
       */
      types?: string | string[];

      /**
       * External drag kinds to watch. Omitting it, or naming no kinds,
       * refuses every external drag: the dwell only reacts to drags from
       * outside the window when a consumer asks for them.
       */
      externalKinds?: ExternalDragKind | ExternalDragKind[];

      /**
       * How long a qualifying hover lasts before `onDwell` fires. `true`, the
       * default, is the standard 500 ms; `false` fires on the first qualifying
       * frame; a number is the wait in milliseconds. Sampled when the first
       * candidacy arms.
       */
      delay?: boolean | number;

      /**
       * Grace before a fired dwell is undone once the drag leaves the
       * element. `true`, the default, mirrors the entry delay, or the
       * standard 500 ms when entry is immediate; `false` ends it in the
       * leaving frame; a number is the grace in milliseconds. A drag
       * returning within the grace keeps the dwell as if it never left, and
       * a drag ending during it reports `drag-ended` instead. A candidacy
       * that has not fired yet ends immediately either way.
       */
      leaveDelay?: boolean | number;

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

/**
 * The entry delay in milliseconds: `true` and omission are the standard
 * delay, `false` is immediate, and a number stands as given.
 */
export function resolveDwellDelay(delay: boolean | number | undefined): number {
  if (delay === false) {
    return 0;
  }
  if (delay === true || delay == null) {
    return DEFAULT_DRAG_DWELL_DELAY;
  }
  return delay;
}

/**
 * The leave grace in milliseconds: `true` and omission mirror the resolved
 * entry delay and fall back to the standard delay when entry is immediate,
 * `false` is immediate, and a number stands as given.
 */
export function resolveDwellLeaveDelay(
  leaveDelay: boolean | number | undefined,
  delay: boolean | number | undefined
): number {
  if (leaveDelay === false) {
    return 0;
  }
  if (leaveDelay === true || leaveDelay == null) {
    const entry = resolveDwellDelay(delay);
    return entry > 0 ? entry : DEFAULT_DRAG_DWELL_DELAY;
  }
  return leaveDelay;
}

function isWithin(input: DragInput, clientRect: DOMRect) {
  return (
    input.clientX >= clientRect.x &&
    input.clientX <= clientRect.x + clientRect.width &&
    input.clientY >= clientRect.y &&
    input.clientY <= clientRect.y + clientRect.height
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
  let pendingLeave: ReturnType<typeof discourseLater> | null = null;
  let isDestroying = false;

  const cancelPendingLeave = () => {
    if (pendingLeave) {
      cancel(pendingLeave);
      pendingLeave = null;
    }
  };

  const passesGate = (event: DragDwellEvent) => {
    const callback = getArgsRef().canDwell;
    if (!callback) {
      return true;
    }
    const { location, ...observation } = event;
    return consumerMayThrow(
      () =>
        callback({ ...observation, input: location.current.input }) !== false,
      false
    );
  };

  const getDwell = () => {
    if (dwell) {
      return dwell;
    }

    dwell = createDragDwell<DragDwellEvent>({
      destroyable: lifetime,
      delay: resolveDwellDelay(getArgsRef().delay),
      identity: () => element,
      onDwell: () => {
        if (isDestroying || !hovering || !lastEvent) {
          return;
        }
        const event = lastEvent;
        const gateAllows = passesGate(event);
        // The gate is consumer code and may have torn this registration down.
        if (isDestroying) {
          return;
        }
        if (!gateAllows) {
          dwell?.reset();
          consumerMayThrow(() =>
            getArgsRef().onDwellEnd?.({
              ...event,
              reason: "left",
              fired: false,
              droppedHere: false,
            })
          );
          hovering = false;
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
    // The gate is consumer code and may have torn this registration down.
    if (isDestroying) {
      return;
    }

    if (!qualifies) {
      if (!hovering || pendingLeave) {
        return;
      }

      const args = getArgsRef();
      const leaveDelay = fired
        ? resolveDwellLeaveDelay(args.leaveDelay, args.delay)
        : 0;
      if (leaveDelay > 0) {
        // The factory's latched identity is left untouched while the grace
        // runs, so a drag returning in time continues the fired candidacy
        // instead of arming a second dwell.
        pendingLeave = discourseLater(() => {
          pendingLeave = null;
          if (isDestroying || !hovering || !lastEvent) {
            return;
          }
          const endEvent = lastEvent;
          dwell?.update(null);
          consumerMayThrow(() =>
            getArgsRef().onDwellEnd?.({
              ...endEvent,
              reason: "left",
              fired,
              droppedHere: false,
            })
          );
          hovering = false;
          fired = false;
          lastEvent = null;
        }, leaveDelay);
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

    cancelPendingLeave();
    if (!hovering) {
      hovering = true;
      fired = false;
    }
    lastEvent = event;
    getDwell().update(event);
  };

  const reportDragEnded = (location: DragLocation) => {
    // A drag ending inside the grace beats it: the terminal event reports
    // once, as a drag end.
    cancelPendingLeave();
    if (isDestroying || !hovering || !lastEvent) {
      return;
    }

    const event = lastEvent;
    const droppedHere = location.current.dropTargets.some((target) =>
      element.contains(target.element)
    );
    // make-adapter.js dispatches source -> drop targets -> monitors, so a
    // target's onDrop is guaranteed to run before this monitor callback.
    consumerMayThrow(() =>
      getArgsRef().onDwellEnd?.({
        ...event,
        location,
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

  const reportElementCandidate = (
    source: ElementDragPayload,
    location: DragLocation
  ) => {
    const args = getArgsRef();
    const normalizedSource = normalizeDragSource(source);
    const acceptsSelf =
      args.acceptsSelf !== false || !element.contains(normalizedSource.element);
    reportCandidate(
      { family: "element", source: normalizedSource, location, element },
      // Matched on the raw payload: an adopted drag answers to its adoption's
      // declared type there, which normalization strips from `data`.
      matchesDragType(args.types, source) && acceptsSelf
    );
  };

  const reportExternalCandidate = (
    source: NativeExternalDragPayload,
    location: DragLocation
  ) => {
    const { externalKinds } = getArgsRef();
    reportCandidate(
      {
        family: "external",
        source: decorateExternalSource(source),
        location,
        element,
      },
      makeArray(externalKinds).length > 0 &&
        matchesExternalKind(externalKinds, source)
    );
  };

  const cleanupElements = monitorForElements({
    onDragStart: ({ source, location }) =>
      reportElementCandidate(source, location),
    onDrag: ({ source, location }) => reportElementCandidate(source, location),
    onDropTargetChange: ({ source, location }) =>
      reportElementCandidate(source, location),
    onDrop: ({ location }) => reportDragEnded(location),
  });

  const cleanupExternal = monitorForExternal({
    onDragStart: ({ source, location }) =>
      reportExternalCandidate(source, location),
    onDrag: ({ source, location }) => reportExternalCandidate(source, location),
    onDropTargetChange: ({ source, location }) =>
      reportExternalCandidate(source, location),
    onDrop: ({ location }) => reportDragEnded(location),
  });

  return () => {
    isDestroying = true;
    cancelPendingLeave();
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
