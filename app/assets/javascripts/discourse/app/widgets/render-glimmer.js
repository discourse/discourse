import Component from "@glimmer/component";
import { setComponentTemplate } from "@ember/component";
import { tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";

/*

This class allows you to render arbitrary Glimmer templates inside widgets.
That glimmer template can include Classic and/or Glimmer components.

Example usage:

```
import { hbs } from "ember-cli-htmlbars";

// NOTE: If your file is already importing the `hbs` helper from "discourse/widgets/hbs-compiler"
// you'll need to rename that import to `import widgetHbs from "discourse/widgets/hbs-compiler"`
// before adding the `ember-cli-htmlbars` import.

...

// (inside an existing widget)
html(){
  return [
    new RenderGlimmer(
      this,
      "div.my-wrapper-class",
      hbs`<MyComponent @arg1={{@data.arg1}} />`,
      {
        arg1: "some argument value"
      }
    ),
  ]
}
```

*/

export default class RenderGlimmer {
  /**
   * Create a RenderGlimmer instance
   * @param widget - the widget instance which is rendering this content
   * @param tagName - tagName for the wrapper element (e.g. `div.my-class`)
   * @param template - a glimmer template compiled via ember-cli-htmlbars
   * @param data - will be made available at `@data` in your template
   */
  constructor(widget, tagName, template, data) {
    assert(
      "`template` should be a template compiled via `ember-cli-htmlbars`",
      template.name === "factory"
    );
    this.tagName = tagName;
    this.widget = widget;
    this.template = template;
    this.data = data;
  }

  init() {
    const [type, ...classNames] = this.tagName.split(".");
    this.element = document.createElement(type);
    this.element.classList.add(...classNames);
    this.connectComponent();
    return this.element;
  }

  destroy() {
    if (this._componentInfo) {
      this.widget._findView().unmountChildComponent(this._componentInfo);
    }
  }

  update(prev) {
    this._componentInfo = prev._componentInfo;
    if (prev.data !== this.data) {
      this._componentInfo.data = this.data;
    }

    return null;
  }

  connectComponent() {
    const { element, template, widget } = this;

    const component = class extends Component {};
    setComponentTemplate(template, component);

    this._componentInfo = {
      element,
      component,
      @tracked data: this.data,
    };
    const parentMountWidgetComponent = widget._findView();
    parentMountWidgetComponent.mountChildComponent(this._componentInfo);
  }
}

RenderGlimmer.prototype.type = "Widget";
