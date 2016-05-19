/*eslint no-loop-func:0*/

const CLICK_ATTRIBUTE_NAME         = '_discourse_click_widget';
const CLICK_OUTSIDE_ATTRIBUTE_NAME = '_discourse_click_outside_widget';
const KEY_UP_ATTRIBUTE_NAME        = '_discourse_key_up_widget';
const DRAG_ATTRIBUTE_NAME          = '_discourse_drag_widget';

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
export const WidgetClickOutsideHook = buildHook(CLICK_OUTSIDE_ATTRIBUTE_NAME, 'data-click-outside');
export const WidgetKeyUpHook = buildHook(KEY_UP_ATTRIBUTE_NAME);
export const WidgetDragHook = buildHook(DRAG_ATTRIBUTE_NAME);


function nodeCallback(node, attrName, cb) {
  const widget = findWidget(node, attrName);
  if (widget) {
    widget.rerenderResult(() => cb(widget));
  }
}

function findWidget(node, attrName) {
  while (node) {
    const widget = node[attrName];
    if (widget) { return widget; }
    node = node.parentNode;
  }
}

let _watchingDocument = false;
let _dragging;

const DRAG_NAME       = "mousemove.discourse-widget-drag";
const DRAG_NAME_TOUCH = "touchmove.discourse-widget-drag";

function cancelDrag() {
  $('body').removeClass('widget-dragging');
  $(document).off(DRAG_NAME).off(DRAG_NAME_TOUCH);

  if (_dragging) {
    if (_dragging.dragEnd) { _dragging.dragEnd(); }
    _dragging = null;
  }
}

WidgetClickHook.setupDocumentCallback = function() {
  if (_watchingDocument) { return; }

  $(document).on('mousedown.discource-widget-drag, touchstart.discourse-widget-drag', e => {
    cancelDrag();
    const widget = findWidget(e.target, DRAG_ATTRIBUTE_NAME);
    if (widget) {
      e.preventDefault();
      e.stopPropagation();
      _dragging = widget;
      $('body').addClass('widget-dragging');
      $(document).on(DRAG_NAME, dragE => widget.drag(dragE));
      $(document).on(DRAG_NAME_TOUCH, dragE => {
        const tt = dragE.originalEvent.targetTouches[0];
        if (tt) {
          widget.drag(tt);
        }
      });
    }
  });

  $(document).on('mouseup.discourse-widget-drag, touchend.discourse-widget-drag', () => cancelDrag());

  $(document).on('click.discourse-widget', e => {
    nodeCallback(e.target, CLICK_ATTRIBUTE_NAME, w => w.click(e));

    let node = e.target;
    const $outside = $('[data-click-outside]');
    $outside.each((i, outNode) => {
      if (outNode.contains(node)) { return; }
      const widget = outNode[CLICK_OUTSIDE_ATTRIBUTE_NAME];
      if (widget) {
        widget.clickOutside(e);
      }
    });
  });

  $(document).on('keyup.discourse-widget', e => {
    nodeCallback(e.target, KEY_UP_ATTRIBUTE_NAME, w => w.keyUp(e));
  });

  _watchingDocument = true;
};
