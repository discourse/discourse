/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { cancel, scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import { camelize } from "@ember/string";
import { diff, patch } from "virtual-dom";
import { removeValueFromArray } from "discourse/lib/array-tools";
import DirtyKeys from "discourse/lib/dirty-keys";
import { getRegister } from "discourse/lib/get-owner";
import LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import { WidgetClickHook } from "discourse/widgets/hooks";
import {
  queryRegistry,
  traverseCustomWidgets,
  warnWidgetsDeprecation,
} from "discourse/widgets/widget";

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
  @service siteSettings;

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

    if (this.isDeactivated) {
      warnWidgetsDeprecation(
        `Widgets are deactivated and won't be rendered. Your site may not work properly. Affected widget: ${name}.`,
        true
      );
      return;
    } else {
      warnWidgetsDeprecation(
        `The \`MountWidget\` component is deprecated and will soon stop working. Use Glimmer components instead. Affected widget: ${name}.`
      );
    }

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
    this._childComponents = LegacyArrayLikeObject.create({ content: [] });
    this._dispatched = [];
    this.dirtyKeys = new DirtyKeys(name);
  }

  get isDeactivated() {
    return this.siteSettings.deactivate_widgets_rendering;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    if (this.isDeactivated) {
      return;
    }

    WidgetClickHook.setupDocumentCallback();

    this._rootNode = document.createElement("div");
    this.element.appendChild(this._rootNode);
    this._timeout = scheduleOnce("render", this, this.rerenderWidget);
  }

  willClearRender() {
    if (this.isDeactivated) {
      return;
    }

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
    if (this.isDeactivated) {
      return;
    }

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
    if (this.isDeactivated) {
      return;
    }

    key = typeof key === "function" ? key(refreshArg) : key;
    const onRefresh = camelize(eventName.replace(/:/, "-"));
    this.dirtyKeys.keyDirty(key, { onRefresh, refreshArg });
    this.queueRerender();
  }

  dispatch(eventName, key) {
    if (this.isDeactivated) {
      return;
    }

    this._childEvents.push(eventName);

    const caller = (refreshArg) =>
      this.eventDispatched(eventName, key, refreshArg);
    this._dispatched.push([eventName, caller]);
    this.appEvents.on(eventName, this, caller);
  }

  queueRerender(callback) {
    if (this.isDeactivated) {
      return;
    }

    if (callback && !this._renderCallback) {
      this._renderCallback = callback;
    }

    scheduleOnce("render", this, this.rerenderWidget);
  }

  buildArgs() {}

  rerenderWidget() {
    if (this.isDeactivated) {
      return;
    }

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
    if (this.isDeactivated) {
      return;
    }

    this._childComponents.content.push(info);
  }

  unmountChildComponent(info) {
    if (this.isDeactivated) {
      return;
    }

    removeValueFromArray(this._childComponents.content, info);
  }

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);
    if (this.isDeactivated) {
      return;
    }

    this.queueRerender();
  }

  <template>
    {{#unless this.isDeactivated}}
      {{#each this._childComponents.content as |info|}}
        {{#in-element info.element insertBefore=null}}
          <info.component
            @data={{info.data}}
            @setWrapperElementAttrs={{info.setWrapperElementAttrs}}
          />
        {{/in-element}}
      {{/each}}
    {{/unless}}
  </template>
}
