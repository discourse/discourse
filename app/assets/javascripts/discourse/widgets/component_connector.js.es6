export default class ComponentConnector {
  constructor(widget, componentName, opts) {
    this.widget = widget;
    this.opts = opts;
    this.componentName = componentName;
  }

  init() {
    const $elem = $('<div style="display: inline-block;" class="widget-component-connector"></div>');
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

  update() { }
}

ComponentConnector.prototype.type = 'Widget';
