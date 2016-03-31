import { diff, patch } from 'virtual-dom';
import { WidgetClickHook } from 'discourse/widgets/click-hook';
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
  _afterRender: null,

  init() {
    this._super();
    const name = this.get('widget');

    this._widgetClass = queryRegistry(name) || this.container.lookupFactory(`widget:${name}`);
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
      const t0 = new Date().getTime();

      const opts = { model: this.get('model') };
      const newTree = new this._widgetClass(this.get('args'), this.container, opts);

      newTree._emberView = this;
      const patches = diff(this._tree || this._rootNode, newTree);

      const $body = $(document);
      const prevHeight = $body.height();
      const prevScrollTop = $body.scrollTop();

      this._rootNode = patch(this._rootNode, patches);

      const height = $body.height();
      const scrollTop = $body.scrollTop();

      // This hack is for when swapping out many cloaked views at once
      // when using keyboard navigation. It could suddenly move the
      // scroll
      if (prevHeight === height && scrollTop !== prevScrollTop) {
        $body.scrollTop(prevScrollTop);
      }

      this._tree = newTree;

      if (this._afterRender) {
        this._afterRender();
        this._afterRender = null;
      }

      renderedKey('*');
      if (this.profileWidget) {
        console.log(new Date().getTime() - t0);
      }

    }
  }

});
