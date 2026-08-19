import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { cancel, next } from "@ember/runloop";
import { draggable } from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import { pointerOutsideOfPreview } from "@atlaskit/pragmatic-drag-and-drop/utils/pointer-outside-of-preview";
import { preventUnhandled } from "@atlaskit/pragmatic-drag-and-drop/utils/prevent-unhandled";
import { setCustomNativeDragPreview } from "@atlaskit/pragmatic-drag-and-drop/utils/set-custom-native-drag-preview";
import Modifier, { type ArgsFor } from "ember-modifier";
import { consumerMayThrow } from "discourse/lib/-internals/drag-and-drop/consumer-may-throw";
import type {
  DragInput,
  DragLocation,
} from "discourse/lib/-internals/drag-and-drop/drop-target-kernel";
import {
  DRAG_BODY,
  normalizeOwnedDragSource,
} from "discourse/lib/-internals/drag-and-drop/vocabulary";

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
export type DragSource = ReturnType<typeof normalizeOwnedDragSource>;

interface DDragAndDropSourceSignature {
  /** The element to mark draggable. */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Discriminator string. Targets filter on this via their `accepts` arg, and
       * it is stamped onto `source.data.type` for callbacks.
       *
       * Reserved: it overwrites any `type` the payload carries. The `dragAndDrop`
       * service also identifies drags by it, so a source without one is invisible
       * there.
       */
      type: string;

      /**
       * Static payload the source attaches to the drag, exposed as `source.data`
       * in target callbacks. A `type` key on it is overwritten; see `type`.
       */
      data?: object;

      /**
       * Alternative to `data` for dynamic payloads. Called once just before
       * `dragstart`. Its `type` key is overwritten the same way.
       */
      getInitialData?: () => object;

      /**
       * A custom native drag preview. An `Element` is photographed in place: the
       * source element keeps the grab point as its hotspot, any other element
       * uses its top-left. Defaults to the source element.
       *
       * A render function mounts a fresh preview into an isolated, offscreen
       * container, so nothing around the source bleeds into the drag image.
       */
      dragPreview?: Element | DragPreviewRenderer;

      /**
       * CSS lengths (e.g. `{x: "1rem", y: "0.5rem"}`) that push the preview clear
       * of the pointer. Applies only to the render-function `dragPreview`; an
       * `Element` preview is placed by its own hotspot.
       */
      dragPreviewOffset?: { x: string; y: string };

      /**
       * Which drop operations this drag permits, written onto the native
       * `dataTransfer` at `dragstart`. Defaults to `"move"`, which also stops the
       * browser badging the pointer with its copy offer.
       *
       * A source whose drop duplicates wants `"copyMove"`: a target's
       * `getDropEffect` may only return an effect this permits.
       */
      effectAllowed?: DataTransfer["effectAllowed"];

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
       * Fires once at the end of every drag, landed or abandoned, and is where
       * drag-time state gets undone. A source destroyed before the deferred
       * dispatch fires does not receive it.
       *
       * Fires after the whole drop dispatch, target and monitor callbacks
       * included, so shared dispatch state can be cleared here. Branch on the
       * outcome with `location.current.dropTargets`.
       */
      onDragEnd?: (event: {
        /** The dragged source. */
        source: DragSource;

        /** The drag's location history. */
        location: DragLocation;
      }) => void;

      /**
       * Fires only for a drag that ended on at least one drop target, so this is
       * where the operation is performed. `onDragEnd` fires first, with the same
       * `source` and `location`.
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
       * captured with a modifier on the handle, not a selector.
       *
       * Changing it re-registers, so a ref that only arrives on a later render
       * still takes effect. Omit it and the whole element initiates a drag.
       *
       * The handle carries `draggable="true"`; this element stays the body: it
       * gets the state markers, is the target's `source.element`, and is what the
       * default preview photographs.
       */
      dragHandle?: Element;

      /**
       * When `true`, the draggable registration is detached; a drag already in
       * flight finishes and reports first. This, not `dragHandle`, is how to stop
       * an element being dragged: a handle only moves where a drag may begin.
       *
       * Style and assert on `data-drag-source`, never on `draggable`: the
       * attribute sits on whichever element was registered.
       */
      disabled?: boolean;
    };
    Positional: [];
  };
}

/**
 * What a registration still owes after being detached without cancelling, and
 * the ways its owner can resume or let go of it.
 *
 * A registration waiting for its drag can be reclaimed when the modifier needs
 * that same element again. Work holding only a scheduled dispatch cannot: its
 * drag has ended and its registration has already been torn down.
 */
export interface DetachedSourceWork {
  /**
   * The element the registration was created on: the drag handle when one was
   * given, the source element otherwise. A replacement registering on the same
   * element can reclaim this work; one registering elsewhere must leave it
   * waiting, because the underlying library dispatches an in-flight drag's end
   * by looking this element up.
   */
  registeredElement: HTMLElement;

  /**
   * Re-adopts a registration still waiting for its drag, or returns `null` when
   * only a scheduled dispatch remains.
   */
  reclaim: () => DragAndDropSourceCleanup | null;

  /** The consumer is going away. Drops everything, dispatch included. */
  abandon: () => void;

  /**
   * Whether anything is still owed. Goes false once the dispatch has fired and
   * no teardown is waiting; a holder has no other way to know when to let go.
   */
  outstanding: () => boolean;
}

/**
 * Tears a drag source registration down.
 *
 * `cancelPending` decides the fate of a drop dispatch already scheduled for the
 * next task. `true` (the default) drops it: the consumer is going away. `false`
 * keeps it: the registration is only being replaced and the consumer lives on.
 *
 * Returns the work still owed, or `null`. A caller that kept the dispatch must
 * hold onto it: it is the only way left to reach the registration, and a
 * reclaimed one is torn down by calling this again.
 */
export type DragAndDropSourceCleanup = (options?: {
  cancelPending?: boolean;
}) => DetachedSourceWork | null;

/**
 * The drag source's named args, for a consumer driving
 * {@link registerDragAndDropSource} imperatively rather than through the
 * modifier.
 */
export type DragAndDropSourceArgs =
  DDragAndDropSourceSignature["Args"]["Named"];

type RegistrationToken = symbol;

/** Which live registrations own each body's source mark. */
const dragSourceMarks = new WeakMap<Element, Set<RegistrationToken>>();

/**
 * Wraps the underlying draggable registration with payload normalisation, the
 * source's state markers, and the end-of-drag deferral. Exported so a consumer
 * can register a source imperatively, beside `registerDragAndDropTarget`.
 *
 * End-of-drag callbacks are deferred to the next task, after the drop event has
 * finished propagating: `onDragEnd` for every drag, then `onDrop` for one that
 * landed on a target.
 *
 * One registration per element: the underlying library keys registrations by
 * element, so a second one must wait for the first's cleanup.
 *
 * @param element - The element to mark draggable.
 * @param getArgsRef - Closure returning the latest args, read on every library
 *   callback, so changes apply without re-registering. `dragHandle` is read once
 *   at registration; change it by re-registering.
 * @returns Cleanup function; see {@link DragAndDropSourceCleanup}.
 */
export function registerDragAndDropSource(
  element: HTMLElement,
  getArgsRef: () => DragAndDropSourceArgs
): DragAndDropSourceCleanup {
  const token = Symbol("drag-source-registration");

  // Registered on the handle itself, not via the library's own `dragHandle`
  // option, so `draggable="true"` never lands on the body.
  const registered = (getArgsRef().dragHandle ?? element) as HTMLElement;

  // An attribute, not a class: the stylesheet gates on it, and a consumer's
  // dynamic `class` binding would overwrite a class written here.
  const marks = dragSourceMarks.get(element) ?? new Set();
  marks.add(token);
  dragSourceMarks.set(element, marks);
  element.setAttribute("data-drag-source", "");

  /** The scheduled end-of-drag dispatch, so teardown can cancel it. */
  let pendingConsumers: Parameters<typeof cancel>[0] | null = null;

  /** Whether a drag from this element is in flight. */
  let dragging = false;

  /** A teardown waiting for the drag in flight to finish, if there is one. */
  let teardownWhenIdle: (() => void) | null = null;

  // Writes the starting drag's `effectAllowed`; left unwritten it means
  // "anything", which the browser renders as its standing offer to copy.
  // A native listener because the library never hands the callbacks the event.
  const declareEffect = (event: DragEvent) => {
    // A dragstart bubbling out of a nested source or a natively draggable
    // child belongs to that element, not to this registration.
    if (event.target !== registered || !event.dataTransfer) {
      return;
    }
    event.dataTransfer.effectAllowed = getArgsRef().effectAllowed ?? "move";
  };
  registered.addEventListener("dragstart", declareEffect);

  const cleanup = draggable({
    element: registered,
    canDrag: ({ input }) => {
      const args = getArgsRef();
      if (!args.canDrag) {
        return true;
      }
      return consumerMayThrow(
        () =>
          args.canDrag!({
            source: { type: args.type, data: args.data, element },
            input,
          }) !== false,
        false
      );
    },
    onGenerateDragPreview: ({ nativeSetDragImage, location }) => {
      const args = getArgsRef();
      // Latched here rather than in `onDragStart`, which the library defers by
      // a frame: a detach landing in that frame must still see the drag.
      dragging = true;

      // Claims the drag over dead space, so a release there ends it in place.
      // Never stopped: the utility unbinds itself on drop, dragend and broken drags.
      preventUnhandled.start();

      if (!nativeSetDragImage) {
        return;
      }
      if (typeof args.dragPreview === "function") {
        setCustomNativeDragPreview({
          nativeSetDragImage,
          getOffset: args.dragPreviewOffset
            ? pointerOutsideOfPreview(args.dragPreviewOffset)
            : undefined,
          render: ({ container }) => {
            const dispose = consumerMayThrow(() =>
              (args.dragPreview as DragPreviewRenderer)({ container, element })
            );
            return typeof dispose === "function"
              ? () => consumerMayThrow(dispose)
              : undefined;
          },
        });
        return;
      }
      // With a handle the browser's default preview would be the grip alone, so
      // the body stands in.
      const preview =
        args.dragPreview ?? (registered === element ? null : element);
      if (preview) {
        if (preview === element) {
          const { clientX, clientY } = location.current.input;
          const { left, top, width, height } = element.getBoundingClientRect();
          nativeSetDragImage(
            preview,
            Math.max(0, Math.min(clientX - left, width)),
            Math.max(0, Math.min(clientY - top, height))
          );
        } else {
          nativeSetDragImage(preview, 0, 0);
        }
      }
    },
    getInitialData: () => {
      const args = getArgsRef();
      const resolved = consumerMayThrow(
        () => args.getInitialData?.() ?? args.data ?? {},
        {}
      );
      // Spread first so the payload's own `type` cannot win. `DRAG_BODY` lets a
      // target resolve the body behind a handle; the vocabulary strips it.
      return { ...resolved, type: args.type, [DRAG_BODY]: element };
    },
    onDragStart: (event) => {
      const args = getArgsRef();
      element.classList.add("--dragging");
      const sourcePayload = normalizeOwnedDragSource(event.source);
      consumerMayThrow(() =>
        args.onDragStart?.({
          source: sourcePayload,
          input: event.location.current.input,
        })
      );
    },
    onDrop: (event) => {
      const args = getArgsRef();
      dragging = false;
      element.classList.remove("--dragging");

      // Snapshot before deferring: when the task runs, `getArgsRef()` may
      // belong to a later render or a new drag.
      const consumerOnDragEnd = args.onDragEnd;
      const consumerOnDrop = args.onDrop;
      const sourcePayload = normalizeOwnedDragSource(event.source);
      const location = event.location;
      const landed = location.current.dropTargets.length > 0;

      // One task for both callbacks, so `pendingConsumers` cancels the whole
      // dispatch and their order is fixed.
      pendingConsumers = next(() => {
        pendingConsumers = null;
        try {
          // Guarded one at a time so an `onDragEnd` that throws does not cost
          // the drag its `onDrop`.
          consumerMayThrow(() =>
            consumerOnDragEnd?.({ source: sourcePayload, location })
          );
          if (landed) {
            consumerMayThrow(() =>
              consumerOnDrop?.({ source: sourcePayload, location })
            );
          }
        } finally {
          // The teardown held back for this drag runs after both callbacks, so
          // the consumer hears its drag end before the registration goes.
          const deferred = teardownWhenIdle;
          teardownWhenIdle = null;
          deferred?.();
        }
      });
    },
  });

  const teardown = () => {
    cleanup();
    registered.removeEventListener("dragstart", declareEffect);
    if (dragging) {
      element.classList.remove("--dragging");
    }
    const currentMarks = dragSourceMarks.get(element);
    if (!currentMarks?.delete(token)) {
      return;
    }
    if (currentMarks.size === 0) {
      dragSourceMarks.delete(element);
      element.removeAttribute("data-drag-source");
    }
  };

  /**
   * Drops everything this registration is still owed, for a consumer that is
   * going away: the scheduled dispatch as well as any waiting teardown.
   */
  const abandon = () => {
    if (pendingConsumers) {
      cancel(pendingConsumers);
      pendingConsumers = null;
    }
    if (teardownWhenIdle) {
      teardownWhenIdle = null;
      teardown();
    }
  };

  const outstanding = () => Boolean(pendingConsumers || teardownWhenIdle);

  /** Re-adopts this registration while its drag still requires it. */
  const reclaim = () => {
    if (!teardownWhenIdle) {
      return null;
    }
    teardownWhenIdle = null;
    return cleanupRegistration;
  };

  /** See {@link DragAndDropSourceCleanup}. */
  const cleanupRegistration: DragAndDropSourceCleanup = ({
    cancelPending = true,
  } = {}) => {
    if (cancelPending) {
      abandon();
      teardown();
      return null;
    }

    if (dragging) {
      // Unregistering mid-drag drops the library's end-of-drag dispatch to this
      // element, so the teardown waits for the drag.
      teardownWhenIdle = teardown;
      return { registeredElement: registered, reclaim, abandon, outstanding };
    }

    teardown();
    return pendingConsumers
      ? { registeredElement: registered, reclaim, abandon, outstanding }
      : null;
  };

  return cleanupRegistration;
}

/**
 * Marks an element as a drag source for the Discourse drag-and-drop vocabulary,
 * paired with `dDragAndDropTarget`. A thin wrapper around
 * {@link registerDragAndDropSource}; every arg is documented on
 * {@link DragAndDropSourceArgs}.
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
 * Stamps `data-drag-source` for the registration's lifetime and `--dragging`
 * while a drag is active; the ui-kit drag-and-drop stylesheet gates its
 * selectors on the attribute.
 *
 * Testing: see the note on `dDragAndDropTarget`; the same helpers drive both
 * ends of a drag.
 *
 * Pointer-only. A native drag has no keyboard equivalent, so a surface built on
 * this needs a keyboard route to the same operation beside it.
 *
 * @see The `dPointerDrag` modifier when there is no drop target and no payload:
 *   a press that changes a value continuously is a different gesture.
 */
export default class DDragAndDropSourceModifier extends Modifier<DDragAndDropSourceSignature> {
  #cleanup: DragAndDropSourceCleanup | null = null;

  /**
   * Replaced by `modify` before any callback can read it; the empty bag only
   * covers the window before the first run.
   */
  #args = {} as DragAndDropSourceArgs;

  /** The handle the live registration was created with, to detect a change. */
  #dragHandle: Element | undefined = undefined;

  /**
   * Registrations replaced while still owing the consumer something. Held here
   * because a consumer can be destroyed after its registration was replaced but
   * before the drag it kept has reported. A set: several can be outstanding.
   */
  #detached = new Set<DetachedSourceWork>();

  constructor(owner: Owner, args: ArgsFor<DDragAndDropSourceSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => {
      instance.#detach();
      instance.#detached.forEach((work) => work.abandon());
      instance.#detached.clear();
    });
  }

  modify(
    element: HTMLElement,
    _positional: [],
    args: DragAndDropSourceArgs = {} as DragAndDropSourceArgs
  ) {
    if (args.disabled) {
      this.#detach({ cancelPending: false });
      return;
    }

    this.#args = args;

    if (this.#cleanup && args.dragHandle !== this.#dragHandle) {
      this.#detach({ cancelPending: false });
    }
    this.#dragHandle = args.dragHandle;

    if (!this.#cleanup) {
      const registering = (args.dragHandle ?? element) as HTMLElement;
      for (const work of this.#detached) {
        if (work.registeredElement === registering) {
          const reclaimed = work.reclaim();
          if (reclaimed) {
            this.#detached.delete(work);
            this.#cleanup = reclaimed;
            break;
          }
        }
      }
      this.#pruneDetached();
      this.#cleanup ??= registerDragAndDropSource(element, () => this.#args);
    }
  }

  /**
   * Unregisters the source.
   *
   * @param options - `cancelPending` passes through to the registration's
   *   cleanup. Defaults to `true`, the destructor's case; only a replacement
   *   while the consumer lives on keeps the pending dispatch.
   */
  #detach({ cancelPending = true }: { cancelPending?: boolean } = {}) {
    const work = this.#cleanup?.({ cancelPending }) ?? null;
    if (work) {
      this.#detached.add(work);
    }
    this.#pruneDetached();
    this.#cleanup = null;
  }

  /**
   * Forgets detached registrations that have finished what they were kept for.
   * Without a sweep on each detach and re-registration, one would be retained
   * per drag for as long as this modifier lives.
   */
  #pruneDetached() {
    this.#detached.forEach((work) => {
      if (!work.outstanding()) {
        this.#detached.delete(work);
      }
    });
  }
}
