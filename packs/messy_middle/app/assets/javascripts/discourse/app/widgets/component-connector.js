import { getOwner } from "@ember/application";
import { scheduleOnce } from "@ember/runloop";

export default class ComponentConnector {
  constructor(
    widget,
    componentName,
    opts,
    trackedProperties,
    { applyStyle = true } = {}
  ) {
    this.widget = widget;
    this.opts = opts;
    this.componentName = componentName;
    this.trackedProperties = trackedProperties || [];
    this.applyStyle = applyStyle;
    this._component = null;
  }

  init() {
    const elem = document.createElement("div");
    if (this.applyStyle) {
      elem.style.display = "inline-flex";
    }
    elem.className = "widget-component-connector";
    this.elem = elem;
    scheduleOnce("afterRender", this, this.connectComponent);

    return this.elem;
  }

  destroy() {
    this._component?.destroy();
  }

  update(prev) {
    // mutated external properties might not correctly update the underlying component
    // in this case we can define trackedProperties, if different from previous
    // state we will re-init the whole component, be careful when using this
    // to not track a property which would be updated too often (on scroll for example)
    let shouldInit = false;
    this.trackedProperties.forEach((prop) => {
      if (prev.opts[prop] !== this.opts[prop]) {
        shouldInit = true;
      }
    });

    if (shouldInit) {
      return this.init();
    }

    return null;
  }

  connectComponent() {
    const { elem, opts, widget, componentName } = this;

    const mounted = widget._findView();
    const component = getOwner(mounted)
      .factoryFor(`component:${componentName}`)
      .create(opts);

    // component connector is not triggering didReceiveAttrs
    // we force it for selectKit components
    if (component.selectKit) {
      component.didReceiveAttrs();
    }

    mounted._connected.push(component);
    component.renderer.appendTo(component, elem);
    this._component = component;
  }
}

ComponentConnector.prototype.type = "Widget";
