import { module, test } from "qunit";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import widgetHbs from "discourse/widgets/hbs-compiler";
import Widget, { deleteFromRegistry } from "discourse/widgets/widget";
import ClassicComponent from "@ember/component";
import RenderGlimmer, {
  registerWidgetShim,
} from "discourse/widgets/render-glimmer";
import { bind } from "discourse-common/utils/decorators";

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
  });

  hooks.afterEach(function () {
    this.registry.unregister("widget:demo-widget");
    this.registry.unregister("widget:toggle-demo-widget");
    this.registry.unregister("component:demo-component");
    deleteFromRegistry("render-glimmer-test-shim");
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

  test("modify widget state with component action", async function (assert) {
    await render(
      hbs`<MountWidget @widget="demo-widget" @args={{hash arg1="val1"}} />`
    );

    assert.false(
      DemoWidget.actionTriggered,
      "widget event has not been triggered yet"
    );

    assert.strictEqual(
      query(".action-state").innerText,
      "false",
      "eventTriggered is false in nested component"
    );

    assert.true(
      exists("div.demo-component button"),
      "component button is rendered"
    );

    await click("div.demo-component button");
    assert.true(DemoWidget.actionTriggered, "widget event is triggered");

    assert.strictEqual(
      query(".action-state").innerText,
      "true",
      "eventTriggered is true in nested component"
    );
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
    assert.strictEqual(query("div.glimmer-wrapper").innerText, "One");
    await click(".toggleButton");
    assert.strictEqual(query("div.glimmer-wrapper").innerText, "Two");
    await click(".toggleButton");
    assert.strictEqual(query("div.glimmer-wrapper").innerText, "One");
  });

  test("registerWidgetShim can register a fake widget", async function (assert) {
    await render(
      hbs`<MountWidget @widget="render-glimmer-test-shim" @args={{hash attr1="val1"}} />`
    );

    assert.dom("div.my-wrapper span.shim-content").exists();
    assert.dom("div.my-wrapper span.shim-content").hasText("val1");
  });
});
