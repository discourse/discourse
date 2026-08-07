// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { next } from "@ember/runloop";
import { draggable } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import { pointerOutsideOfPreview } from "@atlaskit/pragmatic-drag-and-drop/element/pointer-outside-of-preview";
import { setCustomNativeDragPreview } from "@atlaskit/pragmatic-drag-and-drop/element/set-custom-native-drag-preview";
import Modifier from "ember-modifier";

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
 * @param {HTMLElement} element - The element to mark draggable.
 * @param {() => Object} getArgsRef - Closure returning the latest args.
 *   PDND callbacks read this on every invocation, so arg changes take
 *   effect without re-registering. Args shape matches the modifier:
 *   `type`, `data`, `getInitialData`, `dragPreview`, `dragPreviewOffset`,
 *   `canDrag`, `onDragStart`, `onDragEnd`, `onDrop`. `dragHandle` is the exception: it is
 *   read once, when this registers, so a caller driving this imperatively must
 *   re-register to change it.
 * @returns {() => void} Cleanup function. Caller invokes it once on
 *   teardown.
 */
export function registerDragAndDropSource(element, getArgsRef) {
  // Marks the element as owned by this primitive for the lifetime of the
  // registration. The stylesheet gates the state modifiers below on it, so a
  // generic state name cannot reach an element this never touched. An attribute
  // rather than a class because consumers frequently bind `class` themselves,
  // and a dynamic binding would drop anything written here.
  element.setAttribute("data-drag-source", "");

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
          render: ({ container }) => args.dragPreview({ container, element }),
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
      return { type: args.type, ...resolved };
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
        type: args.type,
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
      next(() => {
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

  return () => {
    cleanup();
    element.classList.remove("--dragging");
    element.removeAttribute("data-drag-source");
  };
}

/**
 * Marks an element as a drag source for the Discourse drag-and-drop
 * vocabulary, paired with `dDragAndDropTarget` on the receiving side.
 * Thin Ember-modifier wrapper around {@link registerDragAndDropSource}.
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
 * Args (named):
 *  - `type` — discriminator string. Targets filter on this via their
 *    `accepts` arg. Stamped onto `source.data.type` so callbacks
 *    receive it with the rest of the payload.
 *  - `data` — static payload object the source attaches to the drag.
 *    Merged with `{type}` and exposed as `source.data` in target
 *    callbacks.
 *  - `getInitialData` — alternative to `data` for dynamic payloads.
 *    Called once just before `dragstart`; merged with `{type}`.
 *  - `dragPreview` — optional custom native drag preview, in one of two
 *    forms. An `Element` is photographed in place (the browser controls
 *    the hotspot). A render function `({container, element}) =>
 *    cleanupFn` mounts a fresh preview into an isolated, offscreen
 *    container the browser photographs, so nothing around the source
 *    element bleeds into the drag image; return a cleanup function that
 *    tears the preview down. Defaults to the source element if omitted.
 *  - `dragPreviewOffset` — optional `{x, y}` of CSS length values (e.g.
 *    `{x: "1rem", y: "0.5rem"}`) that pushes the preview clear of the
 *    pointer for better drop accuracy. Applies only to the render-
 *    function `dragPreview` form; ignored for an `Element` preview, whose
 *    hotspot the browser clamps to within the image.
 *  - `canDrag` — `({source, input}) => boolean`. Returning `false`
 *    blocks the drag from starting.
 *  - `onDragStart` — `({source, input}) => void`. Fires once the
 *    drag is confirmed; receives `{type, data, element}` as `source`.
 *  - `onDragEnd` — `({source, location}) => void`. Fires once at the end of
 *    EVERY drag, whether it landed on a target or the user abandoned it. This
 *    is where drag-time state gets undone.
 *  - `onDrop` — `({source, location}) => void`. Fires only when the drag ended
 *    on at least one drop target, so it is where the operation gets performed:
 *    an abandoned drag never reaches it. For a drag that lands, both fire —
 *    `onDragEnd` first — with the same `source` and `location`.
 *
 *    Both fire AFTER PDND's full drop dispatch (target callbacks, monitor
 *    callbacks, native bubble listeners), so it is safe to clear shared dispatch
 *    state from either — see the deferral note on `registerDragAndDropSource`.
 *    Inspect `location.current.dropTargets` from `onDragEnd` if a consumer needs
 *    to branch on the outcome itself.
 *  - `dragHandle` — an element inside this one that a drag must start from,
 *    so the rest stays free for selecting text and operating controls. Pass
 *    the element itself, not a selector; capture its ref with a modifier on
 *    the handle rather than querying the DOM. Changing it re-registers, so a
 *    ref that only arrives on a later render still takes effect. Omit it and
 *    the whole element initiates a drag.
 *  - `disabled` — when `true`, the modifier detaches the underlying
 *    draggable registration. Used by consumers that conditionally
 *    suppress dragging (e.g. read-only modes). This, not `dragHandle`, is how
 *    to stop an element being dragged: `draggable="true"` is stamped on the
 *    host element either way, and `dragHandle` only narrows where a drag may
 *    begin.
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
export default class DDragAndDropSourceModifier extends Modifier {
  #cleanup = null;
  #element = null;
  #args = {};
  /** The handle the live registration was created with, to detect a change. */
  #dragHandle = undefined;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#detach());
  }

  modify(element, _positional, args = {}) {
    if (this.#element && this.#element !== element) {
      this.#detach();
    }
    this.#element = element;

    if (args?.disabled) {
      this.#detach();
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
      this.#detach();
      this.#element = element;
    }
    this.#dragHandle = args.dragHandle;

    if (!this.#cleanup) {
      this.#cleanup = registerDragAndDropSource(element, () => this.#args);
    }
  }

  #detach() {
    this.#cleanup?.();
    this.#cleanup = null;
    this.#element?.classList.remove("--dragging");
    this.#element = null;
  }
}
