// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { next } from "@ember/runloop";
import { draggable } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import Modifier from "ember-modifier";

/**
 * Wraps PDND's `draggable()` with the source-payload normalisation, the
 * `is-dragging` class on the source element, and the consumer-onDrop deferral
 * that hides PDND's source-before-target dispatch ordering. Used by the
 * default-exported modifier below, and exported so a consumer can register a
 * drag source imperatively (when a template modifier doesn't fit — e.g. marking
 * elements rendered inside another component as sources) without importing PDND
 * — parallel to `registerDragAndDropTarget` / `registerDragAndDropMonitor`.
 *
 * Library-agnostic by design: `@atlaskit/pragmatic-drag-and-drop` is
 * imported only by the ui-kit modifier files.
 *
 * The consumer's `onDrop` callback is deferred to the next task so it
 * fires after the drop event has finished propagating.
 *
 * @param {HTMLElement} element - The element to mark draggable.
 * @param {() => Object} getArgsRef - Closure returning the latest args.
 *   PDND callbacks read this on every invocation, so arg changes take
 *   effect without re-registering. Args shape matches the modifier:
 *   `type`, `data`, `getInitialData`, `dragPreview`, `canDrag`,
 *   `onDragStart`, `onDrop`.
 * @returns {() => void} Cleanup function. Caller invokes it once on
 *   teardown.
 */
export function registerDragAndDropSource(element, getArgsRef) {
  const cleanup = draggable({
    element,
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
      if (args.dragPreview && nativeSetDragImage) {
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
      element.classList.add("is-dragging");
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
      element.classList.remove("is-dragging");

      // Snapshot the consumer callback + payload BEFORE deferring.
      // The modifier's argsRef can change across re-renders, and by
      // the time the microtask fires a new drag could already have
      // started — we want the consumer for THIS drag, with the
      // payload PDND captured at THIS drag's start.
      const consumerOnDrop = args.onDrop;
      const sourcePayload = {
        type: args.type,
        data: event.source.data,
        element,
      };
      const location = event.location;

      // `next` defers the consumer to the next task, so it fires
      // after the current drop event finishes propagating —
      // including bubble-phase listeners that may still need to
      // read shared dispatch state.
      next(() => {
        consumerOnDrop?.({ source: sourcePayload, location });
      });
    },
  });

  return () => {
    cleanup();
    element.classList.remove("is-dragging");
  };
}

/**
 * Marks an element as a drag source for the Discourse drag-and-drop
 * vocabulary, paired with `dDragAndDropTarget` on the receiving side.
 * Thin Ember-modifier wrapper around {@link registerDraggable}.
 *
 * ```hbs
 * <li {{dDragAndDropSource
 *   type="sidebar-link"
 *   data=this.link
 *   dragPreview=this.previewEl
 *   canDrag=this.canDrag
 *   onDragStart=this.handleDragStart
 *   onDrop=this.handleDragEnd
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
 *  - `dragPreview` — optional `Element` to use as the native drag
 *    preview. Defaults to the source element if omitted.
 *  - `canDrag` — `({source, input}) => boolean`. Returning `false`
 *    blocks the drag from starting.
 *  - `onDragStart` — `({source, input}) => void`. Fires once the
 *    drag is confirmed; receives `{type, data, element}` as `source`.
 *  - `onDrop` — `({source, location}) => void`. Fires AFTER PDND's
 *    full drop dispatch (target callbacks, monitor callbacks, native
 *    bubble listeners). Safe to clear shared dispatch state from this
 *    callback — see the deferral note on `registerDragAndDropSource`.
 *  - `disabled` — when `true`, the modifier detaches the underlying
 *    draggable registration. Used by consumers that conditionally
 *    suppress dragging (e.g. read-only modes).
 *
 * Adds the `is-dragging` class to the source element while a drag is
 * active so consumers can style it via
 * `app/assets/stylesheets/common/foundation/draggable.scss`.
 */
export default class DDragAndDropSourceModifier extends Modifier {
  #cleanup = null;
  #element = null;
  #args = {};

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

    // The dragAndDrop service observes element drags first-hand via its own
    // `monitorForElements`, so this modifier no longer brackets the consumer
    // callbacks with setCurrentDrag / clearCurrentDrag — it passes them
    // through. The helper stays service-free.
    this.#args = args;

    if (!this.#cleanup) {
      this.#cleanup = registerDragAndDropSource(element, () => this.#args);
    }
  }

  #detach() {
    this.#cleanup?.();
    this.#cleanup = null;
    this.#element?.classList.remove("is-dragging");
    this.#element = null;
  }
}
