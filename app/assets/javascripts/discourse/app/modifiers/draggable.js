import Modifier from "ember-modifier";

export default class DraggableModifier extends Modifier {
  modify(el, _, { didStartDrag, didEndDrag }) {
    this._drag(el, didStartDrag, didEndDrag);
  }

  _drag(target, didStartDrag, didEndDrag) {
    const isTouch = window.ontouchstart !== undefined;
    let hasStarted = false;

    target.addEventListener(isTouch ? "touchstart" : "mousedown", (e) => {
      e.stopPropagation();
      e.preventDefault();

      if (!hasStarted) {
        // Register a global event to capture mouse moves when element 'clicked'.
        document.addEventListener("touchmove", drag, { passive: false });
        document.addEventListener("mousemove", drag, { passive: false });

        //apply mouse styles when dragging
        document.body.classList.add("dragging");
        hasStarted = true;
      }
    });

    // On leaving click, stop moving.
    document.addEventListener(isTouch ? "touchend" : "mouseup", (e) => {
      if (didEndDrag && hasStarted) {
        didEndDrag(e, target);

        // remove event listener from target when dragging complete
        document.removeEventListener("touchmove", drag);
        document.removeEventListener("mousemove", drag);
        document.body.classList.remove("dragging");
        hasStarted = false;
      }
    });

    // Register mouse-move callback to move the element.
    const drag = (e) => {
      if (hasStarted) {
        didStartDrag(e, target);
      }
    };
  }
}
