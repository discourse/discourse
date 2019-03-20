export default class ComponentConnector {
  constructor(widget, componentName, opts, trackedProperties) {
    this.widget = widget;
    this.opts = opts;
    this.componentName = componentName;
    this.trackedProperties = trackedProperties || [];
  }

  init() {
    const $elem = $(
      '<div style="display: inline-flex;" class="widget-component-connector"></div>'
    );
    const elem = $elem[0];
    const { opts, widget, componentName } = this;

    Ember.run.next(() => {
      const mounted = widget._findView();

      const view = widget.register
        .lookupFactory(`component:${componentName}`)
        .create(opts);

      // component connector is not triggering didReceiveAttrs
      // so we make sure to compute the component attrs
      if (view.selectKitComponent) {
        view._compute();
      }

      if (Ember.setOwner) {
        Ember.setOwner(view, Ember.getOwner(mounted));
      }

      mounted._connected.push(view);
      view.renderer.appendTo(view, $elem[0]);
    });

    return elem;
  }

  update(prev) {
    // mutated external properties might not correctly update the underlying component
    // in this case we can define trackedProperties, if different from previous
    // state we will re-init the whole component, be careful when using this
    // to not track a property which would be updated too often (on scroll for example)
    let shouldInit = false;
    this.trackedProperties.forEach(prop => {
      if (prev.opts[prop] !== this.opts[prop]) {
        shouldInit = true;
      }
    });

    if (shouldInit) return this.init();

    return null;
  }
}

ComponentConnector.prototype.type = "Widget";
