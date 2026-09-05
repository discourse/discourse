import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import ElementClassLease from "discourse/lib/element-class-lease";

/**
 * Binds a press-drag lifecycle using legacy mouse and touch event pairs, plus
 * native drag events, with document-level listeners for the gesture's duration.
 *
 * @deprecated since 2026.8.0. Use `dPointerDrag`
 *   (`discourse/ui-kit/modifiers/d-pointer-drag`). Rename `didStartDrag`,
 *   `dragMove` and `didEndDrag` to `onDragStart`, `onDrag` and `onDragEnd`, and
 *   add `onDragCancel` so an interrupted gesture still finishes.
 *
 *   Three differences bite beyond the renames:
 *   - the second callback argument is gesture info, not the element;
 *   - the body class is automatic here, but needs `bodyClass` there;
 *   - a touch handler reading `event.touches[0]` should read the event itself.
 */
export default class DDraggableModifier extends Modifier {
  hasStarted = false;
  element;
  #bodyClassLease;

  constructor(owner, args) {
    super(owner, args);
    deprecated(
      "`dDraggable` is deprecated. Use `dPointerDrag` (`discourse/ui-kit/modifiers/d-pointer-drag`); it is not a drop-in, see its JSDoc.",
      { id: "discourse.ui-kit.d-draggable", since: "2026.8.0" }
    );
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(el, _, { didStartDrag, didEndDrag, dragMove }) {
    this.element = el;
    this.didStartDragCallback = didStartDrag;
    this.didEndDragCallback = didEndDrag;
    this.dragMoveCallback = dragMove;
    this.element.addEventListener("touchstart", this.dragMove, {
      passive: false,
    });
    this.element.addEventListener("mousedown", this.dragMove, {
      passive: false,
    });
    this.element.addEventListener("dragenter", this.dragMove, {
      passive: false,
    });
  }

  @bind
  dragMove(e) {
    if (!this.hasStarted) {
      this.hasStarted = true;

      if (this.didStartDragCallback) {
        this.didStartDragCallback(e);
      }

      // Register a global event to capture mouse moves when element 'clicked'.
      document.addEventListener("touchmove", this.drag, { passive: false });
      document.addEventListener("mousemove", this.drag, { passive: false });
      document.addEventListener("dragover", this.drag, { passive: false });
      this.#bodyClassLease = new ElementClassLease(document.body, "dragging");

      // On leaving click, stop moving.
      document.addEventListener("touchend", this.didEndDrag, {
        passive: false,
      });
      document.addEventListener("mouseup", this.didEndDrag, {
        passive: false,
      });
      document.addEventListener("drop", this.didEndDrag, {
        passive: false,
      });
    }
  }

  @bind
  drag(e) {
    if (this.hasStarted && this.dragMoveCallback) {
      this.dragMoveCallback(e, this.element);
    }
  }

  @bind
  didEndDrag(e) {
    if (this.hasStarted) {
      this.didEndDragCallback(e, this.element);

      document.removeEventListener("touchmove", this.drag);
      document.removeEventListener("mousemove", this.drag);
      document.removeEventListener("dragover", this.drag);

      this.#bodyClassLease?.release();
      this.#bodyClassLease = null;
      this.hasStarted = false;
    }
  }

  cleanup() {
    document.removeEventListener("touchstart", this.dragMove);
    document.removeEventListener("mousedown", this.dragMove);
    document.removeEventListener("dragenter", this.dragMove);
    document.removeEventListener("touchend", this.didEndDrag);
    document.removeEventListener("mouseup", this.didEndDrag);
    document.removeEventListener("drop", this.didEndDrag);
    document.removeEventListener("mousemove", this.drag);
    document.removeEventListener("touchmove", this.drag);
    document.removeEventListener("dragover", this.drag);
    this.#bodyClassLease?.release();
    this.#bodyClassLease = null;
  }
}
