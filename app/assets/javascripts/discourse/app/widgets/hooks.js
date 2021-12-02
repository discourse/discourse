/*eslint no-loop-func:0*/

const CLICK_ATTRIBUTE_NAME = "_discourse_click_widget";
const DOUBLE_CLICK_ATTRIBUTE_NAME = "_discourse_double_click_widget";
const CLICK_OUTSIDE_ATTRIBUTE_NAME = "_discourse_click_outside_widget";
const MOUSE_DOWN_OUTSIDE_ATTRIBUTE_NAME =
  "_discourse_mouse_down_outside_widget";
const KEY_UP_ATTRIBUTE_NAME = "_discourse_key_up_widget";
const KEY_DOWN_ATTRIBUTE_NAME = "_discourse_key_down_widget";
const DRAG_ATTRIBUTE_NAME = "_discourse_drag_widget";
const INPUT_ATTRIBUTE_NAME = "_discourse_input_widget";
const CHANGE_ATTRIBUTE_NAME = "_discourse_change_widget";
const MOUSE_DOWN_ATTRIBUTE_NAME = "_discourse_mouse_down_widget";
const MOUSE_UP_ATTRIBUTE_NAME = "_discourse_mouse_up_widget";
const MOUSE_MOVE_ATTRIBUTE_NAME = "_discourse_mouse_move_widget";
const MOUSE_OVER_ATTRIBUTE_NAME = "_discourse_mouse_over_widget";
const MOUSE_OUT_ATTRIBUTE_NAME = "_discourse_mouse_out_widget";
const TOUCH_START_ATTRIBUTE_NAME = "_discourse_touch_start_widget";
const TOUCH_END_ATTRIBUTE_NAME = "_discourse_touch_end_widget";

class WidgetBaseHook {
  constructor(widget) {
    this.widget = widget;
  }
}

function buildHook(attributeName, setAttr) {
  return class extends WidgetBaseHook {
    hook(node) {
      if (setAttr) {
        node.setAttribute(setAttr, true);
      }
      node[attributeName] = this.widget;
    }

    unhook(node) {
      if (setAttr) {
        node.removeAttribute(setAttr, true);
      }
      node[attributeName] = null;
    }
  };
}

// For the majority of events, we register a single listener on the `<body>`, and then
// notify the relavent widget (if any) when the event fires (see setupDocumentCallback() below)
export const WidgetClickHook = buildHook(CLICK_ATTRIBUTE_NAME);
export const WidgetDoubleClickHook = buildHook(DOUBLE_CLICK_ATTRIBUTE_NAME);
export const WidgetClickOutsideHook = buildHook(
  CLICK_OUTSIDE_ATTRIBUTE_NAME,
  "data-click-outside"
);
export const WidgetMouseDownOutsideHook = buildHook(
  MOUSE_DOWN_OUTSIDE_ATTRIBUTE_NAME,
  "data-mouse-down-outside"
);
export const WidgetKeyUpHook = buildHook(KEY_UP_ATTRIBUTE_NAME);
export const WidgetKeyDownHook = buildHook(KEY_DOWN_ATTRIBUTE_NAME);
export const WidgetInputHook = buildHook(INPUT_ATTRIBUTE_NAME);
export const WidgetChangeHook = buildHook(CHANGE_ATTRIBUTE_NAME);
export const WidgetMouseUpHook = buildHook(MOUSE_UP_ATTRIBUTE_NAME);
export const WidgetMouseDownHook = buildHook(MOUSE_DOWN_ATTRIBUTE_NAME);
export const WidgetMouseMoveHook = buildHook(MOUSE_MOVE_ATTRIBUTE_NAME);
export const WidgetMouseOverHook = buildHook(MOUSE_OVER_ATTRIBUTE_NAME);
export const WidgetMouseOutHook = buildHook(MOUSE_OUT_ATTRIBUTE_NAME);
export const WidgetTouchEndHook = buildHook(TOUCH_END_ATTRIBUTE_NAME);

// `touchstart` and `touchmove` events are particularly performance sensitive because
// they block scrolling on mobile. Therefore we want to avoid registering global non-passive
// listeners for these events.
// Instead, the WidgetTouchStartHook and WidgetDragHook automatically register listeners on
// the specific widget DOM elements when required.
function touchStartHandler(e) {
  return e.currentTarget[TOUCH_START_ATTRIBUTE_NAME].touchStart(e);
}

export class WidgetTouchStartHook extends WidgetBaseHook {
  hook(node, propertyName, previousValue) {
    node[TOUCH_START_ATTRIBUTE_NAME] = this.widget;
    if (!previousValue) {
      // Element added to DOM
      node.addEventListener("touchstart", touchStartHandler, {
        passive: false,
      });
    }
  }

  unhook(node, propertyName, newValue) {
    if (!newValue) {
      // Element removed from DOM
      node.removeEventListener("touchstart", touchStartHandler);
    }
  }
}

let _currentlyDraggingElement;

function dragStart(e) {
  e.preventDefault();
  e.stopPropagation();
  if (_currentlyDraggingElement) {
    dragEnd();
  }
  _currentlyDraggingElement = e.currentTarget;
  document.body.classList.add("widget-dragging");
  document.addEventListener("touchmove", drag, { passive: false });
  document.addEventListener("mousemove", drag, { passive: false });
  document.addEventListener("touchend", dragEnd);
  document.addEventListener("mouseup", dragEnd);
}

function drag(e) {
  const widget = _currentlyDraggingElement[DRAG_ATTRIBUTE_NAME];
  if (event.type === "mousemove") {
    widget.drag(e);
  } else {
    const tt = e.targetTouches[0];
    e.preventDefault();
    e.stopPropagation();
    widget.drag(tt);
  }
}

function dragEnd(e) {
  document.body.classList.remove("widget-dragging");
  document.removeEventListener("touchmove", drag);
  document.removeEventListener("mousemove", drag);
  document.removeEventListener("touchend", dragEnd);
  document.removeEventListener("mouseup", dragEnd);
  const widget = _currentlyDraggingElement[DRAG_ATTRIBUTE_NAME];
  widget.dragEnd(e);
  _currentlyDraggingElement = null;
}

export class WidgetDragHook extends WidgetBaseHook {
  hook(node, propertyName, previousValue) {
    node[DRAG_ATTRIBUTE_NAME] = this.widget;
    if (!previousValue) {
      // Adding to DOM
      node.addEventListener("touchstart", dragStart, { passive: false });
      node.addEventListener("mousedown", dragStart, { passive: false });
    }
  }

  unhook(node, propertyName, newValue) {
    if (!newValue) {
      // Removing from DOM
      if (_currentlyDraggingElement === node) {
        dragEnd();
      }
      node.removeEventListener("touchstart", dragStart);
      node.removeEventListener("mousedown", dragStart);
    }
  }
}

function nodeCallback(node, attrName, cb, options = { rerender: true }) {
  const { rerender } = options;
  const widget = findWidget(node, attrName);

  if (widget) {
    if (rerender) {
      widget.rerenderResult(() => cb(widget));
    } else {
      cb(widget);
    }
  }
}

function findWidget(node, attrName) {
  while (node) {
    const widget = node[attrName];
    if (widget) {
      return widget;
    }
    node = node.parentNode;
  }
}

let _watchingDocument = false;

WidgetClickHook.setupDocumentCallback = function () {
  if (_watchingDocument) {
    return;
  }

  $(document).on("mouseover.discourse-widget", (e) => {
    nodeCallback(e.target, MOUSE_OVER_ATTRIBUTE_NAME, (w) => w.mouseOver(e), {
      rerender: false,
    });
  });

  $(document).on("mouseout.discourse-widget", (e) => {
    nodeCallback(e.target, MOUSE_OUT_ATTRIBUTE_NAME, (w) => w.mouseOut(e), {
      rerender: false,
    });
  });

  $(document).on("dblclick.discourse-widget", (e) => {
    nodeCallback(e.target, DOUBLE_CLICK_ATTRIBUTE_NAME, (w) =>
      w.doubleClick(e)
    );
  });

  $(document).on("click.discourse-widget", (e) => {
    nodeCallback(e.target, CLICK_ATTRIBUTE_NAME, (w) => w.click(e));

    let node = e.target;
    const $outside = $("[data-click-outside]");
    $outside.each((i, outNode) => {
      if (
        outNode.contains(node) ||
        (outNode === node && outNode.style.position === "absolute")
      ) {
        return;
      }

      const widget2 = outNode[CLICK_OUTSIDE_ATTRIBUTE_NAME];
      if (widget2) {
        widget2.clickOutside(e);
      }
    });
  });

  $(document).on("mousedown.discourse-widget", (e) => {
    let node = e.target;
    const $outside = $("[data-mouse-down-outside]");
    $outside.each((i, outNode) => {
      if (outNode.contains(node)) {
        return;
      }
      const widget2 = outNode[MOUSE_DOWN_OUTSIDE_ATTRIBUTE_NAME];
      if (widget2) {
        widget2.mouseDownOutside(e);
      }
    });
  });

  $(document).on("keyup.discourse-widget", (e) => {
    nodeCallback(e.target, KEY_UP_ATTRIBUTE_NAME, (w) => w.keyUp(e));
  });

  $(document).on("keydown.discourse-widget", (e) => {
    nodeCallback(e.target, KEY_DOWN_ATTRIBUTE_NAME, (w) => w.keyDown(e));
  });

  $(document).on("input.discourse-widget", (e) => {
    nodeCallback(e.target, INPUT_ATTRIBUTE_NAME, (w) => w.input(e), {
      rerender: false,
    });
  });

  $(document).on("change.discourse-widget", (e) => {
    nodeCallback(e.target, CHANGE_ATTRIBUTE_NAME, (w) => w.change(e), {
      rerender: false,
    });
  });

  $(document).on("touchend.discourse-widget", (e) => {
    nodeCallback(e.target, TOUCH_END_ATTRIBUTE_NAME, (w) => w.touchEnd(e), {
      rerender: false,
    });
  });

  $(document).on("mousedown.discourse-widget", (e) => {
    nodeCallback(e.target, MOUSE_DOWN_ATTRIBUTE_NAME, (w) => {
      w.mouseDown(e);
    });
  });

  $(document).on("mouseup.discourse-widget", (e) => {
    nodeCallback(e.target, MOUSE_UP_ATTRIBUTE_NAME, (w) => w.mouseUp(e));
  });

  $(document).on("mousemove.discourse-widget", (e) => {
    nodeCallback(e.target, MOUSE_MOVE_ATTRIBUTE_NAME, (w) => w.mouseMove(e));
  });

  _watchingDocument = true;
};
