let _loaded = false;
let _callbacks = [];
const _isTouch = window.ontouchstart !== undefined;

export const drag = function (target, didStartDrag, didEndDrag) {
  // Register a global event to capture mouse moves (once).
  if (!_loaded) {
    document.addEventListener(
      _isTouch ? "touchmove" : "mousemove",
      function (e) {
        let c = e;
        if (e.touches) {
          c = e.touches[0];
        }

        // On mouse move, dispatch the coords to all registered callbacks.
        for (let i = 0; i < _callbacks.length; i++) {
          _callbacks[i](c);
        }
      }
    );
  }

  _loaded = true;
  let hasStarted = false;

  target.addEventListener(_isTouch ? "touchstart" : "mousedown", function (e) {
    e.stopPropagation();
    e.preventDefault();

    if (!hasStarted) {
      //apply mouse styles when dragging
      document.body.classList.add("dragging");
      hasStarted = true;
    }
  });

  // On leaving click, stop moving.
  document.addEventListener(_isTouch ? "touchend" : "mouseup", function (e) {
    if (didEndDrag && hasStarted) {
      didEndDrag(e, target);
    }

    document.body.classList.remove("dragging");
    hasStarted = false;
  });

  // Register mouse-move callback to move the element.
  _callbacks.push(function move(e) {
    if (hasStarted) {
      didStartDrag(e, target);
    }
  });
};

export { drag as default };
