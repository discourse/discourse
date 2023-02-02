import templateOnly from "@ember/component/template-only";
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

You can also include function references in the `data` object, and use them as actions within the Ember component.
You will need to `bind` the function to ensure it maintains a reference to the widget, and you'll need to manually
call `this.scheduleRerender()` after making any changes to widget state (the normal widget auto-rerendering does not apply).

Note that the @bind decorator will only work if you're using class-based Widget syntax. When using createWidget, you'll need to
call `.bind(this)` manually when passing the function to RenderGlimmer.

For example:
```
createWidget("my-widget", {
  tagName: "div",
  buildKey: () => `my-widget`,

  defaultState() {
    return { counter: 0 };
  },

  html(args, state){
    return [
      new RenderGlimmer(
        this,
        "div.my-wrapper-class",
        hbs`<MyComponent @counter={{@data.counter}} @incrementCounter={{@data.incrementCounter}} />`,
        {
          counter: state.counter,
          incrementCounter: this.incrementCounter.bind(this),
        }
      ),
    ]
  },

  incrementCounter() {
    this.state.counter++;
    this.scheduleRerender();
  },
});
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
    if (
      prev.template.__id !== this.template.__id ||
      prev.tagName !== this.tagName
    ) {
      // Totally different component, but the widget framework guessed it was the
      // same widget. Destroy old component and re-init the new one.
      prev.destroy();
      return this.init();
    }

    this._componentInfo = prev._componentInfo;
    if (prev.data !== this.data) {
      this._componentInfo.data = this.data;
    }

    return null;
  }

  connectComponent() {
    const { element, template, widget } = this;

    const component = templateOnly();
    component.name = "Widgets/RenderGlimmer";
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
