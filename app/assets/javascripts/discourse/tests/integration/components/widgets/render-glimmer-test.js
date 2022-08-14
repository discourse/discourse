import { module, test } from "qunit";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import widgetHbs from "discourse/widgets/hbs-compiler";
import Widget from "discourse/widgets/widget";
import ClassicComponent from "@ember/component";
import RenderGlimmer from "discourse/widgets/render-glimmer";

class DemoWidget extends Widget {
  static actionTriggered = false;
  tagName = "div.my-widget";

  html(attrs) {
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
            <DemoComponent @arg1={{@data.arg1}} @dynamicArg={{@data.dynamicArg}} @action={{@data.actionForComponentToTrigger}}/>`,
        {
          ...attrs,
          actionForComponentToTrigger: this.actionForComponentToTrigger,
        }
      ),
    ];
  }
  dummyAction() {}
  actionForComponentToTrigger() {
    DemoWidget.actionTriggered = true;
  }
}

class DemoComponent extends ClassicComponent {
  static eventLog = [];
  classNames = ["demo-component"];
  layout = hbs`<DButton class="component-action-button" @label="component_action" @action={{@action}} />`;

  init() {
    DemoComponent.eventLog.push("init");
    super.init(...arguments);
  }

  didInsertElement() {
    DemoComponent.eventLog.push("didInsertElement");
  }

  willDestroyElement() {
    DemoComponent.eventLog.push("willDestroyElement");
  }

  didReceiveAttrs() {
    DemoComponent.eventLog.push("didReceiveAttrs");
  }

  willDestroy() {
    DemoComponent.eventLog.push("willDestroy");
  }
}

module("Integration | Component | Widget | render-glimmer", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    DemoComponent.eventLog = [];
    DemoWidget.actionTriggered = false;
    this.registry.register("widget:demo-widget", DemoWidget);
    this.registry.register("component:demo-component", DemoComponent);
  });

  hooks.afterEach(function () {
    this.registry.unregister("widget:demo-widget");
    this.registry.unregister("component:demo-component");
  });

  test("argument handling", async function (assert) {
    await render(
      hbs`
        <Input class='dynamic-value-input' @type="text" @value={{this.dynamicValue}} />
        <MountWidget @widget="demo-widget" @args={{hash arg1="val1" dynamicArg=this.dynamicValue}} />`
    );

    assert.true(exists("div.my-widget"), "widget is rendered");
    assert.true(exists("div.glimmer-content"), "glimmer content is rendered");
    assert.strictEqual(
      query("div.glimmer-content").innerText,
      "arg1=val1 dynamicArg=",
      "arguments are passed through"
    );

    await fillIn("input.dynamic-value-input", "somedynamicvalue");
    assert.strictEqual(
      query("div.glimmer-content").innerText,
      "arg1=val1 dynamicArg=",
      "changed arguments do not change before rerender"
    );

    await click(".my-widget button");
    assert.strictEqual(
      query("div.glimmer-content").innerText,
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

    assert.true(exists("div.my-widget"), "widget is rendered");
    assert.true(exists("div.glimmer-content"), "glimmer content is rendered");
    assert.true(exists("div.demo-component"), "demo component is rendered");

    assert.deepEqual(
      DemoComponent.eventLog,
      ["init", "didReceiveAttrs", "didInsertElement"],
      "component is initialized correctly"
    );

    DemoComponent.eventLog = [];

    await fillIn("input.dynamic-value-input", "somedynamicvalue");
    assert.deepEqual(
      DemoComponent.eventLog,
      [],
      "component is not notified of attr change before widget rerender"
    );

    await click(".my-widget button");
    assert.deepEqual(
      DemoComponent.eventLog,
      ["didReceiveAttrs"],
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

    assert.true(
      exists("div.demo-component button"),
      "component button is rendered"
    );

    await click("div.demo-component button");
    assert.true(DemoWidget.actionTriggered, "widget event is triggered");
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
});
