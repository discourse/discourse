import { diff, patch } from 'virtual-dom';
import { WidgetClickHook } from 'discourse/widgets/click-hook';
import { renderedKey } from 'discourse/widgets/widget';

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
  _afterRender: null,

  init() {
    this._super();
    this._widgetClass = this.container.lookupFactory(`widget:${this.get('widget')}`);
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
    Ember.run.cancel(this._timeout);
  },

  queueRerender(callback) {
    if (callback && !this._afterRender) {
      this._afterRender = callback;
    }

    Ember.run.scheduleOnce('render', this, this.rerenderWidget);
  },

  rerenderWidget() {
    Ember.run.cancel(this._timeout);
    if (this._rootNode) {
      const opts = { model: this.get('model') };
      const newTree = new this._widgetClass(this.get('args'), this.container, opts);

      newTree._emberView = this;
      const patches = diff(this._tree || this._rootNode, newTree);
      this._rootNode = patch(this._rootNode, patches);
      this._tree = newTree;

      if (this._afterRender) {
        this._afterRender();
        this._afterRender = null;
      }

      renderedKey('*');
    }
  }

});
