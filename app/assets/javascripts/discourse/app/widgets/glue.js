import { cancel, scheduleOnce } from "@ember/runloop";
import { diff, patch } from "virtual-dom";
import DirtyKeys from "discourse/lib/dirty-keys";
import { queryRegistry, traverseCustomWidgets } from "discourse/widgets/widget";
import { isTesting } from "discourse-common/config/environment";

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
    if (isTesting()) {
      try {
        this.register.lookup("service:store");
      } catch {
        return;
      }
    }

    const newTree = new this._widgetClass(this.attrs, this.register, {
      dirtyKeys: this.dirtyKeys,
    });
    const patches = diff(this._tree || this._rootNode, newTree);

    traverseCustomWidgets(this._tree, (w) => w.willRerenderWidget());

    newTree._rerenderable = this;
    this._rootNode = patch(this._rootNode, patches);
    this._tree = newTree;

    traverseCustomWidgets(newTree, (w) => w.didRenderWidget());
  }

  cleanUp() {
    traverseCustomWidgets(this._tree, (w) => w.destroy());

    cancel(this._timeout);

    this._rootNode = patch(this._rootNode, diff(this._tree, null));
    this._tree = null;
  }
}
