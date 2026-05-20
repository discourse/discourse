// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import { draggable } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import Modifier from "ember-modifier";

/**
 * Imperative draggable registration backed by Pragmatic Drag and Drop.
 * Wraps `draggable()` with the source-payload normalisation, the
 * `is-dragging` class on the source element, and the consumer-onDrop
 * deferral that hides PDND's source-before-target dispatch ordering.
 *
 * Use this directly when you need a draggable from imperative code and
 * can't attach the `{{dDragAndDropSource}}` modifier. The modifier
 * class is a thin wrapper around this function for the template-based
 * common case.
 *
 * Library-agnostic by design: `@atlaskit/pragmatic-drag-and-drop` is
 * imported only by the ui-kit modifier files. Consumers (plugins, core
 * features) talk to this helper, not to PDND directly.
 *
 * The consumer's `onDrop` callback fires after PDND's full drop
 * dispatch chain — see the inline comment at the `queueMicrotask`
 * call below for the spec guarantee that backs the ordering.
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
export function registerDraggable(element, getArgsRef) {
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

      // PDND dispatches source.onDrop BEFORE target.onDrop in the
      // same drop event (see `make-adapter.js::dispatchEvent` in
      // PDND). Native bubble-phase drop listeners on non-PDND
      // elements run later still, inside the same task. If the
      // consumer's callback (typically a drag-end cleanup that
      // clears shared dispatch state) ran synchronously here, it
      // would wipe state that downstream handlers still need to
      // read — and any consumer who didn't notice this ordering
      // detail would silently race.
      //
      // Microtask deferral makes that impossible by construction.
      // Per the HTML spec, microtasks queued during a task drain at
      // the END of that task, before any new task can start. The
      // drop event's entire propagation (capture + target + bubble)
      // is one task; our microtask fires after every synchronous
      // listener for this drop. Microtasks run FIFO, and we schedule
      // ours from PDND's source.onDrop — which fires FIRST in PDND's
      // chain — so this callback runs before any other microtask
      // queued during the same drop event.
      //
      // Net effect for consumers: `onDrop` is a "drag finished, do
      // your cleanup" hook. By the time it fires, every other
      // handler has consumed whatever state it needed. Touching any
      // shared field is safe.
      queueMicrotask(() => {
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
 *    callback — see the implementation note on `registerDraggable`.
 *  - `disabled` — when `true`, the modifier detaches the underlying
 *    draggable registration. Used by consumers that conditionally
 *    suppress dragging (e.g. read-only modes).
 *
 * Adds the `is-dragging` class to the source element while a drag is
 * active so consumers can style it via
 * `app/assets/stylesheets/common/foundation/draggable.scss`.
 */
export default class DDragAndDropSourceModifier extends Modifier {
  @service dragAndDrop;

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

    // Wrap the consumer's onDragStart / onDrop so the dragAndDrop
    // service sees setCurrentDrag / clearCurrentDrag bracketed around
    // the consumer's callbacks. The service interaction lives in the
    // modifier (which has the `@service` injection); `registerDraggable`
    // itself is service-free so it stays usable from any context.
    const consumerOnDragStart = args.onDragStart;
    const consumerOnDrop = args.onDrop;
    this.#args = {
      ...args,
      onDragStart: (payload) => {
        this.dragAndDrop.setCurrentDrag(payload.source);
        consumerOnDragStart?.(payload);
      },
      onDrop: (payload) => {
        // Runs in the microtask scheduled by `registerDraggable` —
        // already deferred past PDND's full dispatch.
        this.dragAndDrop.clearCurrentDrag();
        consumerOnDrop?.(payload);
      },
    };

    if (!this.#cleanup) {
      this.#cleanup = registerDraggable(element, () => this.#args);
    }
  }

  #detach() {
    this.#cleanup?.();
    this.#cleanup = null;
    this.#element?.classList.remove("is-dragging");
    this.#element = null;
  }
}
