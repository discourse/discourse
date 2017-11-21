export default class ComponentConnector {
  constructor(widget, componentName, opts, trackedProperties) {
    this.widget = widget;
    this.opts = opts;
    this.componentName = componentName;
    this.trackedProperties = trackedProperties || [];
  }

  init() {
    const $elem = $('<div style="display: inline-flex;" class="widget-component-connector"></div>');
    const elem = $elem[0];
    const { opts, widget, componentName } = this;

    Ember.run.next(() => {
      const mounted = widget._findView();

      const view = widget
        .register
        .lookupFactory(`component:${componentName}`)
        .create(opts);

      if (Ember.setOwner) {
        Ember.setOwner(view, Ember.getOwner(mounted));
      }

      mounted._connected.push(view);
      view.renderer.appendTo(view, $elem[0]);
    });

    return elem;
  }

  update(prev) {
    let shouldInit = false;
    this.trackedProperties.forEach(prop => {
      if (prev.opts[prop] !== this.opts[prop]) {
        shouldInit = true;
      }
    });

    if (shouldInit === true) return this.init();

    return null;
  }
}

ComponentConnector.prototype.type = 'Widget';
