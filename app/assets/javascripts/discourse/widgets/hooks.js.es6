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

function buildHook(attributeName, setAttr) {
  return class {
    constructor(widget) {
      this.widget = widget;
    }

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
export const WidgetDragHook = buildHook(DRAG_ATTRIBUTE_NAME);
export const WidgetInputHook = buildHook(INPUT_ATTRIBUTE_NAME);
export const WidgetChangeHook = buildHook(CHANGE_ATTRIBUTE_NAME);
export const WidgetMouseUpHook = buildHook(MOUSE_UP_ATTRIBUTE_NAME);
export const WidgetMouseDownHook = buildHook(MOUSE_DOWN_ATTRIBUTE_NAME);
export const WidgetMouseMoveHook = buildHook(MOUSE_MOVE_ATTRIBUTE_NAME);

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
let _dragging;

const DRAG_NAME = "mousemove.discourse-widget-drag";

function cancelDrag(e) {
  $("body").removeClass("widget-dragging");
  $(document).off(DRAG_NAME);

  // We leave the touchmove event cause touch needs it always bound on iOS

  if (_dragging) {
    if (_dragging.dragEnd) {
      _dragging.dragEnd(e);
    }
    _dragging = null;
  }
}

WidgetClickHook.setupDocumentCallback = function() {
  if (_watchingDocument) {
    return;
  }

  let widget;
  let onDrag = dragE => {
    const tt = dragE.targetTouches[0];
    if (tt && widget) {
      dragE.preventDefault();
      dragE.stopPropagation();
      widget.drag(tt);
    }
  };

  document.addEventListener("touchmove", onDrag, {
    passive: false,
    capture: true
  });

  $(document).on(
    "mousedown.discource-widget-drag, touchstart.discourse-widget-drag",
    e => {
      cancelDrag(e);
      widget = findWidget(e.target, DRAG_ATTRIBUTE_NAME);
      if (widget) {
        e.preventDefault();
        e.stopPropagation();
        _dragging = widget;
        $("body").addClass("widget-dragging");
        $(document).on(DRAG_NAME, dragE => {
          if (widget) {
            widget.drag(dragE);
          }
        });
      }
    }
  );

  $(document).on(
    "mouseup.discourse-widget-drag, touchend.discourse-widget-drag",
    e => {
      widget = null;
      cancelDrag(e);
    }
  );

  $(document).on("dblclick.discourse-widget", e => {
    nodeCallback(e.target, DOUBLE_CLICK_ATTRIBUTE_NAME, w => w.doubleClick(e));
  });

  $(document).on("click.discourse-widget", e => {
    nodeCallback(e.target, CLICK_ATTRIBUTE_NAME, w => w.click(e));

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

  $(document).on("mousedown.discourse-widget", e => {
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

  $(document).on("keyup.discourse-widget", e => {
    nodeCallback(e.target, KEY_UP_ATTRIBUTE_NAME, w => w.keyUp(e));
  });

  $(document).on("keydown.discourse-widget", e => {
    nodeCallback(e.target, KEY_DOWN_ATTRIBUTE_NAME, w => w.keyDown(e));
  });

  $(document).on("input.discourse-widget", e => {
    nodeCallback(e.target, INPUT_ATTRIBUTE_NAME, w => w.input(e), {
      rerender: false
    });
  });

  $(document).on("change.discourse-widget", e => {
    nodeCallback(e.target, CHANGE_ATTRIBUTE_NAME, w => w.change(e), {
      rerender: false
    });
  });

  $(document).on("mousedown.discourse-widget", e => {
    nodeCallback(e.target, MOUSE_DOWN_ATTRIBUTE_NAME, w => {
      w.mouseDown(e);
    });
  });

  $(document).on("mouseup.discourse-widget", e => {
    nodeCallback(e.target, MOUSE_UP_ATTRIBUTE_NAME, w => w.mouseUp(e));
  });

  $(document).on("mousemove.discourse-widget", e => {
    nodeCallback(e.target, MOUSE_MOVE_ATTRIBUTE_NAME, w => w.mouseMove(e));
  });

  _watchingDocument = true;
};
