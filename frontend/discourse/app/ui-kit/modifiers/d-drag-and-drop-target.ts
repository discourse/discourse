import {
  dropTargetForElements,
  type ElementDragPayload,
} from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import { modifier } from "ember-modifier";
import {
  type DropTargetKernelArgs,
  type DropTargetKernelEvent,
  type DropTargetKernelFeedback,
  registerDropTargetKernel,
} from "discourse/lib/-internals/drag-and-drop/drop-target-kernel";
import {
  isAdoptedDrag,
  type NativeDragAdoption,
  offersAdoptionFor,
  watchForAdoptableDrags,
} from "discourse/lib/-internals/drag-and-drop/native-drag-adoption";
import {
  dragBodyOf,
  matchesDragType,
  type NormalizedDragSource,
  normalizeDragSource,
} from "discourse/lib/-internals/drag-and-drop/vocabulary";

export type {
  NativeDragAdoption,
  NativeDragAdoptionFeedback,
} from "discourse/lib/-internals/drag-and-drop/native-drag-adoption";

export {
  type DropEffect,
  type DropPosition,
  type DropPositionOptions,
} from "discourse/lib/-internals/drag-and-drop/drop-target-kernel";

/**
 * The dragged source, normalized to the shape `dDragAndDropSource` publishes.
 * An adopted drag also carries `native`, with the same reader API as an
 * external target's payload; its `items` is always empty.
 */
export type DropTargetSource = NormalizedDragSource;

/** What a synchronous gate (`canDrop`, `getDropEffect`) is asked about. */
export type DropTargetFeedback = DropTargetKernelFeedback<DropTargetSource>;

/** What a lifecycle callback is told. */
export type DropTargetEvent = DropTargetKernelEvent<DropTargetSource>;

/**
 * The drop target's named args, shared by the `dDragAndDropTarget` modifier
 * and {@link registerDragAndDropTarget}.
 */
export interface DragAndDropTargetArgs extends DropTargetKernelArgs<DropTargetSource> {
  /**
   * The dragged source's `type` must be in this list for the target to engage.
   * Omit to accept any registered source, unless `adopts` is set; then omission
   * accepts only the adopted drags named there.
   */
  accepts?: string | string[];

  /**
   * Also accept browser-started drags from page content that no
   * `dDragAndDropSource` registered, such as native links or images.
   * Independent of `accepts`, since such content carries no source type;
   * adopted payloads arrive on `source.native`.
   *
   * Adoption is resolved once for the page, not per target. At `dragstart` the
   * first live adoption whose predicate matches names the drag, and every
   * target listing that name accepts it.
   *
   * So two adoptions sharing a name must share a predicate. Declare one as a
   * module constant and offer it from each target.
   *
   * Covers only what the browser started on this page. Pair it with
   * `dDragAndDropExternalTarget` on the same element to take the same content
   * dragged in from outside the window.
   */
  adopts?: NativeDragAdoption | NativeDragAdoption[];

  /**
   * `false` refuses a drop whose dragged element is this element. Defaults to
   * `true`: an element that is both source and target has a meaningful drop
   * onto itself, so excluding it is opt-in.
   */
  acceptsSelf?: boolean;
}

interface DDragAndDropTargetSignature {
  /** The element to register as a drop target. */
  Element: HTMLElement;
  Args: {
    Named: DragAndDropTargetArgs;
    Positional: [];
  };
}

/**
 * Imperative drop-target registration; the `dDragAndDropTarget` modifier
 * below wraps it.
 *
 * @param element - The element to register as a drop target.
 * @param getArgsRef - Closure returning the latest args. Library callbacks read
 *   it on every invocation, so arg changes apply without re-registering.
 * @returns Cleanup; call it once on teardown.
 */
export function registerDragAndDropTarget(
  element: Element,
  getArgsRef: () => DragAndDropTargetArgs
) {
  const stopWatchingForAdoption = watchForAdoptableDrags(getArgsRef);

  return registerDropTargetKernel({
    element,
    attribute: "data-drop-target",
    register: dropTargetForElements,
    decorateSource: (source: ElementDragPayload) => normalizeDragSource(source),
    accepts: (source) => {
      const args = getArgsRef();
      // Computed above every branch, so a filter added later cannot return
      // without applying it.
      const acceptsSelf =
        args.acceptsSelf !== false || dragBodyOf(source) !== element;

      if (isAdoptedDrag(source.data)) {
        return offersAdoptionFor(source.data, args.adopts) && acceptsSelf;
      }
      // A target offering adoption named exactly what it wants through
      // `adopts`; treating an omitted source filter as "everything" would also
      // hand it every registered source on the page.
      if (!args.accepts && args.adopts) {
        return false;
      }

      return matchesDragType(args.accepts, source) && acceptsSelf;
    },
    onCleanup: stopWatchingForAdoption,
    getArgs: getArgsRef,
  });
}

/**
 * Marks an element as a drop target for `dDragAndDropSource` drags. Every arg
 * is documented on {@link DragAndDropTargetArgs}. The indicator classes are
 * styled in `app/assets/stylesheets/common/ui-kit/d-drag-and-drop.scss`.
 *
 * Position from the pointer against the element's midpoint:
 *
 * ```hbs
 * <li {{dDragAndDropTarget accepts="sidebar-link" onDrop=this.reorder}}>...</li>
 * ```
 *
 * A fixed position:
 *
 * ```hbs
 * <div {{dDragAndDropTarget
 *   accepts="block"
 *   position="inside"
 *   onDrop=this.applyMove
 * }}></div>
 * ```
 *
 * Testing: use `simulateDrag` from
 * `discourse/tests/helpers/ui-kit/drag-and-drop-helper` in JS, and
 * `SystemHelpers#drag_and_drop` in system specs; synthetic mouse drags stall.
 *
 * Element drags, and with `adopts` browser-started drags from page content;
 * see `dDragAndDropExternalTarget` for payloads dragged in from outside the
 * window.
 */
export default modifier<DDragAndDropTargetSignature>(
  (element, _positional, args) =>
    // Pass `args` unread: reading a property here would track it and re-run
    // the modifier, re-registering the target on every change.
    registerDragAndDropTarget(element, () => args)
);
