import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";

/**
 * Binds a press-drag lifecycle using legacy mouse and touch event pairs, plus
 * native drag events, with document-level listeners for the gesture's duration.
 *
 * @deprecated since 2026.8.0. Use `dPointerDrag`
 *   (`discourse/ui-kit/modifiers/d-pointer-drag`), which covers mouse, touch and
 *   pen through unified Pointer Events and `setPointerCapture` rather than
 *   parallel event pairs. Map `didStartDrag` to `onDragStart`, `dragMove` to
 *   `onDrag`, and `didEndDrag` to `onDragEnd` — usually to `onDragCancel` too, so
 *   an interrupted gesture still finishes. Where this marked the body, pass
 *   `bodyClass="dragging"`.
 *
 *   Three behaviour differences matter when migrating. This treats `dragenter` and
 *   `dragover` as gesture input, so a file dragged over the element starts a
 *   gesture, where `dPointerDrag` answers pointer input only. Handlers here can
 *   receive a `TouchEvent` and so tend to read `event.touches[0].pageY`, which a
 *   `PointerEvent` does not have — read `event.pageY` directly. And a gesture here
 *   is driven by whichever pointer moves, while `dPointerDrag` matches the
 *   `pointerId` that began it, so a second finger cannot take one over.
 */
export default class DDraggableModifier extends Modifier {
  hasStarted = false;
  element;

  constructor(owner, args) {
    super(owner, args);
    deprecated(
      "`dDraggable` is deprecated. Use `dPointerDrag` (`discourse/ui-kit/modifiers/d-pointer-drag`) instead.",
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
      document.body.classList.add("dragging");

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

      document.body.classList.remove("dragging");
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
    document.body.classList.remove("dragging");
  }
}
