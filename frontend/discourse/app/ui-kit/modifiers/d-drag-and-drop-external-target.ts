import {
  dropTargetForExternal,
  type ExternalDragPayload as NativeExternalDragPayload,
  type ExternalDropTargetEventBasePayload,
  type ExternalDropTargetGetFeedbackArgs,
} from "@atlaskit/pragmatic-drag-and-drop/external/adapter";
import { modifier } from "ember-modifier";
import {
  decorateExternalSource,
  type ExternalDragKind,
  type ExternalDragPayload,
  matchesExternalKind,
} from "discourse/lib/-internals/drag-and-drop/external-vocabulary";
import {
  createEnterLeavePairing,
  createPositionIndicator,
  type DropAxis,
  type DropEffect,
  type DropPosition,
  isDeepestTarget,
  resolveDropPosition,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

/** The pointer position as the underlying library reports it. */
type DragInput = ExternalDropTargetGetFeedbackArgs["input"];

/** The drag's initial, previous and current locations. */
type DragLocation = ExternalDropTargetEventBasePayload["location"];

/** What a synchronous gate (`canDrop`, `getDropEffect`) is asked about. */
export interface ExternalDropTargetFeedback {
  /** The incoming payload, with the read helpers bound to it. */
  source: ExternalDragPayload;

  /** Where the pointer is. */
  input: DragInput;

  /** This target's element. */
  element: Element;
}

/** What a lifecycle callback is told. */
export interface ExternalDropTargetEvent {
  /** The incoming payload, with the read helpers bound to it. */
  source: ExternalDragPayload;

  /**
   * Where the drop would land, `null` when the drag has left and also when the
   * target asked for no position at all — see `axis`.
   */
  position: DropPosition | null;

  /** The drag's location history. */
  location: DragLocation;

  /** This target's element. */
  element: Element;
}

/**
 * State modifier class toggled on the target while a compatible external drag
 * is hovering, for a target that resolves no position: it is a single
 * destination, so there is only one thing to say about it. A target that does
 * resolve a position uses the element variant's `--drag-above` / `--drag-below`
 * / `--drag-inside` instead, and never both — the two answer the same question
 * at different resolutions.
 */
const INDICATOR_CLASS = "--drag-over-external";

interface DDragAndDropExternalTargetSignature {
  /** The element to register as a drop target. */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Filters which external drag kinds engage the target. Omit to accept any
       * external drag.
       */
      accepts?: ExternalDragKind | ExternalDragKind[];

      /**
       * A fixed drop position. When set, `axis` and the midpoint logic are
       * ignored. Supplying it opts the target into resolving a position at all —
       * see `axis`.
       */
      position?: DropPosition;

      /**
       * Drives the indicator class selection and the midpoint position math,
       * exactly as on the element target.
       *
       * Supplying either this or `position` is what opts a target into
       * resolving a position: without one, callbacks are told `position: null`
       * and the indicator is the single `--drag-over-external` class. Most
       * external targets want that — a drop zone is one destination, not a slot
       * in a list. Reach for an axis when the target IS a slot, such as a row a
       * dragged-in link should land above or below.
       */
      axis?: DropAxis;

      /** Synchronous gate. Returning `false` refuses the drop. */
      canDrop?: (feedback: ExternalDropTargetFeedback) => boolean | void;

      /** Determines the cursor feedback browsers show during the drag. */
      getDropEffect?: (feedback: ExternalDropTargetFeedback) => DropEffect;

      /**
       * `false` to suppress the `--drag-over-external` indicator class. Defaults
       * to `true`.
       */
      indicator?: boolean;

      /**
       * This target became the one a drop would land on, with a compatible
       * external drag in flight. Usually the cursor entering it, but also a
       * nested target that was covering it going away, so it can fire without
       * the cursor moving.
       */
      onDragEnter?: (event: ExternalDropTargetEvent) => void;

      /**
       * The drag progressed. Throttled; fires when the input or the drop-target
       * hierarchy updates while this target is active.
       */
      onDrag?: (event: ExternalDropTargetEvent) => void;

      /**
       * This target stopped being the one a drop would land on. The cursor
       * leaving it, or a nested target taking over while the cursor is still
       * inside it. `position` is `null`.
       *
       * Tracks the role rather than the callbacks: fires only for a target that
       * had taken the role, and only once each time it gives it up, whether or
       * not an `onDragEnter` was supplied to observe it being taken.
       *
       * Not every taking is given up here, though. A drop ends the drag without
       * a leave, and so does the target being torn down mid-drag, so drag-time
       * state has to be released on the consumer's own destruction too.
       */
      onDragLeave?: (event: ExternalDropTargetEvent) => void;

      /** The drag was released on this target. */
      onDrop?: (event: ExternalDropTargetEvent) => void;
    };
    Positional: [];
  };
}

/**
 * The external drop target's named args, for a consumer driving
 * {@link registerDragAndDropExternalTarget} imperatively rather than through the
 * modifier.
 */
export type DragAndDropExternalTargetArgs =
  DDragAndDropExternalTargetSignature["Args"]["Named"];

/**
 * Imperative external drop-target registration. Wraps the native adapter with
 * the deepest-target filter, the `--drag-over-external` indicator class, and the
 * decorated-source payload the modifier exposes.
 *
 * Use this directly when you've captured an element ref outside your
 * own template (e.g. via `didInsert` on a sibling marker, or after
 * walking the DOM) and can't attach the `{{dDragAndDropExternalTarget}}`
 * modifier. The modifier itself is a thin wrapper around this
 * function for the template-based common case.
 *
 * Library-agnostic by design: the dependency is imported only by the ui-kit
 * modifier files. Consumers talk to this helper rather than the adapter
 * directly.
 *
 * @param element - The element to register as a drop target.
 * @param getArgsRef - Closure returning the latest args. Adapter callbacks read
 *   this on every invocation, so arg changes take effect without re-registering.
 * @returns Cleanup function. Caller invokes it once on teardown (modifier
 *   destroy, component willDestroy, etc.).
 */
export function registerDragAndDropExternalTarget(
  element: Element,
  getArgsRef: () => DragAndDropExternalTargetArgs
) {
  let isIndicating = false;
  const positionIndicator = createPositionIndicator(element);

  const resolvePosition = (input: DragInput): DropPosition | null => {
    const { position, axis } = getArgsRef();
    if (!position && !axis) {
      return null;
    }
    return resolveDropPosition(element, input, { position, axis });
  };

  const showIndicator = (position: DropPosition | null) => {
    if (position) {
      positionIndicator.apply(position, getArgsRef().axis ?? "y");
      return;
    }
    if (isIndicating) {
      return;
    }
    element.classList.add(INDICATOR_CLASS);
    isIndicating = true;
  };

  const clearIndicator = () => {
    positionIndicator.clear();
    if (!isIndicating) {
      return;
    }
    element.classList.remove(INDICATOR_CLASS);
    isIndicating = false;
  };

  const acceptsSource = (sourcePayload: NativeExternalDragPayload) =>
    matchesExternalKind(getArgsRef().accepts, sourcePayload);

  const isDeepest = (location: DragLocation) =>
    isDeepestTarget(location, element);

  const pairing = createEnterLeavePairing();

  /**
   * Closes an open enter, if there is one. Mirrors the element target: an
   * ancestor superseded by one of its own children is never sent a leave by the
   * adapter, so it has to synthesise one or the enter stays open for the rest of
   * the drag.
   */
  const reportLeave = (
    source: NativeExternalDragPayload,
    location: DragLocation
  ) =>
    pairing.leave(() =>
      getArgsRef().onDragLeave?.({
        source: decorateExternalSource(source),
        position: null,
        location,
        element,
      })
    );

  // See the note in `registerDragAndDropSource`.
  element.setAttribute("data-drop-target-external", "");

  // One gate for feedback time and drop time, as on the element target:
  // consumers put authorization in `canDrop`, so re-asking at drop is the
  // difference between refusing and acting on stale permission.
  const passesGate = (source: NativeExternalDragPayload, input: DragInput) => {
    if (!acceptsSource(source)) {
      return false;
    }
    const args = getArgsRef();
    if (!args.canDrop) {
      return true;
    }
    return (
      args.canDrop({
        source: decorateExternalSource(source),
        input,
        element,
      }) !== false
    );
  };

  const cleanup = dropTargetForExternal({
    element,
    canDrop: ({ source, input }) => passesGate(source, input),
    getDropEffect: ({ source, input }) => {
      const args = getArgsRef();
      return args.getDropEffect?.({
        source: decorateExternalSource(source),
        input,
        element,
      });
    },
    onDragEnter: ({ source, location }) => {
      // Ceasing to be the deepest target makes any indicator this element is
      // showing stale, and an ancestor is kept in the hierarchy rather than
      // sent a leave, so clearing here is the only chance to drop it.
      if (!isDeepest(location)) {
        clearIndicator();
        reportLeave(source, location);
        return;
      }
      const args = getArgsRef();
      const position = resolvePosition(location.current.input);
      if (args.indicator !== false) {
        showIndicator(position);
      }
      pairing.enter(() =>
        args.onDragEnter?.({
          source: decorateExternalSource(source),
          position,
          location,
          element,
        })
      );
    },
    onDrag: ({ source, location }) => {
      if (!isDeepest(location)) {
        clearIndicator();
        reportLeave(source, location);
        return;
      }
      const args = getArgsRef();
      const position = resolvePosition(location.current.input);
      if (args.indicator !== false) {
        showIndicator(position);
      }
      // Taking over as the deepest target without a fresh enter; see the element
      // target, which pairs the same way.
      pairing.enter(() =>
        args.onDragEnter?.({
          source: decorateExternalSource(source),
          position,
          location,
          element,
        })
      );
      args.onDrag?.({
        source: decorateExternalSource(source),
        position,
        location,
        element,
      });
    },
    onDragLeave: ({ source, location }) => {
      clearIndicator();
      reportLeave(source, location);
    },
    onDrop: ({ source, location }) => {
      clearIndicator();
      pairing.reset();
      if (!isDeepest(location)) {
        return;
      }
      // The adapter reuses the target stack from the last `dragover` and never
      // re-asks `canDrop` at drop time, so a gate that flipped false in the
      // final moments before release would otherwise still act.
      if (!passesGate(source, location.current.input)) {
        return;
      }
      getArgsRef().onDrop?.({
        source: decorateExternalSource(source),
        position: resolvePosition(location.current.input),
        location,
        element,
      });
    },
  });

  return () => {
    cleanup();
    clearIndicator();
    element.removeAttribute("data-drop-target-external");
  };
}

/**
 * Marks an element as a drop target for **external** drags — files,
 * URLs, HTML, text dragged into the window from outside (OS file
 * manager, another browser tab, etc.). Thin Ember-modifier wrapper
 * around {@link registerDragAndDropExternalTarget}. Every arg is documented on
 * {@link DragAndDropExternalTargetArgs}, and the payload every callback
 * receives on {@link ExternalDragPayload}.
 *
 * Pair with the existing `dDragAndDropTarget` modifier for
 * element-to-element drags; the two adapters are independent and can coexist on
 * the same element. The external adapter does not call `preventDefault`, so it
 * also coexists with another consumer of the same native `dragover` / `drop`
 * events.
 *
 * Files:
 *
 * ```hbs
 * <div {{dDragAndDropExternalTarget
 *   accepts="files"
 *   onDrop=this.handleFileDrop
 * }}>...</div>
 * ```
 *
 * Multiple kinds:
 *
 * ```hbs
 * <div {{dDragAndDropExternalTarget
 *   accepts=(array "files" "urls")
 *   onDragEnter=this.highlight
 *   onDragLeave=this.unhighlight
 *   onDrop=this.handleDrop
 * }}>...</div>
 * ```
 *
 * A slot rather than a destination — `axis` opts into the element target's
 * before/after position, for a row an incoming payload should land beside:
 *
 * ```hbs
 * <li {{dDragAndDropExternalTarget
 *   accepts="urls"
 *   axis="y"
 *   onDrop=this.insertBeside
 * }}>...</li>
 * ```
 *
 * Nested targets: only the deepest accepted target receives the
 * lifecycle callbacks, so an ancestor decorated with this modifier
 * doesn't double-handle a drop the child already claimed. An ancestor that
 * should stay lit throughout should therefore read `@service dragAndDrop`
 * rather than register a target of its own.
 *
 * Guide to choosing between the gesture primitives:
 * `docs/developer-guides/docs/03-code-internals/29-drag-and-gesture-primitives.md`
 *
 * This modifier hands the consumer the raw payload and stops; it does not upload
 * anything.
 */
export default modifier<DDragAndDropExternalTargetSignature>(
  (element, _positional, args) =>
    // Pass `args` through to the closure WITHOUT reading any property of
    // it here. Reading args.X inside the body would mark its tag consumed
    // and force the modifier to re-run (re-registering the adapter) on every
    // change. The closure reads fresh values inside the adapter callbacks.
    registerDragAndDropExternalTarget(element, () => args)
);
