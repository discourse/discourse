import type {
  CleanupFn,
  DragLocationHistory,
  Input,
} from "@atlaskit/pragmatic-drag-and-drop/types";
import { consumerMayThrow } from "discourse/lib/-internals/drag-and-drop/consumer-may-throw";
import type { Axis } from "discourse/lib/geometry";

/** The pointer position as the underlying library reports it. */
export type DragInput = Input;

/** The drag's initial, previous and current locations. */
export type DragLocation = DragLocationHistory;

/** Where a drop would land relative to its target. */
export type DropPosition = "before" | "after" | "inside";

/** The cursor feedback the browser shows for a drop. */
export type DropEffect = "copy" | "link" | "move";

/** How a target decides where a drop would land. */
export interface DropPositionOptions {
  /** A fixed position, which wins over midpoint math. */
  position?: DropPosition;

  /** The axis whose midpoint is measured. Defaults to `"vertical"`. */
  axis?: Axis;
}

/** What a synchronous consumer gate is asked about. */
export interface DropTargetKernelFeedback<Source> {
  /** The consumer-facing drag source. */
  source: Source;

  /** The pointer position. */
  input: Input;

  /** The registered target element. */
  element: Element;
}

/** What a consumer lifecycle callback is told. */
export interface DropTargetKernelEvent<Source> {
  /** The consumer-facing drag source. */
  source: Source;

  /** Where the drop would land, or `null` when no position applies. */
  position: DropPosition | null;

  /** The drag's location history. */
  location: DragLocationHistory;

  /** The registered target element. */
  element: Element;
}

/** Consumer callbacks and display options shared by every drop target. */
export interface DropTargetKernelArgs<Source> extends DropPositionOptions {
  /**
   * Synchronous gate. Returning `false` refuses the drop. The feedback carries
   * the consumer-facing source, current pointer input, and target element.
   */
  canDrop?: (feedback: DropTargetKernelFeedback<Source>) => boolean | void;

  /** Determines the cursor feedback browsers show during the drag. */
  getDropEffect?: (feedback: DropTargetKernelFeedback<Source>) => DropEffect;

  /** Metadata attached to the drag's record of this target under `.data`. */
  getData?: () => object;

  /** Whether the target remains current briefly after the pointer leaves. */
  getIsSticky?: () => boolean;

  /** `false` suppresses the target's indicator. Defaults to `true`. */
  indicator?: boolean;

  /**
   * Called when this target becomes the deepest accepted target. This usually
   * means the pointer entered it, but can also mean a nested target that was
   * covering it went away, so it can fire without the pointer moving.
   */
  onDragEnter?: (event: DropTargetKernelEvent<Source>) => void;

  /**
   * Called while this target is the deepest accepted target. It is throttled
   * and fires when the input or drop-target hierarchy updates.
   */
  onDrag?: (event: DropTargetKernelEvent<Source>) => void;

  /**
   * Called when this target stops being the deepest accepted target. This can
   * mean the pointer left or a nested target took over; `position` is `null`.
   *
   * This tracks the role rather than callback presence: it fires only after the
   * target took the role, and once each time it gives it up, whether or not an
   * `onDragEnter` callback observed it taking the role.
   *
   * A drop and teardown end the drag without a leave callback, so consumers
   * must also release their own drag-time state when they are destroyed.
   */
  onDragLeave?: (event: DropTargetKernelEvent<Source>) => void;

  /** Called when the drag is released on this target. */
  onDrop?: (event: DropTargetKernelEvent<Source>) => void;
}

type LibraryFeedbackArgs<Payload> = {
  input: Input;
  source: Payload;
  element: Element;
};

type LibraryEventArgs<Payload> = {
  source: Payload;
  location: DragLocationHistory;
};

export type DropTargetRegistrationArgs<Payload> = {
  element: Element;
  canDrop: (args: LibraryFeedbackArgs<Payload>) => boolean;
  getData: (
    args: LibraryFeedbackArgs<Payload>
  ) => Record<string | symbol, unknown>;
  getDropEffect: (args: LibraryFeedbackArgs<Payload>) => DropEffect | undefined;
  getIsSticky: (args: LibraryFeedbackArgs<Payload>) => boolean;
  onDropTargetChange: (args: LibraryEventArgs<Payload>) => void;
  onDragEnter: (args: LibraryEventArgs<Payload>) => void;
  onDrag: (args: LibraryEventArgs<Payload>) => void;
  onDragLeave: (args: LibraryEventArgs<Payload>) => void;
  onDrop: (args: LibraryEventArgs<Payload>) => void;
};

/** Adapter-specific configuration for the shared drop-target state machine. */
export interface DropTargetKernelConfig<Payload, Source> {
  /** The element to register as a drop target. */
  element: Element;

  /** The data attribute stamped for the lifetime of the registration. */
  attribute: "data-drop-target" | "data-drop-target-external";

  /** Registers the callbacks with the adapter. */
  register: (args: DropTargetRegistrationArgs<Payload>) => CleanupFn;

  /** Converts the adapter payload to the consumer-facing source. */
  decorateSource: (payload: Payload) => Source;

  /** Applies adapter-specific filters before the consumer's gate. */
  accepts: (payload: Payload) => boolean;

  /** Whether this adapter resolves a position for the current arguments. */
  resolvesPosition?: (args: DropTargetKernelArgs<Source>) => boolean;

  /** The hover class used when this adapter resolves no position. */
  positionlessClass?: string;

  /** Optional adapter teardown run after the shared cleanup. */
  onCleanup?: () => void;

  /** Returns the consumer's latest callbacks and display options. */
  getArgs: () => DropTargetKernelArgs<Source>;
}

const POSITION_CLASSES = Object.freeze({
  before: { vertical: "--drag-above", horizontal: "--drag-left" },
  after: { vertical: "--drag-below", horizontal: "--drag-right" },
  inside: { vertical: "--drag-inside", horizontal: "--drag-inside" },
});

/**
 * Resolves a fixed position or the side of the element's midpoint containing
 * the pointer.
 *
 * @param element - The target element to measure against.
 * @param input - The current pointer position.
 * @param options - The consumer's position and axis options.
 * @param rtl - Whether the target's sampled writing direction is right-to-left.
 */
function resolveDropPosition(
  element: Element,
  input: Input,
  { position, axis = "vertical" }: DropPositionOptions,
  rtl: boolean
): DropPosition {
  if (position) {
    return position;
  }
  const rect = element.getBoundingClientRect();
  if (axis === "horizontal") {
    const isPhysicalLeft = input.clientX < rect.left + rect.width / 2;
    return isPhysicalLeft === rtl ? "after" : "before";
  }
  return input.clientY < rect.top + rect.height / 2 ? "before" : "after";
}

/**
 * Creates positional feedback that keeps at most one indicator class active.
 *
 * @param element - The element carrying the indicator class.
 */
function createPositionIndicator(element: Element, positionlessClass?: string) {
  let activeClass: string | null = null;

  return {
    show(position: DropPosition | null, axis: Axis, rtl: boolean) {
      if (!position) {
        if (activeClass) {
          element.classList.remove(activeClass);
          activeClass = null;
        }
        if (positionlessClass) {
          element.classList.add(positionlessClass);
        }
        return;
      }

      if (positionlessClass) {
        element.classList.remove(positionlessClass);
      }
      const physicalPosition =
        axis === "horizontal" && rtl && position !== "inside"
          ? position === "before"
            ? "after"
            : "before"
          : position;
      const className = POSITION_CLASSES[physicalPosition][axis];
      if (!className || activeClass === className) {
        return;
      }
      if (activeClass) {
        element.classList.remove(activeClass);
      }
      element.classList.add(className);
      activeClass = className;
    },
    clear() {
      if (activeClass) {
        element.classList.remove(activeClass);
        activeClass = null;
      }
      if (positionlessClass) {
        element.classList.remove(positionlessClass);
      }
    },
  };
}

function isDeepestTarget(location: DragLocationHistory, element: Element) {
  return location.current.dropTargets[0]?.element === element;
}

function createEnterLeavePairing(element: Element) {
  let entered = false;
  let rtl: boolean | null = null;

  return {
    enter() {
      if (entered) {
        return false;
      }
      entered = true;
      return true;
    },
    isRtl() {
      if (!entered) {
        return false;
      }
      return (rtl ??= getComputedStyle(element).direction === "rtl");
    },
    leave(fire: () => void) {
      rtl = null;
      if (!entered) {
        return;
      }
      entered = false;
      fire();
    },
    reset() {
      entered = false;
      rtl = null;
    },
  };
}

/**
 * Registers the shared drop-target state machine through a concrete adapter.
 *
 * @param config - Adapter hooks and the latest consumer arguments.
 * @returns Cleanup for the adapter registration and its target state.
 */
export function registerDropTargetKernel<Payload, Source>({
  element,
  attribute,
  register,
  decorateSource,
  accepts,
  resolvesPosition = () => true,
  positionlessClass,
  onCleanup,
  getArgs,
}: DropTargetKernelConfig<Payload, Source>): CleanupFn {
  const pairing = createEnterLeavePairing(element);
  const indicator = createPositionIndicator(element, positionlessClass);

  const positionFor = (
    args: DropTargetKernelArgs<Source>,
    input: Input,
    rtl: boolean
  ) =>
    resolvesPosition(args)
      ? resolveDropPosition(element, input, args, rtl)
      : null;

  const passesGate = (source: Payload, input: Input) => {
    if (!accepts(source)) {
      return false;
    }
    const callback = getArgs().canDrop;
    if (!callback) {
      return true;
    }
    return consumerMayThrow(
      () =>
        callback({ source: decorateSource(source), input, element }) !== false,
      false
    );
  };

  const reportLeave = (source: Payload, location: DragLocationHistory) =>
    pairing.leave(() =>
      consumerMayThrow(() =>
        getArgs().onDragLeave?.({
          source: decorateSource(source),
          position: null,
          location,
          element,
        })
      )
    );

  const reportActive = (
    source: Payload,
    location: DragLocationHistory,
    reportDrag: boolean
  ) => {
    if (!isDeepestTarget(location, element)) {
      indicator.clear();
      // An ancestor remains in the target hierarchy when a child takes over,
      // so no native leave arrives to close its consumer-facing enter.
      reportLeave(source, location);
      return;
    }

    const args = getArgs();
    const entered = pairing.enter();
    const rtl = pairing.isRtl();
    const position = positionFor(args, location.current.input, rtl);
    if (args.indicator === false) {
      indicator.clear();
    } else {
      indicator.show(position, args.axis ?? "vertical", rtl);
    }
    // A target can become deepest on a drag update without receiving a fresh
    // enter, so taking the role and observing it stay active share this path.
    if (entered) {
      consumerMayThrow(() =>
        args.onDragEnter?.({
          source: decorateSource(source),
          position,
          location,
          element,
        })
      );
    }
    if (reportDrag) {
      consumerMayThrow(() =>
        args.onDrag?.({
          source: decorateSource(source),
          position,
          location,
          element,
        })
      );
    }
  };

  // The stylesheet gates the indicator classes on this attribute, which survives
  // a consumer rebinding `class` where a marker class would not.
  element.setAttribute(attribute, "");

  const cleanup = register({
    element,
    canDrop: ({ source, input }) => passesGate(source, input),
    getData: () =>
      consumerMayThrow(() => getArgs().getData?.() ?? {}, {}) as Record<
        string | symbol,
        unknown
      >,
    getDropEffect: ({ source, input }) =>
      consumerMayThrow(() =>
        getArgs().getDropEffect?.({
          source: decorateSource(source),
          input,
          element,
        })
      ),
    getIsSticky: () =>
      consumerMayThrow(() => getArgs().getIsSticky?.() === true, false),
    onDragEnter: ({ source, location }) =>
      reportActive(source, location, false),
    onDropTargetChange: ({ source, location }) =>
      reportActive(source, location, false),
    onDrag: ({ source, location }) => reportActive(source, location, true),
    onDragLeave: ({ source, location }) => {
      indicator.clear();
      reportLeave(source, location);
    },
    onDrop: ({ source, location }) => {
      // Read before the pairing is reset, so the drop's position agrees with
      // the direction the hover was measured against.
      const rtl = pairing.isRtl();
      // Every target in the settled hierarchy receives the drop; the deepest
      // one still shows its indicator.
      indicator.clear();
      // A non-deepest target was already left by the synchronous hierarchy
      // update; the drop only closes any pairing that remains.
      pairing.reset();
      if (!isDeepestTarget(location, element)) {
        return;
      }
      // The settled hierarchy is reused at drop, so a gate that changed since
      // the last drag update must be asked again before acting.
      if (!passesGate(source, location.current.input)) {
        return;
      }
      const args = getArgs();
      consumerMayThrow(() =>
        args.onDrop?.({
          source: decorateSource(source),
          position: positionFor(args, location.current.input, rtl),
          location,
          element,
        })
      );
    },
  });

  return () => {
    cleanup();
    indicator.clear();
    element.removeAttribute(attribute);
    onCleanup?.();
  };
}
