// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import { draggable } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import Modifier from "ember-modifier";

/**
 * Marks an element as a drag source for the Discourse drag-and-drop
 * vocabulary, paired with `dDragAndDropTarget` on the receiving side.
 * Backed by Atlassian's Pragmatic Drag and Drop primitives (`draggable`
 * from `@atlaskit/pragmatic-drag-and-drop`) for rAF-batched events,
 * cleaner lifecycle, and a path to auto-scroll / accessibility helpers
 * later.
 *
 * ```hbs
 * <li {{dDragAndDropSource
 *   type="sidebar-link"
 *   data=this.link
 *   dragPreview=this.previewEl
 *   canDrag=this.canDrag
 *   onDragStart=this.handleDragStart
 *   onDrop=this.handleDragEnd
 *   getDropEffect=this.dropEffect
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
 *  - `onDrop` — `({source, location}) => void`. Fires when the drag
 *    ends (a successful drop OR a cancellation). Receives the same
 *    `source` shape and the full PDND location history.
 *  - `disabled` — when `true`, the modifier detaches the underlying
 *    `draggable()`. Used by consumers that conditionally suppress
 *    dragging (e.g. read-only modes).
 *
 * Adds the `is-dragging` class to the source element while a drag is
 * active so consumers can style it via
 * `app/assets/stylesheets/common/foundation/draggable.scss`.
 */
export default class DDragAndDropSourceModifier extends Modifier {
  @service dragAndDrop;

  #cleanup = null;
  #element = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#detach());
  }

  modify(
    element,
    _positional,
    {
      type,
      data,
      getInitialData,
      dragPreview,
      canDrag,
      onDragStart,
      onDrop,
      disabled = false,
    } = {}
  ) {
    if (this.#element && this.#element !== element) {
      // Ember reuses modifier instances when the host element identity
      // is stable; we never expect the element to change underneath us.
      // Detach defensively rather than leak listeners on the previous
      // element.
      this.#detach();
    }
    this.#element = element;
    this.#detach();

    if (disabled) {
      return;
    }

    this.#cleanup = draggable({
      element,
      canDrag: canDrag
        ? ({ input }) =>
            canDrag({ source: this.#buildPartialSource(type, data), input }) !==
            false
        : undefined,
      onGenerateDragPreview: dragPreview
        ? ({ nativeSetDragImage }) => {
            nativeSetDragImage?.(dragPreview, 0, 0);
          }
        : undefined,
      getInitialData: () => {
        const resolved = getInitialData?.() ?? data ?? {};
        return { type, ...resolved };
      },
      onDragStart: (event) => {
        element.classList.add("is-dragging");
        const sourcePayload = {
          type,
          data: event.source.data,
          element,
        };
        this.dragAndDrop.setCurrentDrag(sourcePayload);
        onDragStart?.({
          source: sourcePayload,
          input: event.location?.current?.input,
        });
      },
      onDrop: (event) => {
        element.classList.remove("is-dragging");
        this.dragAndDrop.clearCurrentDrag();
        const sourcePayload = {
          type,
          data: event.source.data,
          element,
        };
        onDrop?.({ source: sourcePayload, location: event.location });
      },
    });
  }

  #buildPartialSource(type, data) {
    // For `canDrag`, `getInitialData` hasn't run yet so we don't have the
    // merged payload PDND would otherwise expose. Build a best-effort
    // shape from the declared args.
    return { type, data, element: this.#element };
  }

  #detach() {
    this.#cleanup?.();
    this.#cleanup = null;
    this.#element?.classList.remove("is-dragging");
  }
}
