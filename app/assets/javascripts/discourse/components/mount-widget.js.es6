import { keyDirty } from 'discourse/widgets/widget';
import { diff, patch } from 'virtual-dom';
import { WidgetClickHook } from 'discourse/widgets/hooks';
import { renderedKey, queryRegistry } from 'discourse/widgets/widget';

const _cleanCallbacks = {};
export function addWidgetCleanCallback(widgetName, fn) {
  _cleanCallbacks[widgetName] = _cleanCallbacks[widgetName] || [];
  _cleanCallbacks[widgetName].push(fn);
}

export default Ember.Component.extend({
  _tree: null,
  _rootNode: null,
  _timeout: null,
  _widgetClass: null,
  _renderCallback: null,
  _childEvents: null,

  init() {
    this._super();
    const name = this.get('widget');

    (this.get('delegated') || []).forEach(m => this.set(m, m));

    this._widgetClass = queryRegistry(name) || this.container.lookupFactory(`widget:${name}`);

    if (!this._widgetClass) {
      console.error(`Error: Could not find widget: ${name}`);
    }

    this._childEvents = [];
    this._connected = [];
  },

  didInsertElement() {
    WidgetClickHook.setupDocumentCallback();

    this._rootNode = document.createElement('div');
    this.element.appendChild(this._rootNode);
    this._timeout = Ember.run.scheduleOnce('render', this, this.rerenderWidget);
  },

  willClearRender() {
    const callbacks = _cleanCallbacks[this.get('widget')];
    if (callbacks) {
      callbacks.forEach(cb => cb());
    }

    this._connected.forEach(v => v.destroy());
    this._connected.length = 0;
  },

  willDestroyElement() {
    this._childEvents.forEach(evt => this.appEvents.off(evt));
    Ember.run.cancel(this._timeout);
  },

  afterRender() {
  },

  beforePatch() {
  },

  afterPatch() {
  },

  eventDispatched(eventName, key, refreshArg) {
    const onRefresh = Ember.String.camelize(eventName.replace(/:/, '-'));
    keyDirty(key, { onRefresh, refreshArg });
    this.queueRerender();
  },

  dispatch(eventName, key) {
    this._childEvents.push(eventName);
    this.appEvents.on(eventName, refreshArg => {
      this.eventDispatched(eventName, key, refreshArg);
    });
  },

  queueRerender(callback) {
    if (callback && !this._renderCallback) {
      this._renderCallback = callback;
    }

    Ember.run.scheduleOnce('render', this, this.rerenderWidget);
  },

  buildArgs() {
  },

  rerenderWidget() {
    Ember.run.cancel(this._timeout);
    if (this._rootNode) {
      if (!this._widgetClass) { return; }

      const t0 = new Date().getTime();
      const args = this.get('args') || this.buildArgs();
      const opts = { model: this.get('model') };
      const newTree = new this._widgetClass(args, this.container, opts);

      newTree._emberView = this;
      const patches = diff(this._tree || this._rootNode, newTree);

      this.beforePatch();
      this._rootNode = patch(this._rootNode, patches);
      this.afterPatch();

      this._tree = newTree;

      if (this._renderCallback) {
        this._renderCallback();
        this._renderCallback = null;
      }
      this.afterRender();

      renderedKey('*');
      if (this.profileWidget) {
        console.log(new Date().getTime() - t0);
      }
    }
  }
});
