/*eslint no-loop-func:0*/

const CLICK_ATTRIBUTE_NAME = '_discourse_click_widget';
const CLICK_OUTSIDE_ATTRIBUTE_NAME = '_discourse_click_outside_widget';

export class WidgetClickHook {
  constructor(widget) {
    this.widget = widget;
  }

  hook(node) {
    node[CLICK_ATTRIBUTE_NAME] = this.widget;
  }

  unhook(node) {
    node[CLICK_ATTRIBUTE_NAME] = null;
  }
};

export class WidgetClickOutsideHook {
  constructor(widget) {
    this.widget = widget;
  }

  hook(node) {
    node.setAttribute('data-click-outside', true);
    node[CLICK_OUTSIDE_ATTRIBUTE_NAME] = this.widget;
  }

  unhook(node) {
    node.removeAttribute('data-click-outside');
    node[CLICK_OUTSIDE_ATTRIBUTE_NAME] = null;
  }
};

let _watchingDocument = false;
WidgetClickHook.setupDocumentCallback = function() {
  if (_watchingDocument) { return; }

  $(document).on('click.discourse-widget', e => {
    let node = e.target;
    while (node) {
      const widget = node[CLICK_ATTRIBUTE_NAME];
      if (widget) {
        widget.rerenderResult(() => widget.click(e));
        break;
      }
      node = node.parentNode;
    }

    node = e.target;
    const $outside = $('[data-click-outside]');
    $outside.each((i, outNode) => {
      if (outNode.contains(node)) { return; }
      const widget = outNode[CLICK_OUTSIDE_ATTRIBUTE_NAME];
      if (widget) {
        widget.clickOutside(e);
      }
    });
  });


  _watchingDocument = true;
};
