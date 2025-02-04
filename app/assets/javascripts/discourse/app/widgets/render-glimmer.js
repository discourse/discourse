import { hasInternalComponentManager } from "@glimmer/manager";
import { tracked } from "@glimmer/tracking";
import { setComponentTemplate } from "@ember/component";
import templateOnly from "@ember/component/template-only";
import { assert } from "@ember/debug";
import { createWidgetFrom } from "discourse/widgets/widget";

const INITIAL_CLASSES = Symbol("RENDER_GLIMMER_INITIAL_CLASSES");

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

To dynamically control the attributes of the wrapper element, a helper function is provided as an argument to your hbs template.
To use this via a template, you can do something like this:
```
hbs`{{@setWrapperElementAttrs class="some class value" title="title value"}}`
```
If you prefer, you can pass this function down into your own components, and call it from there. Invoked as a helper, this can
be passed (auto-)tracked values, and will update the wrapper element attributes whenever the inputs.
*/

export default class RenderGlimmer {
  /**
   * Create a RenderGlimmer instance
   * @param widget - the widget instance which is rendering this content
   * @param renderInto - a string describing a new wrapper element (e.g. `div.my-class`),
   *  or an existing HTML element to append content into.
   * @param template - a glimmer template compiled via ember-cli-htmlbars
   * @param data - will be made available at `@data` in your template
   */
  constructor(widget, renderInto, template, data) {
    assert(
      "`template` should be a template compiled via `ember-cli-htmlbars`, or a component",
      template.name === "factory" || hasInternalComponentManager(template)
    );
    this.renderInto = renderInto;
    if (widget) {
      this.widget = widget;
    }
    this.template = template;
    this.data = data;
  }

  init() {
    if (this.renderInto instanceof Element) {
      this.element = this.renderInto;
    } else {
      const [type, ...classNames] = this.renderInto.split(".");
      this.element = document.createElement(type);
      this.element.classList.add(...classNames);
      this.element[INITIAL_CLASSES] = classNames;
    }
    this.connectComponent();
    return this.element;
  }

  destroy() {
    if (this._componentInfo) {
      this.parentMountWidgetComponent.unmountChildComponent(
        this._componentInfo
      );
    }
  }

  update(prev) {
    if (
      prev.template.__id !== this.template.__id ||
      prev.renderInto !== this.renderInto
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
    const { element, template } = this;

    let component;
    if (hasInternalComponentManager(template)) {
      component = template;
    } else {
      component = templateOnly();
      component.name = "Widgets/RenderGlimmer";
      setComponentTemplate(template, component);
    }

    this._componentInfo = new ComponentInfo({
      element,
      component,
      data: this.data,
      setWrapperElementAttrs: (attrs) =>
        this.updateElementAttrs(element, attrs),
    });

    this.parentMountWidgetComponent.mountChildComponent(this._componentInfo);
  }

  updateElementAttrs(element, attrs) {
    for (let [key, value] of Object.entries(attrs)) {
      if (key === "class") {
        value = [element[INITIAL_CLASSES], value].filter(Boolean).join(" ");
      }

      if ([null, undefined].includes(value)) {
        element.removeAttribute(key);
      } else {
        element.setAttribute(key, value);
      }
    }
  }

  get parentMountWidgetComponent() {
    if (this._emberView) {
      return this._emberView;
    }
    // Work up parent widgets until we find one with a _emberView
    // attribute. `.parentWidget` is the normal way to work up the tree,
    // but we use `attrs._postCookedWidget` to handle the special case
    // of widgets rendered inside post-cooked.
    let widget = this.widget;
    while (widget) {
      const component = widget._emberView;
      if (component) {
        return component;
      }
      widget = widget.parentWidget || widget.attrs._postCookedWidget;
    }
  }
}

RenderGlimmer.prototype.type = "Widget";

/**
 * Define a widget shim which renders a Glimmer template. Designed for incrementally migrating
 * a widget-based UI to Glimmer. Widget attrs will be made available to your template at `@data`.
 * For more details, see documentation for the RenderGlimmer class.
 * @param name - the widget's name (which can then be used in `.attach` elsewhere)
 * @param tagName - a string describing a new wrapper element (e.g. `div.my-class`)
 * @param template - a glimmer template compiled via ember-cli-htmlbars
 */
export function registerWidgetShim(name, tagName, template) {
  const RenderGlimmerShim = class MyClass extends RenderGlimmer {
    constructor(attrs) {
      super(null, tagName, template, attrs);
      return this;
    }

    get widget() {
      return this.parentWidget;
    }

    didRenderWidget() {}
    willRerenderWidget() {}
  };

  createWidgetFrom(RenderGlimmerShim, name, {});
}

class ComponentInfo {
  @tracked data;
  element;
  component;
  setWrapperElementAttrs;

  constructor(params) {
    Object.assign(this, params);
  }
}
