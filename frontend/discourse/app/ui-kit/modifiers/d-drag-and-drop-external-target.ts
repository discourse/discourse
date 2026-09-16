import { dropTargetForExternal } from "@atlaskit/pragmatic-drag-and-drop/adapter/drop-target-for-external";
import type { ExternalDragPayload as NativeExternalDragPayload } from "@atlaskit/pragmatic-drag-and-drop/adapter/external-adapter-types";
import { modifier } from "ember-modifier";
import {
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

/** What a synchronous gate (`canDrop`, a `dropEffect` function) is asked about. */
export type ExternalDropTargetFeedback =
  DropTargetKernelFeedback<ExternalDragPayload>;

/** What a lifecycle callback is told. */
export type ExternalDropTargetEvent =
  DropTargetKernelEvent<ExternalDragPayload>;

/**
 * The external drop target's named args, shared by the
 * `dDragAndDropExternalTarget` modifier and
 * {@link registerDragAndDropExternalTarget}.
 */
export type DragAndDropExternalTargetArgs =
  DropTargetKernelArgs<ExternalDragPayload> & {
    /**
     * Filters which external drag kinds engage the target. Omit to accept any
     * external drag.
     */
    accepts?: ExternalDragKind | ExternalDragKind[];

    /** Setting this or `axis` opts the target into resolving a position at all. */
    position?: DropPosition;

    /**
     * Without this or `position` the target is one destination, not a slot:
     * callbacks get `position: null` and the indicator is the single
     * `--drag-over-external` class.
     */
    axis?: Axis;
  };

interface DDragAndDropExternalTargetSignature {
  /** The element to register as a drop target. */
  Element: HTMLElement;
  Args: {
    Named: DragAndDropExternalTargetArgs;
    Positional: [];
  };
}

/**
 * Imperative external drop-target registration, wrapped by the
 * `dDragAndDropExternalTarget` modifier below; the counterpart of
 * `registerDragAndDropTarget` for drags from outside the window.
 *
 * @param element - The element to register as a drop target.
 * @param getArgsRef - Closure returning the latest args. Adapter callbacks read
 *   it on every invocation, so arg changes apply without re-registering.
 * @returns Cleanup; call it once on teardown.
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
 * Marks an element as a drop target for drags from outside the window: files,
 * URLs, HTML or text from another application or tab. Every arg is documented
 * on {@link DragAndDropExternalTargetArgs}, and the payload every callback
 * receives on {@link ExternalDragPayload}.
 *
 * An accepted drop cancels the native event's default without stopping its
 * propagation, so another `dragover` / `drop` handler still runs and sees
 * `defaultPrevented`.
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
 * A slot rather than a destination, with `axis` opting into a before/after
 * position:
 *
 * ```hbs
 * <li {{dDragAndDropExternalTarget
 *   accepts="urls"
 *   axis="vertical"
 *   onDrop=this.insertBeside
 * }}>...</li>
 * ```
 *
 * An ancestor that should stay lit while a nested target is hovered reads
 * `@service dragAndDrop` instead of registering a target of its own.
 */
export default modifier<DDragAndDropExternalTargetSignature>(
  (element, _positional, args) =>
    // Pass `args` unread: reading a property here would track it and re-run
    // the modifier, re-registering the target on every change.
    registerDragAndDropExternalTarget(element, () => args)
);
