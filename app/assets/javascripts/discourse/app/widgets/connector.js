import { getOwner } from "@ember/owner";
import { next } from "@ember/runloop";

export default class Connector {
  constructor(widget, opts) {
    this.widget = widget;
    this.opts = opts;
  }

  init() {
    const elem = document.createElement("div");
    elem.classList.add("widget-connector");

    const { opts, widget } = this;
    next(() => {
      const mounted = widget._findView();

      if (opts.component) {
        const component = getOwner(mounted)
          .factoryFor("component:connector-container")
          .create({
            layoutName: `components/${opts.component}`,
            model: widget.findAncestorModel(),
          });

        mounted._connected.push(component);
        component.renderer.appendTo(component, elem);
      }
    });

    return elem;
  }

  update() {}
}

Connector.prototype.type = "Widget";
