import { dropTargetForExternal } from "@atlaskit/pragmatic-drag-and-drop/adapter/drop-target-for-external";
import type { ExternalDragPayload as NativeExternalDragPayload } from "@atlaskit/pragmatic-drag-and-drop/adapter/external-adapter-types";
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
  decorateExternalSource,
  type ExternalDragKind,
  type ExternalDragPayload,
  matchesExternalKind,
} from "discourse/lib/-internals/drag-and-drop/external-vocabulary";
import type { Axis } from "discourse/lib/geometry";

/** What a synchronous gate (`canDrop`, `getDropEffect`) is asked about. */
export type ExternalDropTargetFeedback =
  DropTargetKernelFeedback<ExternalDragPayload>;

/** What a lifecycle callback is told. */
export type ExternalDropTargetEvent =
  DropTargetKernelEvent<ExternalDragPayload>;

type SharedDropTargetArgs = DropTargetKernelArgs<ExternalDragPayload>;

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
       * See {@link DropTargetKernelArgs}.
       *
       * A fixed drop position. When set, `axis` and the midpoint logic are
       * ignored. Supplying it opts the target into resolving a position at all —
       * see `axis`.
       */
      position?: DropPosition;

      /**
       * See {@link DropTargetKernelArgs}.
       *
       * Drives the indicator class selection and midpoint position math.
       *
       * Supplying either this or `position` is what opts a target into
       * resolving a position: without one, callbacks are told `position: null`
       * and the indicator is the single `--drag-over-external` class. Most
       * external targets want that — a drop zone is one destination, not a slot
       * in a list. Reach for an axis when the target IS a slot, such as a row a
       * dragged-in link should land above or below.
       */
      axis?: Axis;

      /** See {@link DropTargetKernelArgs}. */
      canDrop?: SharedDropTargetArgs["canDrop"];

      /** See {@link DropTargetKernelArgs}. */
      getData?: () => object;

      /** See {@link DropTargetKernelArgs}. */
      getDropEffect?: (feedback: ExternalDropTargetFeedback) => DropEffect;

      /** See {@link DropTargetKernelArgs}. */
      getIsSticky?: () => boolean;

      /** See {@link DropTargetKernelArgs}. */
      indicator?: boolean;

      /** See {@link DropTargetKernelArgs}. */
      onDragEnter?: (event: ExternalDropTargetEvent) => void;

      /** See {@link DropTargetKernelArgs}. */
      onDrag?: (event: ExternalDropTargetEvent) => void;

      /** See {@link DropTargetKernelArgs}. */
      onDragLeave?: (event: ExternalDropTargetEvent) => void;

      /** See {@link DropTargetKernelArgs}. */
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
 * The imperative counterpart of the modifier below, for the same reasons
 * `registerDragAndDropTarget` exists beside `dDragAndDropTarget`; consumers use
 * it instead of importing the underlying library themselves.
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
  return registerDropTargetKernel({
    element,
    attribute: "data-drop-target-external",
    register: dropTargetForExternal,
    decorateSource: (source: NativeExternalDragPayload) =>
      decorateExternalSource(source),
    accepts: (source) => matchesExternalKind(getArgsRef().accepts, source),
    resolvesPosition: (args) => !!(args.position || args.axis),
    positionlessClass: "--drag-over-external",
    getArgs: getArgsRef,
  });
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
 *   axis="vertical"
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
