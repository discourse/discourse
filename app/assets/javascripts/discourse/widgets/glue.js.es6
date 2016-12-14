import { diff, patch } from 'virtual-dom';
import { queryRegistry } from 'discourse/widgets/widget';

export default class WidgetGlue {

  constructor(name, register, attrs) {
    this._tree = null;
    this._rootNode = null;
    this.register = register;
    this.attrs = attrs;
    this._timeout = null;

    this._widgetClass = queryRegistry(name) || this.register.lookupFactory(`widget:${name}`);
    if (!this._widgetClass) {
      console.error(`Error: Could not find widget: ${name}`);
    }
  }

  appendTo(elem) {
    this._rootNode = elem;
    this.queueRerender();
  }

  queueRerender() {
    this._timeout = Ember.run.scheduleOnce('render', this, this.rerenderWidget);
  }

  rerenderWidget() {
    Ember.run.cancel(this._timeout);
    const newTree = new this._widgetClass(this.attrs, this.register);
    const patches = diff(this._tree || this._rootNode, newTree);

    newTree._rerenderable = this;
    this._rootNode = patch(this._rootNode, patches);
    this._tree = newTree;
  }

  cleanUp() {
    Ember.run.cancel(this._timeout);
  }
}


