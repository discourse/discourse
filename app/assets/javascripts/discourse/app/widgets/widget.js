import {
  WidgetClickHook,
  WidgetDoubleClickHook,
  WidgetClickOutsideHook,
  WidgetKeyUpHook,
  WidgetKeyDownHook,
  WidgetMouseDownOutsideHook,
  WidgetDragHook,
  WidgetInputHook,
  WidgetChangeHook,
  WidgetMouseUpHook,
  WidgetMouseDownHook,
  WidgetMouseMoveHook
} from "discourse/widgets/hooks";
import { h } from "virtual-dom";
import DecoratorHelper from "discourse/widgets/decorator-helper";
import { Promise } from "rsvp";
import ENV from "discourse-common/config/environment";
import { get } from "@ember/object";

const _registry = {};

export function queryRegistry(name) {
  return _registry[name];
}

const _decorators = {};

export function decorateWidget(widgetName, cb) {
  _decorators[widgetName] = _decorators[widgetName] || [];
  _decorators[widgetName].push(cb);
}

export function applyDecorators(widget, type, attrs, state) {
  const decorators = _decorators[`${widget.name}:${type}`] || [];

  if (decorators.length) {
    const helper = new DecoratorHelper(widget, attrs, state);
    return decorators.map(d => d(helper));
  }

  return [];
}

export function resetDecorators() {
  Object.keys(_decorators).forEach(key => delete _decorators[key]);
}

const _customSettings = {};
export function changeSetting(widgetName, settingName, newValue) {
  _customSettings[widgetName] = _customSettings[widgetName] || {};
  _customSettings[widgetName][settingName] = newValue;
}

export function createWidgetFrom(base, name, opts) {
  const result = class CustomWidget extends base {};

  if (name) {
    _registry[name] = result;
  }

  opts.name = name;

  if (opts.template) {
    opts.html = opts.template;
  }

  Object.keys(opts).forEach(k => (result.prototype[k] = opts[k]));
  return result;
}

export function createWidget(name, opts) {
  return createWidgetFrom(Widget, name, opts);
}

export function reopenWidget(name, opts) {
  let existing = _registry[name];
  if (!existing) {
    // eslint-disable-next-line no-console
    console.error(`Could not find widget ${name} in registry`);
    return;
  }

  if (opts.template) {
    opts.html = opts.template;
  }

  Object.keys(opts).forEach(k => {
    let old = existing.prototype[k];

    if (old instanceof Function) {
      // Add support for `this._super()` to reopened widgets if the prototype exists in the
      // base object
      existing.prototype[k] = function(...args) {
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

    this.key = this.buildKey ? this.buildKey(attrs) : null;
    this.site = register.lookup("site:main");
    this.siteSettings = register.lookup("site-settings:main");
    this.currentUser = register.lookup("current-user:main");
    this.capabilities = register.lookup("capabilities:main");
    this.store = register.lookup("service:store");
    this.appEvents = register.lookup("service:app-events");
    this.keyValueStore = register.lookup("key-value-store:main");

    this.init(this.attrs);

    // Helps debug widgets
    if (Discourse.Environment === "development" || ENV.environment === "test") {
      const ds = this.defaultState(attrs);
      if (typeof ds !== "object") {
        throw new Error(`defaultState must return an object`);
      } else if (Object.keys(ds).length > 0 && !this.key) {
        throw new Error(`you need a key when using state in ${this.name}`);
      }
    }

    if (this.name) {
      const custom = _customSettings[this.name];
      if (custom) {
        Object.keys(custom).forEach(k => (this.settings[k] = custom[k]));
      }
    }
  }

  transform() {
    return {};
  }

  defaultState() {
    return {};
  }

  init() {}

  destroy() {}

  get(propertyPath) {
    return get(this, propertyPath);
  }

  render(prev) {
    const { dirtyKeys } = this;

    if (prev && prev.key && prev.key === this.key) {
      this.state = prev.state;
    } else {
      this.state = this.defaultState(this.attrs, this.state);
    }

    // Sometimes we pass state down from the parent
    if (this.mergeState) {
      this.state = _.merge(this.state, this.mergeState);
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
      return result;
    } else {
      throw new Error(
        `Couldn't find ${widgetName} or fallback ${otherOpts.fallbackWidgetName}`
      );
    }
  }

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
      const method = view.get(name);
      if (!method) {
        // eslint-disable-next-line no-console
        console.warn(`${name} not found`);
        return;
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

    const attributes = properties["attributes"] || {};
    properties.attributes = attributes;

    if (this.title) {
      if (typeof this.title === "function") {
        attributes.title = this.title(attrs, state);
      } else {
        attributes.title = I18n.t(this.title);
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
