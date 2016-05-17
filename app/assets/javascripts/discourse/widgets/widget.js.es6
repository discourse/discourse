import { WidgetClickHook, WidgetClickOutsideHook, WidgetKeyUpHook, WidgetDragHook } from 'discourse/widgets/hooks';
import { h } from 'virtual-dom';
import DecoratorHelper from 'discourse/widgets/decorator-helper';

function emptyContent() { }

const _registry = {};
let _dirty = {};

export function keyDirty(key, options) {
  _dirty[key] = options || {};
}

export function renderedKey(key) {
  delete _dirty[key];
}

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

const _customSettings = {};
export function changeSetting(widgetName, settingName, newValue) {
  _customSettings[widgetName] = _customSettings[widgetName] || {};
  _customSettings[widgetName][settingName] = newValue;
}

function drawWidget(builder, attrs, state) {
  const properties = {};

  if (this.buildClasses) {
    let classes = this.buildClasses(attrs, state) || [];
    if (!Array.isArray(classes)) { classes = [classes]; }

    const customClasses = applyDecorators(this, 'classNames', attrs, state);
    if (customClasses && customClasses.length) {
      classes = classes.concat(customClasses);
    }

    if (classes.length) {
      properties.className = classes.join(' ');
    }
  }
  if (this.buildId) {
    properties.id = this.buildId(attrs);
  }

  if (this.buildAttributes) {
    properties.attributes = this.buildAttributes(attrs);
  }

  if (this.keyUp) {
    properties['widget-key-up'] = new WidgetKeyUpHook(this);
  }

  if (this.clickOutside) {
    properties['widget-click-outside'] = new WidgetClickOutsideHook(this);
  }
  if (this.click) {
    properties['widget-click'] = new WidgetClickHook(this);
  }
  if (this.drag) {
    properties['widget-drag'] = new WidgetDragHook(this);
  }

  const attributes = properties['attributes'] || {};
  properties.attributes = attributes;

  if (this.title) {
    if (typeof this.title === 'function') {
      attributes.title = this.title(attrs, state);
    } else {
      attributes.title = I18n.t(this.title);
    }
  }

  let contents = this.html(attrs, state);
  if (this.name) {
    const beforeContents = applyDecorators(this, 'before', attrs, state) || [];
    const afterContents = applyDecorators(this, 'after', attrs, state) || [];
    contents = beforeContents.concat(contents).concat(afterContents);
  }

  return h(this.tagName || 'div', properties, contents);
}

export function createWidget(name, opts) {
  const result = class CustomWidget extends Widget {};

  if (name) {
    _registry[name] = result;
  }

  opts.name = name;
  opts.html = opts.html || emptyContent;
  opts.draw = drawWidget;

  Object.keys(opts).forEach(k => result.prototype[k] = opts[k]);
  return result;
}

export default class Widget {
  constructor(attrs, container, opts) {
    opts = opts || {};
    this.attrs = attrs || {};
    this.mergeState = opts.state;
    this.container = container;
    this.model = opts.model;

    this.key = this.buildKey ? this.buildKey(attrs) : null;

    // Helps debug widgets
    if (Ember.testing) {
      const ds = this.defaultState(attrs);
      if (typeof ds !== "object") {
        Ember.warn(`defaultState must return an object`);
      } else if (Object.keys(ds).length > 0 && !this.key) {
        Ember.warn(`you need a key when using state ${this.name}`);
      }
    }

    this.site = container.lookup('site:main');
    this.siteSettings = container.lookup('site-settings:main');
    this.currentUser = container.lookup('current-user:main');
    this.capabilities = container.lookup('capabilities:main');
    this.store = container.lookup('store:main');
    this.appEvents = container.lookup('app-events:main');
    this.keyValueStore = container.lookup('key-value-store:main');

    if (this.name) {
      const custom = _customSettings[this.name];
      if (custom) {
        Object.keys(custom).forEach(k => this.settings[k] = custom[k]);
      }
    }
  }

  defaultState() {
    return {};
  }

  destroy() {
    console.log('destroy called');
  }

  render(prev) {
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
      const dirtyOpts = _dirty[prev.key] || {};
      if (prev.shadowTree) {
        this.shadowTree = true;
        if (!dirtyOpts && !_dirty['*']) {
          return prev.vnode;
        }
      }
      renderedKey(prev.key);

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
    const widget = this._findAncestorWithProperty('_emberView');
    if (widget) {
      return widget._emberView;
    }
  }

  attach(widgetName, attrs, opts) {
    let WidgetClass = _registry[widgetName];

    if (!WidgetClass) {
      if (!this.container) {
        console.error("couldn't find container");
        return;
      }
      WidgetClass = this.container.lookupFactory(`widget:${widgetName}`);
    }

    if (WidgetClass) {
      const result = new WidgetClass(attrs, this.container, opts);
      result.parentWidget = this;
      return result;
    } else {
      throw `Couldn't find ${widgetName} factory`;
    }
  }

  scheduleRerender() {
    let widget = this;
    while (widget) {
      if (widget.shadowTree) {
        keyDirty(widget.key);
      }

      const emberView = widget._emberView;
      if (emberView) {
        return emberView.queueRerender();
      }
      widget = widget.parentWidget;
    }
  }

  _sendComponentAction(name, param) {
    const view = this._findAncestorWithProperty('_emberView');

    let promise;
    if (view) {
      // Peek into ember internals to allow us to return promises from actions
      const ev = view._emberView;
      const target = ev.get('targetObject');

      const actionName = ev.get(name);
      if (!actionName) {
        Ember.warn(`${name} not found`);
        return;
      }

      if (target) {
        // TODO: Use ember closure actions
        const actions = target._actions || target.actionHooks || {};
        const method = actions[actionName];
        if (method) {
          promise = method.call(target, param);
          if (!promise || !promise.then) {
            promise = Ember.RSVP.resolve(promise);
          }
        } else {
          return ev.sendAction(name, param);
        }
      }
    }

    return this.rerenderResult(() => promise);
  }

  findAncestorModel() {
    const modelWidget = this._findAncestorWithProperty('model');
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

  sendWidgetEvent(name) {
    const methodName = `${name}Event`;
    return this.rerenderResult(() => {
      const widget = this._findAncestorWithProperty(methodName);
      if (widget) {
        return widget[methodName]();
      }
    });
  }

  sendWidgetAction(name, param) {
    return this.rerenderResult(() => {
      const widget = this._findAncestorWithProperty(name);
      if (widget) {
        return widget[name](param);
      }

      return this._sendComponentAction(name, param || this.findAncestorModel());
    });
  }
}

Widget.prototype.type = 'Thunk';
