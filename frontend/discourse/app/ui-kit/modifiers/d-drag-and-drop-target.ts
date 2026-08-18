import {
  dropTargetForElements,
  type ElementDragPayload,
} from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import type {
  DragLocationHistory,
  Input,
} from "@atlaskit/pragmatic-drag-and-drop/types";
import { modifier } from "ember-modifier";
import { consumerMayThrow } from "discourse/lib/-internals/drag-and-drop/consumer-may-throw";
import {
  createPositionIndicator,
  type DropAxis,
  type DropEffect,
  type DropPosition,
  registerDropTargetKernel,
  resolveDropPosition,
} from "discourse/lib/-internals/drag-and-drop/drop-target-kernel";
import {
  DRAG_BODY,
  matchesDragType,
  normalizeDragSource,
} from "discourse/lib/-internals/drag-and-drop/vocabulary";

/** The pointer position as the underlying library reports it. */
type DragInput = Input;

/** The drag's initial, previous and current locations. */
type DragLocation = DragLocationHistory;

export {
  type DropAxis,
  type DropEffect,
  type DropPosition,
  type DropPositionOptions,
  resolveDropPosition,
} from "discourse/lib/-internals/drag-and-drop/drop-target-kernel";

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
       * Defaults to `"vertical"`.
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
  const positionIndicator = createPositionIndicator(element);

  return registerDropTargetKernel({
    element,
    attribute: "data-drop-target",
    register: dropTargetForElements,
    decorateSource: (source: ElementDragPayload) =>
      normalizeSource(source, element),
    accepts: (source: ElementDragPayload) => {
      const args = getArgsRef();
      if (!matchesDragType(args.accepts, source)) {
        return false;
      }

      // A handled source registers its grip but moves the body it represents.
      const moving = (source.data?.[DRAG_BODY] as Element) ?? source.element;
      return args.acceptsSelf !== false || moving !== element;
    },
    resolvePosition: (input: DragInput) => {
      const { position, axis } = getArgsRef();
      return resolveDropPosition(element, input, { position, axis });
    },
    indicator: {
      show: (position, axis) => {
        if (position) {
          positionIndicator.apply(position, axis);
        }
      },
      clear: positionIndicator.clear,
    },
    libraryExtras: {
      // Consumer metadata is a plain object; the adapter stores a keyed record.
      getData: () =>
        consumerMayThrow(() => getArgsRef().getData?.() ?? {}, {}) as Record<
          string | symbol,
          unknown
        >,
      getIsSticky: () =>
        consumerMayThrow(
          () => getArgsRef().getIsSticky?.() === true,
          false
        ) as boolean,
    } satisfies Pick<
      Parameters<typeof dropTargetForElements>[0],
      "getData" | "getIsSticky"
    >,
    getArgs: getArgsRef,
  });
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
