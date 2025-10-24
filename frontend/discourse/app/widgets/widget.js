import { get } from "@ember/object";
import { getOwner, setOwner } from "@ember/owner";
import { camelize } from "@ember/string";
import { Promise } from "rsvp";
import { h } from "virtual-dom";
import deprecated, { isDeprecationSilenced } from "discourse/lib/deprecated";
import { isProduction } from "discourse/lib/environment";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { deepMerge } from "discourse/lib/object";
import { consolePrefix } from "discourse/lib/source-identifier";
import DecoratorHelper from "discourse/widgets/decorator-helper";
import {
  WidgetChangeHook,
  WidgetClickHook,
  WidgetClickOutsideHook,
  WidgetDoubleClickHook,
  WidgetDragHook,
  WidgetInputHook,
  WidgetKeyDownHook,
  WidgetKeyUpHook,
  WidgetMouseDownHook,
  WidgetMouseDownOutsideHook,
  WidgetMouseMoveHook,
  WidgetMouseOutHook,
  WidgetMouseOverHook,
  WidgetMouseUpHook,
  WidgetPointerOutHook,
  WidgetPointerOverHook,
  WidgetTouchEndHook,
  WidgetTouchMoveHook,
  WidgetTouchStartHook,
} from "discourse/widgets/hooks";
import { i18n } from "discourse-i18n";

export const WIDGET_DEPRECATION_OPTIONS = {
  since: "v3.5.0.beta8-dev",
  id: "discourse.widgets-end-of-life",
  url: "https://meta.discourse.org/t/375332/1",
};

export const POST_STREAM_DEPRECATION_OPTIONS = {
  since: "v3.5.0.beta1-dev",
  id: "discourse.post-stream-widget-overrides",
  url: "https://meta.discourse.org/t/372063/1",
};

export function warnWidgetsDeprecation(message, dontSkipCore = false) {
  if (
    (dontSkipCore || consolePrefix()) &&
    !isDeprecationSilenced(POST_STREAM_DEPRECATION_OPTIONS.id)
  ) {
    deprecated(message, WIDGET_DEPRECATION_OPTIONS);
  }
}

const _registry = {};

export function queryRegistry(name) {
  return _registry[name];
}

export function deleteFromRegistry(name) {
  return delete _registry[name];
}

const _decorators = {};

export function decorateWidget(decorateIdentifier, cb) {
  const widgetName = decorateIdentifier.split(":")[0];
  if (!_registry[widgetName]) {
    // eslint-disable-next-line no-console
    console.error(
      consolePrefix(),
      `decorateWidget: Could not find widget '${widgetName}' in registry`
    );
  }
  _decorators[decorateIdentifier] ??= [];
  _decorators[decorateIdentifier].push(cb);
}

export function traverseCustomWidgets(tree, callback) {
  if (!tree) {
    return;
  }

  if (tree.__type === "CustomWidget") {
    callback(tree);
  }

  (tree.children || (tree.vnode ? tree.vnode.children : [])).forEach((node) => {
    traverseCustomWidgets(node, callback);
  });
}

export function applyDecorators(widget, type, attrs, state) {
  const decorators = _decorators[`${widget.name}:${type}`] || [];

  if (decorators.length) {
    const helper = new DecoratorHelper(widget, attrs, state);
    return decorators.map((d) => d(helper));
  }

  return [];
}

export function resetDecorators() {
  Object.keys(_decorators).forEach((key) => delete _decorators[key]);
}

const _customSettings = {};

export function changeSetting(widgetName, settingName, newValue) {
  _customSettings[widgetName] = _customSettings[widgetName] || {};
  _customSettings[widgetName][settingName] = newValue;
}

export function createWidgetFrom(base, name, opts) {
  const result = class CustomWidget extends base {};

  // todo this shouldn't been needed anymore once we don't transpile for IE anymore
  // see: https://discuss.emberjs.com/t/constructor-name-behaves-differently-in-dev-and-prod-builds-for-models-defined-with-the-es6-class-syntax/15572/6
  // once done, we can just check on constructor.name
  result.prototype.__type = "CustomWidget";

  if (name) {
    _registry[name] = result;
  }

  opts.name = name;

  if (opts.template) {
    opts.html = opts.template;
  }

  Object.keys(opts).forEach((k) => (result.prototype[k] = opts[k]));
  return result;
}

export function createWidget(name, opts) {
  if (
    getOwnerWithFallback(this)?.lookup(`service:site-settings`)
      ?.deactivate_widgets_rendering
  ) {
    warnWidgetsDeprecation(
      `Widgets are deactivated. Your site may not work properly. Affected widget: ${name}.`
    );
  } else {
    warnWidgetsDeprecation(
      `Using \`api.createWidget\` is deprecated and will soon stop working. Use Glimmer components instead. Affected widget: ${name}.`
    );
  }

  return createWidgetFrom(Widget, name, opts);
}

export function reopenWidget(name, opts) {
  let existing = _registry[name];
  if (!existing) {
    // eslint-disable-next-line no-console
    console.error(
      consolePrefix(),
      `reopenWidget: Could not find widget ${name} in registry`
    );
    return;
  }

  if (opts.template) {
    opts.html = opts.template;
  }

  Object.keys(opts).forEach((k) => {
    let old = existing.prototype[k];

    if (old instanceof Function) {
      // Add support for `this._super()` to reopened widgets if the prototype exists in the
      // base object
      existing.prototype[k] = function (...args) {
        let ctx = Object.create(this);
        ctx._super = (...superArgs) => old.apply(this, superArgs);
        return opts[k].apply(ctx, args);
      };
    } else {
      existing.prototype[k] = opts[k];
    }
  });
  return existing;
}

export default class Widget {
  constructor(attrs, register, opts) {
    opts = opts || {};
    this.attrs = attrs || {};
    this.mergeState = opts.state;
    this.model = opts.model;
    this.register = register;
    this.dirtyKeys = opts.dirtyKeys;

    register.deprecateContainer(this);
    setOwner(this, getOwner(register));

    this.key = this.buildKey ? this.buildKey(attrs) : null;
    this.site = register.lookup("service:site");
    this.siteSettings = register.lookup("service:site-settings");
    this.currentUser = register.lookup("service:current-user");
    this.capabilities = register.lookup("service:capabilities");
    this.store = register.lookup("service:store");
    this.appEvents = register.lookup("service:app-events");
    this.keyValueStore = register.lookup("service:key-value-store");

    // We can inject services into widgets by passing a `services` parameter on creation
    (this.services || []).forEach((s) => {
      this[camelize(s)] = register.lookup(`service:${s}`);
    });

    this.init(this.attrs);

    if (this.name) {
      const custom = _customSettings[this.name];
      if (custom) {
        Object.keys(custom).forEach((k) => (this.settings[k] = custom[k]));
      }
    }
  }

  init() {}

  transform() {
    return {};
  }

  defaultState() {
    return {};
  }

  destroy() {}

  get(propertyPath) {
    return get(this, propertyPath);
  }

  render(prev) {
    const { dirtyKeys } = this;

    if (prev && prev.key && prev.key === this.key) {
      this.state = prev.state;
    } else {
      // Helps debug widgets
      this.state = this.defaultState(this.attrs, this.state);
      if (!isProduction()) {
        if (typeof this.state !== "object") {
          throw new Error(`defaultState must return an object`);
        } else if (Object.keys(this.state).length > 0 && !this.key) {
          throw new Error(`you need a key when using state in ${this.name}`);
        }
      }
    }

    // Sometimes we pass state down from the parent
    if (this.mergeState) {
      this.state = deepMerge(this.state, this.mergeState);
    }

    if (prev) {
      const dirtyOpts = dirtyKeys.optionsFor(prev.key);

      if (prev.shadowTree) {
        this.shadowTree = true;
        if (!dirtyOpts.dirty && !dirtyKeys.allDirty()) {
          return prev.vnode;
        }
      }
      if (prev.key) {
        dirtyKeys.renderedKey(prev.key);
      }

      const refreshAction = dirtyOpts.onRefresh;
      if (refreshAction) {
        this.sendWidgetAction(refreshAction, dirtyOpts.refreshArg);
      }
    }

    return this.draw(h, this.attrs, this.state);
  }

  _findAncestorWithProperty(property) {
    let widget = this;
    while (widget) {
      const value = widget[property];
      if (value) {
        return widget;
      }
      widget = widget.parentWidget;
    }
  }

  _findView() {
    const widget = this._findAncestorWithProperty("_emberView");
    if (widget) {
      return widget._emberView;
    }
  }

  lookupWidgetClass(widgetName) {
    let WidgetClass = _registry[widgetName];
    if (WidgetClass) {
      return WidgetClass;
    }

    if (!this.register) {
      // eslint-disable-next-line no-console
      console.error("couldn't find register");
      return null;
    }

    WidgetClass = this.register.lookupFactory(`widget:${widgetName}`);
    if (WidgetClass && WidgetClass.class) {
      return WidgetClass.class;
    }

    return null;
  }

  attach(widgetName, attrs, opts, otherOpts = {}) {
    let WidgetClass = this.lookupWidgetClass(widgetName);

    if (!WidgetClass && otherOpts.fallbackWidgetName) {
      WidgetClass = this.lookupWidgetClass(otherOpts.fallbackWidgetName);
    }

    if (WidgetClass) {
      const result = new WidgetClass(attrs, this.register, opts);
      result.parentWidget = this;
      result.dirtyKeys = this.dirtyKeys;

      if (otherOpts.tagName) {
        result.tagName = otherOpts.tagName;
      }

      return result;
    } else {
      throw new Error(
        `Couldn't find ${widgetName} or fallback ${otherOpts.fallbackWidgetName}`
      );
    }
  }

  didRenderWidget() {}

  willRerenderWidget() {}

  scheduleRerender() {
    let widget = this;
    while (widget) {
      if (widget.shadowTree) {
        this.dirtyKeys.keyDirty(widget.key);
      }

      const rerenderable = widget._rerenderable;
      if (rerenderable) {
        return rerenderable.queueRerender();
      }

      widget = widget.parentWidget;
    }
  }

  _sendComponentAction(name, param) {
    let promise;

    const view = this._findView();
    if (view) {
      let method;

      if (typeof name === "function") {
        method = name;
      } else {
        method = view.get(name);
        if (!method) {
          // eslint-disable-next-line no-console
          console.warn(`${name} not found`);
          return;
        }
      }

      if (typeof method === "string") {
        view[method](param);
        promise = Promise.resolve();
      } else {
        const target = view.get("target") || view;
        promise = method.call(target, param);
        if (!promise || !promise.then) {
          promise = Promise.resolve(promise);
        }
      }
    }

    return this.rerenderResult(() => promise);
  }

  findAncestorModel() {
    const modelWidget = this._findAncestorWithProperty("model");
    if (modelWidget) {
      return modelWidget.model;
    }
  }

  rerenderResult(fn) {
    this.scheduleRerender();
    const result = fn();
    // re-render after any promises complete, too!
    if (result && result.then) {
      return result.then(() => this.scheduleRerender());
    }
    return result;
  }

  sendWidgetEvent(name, attrs) {
    const methodName = `${name}Event`;
    return this.rerenderResult(() => {
      const widget = this._findAncestorWithProperty(methodName);
      if (widget) {
        return widget[methodName](attrs);
      }
    });
  }

  callWidgetFunction(name, param) {
    const widget = this._findAncestorWithProperty(name);
    if (widget) {
      return widget[name].call(widget, param);
    }
  }

  sendWidgetAction(name, param) {
    return this.rerenderResult(() => {
      const widget = this._findAncestorWithProperty(name);
      if (widget) {
        return widget[name].call(widget, param);
      }

      return this._sendComponentAction(name, param || this.findAncestorModel());
    });
  }

  html() {}

  draw(builder, attrs, state) {
    const properties = {};

    if (this.buildClasses) {
      let classes = this.buildClasses(attrs, state) || [];
      if (!Array.isArray(classes)) {
        classes = [classes];
      }

      const customClasses = applyDecorators(this, "classNames", attrs, state);
      if (customClasses && customClasses.length) {
        classes = classes.concat(customClasses);
      }

      if (classes.length) {
        properties.className = classes.join(" ");
      }
    }
    if (this.buildId) {
      properties.id = this.buildId(attrs);
    }

    if (this.buildAttributes) {
      properties.attributes = this.buildAttributes(attrs);
    }

    if (this.keyUp) {
      properties["widget-key-up"] = new WidgetKeyUpHook(this);
    }

    if (this.keyDown) {
      properties["widget-key-down"] = new WidgetKeyDownHook(this);
    }

    if (this.clickOutside) {
      properties["widget-click-outside"] = new WidgetClickOutsideHook(this);
    }

    if (this.click) {
      properties["widget-click"] = new WidgetClickHook(this);
    }

    if (this.doubleClick) {
      properties["widget-double-click"] = new WidgetDoubleClickHook(this);
    }

    if (this.mouseDownOutside) {
      properties["widget-mouse-down-outside"] = new WidgetMouseDownOutsideHook(
        this
      );
    }

    if (this.drag) {
      properties["widget-drag"] = new WidgetDragHook(this);
    }

    if (this.input) {
      properties["widget-input"] = new WidgetInputHook(this);
    }

    if (this.change) {
      properties["widget-change"] = new WidgetChangeHook(this);
    }

    if (this.mouseDown) {
      properties["widget-mouse-down"] = new WidgetMouseDownHook(this);
    }

    if (this.mouseUp) {
      properties["widget-mouse-up"] = new WidgetMouseUpHook(this);
    }

    if (this.mouseMove) {
      properties["widget-mouse-move"] = new WidgetMouseMoveHook(this);
    }

    if (this.mouseOver) {
      properties["widget-mouse-over"] = new WidgetMouseOverHook(this);
    }

    if (this.pointerOver) {
      properties["widget-pointer-over"] = new WidgetPointerOverHook(this);
    }

    if (this.pointerOut) {
      properties["widget-pointer-out"] = new WidgetPointerOutHook(this);
    }

    if (this.mouseOut) {
      properties["widget-mouse-out"] = new WidgetMouseOutHook(this);
    }

    if (this.touchStart) {
      properties["widget-touch-start"] = new WidgetTouchStartHook(this);
    }

    if (this.touchEnd) {
      properties["widget-touch-end"] = new WidgetTouchEndHook(this);
    }

    if (this.touchMove) {
      properties["widget-touch-move"] = new WidgetTouchMoveHook(this);
    }

    const attributes = properties["attributes"] || {};
    properties.attributes = attributes;

    if (this.title) {
      if (typeof this.title === "function") {
        attributes.title = this.title(attrs, state);
      } else {
        attributes.title = i18n(this.title);
      }
    }

    this.transformed = this.transform(this.attrs, this.state);

    let contents = this.html(attrs, state);
    if (this.name) {
      const beforeContents =
        applyDecorators(this, "before", attrs, state) || [];
      const afterContents = applyDecorators(this, "after", attrs, state) || [];
      contents = beforeContents.concat(contents).concat(afterContents);
    }

    return h(this.tagName || "div", properties, contents);
  }
}

Widget.prototype.type = "Thunk";
