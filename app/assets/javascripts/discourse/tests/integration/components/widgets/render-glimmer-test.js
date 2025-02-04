import ClassicComponent, { setComponentTemplate } from "@ember/component";
import templateOnly from "@ember/component/template-only";
import { click, fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { bind } from "discourse/lib/decorators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import widgetHbs from "discourse/widgets/hbs-compiler";
import RenderGlimmer, {
  registerWidgetShim,
} from "discourse/widgets/render-glimmer";
import Widget, { deleteFromRegistry } from "discourse/widgets/widget";

class DemoWidget extends Widget {
  static actionTriggered = false;
  tagName = "div.my-widget";

  buildKey() {
    return "abc";
  }

  defaultState() {
    return {
      actionTriggered: false,
    };
  }

  html(attrs, state) {
    return [
      this.attach("button", {
        label: "rerender",
        className: "triggerRerender",
        action: "dummyAction",
      }),
      new RenderGlimmer(
        this,
        "div.glimmer-wrapper",
        hbs`<div class='glimmer-content'>
              arg1={{@data.arg1}} dynamicArg={{@data.dynamicArg}}
            </div>
            <DemoComponent @arg1={{@data.arg1}} @dynamicArg={{@data.dynamicArg}} @action={{@data.actionForComponentToTrigger}} @widgetActionTriggered={{@data.widgetActionTriggered}}/>`,
        {
          ...attrs,
          actionForComponentToTrigger: this.actionForComponentToTrigger,
          widgetActionTriggered: state.actionTriggered,
        }
      ),
    ];
  }

  dummyAction() {}

  @bind
  actionForComponentToTrigger() {
    this.state.actionTriggered = true;
    DemoWidget.actionTriggered = true;
    this.scheduleRerender();
  }
}

class DemoComponent extends ClassicComponent {
  static eventLog = [];
  classNames = ["demo-component"];
  layout = hbs`<DButton class="component-action-button" @label="component_action" @action={{@action}} /><p class='action-state'>{{@widgetActionTriggered}}</p>`;

  init() {
    DemoComponent.eventLog.push("init");
    super.init(...arguments);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    DemoComponent.eventLog.push("willDestroy");
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    DemoComponent.eventLog.push("didInsertElement");
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    DemoComponent.eventLog.push("willDestroyElement");
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    DemoComponent.eventLog.push("didReceiveAttrs");
  }
}

class ToggleDemoWidget extends Widget {
  static actionTriggered = false;
  tagName = "div.my-widget";

  buildKey() {
    return "abc";
  }

  defaultState() {
    return {
      showOne: true,
    };
  }

  html(attrs, state) {
    const output = [
      this.attach("button", {
        label: "toggle",
        className: "toggleButton",
        action: "toggleComponent",
      }),
    ];
    if (state.showOne) {
      output.push(new RenderGlimmer(this, "div.glimmer-wrapper", hbs`One`, {}));
    } else {
      output.push(new RenderGlimmer(this, "div.glimmer-wrapper", hbs`Two`, {}));
    }
    return output;
  }

  toggleComponent() {
    this.state.showOne = !this.state.showOne;
  }
}

const SimpleComponent = templateOnly();
setComponentTemplate(hbs`<div class="component-shim"></div>`, SimpleComponent);

module("Integration | Component | Widget | render-glimmer", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    DemoComponent.eventLog = [];
    DemoWidget.actionTriggered = false;
    this.registry.register("widget:demo-widget", DemoWidget);
    this.registry.register("widget:toggle-demo-widget", ToggleDemoWidget);
    this.registry.register("component:demo-component", DemoComponent);
    registerWidgetShim(
      "render-glimmer-test-shim",
      "div.my-wrapper",
      hbs`<span class='shim-content'>{{@data.attr1}}</span>`
    );
    registerWidgetShim(
      "render-glimmer-test-wrapper-attrs",
      "div.initial-wrapper-class",
      hbs`{{@setWrapperElementAttrs class=(concat-class "static-extra-class" @data.extraClass) data-some-attr=@data.dataAttrValue}}`
    );
    registerWidgetShim(
      "render-glimmer-test-component-shim",
      "div.initial-wrapper-class",
      SimpleComponent
    );
  });

  hooks.afterEach(function () {
    this.registry.unregister("widget:demo-widget");
    this.registry.unregister("widget:toggle-demo-widget");
    this.registry.unregister("component:demo-component");
    deleteFromRegistry("render-glimmer-test-shim");
    deleteFromRegistry("render-glimmer-test-wrapper-attrs");
    deleteFromRegistry("render-glimmer-test-component-shim");
  });

  test("argument handling", async function (assert) {
    await render(
      hbs`
        <Input class='dynamic-value-input' @type="text" @value={{this.dynamicValue}} />
        <MountWidget @widget="demo-widget" @args={{hash arg1="val1" dynamicArg=this.dynamicValue}} />`
    );

    assert.dom("div.my-widget").exists("widget is rendered");
    assert.dom("div.glimmer-content").exists("glimmer content is rendered");
    assert
      .dom("div.glimmer-content")
      .hasText("arg1=val1 dynamicArg=", "arguments are passed through");

    await fillIn("input.dynamic-value-input", "somedynamicvalue");
    await click(".my-widget button");
    assert
      .dom("div.glimmer-content")
      .hasText(
        "arg1=val1 dynamicArg=somedynamicvalue",
        "changed arguments are applied after rerender"
      );
  });

  test("child component lifecycle", async function (assert) {
    assert.deepEqual(
      DemoComponent.eventLog,
      [],
      "component event log starts empty"
    );

    await render(
      hbs`
        <Input class='dynamic-value-input' @type="text" @value={{this.dynamicValue}} />
        {{#unless (eq this.dynamicValue 'hidden')}}
          <MountWidget @widget="demo-widget" @args={{hash arg1="val1" dynamicArg=this.dynamicValue}} />
        {{/unless}}`
    );

    assert.dom("div.my-widget").exists("widget is rendered");
    assert.dom("div.glimmer-content").exists("glimmer content is rendered");
    assert.dom("div.demo-component").exists("demo component is rendered");

    assert.deepEqual(
      DemoComponent.eventLog,
      ["init", "didReceiveAttrs", "didInsertElement"],
      "component is initialized correctly"
    );

    DemoComponent.eventLog = [];

    await fillIn("input.dynamic-value-input", "somedynamicvalue");
    await click(".my-widget button");
    assert.deepEqual(
      DemoComponent.eventLog,
      ["didReceiveAttrs", "didReceiveAttrs"], // once for input, once for event
      "component is notified of attr change during widget rerender"
    );

    DemoComponent.eventLog = [];

    await fillIn("input.dynamic-value-input", "hidden");
    assert.deepEqual(
      DemoComponent.eventLog,
      ["willDestroyElement", "willDestroy"],
      "destroy hooks are run correctly"
    );

    DemoComponent.eventLog = [];

    await fillIn("input.dynamic-value-input", "visibleAgain");
    assert.deepEqual(
      DemoComponent.eventLog,
      ["init", "didReceiveAttrs", "didInsertElement"],
      "component can be reinitialized"
    );
  });

  test("rendering component directly", async function (assert) {
    await render(hbs`
      <MountWidget @widget="render-glimmer-test-component-shim" />
    `);

    assert.dom("div.component-shim").exists();
  });

  test("trigger widget actions from component", async function (assert) {
    assert.false(
      DemoWidget.actionTriggered,
      "widget event has not been triggered yet"
    );

    await render(
      hbs`
        <Input class='dynamic-value-input' @type="text" @value={{this.dynamicValue}} />
        {{#unless (eq this.dynamicValue 'hidden')}}
          <MountWidget @widget="demo-widget" @args={{hash arg1="val1" dynamicArg=this.dynamicValue}} />
        {{/unless}}`
    );

    assert
      .dom("div.demo-component button")
      .exists("component button is rendered");

    await click("div.demo-component button");
    assert.true(DemoWidget.actionTriggered, "widget event is triggered");
  });

  test("modify widget state with component action", async function (assert) {
    await render(
      hbs`<MountWidget @widget="demo-widget" @args={{hash arg1="val1"}} />`
    );

    assert.false(
      DemoWidget.actionTriggered,
      "widget event has not been triggered yet"
    );

    assert
      .dom(".action-state")
      .hasText("false", "eventTriggered is false in nested component");

    assert
      .dom("div.demo-component button")
      .exists("component button is rendered");

    await click("div.demo-component button");
    assert.true(DemoWidget.actionTriggered, "widget event is triggered");

    assert
      .dom(".action-state")
      .hasText("true", "eventTriggered is true in nested component");
  });

  test("developer ergonomics", function (assert) {
    assert.throws(
      () => {
        // eslint-disable-next-line no-new
        new RenderGlimmer(this, "div", `<NotActuallyATemplate />`);
      },
      /`template` should be a template compiled via `ember-cli-htmlbars`/,
      "it raises a useful error when passed a string instead of a template"
    );

    assert.throws(
      () => {
        // eslint-disable-next-line no-new
        new RenderGlimmer(this, "div", widgetHbs`{{using-the-wrong-compiler}}`);
      },
      /`template` should be a template compiled via `ember-cli-htmlbars`/,
      "it raises a useful error when passed a widget-hbs-compiler template"
    );

    // eslint-disable-next-line no-new
    new RenderGlimmer(this, "div", hbs`<TheCorrectCompiler />`);
    assert.true(true, "it doesn't raise an error for correct params");
  });

  test("multiple adjacent components", async function (assert) {
    await render(hbs`<MountWidget @widget="toggle-demo-widget" />`);
    assert.dom("div.glimmer-wrapper").hasText("One");
    await click(".toggleButton");
    assert.dom("div.glimmer-wrapper").hasText("Two");
    await click(".toggleButton");
    assert.dom("div.glimmer-wrapper").hasText("One");
  });

  test("registerWidgetShim can register a fake widget", async function (assert) {
    await render(
      hbs`<MountWidget @widget="render-glimmer-test-shim" @args={{hash attr1="val1"}} />`
    );

    assert.dom("div.my-wrapper span.shim-content").exists();
    assert.dom("div.my-wrapper span.shim-content").hasText("val1");
  });

  test("setWrapperElementAttrs API", async function (assert) {
    await render(
      hbs`<MountWidget @widget="render-glimmer-test-wrapper-attrs" @args={{hash extraClass=this.extraClass dataAttrValue=this.dataAttrValue}} />`
    );

    assert.dom("div.initial-wrapper-class").exists();
    assert
      .dom("div.initial-wrapper-class")
      .hasAttribute("class", "initial-wrapper-class static-extra-class");
    assert
      .dom("div.initial-wrapper-class")
      .doesNotHaveAttribute("data-some-attr");

    this.set("extraClass", "dynamic-extra-class");
    this.set("dataAttrValue", "hello world");

    assert
      .dom("div.initial-wrapper-class")
      .hasAttribute(
        "class",
        "initial-wrapper-class static-extra-class dynamic-extra-class"
      );
    assert
      .dom("div.initial-wrapper-class")
      .hasAttribute("data-some-attr", "hello world");
  });
});
