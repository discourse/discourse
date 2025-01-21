import ArrayProxy from "@ember/array/proxy";
import Component from "@ember/component";
import { cancel, scheduleOnce } from "@ember/runloop";
import { camelize } from "@ember/string";
import { diff, patch } from "virtual-dom";
import DirtyKeys from "discourse/lib/dirty-keys";
import { getRegister } from "discourse/lib/get-owner";
import { WidgetClickHook } from "discourse/widgets/hooks";
import { queryRegistry, traverseCustomWidgets } from "discourse/widgets/widget";

let _cleanCallbacks = {};

export function addWidgetCleanCallback(widgetName, fn) {
  _cleanCallbacks[widgetName] = _cleanCallbacks[widgetName] || [];
  _cleanCallbacks[widgetName].push(fn);
}

export function removeWidgetCleanCallback(widgetName, fn) {
  const callbacks = _cleanCallbacks[widgetName];
  if (!callbacks) {
    return;
  }

  const index = callbacks.indexOf(fn);
  if (index === -1) {
    return;
  }

  callbacks.splice(index, 1);
}

export function resetWidgetCleanCallbacks() {
  _cleanCallbacks = {};
}

export default class MountWidget extends Component {
  dirtyKeys = null;
  _tree = null;
  _rootNode = null;
  _timeout = null;
  _widgetClass = null;
  _renderCallback = null;
  _childEvents = null;
  _dispatched = null;

  init() {
    super.init(...arguments);
    const name = this.widget;

    if (name === "post-cooked") {
      throw [
        "Cannot use <MountWidget /> with `post-cooked`.",
        "It's a special-case that needs to be wrapped in another widget.",
        "For example:",
        "  createWidget('test-widget', {",
        "    html(attrs) {",
        "      return [",
        "        new PostCooked(attrs, new DecoratorHelper(this), this.currentUser),",
        "      ];",
        "    },",
        "  });",
      ].join("\n");
    }

    this.register = getRegister(this);

    this._widgetClass =
      queryRegistry(name) || this.register.lookupFactory(`widget:${name}`);

    if (this._widgetClass?.class) {
      this._widgetClass = this._widgetClass.class;
    }

    if (!this._widgetClass) {
      // eslint-disable-next-line no-console
      console.error(`Error: Could not find widget: ${name}`);
    }

    this._childEvents = [];
    this._connected = [];
    this._childComponents = ArrayProxy.create({ content: [] });
    this._dispatched = [];
    this.dirtyKeys = new DirtyKeys(name);
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    WidgetClickHook.setupDocumentCallback();

    this._rootNode = document.createElement("div");
    this.element.appendChild(this._rootNode);
    this._timeout = scheduleOnce("render", this, this.rerenderWidget);
  }

  willClearRender() {
    super.willClearRender(...arguments);
    const callbacks = _cleanCallbacks[this.widget];
    if (callbacks) {
      callbacks.forEach((cb) => cb(this._tree));
    }

    this._connected.forEach((v) => v.destroy());
    this._connected.length = 0;

    traverseCustomWidgets(this._tree, (w) => w.destroy());
    this._rootNode = patch(this._rootNode, diff(this._tree, null));
    this._tree = null;
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this._dispatched.forEach((evt) => {
      const [eventName, caller] = evt;
      this.appEvents.off(eventName, this, caller);
    });
    cancel(this._timeout);
  }

  afterRender() {}
  beforePatch() {}
  afterPatch() {}

  eventDispatched(eventName, key, refreshArg) {
    key = typeof key === "function" ? key(refreshArg) : key;
    const onRefresh = camelize(eventName.replace(/:/, "-"));
    this.dirtyKeys.keyDirty(key, { onRefresh, refreshArg });
    this.queueRerender();
  }

  dispatch(eventName, key) {
    this._childEvents.push(eventName);

    const caller = (refreshArg) =>
      this.eventDispatched(eventName, key, refreshArg);
    this._dispatched.push([eventName, caller]);
    this.appEvents.on(eventName, this, caller);
  }

  queueRerender(callback) {
    if (callback && !this._renderCallback) {
      this._renderCallback = callback;
    }

    scheduleOnce("render", this, this.rerenderWidget);
  }

  buildArgs() {}

  rerenderWidget() {
    cancel(this._timeout);

    if (this._rootNode) {
      if (!this._widgetClass) {
        return;
      }

      const t0 = Date.now();
      const args = this.args || this.buildArgs();
      const opts = {
        model: this.model,
        dirtyKeys: this.dirtyKeys,
      };
      const newTree = new this._widgetClass(args, this.register, opts);

      newTree._rerenderable = this;
      newTree._emberView = this;
      const patches = diff(this._tree || this._rootNode, newTree);

      traverseCustomWidgets(this._tree, (w) => w.willRerenderWidget());

      this.beforePatch();
      this._rootNode = patch(this._rootNode, patches);
      this.afterPatch();

      this._tree = newTree;

      traverseCustomWidgets(newTree, (w) => w.didRenderWidget());

      if (this._renderCallback) {
        this._renderCallback();
        this._renderCallback = null;
      }
      this.afterRender();
      this.dirtyKeys.renderedKey("*");

      if (this.profileWidget) {
        // eslint-disable-next-line no-console
        console.log(Date.now() - t0);
      }
    }
  }

  mountChildComponent(info) {
    this._childComponents.pushObject(info);
  }

  unmountChildComponent(info) {
    this._childComponents.removeObject(info);
  }

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);
    this.queueRerender();
  }
}
