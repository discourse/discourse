import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";

/**
 * A coarse "move/scrub" modifier that mixes raw mouse, touch, and HTML5 drag
 * events into a single drag gesture and toggles a global `body.dragging` class.
 *
 * @deprecated Prefer the modifier built for the gesture you actually have:
 *  - For "press-drag-transform" gestures (press, drag, a value changes
 *    continuously with the pointer — scrollers, splitters, sliders, knobs,
 *    repositioning a handle), use `d-pointer-drag` (`dPointerDrag`). It uses
 *    unified Pointer Events with pointer capture, so it works for mouse, touch,
 *    and pen without per-input branching and without a global class.
 *  - For transferring something to a drop target (reorder a list, drop onto a
 *    zone, accept dropped files), use the `d-drag-and-drop-*` modifiers.
 *
 * Kept only for external consumers still importing the legacy
 * `discourse/modifiers/draggable` path; no in-repo code uses it.
 */
export default class DDraggableModifier extends Modifier {
  hasStarted = false;
  element;

  constructor(owner, args) {
    super(owner, args);
    deprecated(
      "The `draggable` modifier is deprecated. For press-drag-transform gestures (scrollers, splitters, repositioning a handle) use the `d-pointer-drag` modifier; for transferring something to a drop target use the `d-drag-and-drop-*` modifiers.",
      {
        id: "discourse.ui-kit.d-draggable",
        since: "2026.6.0",
      }
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
