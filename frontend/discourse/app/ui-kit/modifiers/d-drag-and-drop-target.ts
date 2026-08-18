import {
  dropTargetForElements,
  type ElementDragPayload,
  type ElementDropTargetEventBasePayload,
  type ElementDropTargetGetFeedbackArgs,
} from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import { modifier } from "ember-modifier";
import {
  consumerMayThrow,
  DRAG_BODY,
  normalizeDragSource,
} from "discourse/services/drag-and-drop";

/** The pointer position as the underlying library reports it. */
type DragInput = ElementDropTargetGetFeedbackArgs["input"];

/** The drag's initial, previous and current locations. */
type DragLocation = ElementDropTargetEventBasePayload["location"];

/** Where a drop would land relative to this target. */
export type DropPosition = "before" | "after" | "inside";

/** The axis the target's position math and indicator classes work along. */
export type DropAxis = "x" | "y";

/** The cursor feedback the browser shows for a drop. */
export type DropEffect = "copy" | "link" | "move";

/** The dragged source, normalised to the shape `dDragAndDropSource` publishes. */
export interface DropTargetSource {
  /** The source's discriminator, or `null` when the drag carries none. */
  type: string | null;

  /** The payload the source attached to the drag. */
  data: Record<string, unknown>;

  /** The dragged element, falling back to this target when the drag has none. */
  element: Element | null;
}

/** What a synchronous gate (`canDrop`, `getDropEffect`) is asked about. */
export interface DropTargetFeedback {
  /** The dragged source. */
  source: DropTargetSource;

  /** Where the pointer is. */
  input: DragInput;

  /** This target's element. */
  element: Element;
}

/** What a lifecycle callback is told. */
export interface DropTargetEvent {
  /** The dragged source. */
  source: DropTargetSource;

  /** Where the drop would land, or `null` when the drag has left. */
  position: DropPosition | null;

  /** The drag's location history. */
  location: DragLocation;

  /** This target's element. */
  element: Element;
}

/**
 * Per-axis state modifier classes toggled while the cursor is hovering with a
 * compatible drag in flight. Paired with the `data-drop-target` attribute the
 * registrar stamps, and styled by
 * `app/assets/stylesheets/common/ui-kit/d-drag-and-drop.scss`, which draws a 2px
 * accent line above/below the row by default; consumers can override with their
 * own treatment when a different look is needed.
 */
const POSITION_CLASSES = Object.freeze({
  before: { y: "--drag-above", x: "--drag-left" },
  after: { y: "--drag-below", x: "--drag-right" },
  inside: { y: "--drag-inside", x: "--drag-inside" },
});

/** How a target decides where a drop would land. */
export interface DropPositionOptions {
  /** A fixed position, which wins over the midpoint math entirely. */
  position?: DropPosition;

  /** The axis the midpoint is measured along. Defaults to `"y"`. */
  axis?: DropAxis;
}

/**
 * Where a drop would land relative to an element: the `position` arg when one is
 * fixed, otherwise which side of the element's midpoint the pointer is on.
 *
 * Centralized so every consumer uses the same midpoint comparison.
 *
 * @param element - The target element to measure against.
 * @param input - The pointer position, as the underlying library reports it.
 * @param options - The consumer's `position` / `axis` args.
 */
export function resolveDropPosition(
  element: Element,
  input: DragInput,
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
 * Keeps at most one positional indicator class on an element, so moving from one
 * position to another swaps rather than accumulates.
 *
 * Centralized with {@link resolveDropPosition} so the position vocabulary and
 * its class lifecycle cannot drift apart.
 *
 * @param element - The element to carry the class.
 * @returns `apply`, which swaps in the class for a position/axis pair, and
 *   `clear`, which removes whichever one is currently on.
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

/**
 * One value, several, or nothing, as a list.
 *
 * @param value - The `accepts` filter as the consumer supplied it.
 */
export function toAcceptList<T>(value?: T | T[]): T[] {
  if (!value) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  return [value];
}

/**
 * Whether this element is the innermost accepted target under the pointer.
 *
 * The underlying library fires every lifecycle event on every target in the
 * hierarchy; the contract here is that only the deepest one acts on it.
 *
 * @param location - The drag's location history.
 * @param element - The element being asked about.
 */
export function isDeepestTarget(location: DragLocation, element: Element) {
  return location.current.dropTargets[0]?.element === element;
}

/**
 * Keeps one registration's `onDragEnter` and `onDragLeave` in step.
 *
 * The underlying library fires both on every target in the hierarchy, while the
 * contract here is that only the deepest one tells its consumer. That makes the
 * two halves easy to get out of step in either direction: an ancestor whose
 * enter was swallowed would otherwise still be sent a leave, and one that takes
 * over as deepest without a fresh enter would be sent a leave it was never
 * given an enter for. Shared because both target modifiers need exactly this and
 * the pair drifted between them once already.
 *
 * @returns `enter` and `leave`, which each run the callback only when doing so
 *   keeps the pair balanced, and `reset` for a drop, which ends the drag without
 *   a leave.
 */
export function createEnterLeavePairing() {
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

function normalizeSource(
  pdndSource: ElementDragPayload,
  element: Element
): DropTargetSource {
  // The routing interpretation lives with the vocabulary it reads. The target
  // supplies itself as the fallback because `acceptsSelf` compares against the
  // reported element, which is why a handled row still recognises a drop of
  // itself.
  return normalizeDragSource(pdndSource, element);
}

interface DDragAndDropTargetSignature {
  /** The element to register as a drop target. */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * The dragged source's `type` must be in this list for the target to
       * engage. Omit to accept any source.
       */
      accepts?: string | string[];

      /**
       * `false` to refuse a drop whose dragged element is this element. Where
       * `accepts` filters by type, this filters by identity. Defaults to `true`,
       * because an element carrying both this modifier and `dDragAndDropSource`
       * is a supported arrangement with a meaningful drop, so excluding it is
       * opt-in rather than automatic.
       */
      acceptsSelf?: boolean;

      /**
       * A fixed drop position. When set, `axis` and the midpoint logic are
       * ignored.
       */
      position?: DropPosition;

      /**
       * Drives the indicator class selection and the smart-row position math.
       * Defaults to `"y"`.
       */
      axis?: DropAxis;

      /**
       * Synchronous gate. Returning `false` refuses the drop. `source` is
       * `{type, data, element}` — the shape the matching `dDragAndDropSource`
       * published.
       */
      canDrop?: (feedback: DropTargetFeedback) => boolean | void;

      /**
       * Optional target-side metadata attached to the drag's record of this
       * target; consumers reading `source.dropTargets` see it under `.data`.
       */
      getData?: () => object;

      /** Determines the cursor feedback browsers show. */
      getDropEffect?: (feedback: DropTargetFeedback) => DropEffect;

      /**
       * Enables sticky-target semantics: the target stays "current" briefly
       * after the cursor leaves, which suits hover-to-expand patterns.
       */
      getIsSticky?: () => boolean;

      /** `false` to suppress the `--drag-*` indicator classes. Defaults to `true`. */
      indicator?: boolean;

      /**
       * This target became the one a drop would land on, with a compatible drag
       * in flight. Usually the cursor entering it, but also a nested target that
       * was covering it going away, so it can fire without the cursor moving.
       */
      onDragEnter?: (event: DropTargetEvent) => void;

      /**
       * The drag progressed. Throttled; fires when the input or the drop-target
       * hierarchy updates while this target is active.
       */
      onDrag?: (event: DropTargetEvent) => void;

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
      onDragLeave?: (event: DropTargetEvent) => void;

      /** The drag was released on this target. */
      onDrop?: (event: DropTargetEvent) => void;
    };
    Positional: [];
  };
}

/**
 * The drop target's named args, for a consumer driving
 * {@link registerDragAndDropTarget} imperatively rather than through the
 * modifier.
 */
export type DragAndDropTargetArgs =
  DDragAndDropTargetSignature["Args"]["Named"];

/**
 * Imperative drop-target registration. Wraps `dropTargetForElements` with the
 * deepest-target filter,
 * `--drag-above` / `--drag-below` indicator classes, and the
 * source-payload normalisation the modifier exposes.
 *
 * Use this directly when you've captured an element ref outside your
 * own template (e.g. via `didInsert` on a sibling marker, or after
 * walking the DOM) and can't attach the `{{dDragAndDropTarget}}`
 * modifier. The modifier itself is a thin wrapper around this
 * function for the template-based common case.
 *
 * Library-agnostic by design: the dependency is imported only by the ui-kit
 * modifier files. Consumers talk to this helper rather than the dependency
 * directly.
 *
 * @param element - The element to register as a drop target.
 * @param getArgsRef - Closure returning the latest args. Library callbacks read
 *   this on every invocation, so arg changes take effect without re-registering.
 * @returns Cleanup function. Caller invokes it once on teardown (modifier
 *   destroy, component willDestroy, etc.).
 */
export function registerDragAndDropTarget(
  element: Element,
  getArgsRef: () => DragAndDropTargetArgs
) {
  const indicator = createPositionIndicator(element);
  // Whether this wrapper has forwarded an enter the consumer is still owed a
  // leave for. The underlying library sends both to every target in the
  // hierarchy, but only the deepest one is forwarded, so an ancestor would
  // otherwise be handed a leave it never had an enter for.
  const pairing = createEnterLeavePairing();

  const acceptsType = (type: unknown) => {
    const list = toAcceptList(getArgsRef().accepts);
    return list.length === 0 || list.includes(type as string);
  };

  /**
   * Whether this target will take the drag, by whichever branch applies.
   *
   * Shared between the synchronous gate and the drop, because the library
   * decides the target list on the last `dragover` and reuses it when the
   * pointer is released — so a target that stopped qualifying in between would
   * otherwise still be handed the drop. Consumers put authorization here, which
   * makes re-asking the difference between refusing and acting on stale
   * permission.
   */
  const passesGate = (source: ElementDragPayload, input: DragInput) => {
    const args = getArgsRef();

    if (!acceptsType(source.data?.type)) {
      return false;
    }

    // The body a handled source stands for, or the raw source element when
    // there is none. Deliberately not the normalised payload, whose `element`
    // falls back to this one and would therefore read as self whenever the
    // source element is absent — and deliberately not the registered element
    // alone, which for a handled source is a grip nested inside the row and so
    // never equal to the target that is the row.
    const moving = (source.data?.[DRAG_BODY] as Element) ?? source.element;
    if (args.acceptsSelf === false && moving === element) {
      return false;
    }

    if (!args.canDrop) {
      return true;
    }

    return consumerMayThrow(
      () =>
        args.canDrop!({
          source: normalizeSource(source, element),
          input,
          element,
        }) !== false,
      false
    );
  };

  const resolvePosition = (input: DragInput): DropPosition => {
    const { position, axis } = getArgsRef();
    return resolveDropPosition(element, input, { position, axis });
  };

  const isDeepest = (location: DragLocation) =>
    isDeepestTarget(location, element);

  /**
   * Closes an open enter, if there is one.
   *
   * Called both when the library reports a leave and when this element merely
   * stops being the deepest target, which the library reports as nothing at all
   * because the element never left the hierarchy. Without the second case an
   * ancestor superseded by one of its own children would keep an enter open for
   * the rest of the drag.
   */
  const reportLeave = (source: ElementDragPayload, location: DragLocation) =>
    pairing.leave(() =>
      consumerMayThrow(() =>
        getArgsRef().onDragLeave?.({
          source: normalizeSource(source, element),
          position: null,
          location,
          element,
        })
      )
    );

  // See the note in `registerDragAndDropSource`: the stylesheet gates the state
  // modifiers on this attribute, and an attribute survives a consumer rebinding
  // `class`.
  element.setAttribute("data-drop-target", "");

  const cleanup = dropTargetForElements({
    element,
    canDrop: ({ source, input }) => passesGate(source, input),
    // The consumer's metadata is deliberately typed as a plain object, which the
    // underlying library's index-signature shape does not accept as-is.
    getData: () =>
      consumerMayThrow(() => getArgsRef().getData?.() ?? {}, {}) as Record<
        string | symbol,
        unknown
      >,
    getDropEffect: ({ source, input }) =>
      consumerMayThrow(() =>
        getArgsRef().getDropEffect?.({
          source: normalizeSource(source, element),
          input,
          element,
        })
      ),
    getIsSticky: () =>
      consumerMayThrow(
        () => getArgsRef().getIsSticky?.() === true,
        false
      ) as boolean,
    onDragEnter: ({ source, location }) => {
      // Ceasing to be the deepest target makes any indicator this element is
      // showing stale, and the library keeps an ancestor in the hierarchy rather
      // than sending it a leave, so clearing here is the only chance to drop it.
      if (!isDeepest(location)) {
        indicator.clear();
        reportLeave(source, location);
        return;
      }
      const args = getArgsRef();
      const pos = resolvePosition(location.current.input);
      if (args.indicator !== false) {
        indicator.apply(pos, args.axis ?? "y");
      }
      pairing.enter(() =>
        consumerMayThrow(() =>
          args.onDragEnter?.({
            source: normalizeSource(source, element),
            position: pos,
            location,
            element,
          })
        )
      );
    },
    onDrag: ({ source, location }) => {
      if (!isDeepest(location)) {
        indicator.clear();
        reportLeave(source, location);
        return;
      }
      const args = getArgsRef();
      const pos = resolvePosition(location.current.input);
      if (args.indicator !== false) {
        indicator.apply(pos, args.axis ?? "y");
      }
      // Taking over as the deepest target without a fresh enter, because an
      // ancestor never left the hierarchy for the child to be entered. The
      // consumer is told it entered here instead: this is the target a drop
      // would land on now, and without it the leave would be unmatched.
      pairing.enter(() =>
        consumerMayThrow(() =>
          args.onDragEnter?.({
            source: normalizeSource(source, element),
            position: pos,
            location,
            element,
          })
        )
      );
      consumerMayThrow(() =>
        args.onDrag?.({
          source: normalizeSource(source, element),
          position: pos,
          location,
          element,
        })
      );
    },
    onDragLeave: ({ source, location }) => {
      indicator.clear();
      reportLeave(source, location);
    },
    onDrop: ({ source, location }) => {
      // Unconditionally, and before the deepest check: an ancestor that stopped
      // being deepest still needs its indicator dropped.
      indicator.clear();
      // A drop ends the drag, so the enter it closes is not also reported as a
      // leave.
      pairing.reset();
      if (!isDeepest(location)) {
        return;
      }
      // Asked again rather than trusted: the target list was settled on the last
      // `dragover`, so anything that changed since — a panel switched, a
      // permission withdrawn, the arg turned off — would otherwise land a drop
      // this target would now refuse.
      if (!passesGate(source, location.current.input)) {
        return;
      }
      const pos = resolvePosition(location.current.input);
      consumerMayThrow(() =>
        getArgsRef().onDrop?.({
          source: normalizeSource(source, element),
          position: pos,
          location,
          element,
        })
      );
    },
  });

  return () => {
    cleanup();
    indicator.clear();
    element.removeAttribute("data-drop-target");
  };
}

/**
 * Marks an element as a drop target compatible with the
 * `dDragAndDropSource` vocabulary. Thin Ember-modifier wrapper around
 * {@link registerDragAndDropTarget}. Every arg is documented on
 * {@link DragAndDropTargetArgs}.
 *
 * Smart row mode — position is computed from the cursor against the
 * element's midpoint:
 *
 * ```hbs
 * <li {{dDragAndDropTarget
 *   accepts="sidebar-link"
 *   onDrop=this.reorder
 * }}>...</li>
 * ```
 *
 * Fixed-position mode — for explicit `"before"` / `"after"` / `"inside"`
 * zones where the slot is decided by geometry, not the cursor:
 *
 * ```hbs
 * <div {{dDragAndDropTarget
 *   accepts="block"
 *   position="inside"
 *   onDrop=this.applyMove
 * }}></div>
 * ```
 *
 * Nested targets: only the deepest accepted target receives the
 * lifecycle callbacks, so an ancestor decorated with this modifier
 * doesn't double-handle a drop the child already claimed.
 *
 * Testing: in JS integration tests use `simulateDrag` from
 * `discourse/tests/helpers/ui-kit/drag-and-drop-helper`; in Ruby system
 * tests use `SystemHelpers#drag_and_drop` (a real native drag via
 * Playwright) rather than Capybara's `drag_to`, whose synthetic mouse
 * events can silently stall mid-drag.
 *
 * This modifier only receives registered element sources. File uploads continue
 * to use the existing upload target.
 */
export default modifier<DDragAndDropTargetSignature>(
  (element, _positional, args) =>
    // Pass `args` through to the closure WITHOUT reading any property of
    // it here. Reading args.X inside the body would mark its tag consumed
    // and force the modifier to re-run (re-registering the target) on every
    // change. The closure reads fresh values inside the library's callbacks.
    registerDragAndDropTarget(element, () => args)
);
