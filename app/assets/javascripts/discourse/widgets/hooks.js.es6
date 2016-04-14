/*eslint no-loop-func:0*/

const CLICK_ATTRIBUTE_NAME = '_discourse_click_widget';
const CLICK_OUTSIDE_ATTRIBUTE_NAME = '_discourse_click_outside_widget';
const KEY_UP_ATTRIBUTE_NAME = '_discourse_key_up_widget';

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

function findNode(node, attrName, cb) {
  while (node) {
    const widget = node[attrName];
    if (widget) {
      widget.rerenderResult(() => cb(widget));
      break;
    }
    node = node.parentNode;
  }
}

let _watchingDocument = false;
WidgetClickHook.setupDocumentCallback = function() {
  if (_watchingDocument) { return; }

  $(document).on('click.discourse-widget', e => {
    findNode(e.target, CLICK_ATTRIBUTE_NAME, w => w.click(e));

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
    findNode(e.target, KEY_UP_ATTRIBUTE_NAME, w => w.keyUp(e));
  });

  _watchingDocument = true;
};
