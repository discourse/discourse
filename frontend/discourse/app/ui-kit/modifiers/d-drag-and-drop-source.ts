import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { cancel, next } from "@ember/runloop";
import {
  draggable,
  type ElementDropTargetEventBasePayload,
  type ElementGetFeedbackArgs,
} from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import { pointerOutsideOfPreview } from "@atlaskit/pragmatic-drag-and-drop/element/pointer-outside-of-preview";
import { setCustomNativeDragPreview } from "@atlaskit/pragmatic-drag-and-drop/element/set-custom-native-drag-preview";
import Modifier, { type ArgsFor } from "ember-modifier";

/** The pointer position as the underlying library reports it. */
type DragInput = ElementGetFeedbackArgs["input"];

/** The drag's initial, previous and current locations. */
type DragLocation = ElementDropTargetEventBasePayload["location"];

/**
 * Renders a drag preview into an isolated, offscreen container the browser
 * photographs. Return a cleanup function that tears the preview down.
 */
export type DragPreviewRenderer = (args: {
  /** The offscreen container to render into. */
  container: HTMLElement;

  /** The source element the drag began on. */
  element: HTMLElement;
}) => (() => void) | void;

/** The dragged source, as the lifecycle callbacks receive it. */
export interface DragSource {
  /** The discriminator this source stamps, so targets can filter on it. */
  type?: string;

  /** The payload the drag carries, with `type` merged in. */
  data: Record<string, unknown>;

  /** The element the drag began on. */
  element: HTMLElement;
}

interface DDragAndDropSourceSignature {
  /** The element to mark draggable. */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Discriminator string. Targets filter on this via their `accepts` arg.
       * Stamped onto `source.data.type` so callbacks receive it with the rest of
       * the payload.
       *
       * Required, and reserved: it is stamped over any `type` the payload
       * carries. The `dragAndDrop` service also identifies its own drags by it,
       * so a source without one would be invisible there.
       */
      type: string;

      /**
       * Static payload the source attaches to the drag, exposed as `source.data`
       * in target callbacks. A `type` key on it is overwritten — see `type`.
       */
      data?: object;

      /**
       * Alternative to `data` for dynamic payloads. Called once just before
       * `dragstart`. Its `type` key is overwritten the same way.
       */
      getInitialData?: () => object;

      /**
       * A custom native drag preview, in one of two forms. An `Element` is
       * photographed in place and the browser controls the hotspot. A render
       * function mounts a fresh preview into an isolated, offscreen container,
       * so nothing around the source element bleeds into the drag image.
       * Defaults to the source element when omitted.
       */
      dragPreview?: Element | DragPreviewRenderer;

      /**
       * CSS length values (e.g. `{x: "1rem", y: "0.5rem"}`) that push the preview
       * clear of the pointer for better drop accuracy. Applies only to the
       * render-function `dragPreview` form; ignored for an `Element` preview,
       * whose hotspot the browser clamps to within the image.
       */
      dragPreviewOffset?: { x: string; y: string };

      /** Returning `false` blocks the drag from starting. */
      canDrag?: (feedback: {
        /**
         * The source as it stands before the drag begins. `data` is the arg
         * exactly as passed, before it is merged into the drag payload.
         */
        source: { type?: string; data?: object; element: HTMLElement };

        /** Where the pointer is. */
        input: DragInput;
      }) => boolean | void;

      /** Fires once the drag is confirmed. */
      onDragStart?: (event: {
        /** The dragged source. */
        source: DragSource;

        /** Where the pointer is. */
        input: DragInput;
      }) => void;

      /**
       * Fires once at the end of EVERY drag, whether it landed on a target or the
       * user abandoned it. This is where drag-time state gets undone.
       *
       * Fires AFTER the full drop dispatch (target callbacks, monitor callbacks,
       * native bubble listeners), so it is safe to clear shared dispatch state
       * from here. Inspect `location.current.dropTargets` to branch on the
       * outcome.
       */
      onDragEnd?: (event: {
        /** The dragged source. */
        source: DragSource;

        /** The drag's location history. */
        location: DragLocation;
      }) => void;

      /**
       * Fires only when the drag ended on at least one drop target, so it is
       * where the operation gets performed: an abandoned drag never reaches it.
       * For a drag that lands, both this and `onDragEnd` fire — `onDragEnd`
       * first — with the same `source` and `location`.
       */
      onDrop?: (event: {
        /** The dragged source. */
        source: DragSource;

        /** The drag's location history. */
        location: DragLocation;
      }) => void;

      /**
       * An element inside this one that a drag must start from, so the rest stays
       * free for selecting text and operating controls. Pass the element itself,
       * not a selector; capture its ref with a modifier on the handle rather than
       * querying the DOM. Changing it re-registers, so a ref that only arrives on
       * a later render still takes effect. Omit it and the whole element
       * initiates a drag.
       */
      dragHandle?: Element;

      /**
       * When `true`, the underlying draggable registration is detached. Used by
       * consumers that conditionally suppress dragging (e.g. read-only modes).
       * This, not `dragHandle`, is how to stop an element being dragged:
       * `draggable="true"` is stamped on the host element either way, and
       * `dragHandle` only narrows where a drag may begin.
       */
      disabled?: boolean;
    };
    Positional: [];
  };
}

/**
 * The drag source's named args, for a consumer driving
 * {@link registerDragAndDropSource} imperatively rather than through the
 * modifier.
 */
export type DragAndDropSourceArgs =
  DDragAndDropSourceSignature["Args"]["Named"];

/**
 * Wraps PDND's `draggable()` with the source-payload normalisation, the
 * `--dragging` class on the source element, and the end-of-drag deferral
 * that hides PDND's source-before-target dispatch ordering. Used by the
 * default-exported modifier below, and exported so a consumer can register a
 * drag source imperatively (when a template modifier doesn't fit — e.g. marking
 * elements rendered inside another component as sources) without importing PDND
 * — parallel to `registerDragAndDropTarget` / `registerDragAndDropMonitor`.
 *
 * Library-agnostic by design: `@atlaskit/pragmatic-drag-and-drop` is
 * imported only by the ui-kit modifier files.
 *
 * The consumer's end-of-drag callbacks are deferred to the next task so they fire
 * after the drop event has finished propagating: `onDragEnd` for every drag, then
 * `onDrop` only for one that ended on a drop target.
 *
 * @param element - The element to mark draggable.
 * @param getArgsRef - Closure returning the latest args. PDND callbacks read this
 *   on every invocation, so arg changes take effect without re-registering.
 *   `dragHandle` is the exception: it is read once, when this registers, so a
 *   caller driving this imperatively must re-register to change it.
 * @returns Cleanup function. Caller invokes it once on teardown.
 */
export function registerDragAndDropSource(
  element: HTMLElement,
  getArgsRef: () => DragAndDropSourceArgs
) {
  // Marks the element as owned by this primitive for the lifetime of the
  // registration. The stylesheet gates the state modifiers below on it, so a
  // generic state name cannot reach an element this never touched. An attribute
  // rather than a class because consumers frequently bind `class` themselves,
  // and a dynamic binding would drop anything written here.
  element.setAttribute("data-drag-source", "");

  // The end-of-drag consumer callbacks are deferred, so teardown has to be able
  // to take them back: without this a route transition, or a re-render dropping
  // the row, runs them against a destroyed component one task later.
  let pendingConsumers: Parameters<typeof cancel>[0] | null = null;

  const cleanup = draggable({
    element,
    // Read once, here: the underlying library keeps this in the config captured
    // at registration, so it does not see a later change the way the callbacks
    // below see one through `getArgsRef`. Replacing the registration when the
    // handle changes is the modifier's job.
    dragHandle: getArgsRef().dragHandle,
    canDrag: ({ input }) => {
      const args = getArgsRef();
      if (!args.canDrag) {
        return true;
      }
      return (
        args.canDrag({
          source: { type: args.type, data: args.data, element },
          input,
        }) !== false
      );
    },
    onGenerateDragPreview: ({ nativeSetDragImage }) => {
      const args = getArgsRef();
      if (!nativeSetDragImage) {
        return;
      }
      // A function `dragPreview` renders a fresh preview into an isolated,
      // offscreen container the browser photographs — nothing around the source
      // element can bleed into the drag image — and can be pushed clear of the
      // pointer via `dragPreviewOffset`.
      if (typeof args.dragPreview === "function") {
        setCustomNativeDragPreview({
          nativeSetDragImage,
          getOffset: args.dragPreviewOffset
            ? pointerOutsideOfPreview(args.dragPreviewOffset)
            : undefined,
          // The narrowing above does not survive into this nested callback,
          // where TypeScript sees the whole `Element | DragPreviewRenderer`
          // union again.
          render: ({ container }) =>
            (args.dragPreview as DragPreviewRenderer)({ container, element }),
        });
        return;
      }
      // An `Element` is photographed in place. The browser clamps the hotspot
      // to within the element, so `dragPreviewOffset` cannot push it off the
      // pointer here — it applies only to the render-function form above.
      if (args.dragPreview) {
        nativeSetDragImage(args.dragPreview, 0, 0);
      }
    },
    getInitialData: () => {
      const args = getArgsRef();
      const resolved = args.getInitialData?.() ?? args.data ?? {};
      // Stamped last: the discriminator is the primitive's, and a payload
      // carrying its own `type` — which domain objects routinely do — would
      // otherwise decide which targets accept the drag.
      return { ...resolved, type: args.type };
    },
    onDragStart: (event) => {
      const args = getArgsRef();
      element.classList.add("--dragging");
      const sourcePayload = {
        type: args.type,
        data: event.source.data,
        element,
      };
      args.onDragStart?.({
        source: sourcePayload,
        input: event.location?.current?.input,
      });
    },
    onDrop: (event) => {
      const args = getArgsRef();
      // Source-private cleanup runs synchronously. These touch only
      // state owned by the source element / source modifier; nothing
      // downstream (target callbacks, native bubble-phase listeners)
      // depends on them.
      element.classList.remove("--dragging");

      // Snapshot the consumer callbacks + payload BEFORE deferring.
      // The modifier's argsRef can change across re-renders, and by
      // the time the microtask fires a new drag could already have
      // started — we want the consumers for THIS drag, with the
      // payload PDND captured at THIS drag's start.
      const consumerOnDragEnd = args.onDragEnd;
      const consumerOnDrop = args.onDrop;
      const sourcePayload = {
        // Read from the captured payload rather than from the current args, so
        // it agrees with `data` beside it. `type` is stamped into that payload
        // when the drag starts, and a consumer that changed `@type` mid-drag
        // would otherwise be handed a `type` its own `data.type` contradicts.
        // The library types every payload value as `unknown`; this key is
        // written by `getInitialData` above and is always the string `type`.
        type: event.source.data?.type as string,
        data: event.source.data,
        element,
      };
      const location = event.location;
      // An abandoned drag — cancelled, or released outside every drop target —
      // arrives here too, and is what separates the two callbacks below.
      const landed = location.current.dropTargets.length > 0;

      // `next` defers the consumers to the next task, so they fire
      // after the current drop event finishes propagating —
      // including bubble-phase listeners that may still need to
      // read shared dispatch state. One task for both, so their
      // order is fixed and a drag schedules exactly one.
      pendingConsumers = next(() => {
        pendingConsumers = null;
        // Lifecycle before dispatch: a consumer that only needs to undo its
        // drag-time state hears about every drag, while one that performs an
        // operation is not asked to perform it for a drag the user gave up on.
        consumerOnDragEnd?.({ source: sourcePayload, location });
        if (landed) {
          consumerOnDrop?.({ source: sourcePayload, location });
        }
      });
    },
  });

  /**
   * Tears the registration down.
   *
   * @param options.cancelPending - Whether to drop a drop dispatch already
   *   scheduled for the next task. True when the consumer itself is going away,
   *   because running its callbacks against a destroyed component is the hazard
   *   this defers around. False when the registration is merely being replaced —
   *   a `disabled` arg flipping, or a new handle — because the consumer is still
   *   there and still expects to hear how its own drag ended.
   */
  return ({ cancelPending = true }: { cancelPending?: boolean } = {}) => {
    if (cancelPending && pendingConsumers) {
      cancel(pendingConsumers);
      pendingConsumers = null;
    }
    cleanup();
    element.classList.remove("--dragging");
    element.removeAttribute("data-drag-source");
  };
}

/**
 * Marks an element as a drag source for the Discourse drag-and-drop
 * vocabulary, paired with `dDragAndDropTarget` on the receiving side.
 * Thin Ember-modifier wrapper around {@link registerDragAndDropSource}. Every
 * arg is documented on {@link DragAndDropSourceArgs}.
 *
 * ```hbs
 * <li {{dDragAndDropSource
 *   type="sidebar-link"
 *   data=this.link
 *   dragPreview=this.previewEl
 *   canDrag=this.canDrag
 *   onDragStart=this.handleDragStart
 *   onDragEnd=this.clearDragState
 *   onDrop=this.applyDrop
 * }}>...</li>
 * ```
 *
 * Stamps `data-drag-source` on the element for the lifetime of the
 * registration and adds the `--dragging` class while a drag is active. Both are
 * styled by `app/assets/stylesheets/common/ui-kit/d-drag-and-drop.scss`, whose
 * selectors are gated on the attribute.
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
 * @see The `dPointerDrag` modifier when there is no drop target and no payload — a
 *   press that changes a value continuously is a different gesture.
 */
export default class DDragAndDropSourceModifier extends Modifier<DDragAndDropSourceSignature> {
  #cleanup: ReturnType<typeof registerDragAndDropSource> | null = null;
  #element: HTMLElement | null = null;
  // Replaced by `modify` before any callback can read it; the empty bag only
  // covers the window before the first run.
  #args = {} as DragAndDropSourceArgs;

  /** The handle the live registration was created with, to detect a change. */
  #dragHandle: Element | undefined = undefined;

  constructor(owner: Owner, args: ArgsFor<DDragAndDropSourceSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#detach());
  }

  modify(
    element: HTMLElement,
    _positional: [],
    args: DragAndDropSourceArgs = {} as DragAndDropSourceArgs
  ) {
    if (this.#element && this.#element !== element) {
      this.#detach({ cancelPending: false });
    }
    this.#element = element;

    if (args?.disabled) {
      this.#detach({ cancelPending: false });
      return;
    }

    // Consumer callbacks pass straight through. The `dragAndDrop` service
    // observes element drags first-hand via its own `monitorForElements`, so
    // this modifier owns no shared drag state and stays service-free.
    this.#args = args;

    // A handle is captured when the registration is created, so a new one has to
    // replace it. This is the ordinary case rather than an edge case: a handle is
    // often rendered conditionally and its ref only reaches these args on a later
    // run, and without this the element would keep dragging from anywhere.
    if (this.#cleanup && args.dragHandle !== this.#dragHandle) {
      this.#detach({ cancelPending: false });
      this.#element = element;
    }
    this.#dragHandle = args.dragHandle;

    if (!this.#cleanup) {
      this.#cleanup = registerDragAndDropSource(element, () => this.#args);
    }
  }

  /**
   * Unregisters the source.
   *
   * @param options.cancelPending - Passed through to the registration's own
   *   cleanup. Defaults to true, which is the destructor's case: only a caller
   *   that is replacing the registration while the consumer lives on asks for
   *   the pending drop dispatch to be kept.
   */
  #detach({ cancelPending = true }: { cancelPending?: boolean } = {}) {
    this.#cleanup?.({ cancelPending });
    this.#cleanup = null;
    this.#element?.classList.remove("--dragging");
    this.#element = null;
  }
}
