export default class Connector {

  constructor(widget, opts) {
    this.widget = widget;
    this.opts = opts;
  }

  init() {
    const $elem = $(`<div class='widget-connector'></div>`);
    const elem = $elem[0];

    const { opts, widget } = this;
    Ember.run.next(() => {

      const mounted = widget._findView();

      let context;
      if (opts.context === 'model') {
        const model = widget.findAncestorModel();
        context = model;
      }

      const view = Ember.View.create({
        container: widget.container,
        templateName: opts.templateName,
        context
      });
      mounted._connected.push(view);

      view.renderer.replaceIn(view, $elem[0]);
    });

    return elem;
  }

  update() { }
}

Connector.prototype.type = 'Widget';
