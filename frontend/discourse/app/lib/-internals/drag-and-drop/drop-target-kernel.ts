import type {
  CleanupFn,
  DragLocationHistory,
  Input,
} from "@atlaskit/pragmatic-drag-and-drop/types";
import { consumerMayThrow } from "discourse/lib/-internals/drag-and-drop/consumer-may-throw";

/** Where a drop would land relative to its target. */
export type DropPosition = "before" | "after" | "inside";

/** The axis used for position math and indicator classes. */
export type DropAxis = "x" | "y";

/** The cursor feedback the browser shows for a drop. */
export type DropEffect = "copy" | "link" | "move";

/** How a target decides where a drop would land. */
export interface DropPositionOptions {
  /** A fixed position, which wins over midpoint math. */
  position?: DropPosition;

  /** The axis whose midpoint is measured. Defaults to `"y"`. */
  axis?: DropAxis;
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
  /** Synchronous gate. Returning `false` refuses the drop. */
  canDrop?: (feedback: DropTargetKernelFeedback<Source>) => boolean | void;

  /** Determines the cursor feedback browsers show during the drag. */
  getDropEffect?: (feedback: DropTargetKernelFeedback<Source>) => DropEffect;

  /** `false` suppresses the target's indicator. */
  indicator?: boolean;

  /** Called when this target becomes the deepest accepted target. */
  onDragEnter?: (event: DropTargetKernelEvent<Source>) => void;

  /** Called while this target is the deepest accepted target. */
  onDrag?: (event: DropTargetKernelEvent<Source>) => void;

  /** Called when this target stops being the deepest accepted target. */
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

type DropTargetRegistrationArgs<Payload> = {
  element: Element;
  canDrop: (args: LibraryFeedbackArgs<Payload>) => boolean;
  getDropEffect: (args: LibraryFeedbackArgs<Payload>) => DropEffect | undefined;
  onDragEnter: (args: LibraryEventArgs<Payload>) => void;
  onDrag: (args: LibraryEventArgs<Payload>) => void;
  onDragLeave: (args: LibraryEventArgs<Payload>) => void;
  onDrop: (args: LibraryEventArgs<Payload>) => void;
};

/** Adapter-specific configuration for the shared drop-target state machine. */
export interface DropTargetKernelConfig<
  Payload,
  Source,
  LibraryExtras extends object = object,
> {
  /** The element to register as a drop target. */
  element: Element;

  /** The data attribute stamped for the lifetime of the registration. */
  attribute: "data-drop-target" | "data-drop-target-external";

  /** Registers the callbacks with the adapter. */
  register: (
    args: DropTargetRegistrationArgs<Payload> & LibraryExtras
  ) => CleanupFn;

  /** Converts the adapter payload to the consumer-facing source. */
  decorateSource: (payload: Payload) => Source;

  /** Applies adapter-specific filters before the consumer's gate. */
  accepts: (payload: Payload) => boolean;

  /** Resolves the position reported for the current pointer input. */
  resolvePosition: (input: Input) => DropPosition | null;

  /** Displays and clears adapter-specific target feedback. */
  indicator: {
    /** Displays feedback for the current position and axis. */
    show: (position: DropPosition | null, axis: DropAxis) => void;

    /** Clears all feedback owned by this registration. */
    clear: () => void;
  };

  /** Additional callbacks passed only to this adapter's registration. */
  libraryExtras?: LibraryExtras;

  /** Optional adapter teardown run after the shared cleanup. */
  onCleanup?: () => void;

  /** Returns the consumer's latest callbacks and display options. */
  getArgs: () => DropTargetKernelArgs<Source>;
}

const POSITION_CLASSES = Object.freeze({
  before: { y: "--drag-above", x: "--drag-left" },
  after: { y: "--drag-below", x: "--drag-right" },
  inside: { y: "--drag-inside", x: "--drag-inside" },
});

/**
 * Resolves a fixed position or the side of the element's midpoint containing
 * the pointer.
 *
 * @param element - The target element to measure against.
 * @param input - The current pointer position.
 * @param options - The consumer's position and axis options.
 */
export function resolveDropPosition(
  element: Element,
  input: Input,
  { position, axis = "y" }: DropPositionOptions
): DropPosition {
  if (position) {
    return position;
  }
  const rect = element.getBoundingClientRect();
  if (axis === "x") {
    return input.clientX < rect.left + rect.width / 2 ? "before" : "after";
  }
  return input.clientY < rect.top + rect.height / 2 ? "before" : "after";
}

/**
 * Creates positional feedback that keeps at most one indicator class active.
 *
 * @param element - The element carrying the indicator class.
 */
export function createPositionIndicator(element: Element) {
  let activeClass: string | null = null;

  return {
    apply(position: DropPosition, axis: DropAxis) {
      const className = POSITION_CLASSES[position]?.[axis];
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
    },
  };
}

function isDeepestTarget(location: DragLocationHistory, element: Element) {
  return location.current.dropTargets[0]?.element === element;
}

function createEnterLeavePairing() {
  let entered = false;

  return {
    enter(fire: () => void) {
      if (entered) {
        return;
      }
      entered = true;
      fire();
    },
    leave(fire: () => void) {
      if (!entered) {
        return;
      }
      entered = false;
      fire();
    },
    reset() {
      entered = false;
    },
  };
}

/**
 * Registers the shared drop-target state machine through a concrete adapter.
 *
 * @param config - Adapter hooks and the latest consumer arguments.
 * @returns Cleanup for the adapter registration and its target state.
 */
export function registerDropTargetKernel<
  Payload,
  Source,
  LibraryExtras extends object = object,
>({
  element,
  attribute,
  register,
  decorateSource,
  accepts,
  resolvePosition,
  indicator,
  libraryExtras,
  onCleanup,
  getArgs,
}: DropTargetKernelConfig<Payload, Source, LibraryExtras>): CleanupFn {
  const pairing = createEnterLeavePairing();

  const passesGate = (source: Payload, input: Input) => {
    if (!accepts(source)) {
      return false;
    }
    const callback = getArgs().canDrop;
    if (!callback) {
      return true;
    }
    return (
      consumerMayThrow(
        () =>
          callback({ source: decorateSource(source), input, element }) !==
          false,
        false
      ) ?? false
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
    const position = resolvePosition(location.current.input);
    if (args.indicator !== false) {
      indicator.show(position, args.axis ?? "y");
    }
    // A target can become deepest on a drag update without receiving a fresh
    // enter, so taking the role and observing it stay active share this path.
    pairing.enter(() =>
      consumerMayThrow(() =>
        args.onDragEnter?.({
          source: decorateSource(source),
          position,
          location,
          element,
        })
      )
    );
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
    ...libraryExtras,
    element,
    canDrop: ({ source, input }) => passesGate(source, input),
    getDropEffect: ({ source, input }) =>
      consumerMayThrow(() =>
        getArgs().getDropEffect?.({
          source: decorateSource(source),
          input,
          element,
        })
      ),
    onDragEnter: ({ source, location }) =>
      reportActive(source, location, false),
    onDrag: ({ source, location }) => reportActive(source, location, true),
    onDragLeave: ({ source, location }) => {
      indicator.clear();
      reportLeave(source, location);
    },
    onDrop: ({ source, location }) => {
      // Every target in the settled hierarchy receives the drop, including an
      // ancestor that is no longer deepest but might still show stale feedback.
      indicator.clear();
      // A drop closes the drag without also reporting a leave.
      pairing.reset();
      if (!isDeepestTarget(location, element)) {
        return;
      }
      // The settled hierarchy is reused at drop, so a gate that changed since
      // the last drag update must be asked again before acting.
      if (!passesGate(source, location.current.input)) {
        return;
      }
      consumerMayThrow(() =>
        getArgs().onDrop?.({
          source: decorateSource(source),
          position: resolvePosition(location.current.input),
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
