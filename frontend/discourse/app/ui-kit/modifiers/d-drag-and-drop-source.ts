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
       * photographed in place; when it is the source element, the hotspot is
       * where the user grabbed it, while a foreign element uses its top-left.
       * A render function mounts a fresh preview into an isolated, offscreen
       * container, so nothing around the source element bleeds into the drag
       * image. Defaults to the source element when omitted.
       */
      dragPreview?: Element | DragPreviewRenderer;

      /**
       * CSS length values (e.g. `{x: "1rem", y: "0.5rem"}`) that push the preview
       * clear of the pointer for better drop accuracy. Applies only to the
       * render-function `dragPreview` form; ignored for an `Element` preview,
       * whose hotspot coordinates this primitive supplies directly.
       */
      dragPreviewOffset?: { x: string; y: string };

      /**
       * Which drop operations this drag permits, written onto the native
       * `dataTransfer` at `dragstart`. Defaults to `"move"`, which is what a
       * drag between places in the same page almost always is, and which stops
       * the browser badging the pointer with its standing offer to copy.
       *
       * A source whose drop genuinely duplicates rather than relocates wants
       * `"copyMove"` — a target's `getDropEffect` may only return an effect
       * this permits, and asking for one it does not shows the pointer as
       * refused.
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
       * Fires once at the end of EVERY drag, whether it landed on a target or the
       * user abandoned it. A source destroyed before the deferred dispatch fires
       * does not receive it. This is where drag-time state gets undone.
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
       *
       * The handle becomes what carries `draggable="true"`, because that
       * attribute is what makes a browser read a press-drag as a drag instead of
       * a selection — leaving it on the row would cost exactly the text and
       * controls a handle exists to keep usable. This element stays the body
       * regardless: it is what the state markers land on, what a target receives
       * as `source.element`, and what the drag preview photographs.
       */
      dragHandle?: Element;

      /**
       * When `true`, the underlying draggable registration is detached. Used by
       * consumers that conditionally suppress dragging (e.g. read-only modes).
       * This, not `dragHandle`, is how to stop an element being dragged:
       * `dragHandle` only moves where a drag may begin, and something is always
       * draggable while a registration stands.
       *
       * Style and assert on `data-drag-source`, never on `draggable`: the
       * attribute sits on whichever element was registered, which a handle
       * changes.
       */
      disabled?: boolean;
    };
    Positional: [];
  };
}

/**
 * What a registration still owes after being detached without cancelling, and
 * the two different reasons for letting go of it.
 *
 * They are not interchangeable, and picking the wrong one is silent: a dispatch
 * belongs to a drag that already finished, so cancelling it robs a consumer that
 * is still there of the `onDragEnd` it was promised, while leaving a waiting
 * teardown in place lets a second registration land on the same element.
 */
export interface DetachedSourceWork {
  /**
   * The element the registration was created on — the drag handle when one was
   * given, the source element otherwise. A replacement registering on the SAME
   * element must supersede this work first (two registrations on one element is
   * not a state the library supports); one registering elsewhere must leave it
   * waiting, because the library dispatches an in-flight drag's end by looking
   * this element up.
   */
  registeredElement: HTMLElement;

  /**
   * Something has taken this registration's place. Runs a teardown that was
   * waiting on a drag, and leaves a scheduled dispatch to fire.
   */
  supersede: () => void;

  /** The consumer is going away. Drops everything, dispatch included. */
  abandon: () => void;

  /**
   * Whether anything is still owed. Goes false once the dispatch has fired and
   * no teardown is waiting, which a caller holding these has no other way to
   * find out — so without it they accumulate for as long as it lives.
   */
  outstanding: () => boolean;
}

/**
 * The drag source's named args, for a consumer driving
 * {@link registerDragAndDropSource} imperatively rather than through the
 * modifier.
 */
export type DragAndDropSourceArgs =
  DDragAndDropSourceSignature["Args"]["Named"];

type RegistrationToken = symbol;

/**
 * Where to read a registered source element's current args. Weak because it
 * outlives no registration it should: a module-level strong reference to an
 * element keeps a removed subtree alive for the life of the tab, and a
 * registration this never hears the end of would be exactly that.
 */
let effectDeclarers = new WeakMap<
  Element,
  { token: RegistrationToken; getArgsRef: () => DragAndDropSourceArgs }
>();

/** Which live registrations own each body's source mark. */
let dragSourceMarks = new WeakMap<Element, Set<RegistrationToken>>();

/**
 * How many sources are registered, which a weak map cannot report and the
 * listener below is bound and unbound on.
 */
let liveSourceCount = 0;

/** Unbinds the shared listener below. Null while no source is registered. */
let stopDeclaringEffects: (() => void) | null = null;

/**
 * Says what the drag that is starting permits, which nothing else does — left
 * unwritten, `effectAllowed` means "anything", which the browser renders as its
 * standing offer to copy.
 *
 * A native listener because the drag callbacks are never handed the event. It
 * runs during the `dragstart` dispatch, which is all the browser asks: it reads
 * the value once that dispatch has finished.
 */
function declareEffectAllowed(event: DragEvent) {
  const declarer =
    event.target instanceof Element
      ? effectDeclarers.get(event.target)
      : undefined;
  if (declarer && event.dataTransfer) {
    event.dataTransfer.effectAllowed =
      declarer.getArgsRef().effectAllowed ?? "move";
  }
}

/**
 * Puts a source on the shared listener rather than giving it one of its own: a
 * long list registers a row per item, and the event it needs is one the whole
 * page dispatches anyway.
 *
 * @returns Cleanup, which unbinds the listener once the last source has gone.
 */
function declareEffectFor(
  element: Element,
  getArgsRef: () => DragAndDropSourceArgs,
  token: RegistrationToken
) {
  if (!effectDeclarers.has(element)) {
    liveSourceCount += 1;
  }
  effectDeclarers.set(element, { token, getArgsRef });
  if (!stopDeclaringEffects) {
    window.addEventListener("dragstart", declareEffectAllowed, {
      capture: true,
    });
    stopDeclaringEffects = () =>
      window.removeEventListener("dragstart", declareEffectAllowed, {
        capture: true,
      });
  }

  return () => {
    // Only the release that finds the entry still there counts. A teardown is
    // expected to be idempotent, and a second one decrementing again would take
    // the listener out from under a source that is still registered.
    if (effectDeclarers.get(element)?.token !== token) {
      return;
    }
    effectDeclarers.delete(element);
    // Clamped because a reset zeroes the count while live registrations are
    // still holding a release, and a negative count would never reach zero.
    liveSourceCount = Math.max(0, liveSourceCount - 1);
    if (liveSourceCount === 0) {
      stopDeclaringEffects?.();
      stopDeclaringEffects = null;
    }
  };
}

/** Test-only: forget every source and unbind the listener between tests. */
export function resetDragSourcesForTesting() {
  effectDeclarers = new WeakMap();
  dragSourceMarks = new WeakMap();
  liveSourceCount = 0;
  stopDeclaringEffects?.();
  stopDeclaringEffects = null;
}

/**
 * Wraps the underlying draggable registration with source-payload
 * normalisation, the `--dragging` class on the source element, and the
 * end-of-drag deferral that hides its source-before-target dispatch ordering.
 * Used by the default-exported modifier below, and exported so a consumer can
 * register a drag source imperatively (when a template modifier doesn't fit —
 * e.g. marking elements rendered inside another component as sources) without
 * importing the underlying library — parallel to
 * `registerDragAndDropTarget` / `registerDragAndDropMonitor`.
 *
 * The consumer's end-of-drag callbacks are deferred to the next task so they
 * fire after the drop event has finished propagating: `onDragEnd` for every
 * drag, then `onDrop` only for one that ended on a drop target.
 *
 * @param element - The element to mark draggable.
 * @param getArgsRef - Closure returning the latest args. Library callbacks read
 *   this on every invocation, so arg changes take effect without re-registering.
 *   `dragHandle` is the exception: it is read once, when this registers, so a
 *   caller driving this imperatively must re-register to change it.
 * @returns Cleanup function. Caller invokes it once on teardown.
 */
export function registerDragAndDropSource(
  element: HTMLElement,
  getArgsRef: () => DragAndDropSourceArgs
) {
  const token = Symbol("drag-source-registration");

  // A handle takes the registration, and this element stays the body. The
  // registration is what receives `draggable="true"`, and that attribute is what
  // makes a browser read a press-drag as a drag rather than a selection — so
  // leaving it on the body would cost the row the selectable text and operable
  // controls a handle exists to preserve. It also makes the library's own
  // `dragHandle` unnecessary: a press outside the registration cannot begin a
  // drag at all, rather than beginning one the library then hit-tests and vetoes.
  //
  // Read once, here: the underlying library keeps this in the config captured at
  // registration, so it does not see a later change the way the callbacks below
  // see one through `getArgsRef`. Replacing the registration when the handle
  // changes is the modifier's job. Cast because `dragHandle` is the broader
  // `Element` for consumers, while the library needs an `HTMLElement`.
  const registered = (getArgsRef().dragHandle ?? element) as HTMLElement;

  // Marks the element as owned by this primitive for the lifetime of the
  // registration. The stylesheet gates the state modifiers below on it, so a
  // generic state name cannot reach an element this never touched. An attribute
  // rather than a class because consumers frequently bind `class` themselves,
  // and a dynamic binding would drop anything written here.
  const marks = dragSourceMarks.get(element) ?? new Set();
  marks.add(token);
  dragSourceMarks.set(element, marks);
  element.setAttribute("data-drag-source", "");

  // The end-of-drag consumer callbacks are deferred, so teardown has to be able
  // to take them back: without this a route transition, or a re-render dropping
  // the row, runs them against a destroyed component one task later.
  let pendingConsumers: Parameters<typeof cancel>[0] | null = null;

  /** Whether a drag from this element is in flight. */
  let dragging = false;

  /** A teardown waiting for the drag in flight to finish, if there is one. */
  let teardownWhenIdle: (() => void) | null = null;

  const stopDeclaringEffect = declareEffectFor(registered, getArgsRef, token);

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

      // Answers for the drag everywhere no target accepts it, so releasing over
      // dead space ends the drag where the pointer is instead of playing the
      // browser's snap-back animation. Started here rather than from
      // `onDragStart`, which the library defers by a frame: bound a frame late,
      // the first moments of every drag would go unanswered.
      //
      // Deliberately never stopped. The utility binds its own drop, dragend and
      // broken-drag cleanup, so it releases itself however the drag ends —
      // including one whose source was destroyed mid-flight, where our own
      // teardown callbacks are cancelled and would never run.
      //
      // Only drags this primitive starts reach this callback. Native drags the
      // browser starts from page content carry their own payload, so what the
      // rest of the page does with them stays the browser's business.
      preventUnhandled.start();

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
      // An `Element` is photographed in place. `dragPreviewOffset` does not
      // apply here: the platform records the coordinates it is given.
      //
      // With a handle, the body stands in when the consumer named no preview:
      // what the user is moving is the row, and the browser's own default would
      // photograph the registration — a picture of the grip alone. Without one
      // the two are the same element, so the browser's default already is the
      // body and asking for it explicitly would only cost a call.
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
      // Stamped last: the discriminator is the primitive's, and a payload
      // carrying its own `type` — which domain objects routinely do — would
      // otherwise decide which targets accept the drag.
      //
      // The body rides along so a target can name the element the user is
      // moving rather than the handle the library registered. It is read back
      // out by `dragBodyOf` in `vocabulary.ts` and never surfaces to consumers.
      return { ...resolved, type: args.type, [DRAG_BODY]: element };
    },
    onDragStart: (event) => {
      const args = getArgsRef();
      dragging = true;
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
      // Source-private cleanup runs synchronously. These touch only
      // state owned by the source element / source modifier; nothing
      // downstream (target callbacks, native bubble-phase listeners)
      // depends on them.
      element.classList.remove("--dragging");

      // Snapshot the consumer callbacks + payload BEFORE deferring.
      // The modifier's argsRef can change across re-renders, and by
      // the time the task fires a new drag could already have
      // started — we want the consumers for THIS drag, with the
      // payload the library captured at THIS drag's start.
      const consumerOnDragEnd = args.onDragEnd;
      const consumerOnDrop = args.onDrop;
      const sourcePayload = normalizeOwnedDragSource(event.source);
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
        try {
          // Lifecycle before dispatch: a consumer that only needs to undo its
          // drag-time state hears about every drag, while one that performs an
          // operation is not asked to perform it for a drag the user gave up on.
          //
          // Guarded one at a time. A lifecycle callback that throws must not
          // cost the drag the operation it landed.
          consumerMayThrow(() =>
            consumerOnDragEnd?.({ source: sourcePayload, location })
          );
          if (landed) {
            consumerMayThrow(() =>
              consumerOnDrop?.({ source: sourcePayload, location })
            );
          }
        } finally {
          // A teardown that was held back for this drag. Run last, so the
          // unregistration cannot land in the middle of the library's own
          // dispatch, and in a `finally`, because a consumer that throws would
          // otherwise leave the element registered for good.
          const deferred = teardownWhenIdle;
          teardownWhenIdle = null;
          deferred?.();
        }
      });
    },
  });

  const teardown = () => {
    cleanup();
    stopDeclaringEffect();
    element.classList.remove("--dragging");
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
   * Runs a teardown that was waiting on a drag, because something has taken this
   * registration's place and the drag it was waiting for will never report.
   *
   * Deliberately leaves a scheduled dispatch alone: that belongs to a drag which
   * already finished, and the consumer it belongs to is still there.
   */
  const supersede = () => {
    if (teardownWhenIdle) {
      teardownWhenIdle = null;
      teardown();
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
    supersede();
  };

  const outstanding = () => Boolean(pendingConsumers || teardownWhenIdle);

  /**
   * Tears the registration down.
   *
   * @param options - Cleanup options. `cancelPending` determines whether to
   *   drop a drop dispatch already scheduled for the next task. True when the
   *   consumer itself is going away, because running its callbacks against a
   *   destroyed component is the hazard this defers around. False when the
   *   registration is merely being replaced — a `disabled` arg flipping, or a
   *   new handle — because the consumer is still there and still expects to
   *   hear how its own drag ended.
   * @returns `null` once nothing is outstanding, or the work still owed. A
   *   caller that kept it has to hold onto this: it is the only remaining way to
   *   reach it, and the two ways of letting go are not interchangeable.
   */
  return ({
    cancelPending = true,
  }: { cancelPending?: boolean } = {}): DetachedSourceWork | null => {
    if (cancelPending) {
      abandon();
      teardown();
      return null;
    }

    if (dragging) {
      // Unregistering now would take the element out of the library's dispatch
      // mid-drag, so the drop it is about to report — and with it the
      // `onDragEnd` every drag is promised — would never arrive. The consumer
      // is still here to receive it, so the teardown waits for the drag.
      teardownWhenIdle = teardown;
      return { registeredElement: registered, supersede, abandon, outstanding };
    }

    teardown();
    return pendingConsumers
      ? { registeredElement: registered, supersede, abandon, outstanding }
      : null;
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
 * Testing: see the note on `dDragAndDropTarget`; the same helpers drive both
 * ends of a drag.
 *
 * Pointer-only. A native drag has no keyboard equivalent, so a surface built on this
 * needs a keyboard route to the same operation beside it.
 *
 * @see The `dPointerDrag` modifier when there is no drop target and no payload — a
 *   press that changes a value continuously is a different gesture.
 */
export default class DDragAndDropSourceModifier extends Modifier<DDragAndDropSourceSignature> {
  #cleanup: ReturnType<typeof registerDragAndDropSource> | null = null;

  /**
   * Replaced by `modify` before any callback can read it; the empty bag only
   * covers the window before the first run.
   */
  #args = {} as DragAndDropSourceArgs;

  /** The handle the live registration was created with, to detect a change. */
  #dragHandle: Element | undefined = undefined;

  /**
   * Registrations that were replaced while still owing the consumer something.
   * Held here rather than left in their own closures, which went away with the
   * cleanup functions that reached them: a consumer can be destroyed after its
   * registration was replaced but before the drag it kept has reported.
   *
   * A set rather than one, because a replaced registration keeps owing a
   * dispatch until it fires, and there is no way to observe that it has.
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
    }
    this.#dragHandle = args.dragHandle;

    if (!this.#cleanup) {
      // Anything still holding the element about to be registered is let go of
      // first: two registrations on one element is not a state the library
      // supports. Only that element's work though — a registration waiting on a
      // DIFFERENT element (the ordinary shape of a handle change) is how an
      // in-flight drag's end still reaches the consumer, since the library
      // dispatches it by looking the original element up. And only the
      // teardowns — a dispatch already scheduled belongs to a drag that
      // finished, and this consumer is still here to be told how.
      const registering = (args.dragHandle ?? element) as HTMLElement;
      this.#detached.forEach((work) => {
        if (work.registeredElement === registering) {
          work.supersede();
        }
      });
      this.#pruneDetached();
      this.#cleanup = registerDragAndDropSource(element, () => this.#args);
    }
  }

  /**
   * Unregisters the source.
   *
   * @param options - Cleanup options. `cancelPending` is passed through to the
   *   registration's own cleanup. Defaults to true, which is the destructor's
   *   case: only a caller that is replacing the registration while the consumer
   *   lives on asks for the pending drop dispatch to be kept.
   */
  #detach({ cancelPending = true }: { cancelPending?: boolean } = {}) {
    const work = this.#cleanup?.({ cancelPending }) ?? null;
    if (work) {
      // The drag this work is waiting on is still in flight, so the element
      // keeps its mark; the deferred teardown removes it when the drag ends.
      this.#detached.add(work);
    }
    this.#pruneDetached();
    this.#cleanup = null;
  }

  /**
   * Forgets detached registrations that have finished what they were kept for.
   *
   * They cannot report this themselves, so without a sweep on each detach and
   * re-registration one is retained per drag for as long as this modifier lives,
   * each holding its element and the library's cleanup.
   */
  #pruneDetached() {
    this.#detached.forEach((work) => {
      if (!work.outstanding()) {
        this.#detached.delete(work);
      }
    });
  }
}
