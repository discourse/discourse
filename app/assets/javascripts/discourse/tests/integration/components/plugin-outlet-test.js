import { module, test } from "qunit";
import { count, exists, query } from "discourse/tests/helpers/qunit-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render, settled } from "@ember/test-helpers";
import { action } from "@ember/object";
import { extraConnectorClass } from "discourse/lib/plugin-connectors";
import { hbs } from "ember-cli-htmlbars";
import { registerTemporaryModule } from "discourse/tests/helpers/temporary-module-helper";
import { getOwner } from "discourse-common/lib/get-owner";

const PREFIX = "discourse/plugins/some-plugin/templates/connectors";

module("Integration | Component | plugin-outlet", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    extraConnectorClass("test-name/hello", {
      actions: {
        sayHello() {
          this.set("hello", `${this.hello || ""}hello!`);
        },
      },
    });

    extraConnectorClass("test-name/hi", {
      setupComponent() {
        this.appEvents.on("hi:sayHi", this, this.say);
      },

      teardownComponent() {
        this.appEvents.off("hi:sayHi", this, this.say);
      },

      @action
      say() {
        this.set("hi", "hi!");
      },

      @action
      sayHi() {
        this.appEvents.trigger("hi:sayHi");
      },
    });

    extraConnectorClass("test-name/conditional-render", {
      shouldRender(args, context) {
        return args.shouldDisplay || context.siteSettings.always_display;
      },
    });

    registerTemporaryModule(
      `${PREFIX}/test-name/hello`,
      hbs`<span class='hello-username'>{{username}}</span>
        <button class='say-hello' {{on "click" (action "sayHello")}}></button>
        <button class='say-hello-using-this' {{on "click" this.sayHello}}></button>
        <span class='hello-result'>{{hello}}</span>`
    );
    registerTemporaryModule(
      `${PREFIX}/test-name/hi`,
      hbs`<button class='say-hi' {{on "click" (action "sayHi")}}></button>
        <span class='hi-result'>{{hi}}</span>`
    );
    registerTemporaryModule(
      `${PREFIX}/test-name/conditional-render`,
      hbs`<span class="conditional-render">I only render sometimes</span>`
    );
  });

  test("Renders a template into the outlet", async function (assert) {
    this.set("shouldDisplay", false);
    await render(
      hbs`<PluginOutlet @name="test-name" @outletArgs={{hash shouldDisplay=this.shouldDisplay}} />`
    );
    assert.strictEqual(count(".hello-username"), 1, "renders the hello outlet");
    assert.false(
      exists(".conditional-render"),
      "doesn't render conditional outlet"
    );

    await click(".say-hello");
    assert.strictEqual(
      query(".hello-result").innerText,
      "hello!",
      "actions delegate properly"
    );
    await click(".say-hello-using-this");
    assert.strictEqual(
      query(".hello-result").innerText,
      "hello!hello!",
      "actions are made available on `this` and are bound correctly"
    );

    await click(".say-hi");
    assert.strictEqual(
      query(".hi-result").innerText,
      "hi!",
      "actions delegate properly"
    );
  });

  test("Reevaluates shouldRender for argument changes", async function (assert) {
    this.set("shouldDisplay", false);
    await render(
      hbs`<PluginOutlet @name="test-name" @outletArgs={{hash shouldDisplay=this.shouldDisplay}} />`
    );
    assert.false(
      exists(".conditional-render"),
      "doesn't render conditional outlet"
    );

    this.set("shouldDisplay", true);
    await settled();
    assert.true(exists(".conditional-render"), "renders conditional outlet");
  });

  test("Reevaluates shouldRender for other autotracked changes", async function (assert) {
    this.set("shouldDisplay", false);
    await render(
      hbs`<PluginOutlet @name="test-name" @outletArgs={{hash shouldDisplay=this.shouldDisplay}} />`
    );
    assert.false(
      exists(".conditional-render"),
      "doesn't render conditional outlet"
    );

    getOwner(this).lookup("service:site-settings").always_display = true;
    await settled();
    assert.true(exists(".conditional-render"), "renders conditional outlet");
  });

  test("Other outlets are not re-rendered", async function (assert) {
    this.set("shouldDisplay", false);
    await render(
      hbs`<PluginOutlet @name="test-name" @outletArgs={{hash shouldDisplay=this.shouldDisplay}} />`
    );

    const otherOutletElement = query(".hello-username");
    otherOutletElement.someUniqueProperty = true;

    this.set("shouldDisplay", true);
    await settled();
    assert.true(exists(".conditional-render"), "renders conditional outlet");

    assert.true(
      query(".hello-username").someUniqueProperty,
      "other outlet is left untouched"
    );
  });
});
