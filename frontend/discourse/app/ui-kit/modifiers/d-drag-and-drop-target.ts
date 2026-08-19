import {
  dropTargetForElements,
  type ElementDragPayload,
} from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import { modifier } from "ember-modifier";
import {
  type DropEffect,
  type DropPosition,
  type DropTargetKernelArgs,
  type DropTargetKernelEvent,
  type DropTargetKernelFeedback,
  registerDropTargetKernel,
} from "discourse/lib/-internals/drag-and-drop/drop-target-kernel";
import {
  dragBodyOf,
  matchesDragType,
  type NormalizedDragSource,
  normalizeDragSource,
} from "discourse/lib/-internals/drag-and-drop/vocabulary";
import type { Axis } from "discourse/lib/geometry";

export {
  type DropEffect,
  type DropPosition,
  type DropPositionOptions,
} from "discourse/lib/-internals/drag-and-drop/drop-target-kernel";

/** The dragged source, normalised to the shape `dDragAndDropSource` publishes. */
export type DropTargetSource = NormalizedDragSource;

/** What a synchronous gate (`canDrop`, `getDropEffect`) is asked about. */
export type DropTargetFeedback = DropTargetKernelFeedback<DropTargetSource>;

/** What a lifecycle callback is told. */
export type DropTargetEvent = DropTargetKernelEvent<DropTargetSource>;

type SharedDropTargetArgs = DropTargetKernelArgs<DropTargetSource>;

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

      /** See {@link DropTargetKernelArgs}. */
      position?: DropPosition;

      /** See {@link DropTargetKernelArgs}. */
      axis?: Axis;

      /** See {@link DropTargetKernelArgs}. */
      canDrop?: SharedDropTargetArgs["canDrop"];

      /** See {@link DropTargetKernelArgs}. */
      getData?: () => object;

      /** See {@link DropTargetKernelArgs}. */
      getDropEffect?: (feedback: DropTargetFeedback) => DropEffect;

      /** See {@link DropTargetKernelArgs}. */
      getIsSticky?: () => boolean;

      /** See {@link DropTargetKernelArgs}. */
      indicator?: boolean;

      /** See {@link DropTargetKernelArgs}. */
      onDragEnter?: (event: DropTargetEvent) => void;

      /** See {@link DropTargetKernelArgs}. */
      onDrag?: (event: DropTargetEvent) => void;

      /** See {@link DropTargetKernelArgs}. */
      onDragLeave?: (event: DropTargetEvent) => void;

      /** See {@link DropTargetKernelArgs}. */
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
 * Imperative drop-target registration. Adds deepest-target filtering,
 * `--drag-above` / `--drag-below` / `--drag-left` / `--drag-right` /
 * `--drag-inside` indicator classes, and the source-payload normalisation the
 * modifier exposes.
 *
 * Use this directly when you've captured an element ref outside your
 * own template (e.g. via `didInsert` on a sibling marker, or after
 * walking the DOM) and can't attach the `{{dDragAndDropTarget}}`
 * modifier. The modifier itself is a thin wrapper around this
 * function for the template-based common case.
 *
 * Consumers remain library-agnostic: they use this helper instead of importing
 * the underlying library themselves.
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
  return registerDropTargetKernel({
    element,
    attribute: "data-drop-target",
    register: dropTargetForElements,
    decorateSource: (source: ElementDragPayload) => normalizeDragSource(source),
    accepts: (source) => {
      const args = getArgsRef();
      if (!matchesDragType(args.accepts, source)) {
        return false;
      }

      return args.acceptsSelf !== false || dragBodyOf(source) !== element;
    },
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
