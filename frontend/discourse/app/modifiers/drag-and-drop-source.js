// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";

const DND_MIME_PREFIX = "application/x-discourse-dnd";

/**
 * Marks an element as a drag source for the Discourse drag-and-drop
 * vocabulary shared with `drag-and-drop-target`. Use it on rows, cards,
 * or block handles that the user should be able to grab and reorder via
 * HTML5 drag-and-drop.
 *
 * ```hbs
 * <li {{dragAndDropSource
 *   kind="sidebar-link"
 *   data=this.link
 *   onDragStart=this.handleDragStart
 *   onDragEnd=this.handleDragEnd
 * }}>...</li>
 * ```
 *
 * The `kind` discriminator is encoded as a custom MIME type on the drag
 * event's `dataTransfer.types` so drop targets can sniff which kind is in
 * flight during `dragover` (where `dataTransfer` *values* are hidden by
 * the browser for security but types remain readable). The full payload
 * (`{kind, data, sourceElement}`) lives on the `drag-and-drop` service
 * for the duration of the drag.
 *
 * Toggles `is-dragging` on the source element while the drag is active,
 * matching the foundation styles in
 * `app/assets/stylesheets/common/foundation/draggable.scss`.
 */
export default class DragAndDropSourceModifier extends Modifier {
  @service dragAndDrop;

  element;
  data;
  kind;
  dragImage;
  onDragStart;
  onDragEnd;
  disabled = false;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(
    element,
    _positional,
    { kind, data, dragImage, onDragStart, onDragEnd, disabled = false } = {}
  ) {
    if (this.element && this.element !== element) {
      // Ember reuses modifier instances when the host element identity is
      // stable; we never expect the element to change underneath us. Bail
      // defensively rather than leak listeners on the previous element.
      this.cleanup();
    }
    this.element = element;
    this.kind = kind;
    this.data = data;
    this.dragImage = dragImage;
    this.onDragStart = onDragStart;
    this.onDragEnd = onDragEnd;
    this.disabled = disabled;

    if (disabled) {
      element.removeAttribute("draggable");
      element.removeEventListener("dragstart", this.handleDragStart);
      element.removeEventListener("dragend", this.handleDragEnd);
      return;
    }

    element.setAttribute("draggable", "true");
    element.addEventListener("dragstart", this.handleDragStart);
    element.addEventListener("dragend", this.handleDragEnd);
  }

  @bind
  handleDragStart(event) {
    if (!event.dataTransfer) {
      return;
    }
    event.dataTransfer.effectAllowed = "move";
    // Stamp the kind as a custom MIME type. Browsers expose `dataTransfer
    // .types` to drop targets during `dragover`, but hide actual values —
    // by encoding the kind in the type itself we can sniff it without
    // leaking sensitive payload data cross-origin.
    event.dataTransfer.setData(`${DND_MIME_PREFIX}/${this.kind}`, "");
    if (this.dragImage) {
      event.dataTransfer.setDragImage(this.dragImage, 0, 0);
    }
    this.dragAndDrop.setCurrentDrag({
      kind: this.kind,
      data: this.data,
      sourceElement: this.element,
    });
    this.element.classList.add("is-dragging");
    this.onDragStart?.({ data: this.data, event });
  }

  @bind
  handleDragEnd(event) {
    this.element.classList.remove("is-dragging");
    this.dragAndDrop.clearCurrentDrag();
    this.onDragEnd?.({ data: this.data, event });
  }

  cleanup() {
    if (!this.element) {
      return;
    }
    this.element.removeEventListener("dragstart", this.handleDragStart);
    this.element.removeEventListener("dragend", this.handleDragEnd);
    this.element.removeAttribute("draggable");
    this.element.classList.remove("is-dragging");
  }
}

/**
 * Reads the `kind` of the in-flight drag from a `DragEvent`'s
 * `dataTransfer.types`. Used by the `drag-and-drop-target` modifier when
 * it wants to filter on `kind` without reaching into the
 * `drag-and-drop` service (relevant when the type sniff happens *before*
 * state is read, e.g. native dragenter from outside the application).
 *
 * @param {DragEvent} event
 * @returns {string|null}
 */
export function dragKindFromEvent(event) {
  for (const type of event.dataTransfer?.types ?? []) {
    if (type.startsWith(`${DND_MIME_PREFIX}/`)) {
      return type.slice(DND_MIME_PREFIX.length + 1);
    }
  }
  return null;
}
