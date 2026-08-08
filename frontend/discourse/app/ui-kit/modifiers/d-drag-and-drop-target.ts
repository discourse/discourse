import {
  dropTargetForElements,
  type ElementDragPayload,
  type ElementDropTargetEventBasePayload,
  type ElementDropTargetGetFeedbackArgs,
} from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import { modifier } from "ember-modifier";

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

/**
 * One value, several, or nothing, as a list. Shared with the external target,
 * which normalises its own vocabulary the same way.
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

function sourceFromPDND(
  pdndSource: ElementDragPayload,
  element: Element
): DropTargetSource {
  return {
    // The underlying library types its payload values as `unknown`, because
    // anything registering a draggable with it can put anything there. Only
    // `dDragAndDropSource` does, since the library is imported nowhere outside
    // these files, and it always stamps a string.
    type: (pdndSource.data?.type ?? null) as string | null,
    data: pdndSource.data ?? {},
    element: pdndSource.element ?? element ?? null,
  };
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

      /** The cursor entered this target with a compatible drag in flight. */
      onDragEnter?: (event: DropTargetEvent) => void;

      /**
       * The drag progressed. Throttled; fires when the input or the drop-target
       * hierarchy updates while this target is active.
       */
      onDrag?: (event: DropTargetEvent) => void;

      /** The cursor left this target. `position` is `null`. */
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
 * Imperative drop-target registration backed by Pragmatic Drag and
 * Drop. Wraps `dropTargetForElements` with the deepest-target filter,
 * `--drag-above` / `--drag-below` indicator classes, and the
 * source-payload normalisation the modifier exposes.
 *
 * Use this directly when you've captured an element ref outside your
 * own template (e.g. via `didInsert` on a sibling marker, or after
 * walking the DOM) and can't attach the `{{dDragAndDropTarget}}`
 * modifier. The modifier itself is a thin wrapper around this
 * function for the template-based common case.
 *
 * Library-agnostic by design: `@atlaskit/pragmatic-drag-and-drop` is
 * imported only by the ui-kit modifier files. Consumers (plugins,
 * core features) talk to this helper, not to PDND directly.
 *
 * @param element - The element to register as a drop target.
 * @param getArgsRef - Closure returning the latest args. PDND callbacks read
 *   this on every invocation, so arg changes take effect without re-registering.
 * @returns Cleanup function. Caller invokes it once on teardown (modifier
 *   destroy, component willDestroy, etc.).
 */
export function registerDragAndDropTarget(
  element: Element,
  getArgsRef: () => DragAndDropTargetArgs
) {
  let activeClass: string | null = null;
  // Whether this wrapper has forwarded an enter the consumer is still owed a
  // leave for. The underlying library sends both to every target in the
  // hierarchy, but only the deepest one is forwarded, so an ancestor would
  // otherwise be handed a leave it never had an enter for.
  const pairing = createEnterLeavePairing();

  const applyIndicator = (position: DropPosition, axis: DropAxis) => {
    const className = POSITION_CLASSES[position]?.[axis];
    if (!className || activeClass === className) {
      return;
    }
    if (activeClass) {
      element.classList.remove(activeClass);
    }
    element.classList.add(className);
    activeClass = className;
  };

  const clearIndicators = () => {
    if (activeClass) {
      element.classList.remove(activeClass);
      activeClass = null;
    }
  };

  const acceptsType = (type: unknown) => {
    const list = toAcceptList(getArgsRef().accepts);
    return list.length === 0 || list.includes(type as string);
  };

  const resolvePosition = (input: DragInput): DropPosition => {
    const args = getArgsRef();
    if (args.position) {
      return args.position;
    }
    const axis = args.axis ?? "y";
    const rect = element.getBoundingClientRect();
    if (axis === "x") {
      return input.clientX < rect.left + rect.width / 2 ? "before" : "after";
    }
    return input.clientY < rect.top + rect.height / 2 ? "before" : "after";
  };

  const isDeepest = (location: DragLocation) =>
    isDeepestTarget(location, element);

  // See the note in `registerDragAndDropSource`: the stylesheet gates the state
  // modifiers on this attribute, and an attribute survives a consumer rebinding
  // `class`.
  element.setAttribute("data-drop-target", "");

  const cleanup = dropTargetForElements({
    element,
    canDrop: ({ source, input }) => {
      if (!acceptsType(source.data?.type)) {
        return false;
      }
      const args = getArgsRef();
      // Compared against the raw source element rather than the normalised
      // payload, whose `element` falls back to this one and would therefore read
      // as self whenever the source element is absent.
      if (args.acceptsSelf === false && source.element === element) {
        return false;
      }
      if (!args.canDrop) {
        return true;
      }
      return (
        args.canDrop({
          source: sourceFromPDND(source, element),
          input,
          element,
        }) !== false
      );
    },
    // The consumer's metadata is deliberately typed as a plain object, which the
    // underlying library's index-signature shape does not accept as-is.
    getData: () =>
      (getArgsRef().getData?.() ?? {}) as Record<string | symbol, unknown>,
    getDropEffect: ({ source, input }) => {
      const args = getArgsRef();
      return args.getDropEffect?.({
        source: sourceFromPDND(source, element),
        input,
        element,
      });
    },
    getIsSticky: () => getArgsRef().getIsSticky?.() === true,
    onDragEnter: ({ source, location }) => {
      // Ceasing to be the deepest target makes any indicator this element is
      // showing stale, and PDND keeps an ancestor in the hierarchy rather than
      // sending it a leave, so clearing here is the only chance to drop it.
      if (!isDeepest(location)) {
        clearIndicators();
        return;
      }
      const args = getArgsRef();
      const pos = resolvePosition(location.current.input);
      if (args.indicator !== false) {
        applyIndicator(pos, args.axis ?? "y");
      }
      pairing.enter(() =>
        args.onDragEnter?.({
          source: sourceFromPDND(source, element),
          position: pos,
          location,
          element,
        })
      );
    },
    onDrag: ({ source, location }) => {
      if (!isDeepest(location)) {
        clearIndicators();
        return;
      }
      const args = getArgsRef();
      const pos = resolvePosition(location.current.input);
      if (args.indicator !== false) {
        applyIndicator(pos, args.axis ?? "y");
      }
      // Taking over as the deepest target without a fresh enter, because an
      // ancestor never left the hierarchy for the child to be entered. The
      // consumer is told it entered here instead: this is the target a drop
      // would land on now, and without it the leave would be unmatched.
      pairing.enter(() =>
        args.onDragEnter?.({
          source: sourceFromPDND(source, element),
          position: pos,
          location,
          element,
        })
      );
      args.onDrag?.({
        source: sourceFromPDND(source, element),
        position: pos,
        location,
        element,
      });
    },
    onDragLeave: ({ source, location }) => {
      clearIndicators();
      pairing.leave(() =>
        getArgsRef().onDragLeave?.({
          source: sourceFromPDND(source, element),
          position: null,
          location,
          element,
        })
      );
    },
    onDrop: ({ source, location }) => {
      // Unconditionally, and before the deepest check: an ancestor that stopped
      // being deepest still needs its indicator dropped, matching
      // `registerDragAndDropExternalTarget`.
      clearIndicators();
      // A drop ends the drag, so the enter it closes is not also reported as a
      // leave.
      pairing.reset();
      if (!isDeepest(location)) {
        return;
      }
      const pos = resolvePosition(location.current.input);
      getArgsRef().onDrop?.({
        source: sourceFromPDND(source, element),
        position: pos,
        location,
        element,
      });
    },
  });

  return () => {
    cleanup();
    clearIndicators();
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
 * Guide to choosing between the gesture primitives:
 * `docs/developer-guides/docs/03-code-internals/29-drag-and-gesture-primitives.md`
 *
 * @see The `dDragAndDropExternalTarget` modifier for payloads dragged in from outside
 *   the browser. Neither one is the file-upload path; that is Uppy's `DropTarget`.
 */
export default modifier<DDragAndDropTargetSignature>(
  (element, _positional, args) =>
    // Pass `args` through to the closure WITHOUT reading any property of
    // it here. Reading args.X inside the body would mark its tag consumed
    // and force the modifier to re-run (re-registering PDND) on every
    // change. The closure reads fresh values inside PDND's callbacks.
    registerDragAndDropTarget(element, () => args)
);
