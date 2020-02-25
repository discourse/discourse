import { cancel } from "@ember/runloop";
import { scheduleOnce } from "@ember/runloop";
import { diff, patch } from "virtual-dom";
import { queryRegistry } from "discourse/widgets/widget";
import DirtyKeys from "discourse/lib/dirty-keys";
import ENV from "discourse-common/config/environment";

export default class WidgetGlue {
  constructor(name, register, attrs) {
    this._tree = null;
    this._rootNode = null;
    this.register = register;
    this.attrs = attrs;
    this._timeout = null;
    this.dirtyKeys = new DirtyKeys(name);

    this._widgetClass =
      queryRegistry(name) || this.register.lookupFactory(`widget:${name}`);
    if (!this._widgetClass) {
      // eslint-disable-next-line no-console
      console.error(`Error: Could not find widget: ${name}`);
    }
  }

  appendTo(elem) {
    this._rootNode = elem;
    this.queueRerender();
  }

  queueRerender() {
    this._timeout = scheduleOnce("render", this, this.rerenderWidget);
  }

  rerenderWidget() {
    cancel(this._timeout);

    // in test mode return early if store cannot be found
    if (ENV.environment === "test") {
      try {
        this.register.lookup("service:store");
      } catch (e) {
        return;
      }
    }

    const newTree = new this._widgetClass(this.attrs, this.register, {
      dirtyKeys: this.dirtyKeys
    });
    const patches = diff(this._tree || this._rootNode, newTree);

    newTree._rerenderable = this;
    this._rootNode = patch(this._rootNode, patches);
    this._tree = newTree;
  }

  cleanUp() {
    const widgets = [];
    const findWidgets = widget => {
      widget.vnode.children.forEach(child => {
        if (child.constructor.name === "CustomWidget") {
          widgets.push(child);
          findWidgets(child, widgets);
        }
      });
    };
    findWidgets(this._tree, widgets);
    widgets.reverse().forEach(widget => widget.destroy());

    cancel(this._timeout);
  }
}
