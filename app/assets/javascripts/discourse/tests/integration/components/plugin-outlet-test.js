import { module, test } from "qunit";
import { count, exists, query } from "discourse/tests/helpers/qunit-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render, settled } from "@ember/test-helpers";
import { action } from "@ember/object";
import { extraConnectorClass } from "discourse/lib/plugin-connectors";
import { hbs } from "ember-cli-htmlbars";
import { registerTemporaryModule } from "discourse/tests/helpers/temporary-module-helper";
import { getOwner } from "@ember/application";
import Component from "@glimmer/component";
import templateOnly from "@ember/component/template-only";
import { withSilencedDeprecationsAsync } from "discourse-common/lib/deprecated";
import { setComponentTemplate } from "@glimmer/manager";
import sinon from "sinon";

const TEMPLATE_PREFIX = "discourse/plugins/some-plugin/templates/connectors";
const CLASS_PREFIX = "discourse/plugins/some-plugin/connectors";

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
      `${TEMPLATE_PREFIX}/test-name/hello`,
      hbs`<span class='hello-username'>{{this.username}}</span>
        <button class='say-hello' {{on "click" (action "sayHello")}}></button>
        <button class='say-hello-using-this' {{on "click" this.sayHello}}></button>
        <span class='hello-result'>{{this.hello}}</span>`
    );
    registerTemporaryModule(
      `${TEMPLATE_PREFIX}/test-name/hi`,
      hbs`<button class='say-hi' {{on "click" (action "sayHi")}}></button>
        <span class='hi-result'>{{this.hi}}</span>`
    );
    registerTemporaryModule(
      `${TEMPLATE_PREFIX}/test-name/conditional-render`,
      hbs`<span class="conditional-render">I only render sometimes</span>`
    );

    registerTemporaryModule(
      `${TEMPLATE_PREFIX}/outlet-with-default/my-connector`,
      hbs`<span class='result'>Plugin implementation{{#if @outletArgs.yieldCore}} {{yield}}{{/if}}</span>`
    );
    registerTemporaryModule(
      `${TEMPLATE_PREFIX}/outlet-with-default/clashing-connector`,
      hbs`This will override my-connector and raise an error`
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

  module(
    "as a wrapper around a default core implementation",
    function (innerHooks) {
      innerHooks.beforeEach(function () {
        this.consoleErrorStub = sinon.stub(console, "error");

        this.set("shouldDisplay", false);
        this.set("yieldCore", false);
        this.set("enableClashingConnector", false);

        extraConnectorClass("outlet-with-default/my-connector", {
          shouldRender(args) {
            return args.shouldDisplay;
          },
        });

        extraConnectorClass("outlet-with-default/clashing-connector", {
          shouldRender(args) {
            return args.enableClashingConnector;
          },
        });

        this.template = hbs`
      <PluginOutlet @name="outlet-with-default" @outletArgs={{hash shouldDisplay=this.shouldDisplay yieldCore=this.yieldCore enableClashingConnector=this.enableClashingConnector}}>
        <span class='result'>Core implementation</span>
      </PluginOutlet>
    `;
      });

      test("Can act as a wrapper around core implementation", async function (assert) {
        await render(this.template);

        assert.dom(".result").hasText("Core implementation");

        this.set("shouldDisplay", true);
        await settled();

        assert.dom(".result").hasText("Plugin implementation");

        this.set("yieldCore", true);
        await settled();

        assert
          .dom(".result")
          .hasText("Plugin implementation Core implementation");

        assert.strictEqual(
          this.consoleErrorStub.callCount,
          0,
          "no errors in console"
        );
      });

      test("clashing connectors for regular users", async function (assert) {
        await render(this.template);

        this.set("shouldDisplay", true);
        this.set("enableClashingConnector", true);
        await settled();

        assert.strictEqual(
          this.consoleErrorStub.callCount,
          1,
          "clash error reported to console"
        );

        assert.true(
          this.consoleErrorStub
            .getCall(0)
            .args[0].includes("Multiple connectors"),
          "console error includes message about multiple connectors"
        );

        assert
          .dom(".broken-theme-alert-banner")
          .doesNotExist("Banner is not shown to regular users");
      });

      test("clashing connectors for admins", async function (assert) {
        this.set("currentUser.admin", true);
        await render(this.template);

        this.set("shouldDisplay", true);
        this.set("enableClashingConnector", true);
        await settled();

        assert.strictEqual(
          this.consoleErrorStub.callCount,
          1,
          "clash error reported to console"
        );

        assert.true(
          this.consoleErrorStub
            .getCall(0)
            .args[0].includes("Multiple connectors"),
          "console error includes message about multiple connectors"
        );

        assert
          .dom(".broken-theme-alert-banner")
          .exists("Error banner is shown to admins");
      });
    }
  );

  test("Renders wrapped implementation if no connectors are registered", async function (assert) {
    await render(
      hbs`
        <PluginOutlet @name="outlet-with-no-registrations">
          <span class='result'>Core implementation</span>
        </PluginOutlet>
      `
    );

    assert.dom(".result").hasText("Core implementation");
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

module(
  "Integration | Component | plugin-outlet | connector class definitions",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      registerTemporaryModule(
        `${TEMPLATE_PREFIX}/test-name/my-connector`,
        hbs`<span class='outletArgHelloValue'>{{@outletArgs.hello}}</span><span class='thisHelloValue'>{{this.hello}}</span>`
      );
    });

    test("uses classic PluginConnector by default", async function (assert) {
      await render(
        hbs`<PluginOutlet @name="test-name" @outletArgs={{hash hello="world"}} />`
      );

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText("world");
    });

    test("uses templateOnly by default when @defaultGlimmer=true", async function (assert) {
      await render(
        hbs`<PluginOutlet @name="test-name" @outletArgs={{hash hello="world"}} @defaultGlimmer={{true}} />`
      );

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText(""); // `this.` unavailable in templateOnly components
    });

    test("uses simple object if provided", async function (assert) {
      this.set("someBoolean", true);

      extraConnectorClass("test-name/my-connector", {
        shouldRender(args) {
          return args.someBoolean;
        },

        setupComponent(args, component) {
          component.reopen({
            get hello() {
              return args.hello + " from setupComponent";
            },
          });
        },
      });

      await render(
        hbs`<PluginOutlet @name="test-name" @outletArgs={{hash hello="world" someBoolean=this.someBoolean}} />`
      );

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText("world from setupComponent");

      this.set("someBoolean", false);
      await settled();

      assert.dom(".outletArgHelloValue").doesNotExist();
    });

    test("ignores classic hooks for glimmer components", async function (assert) {
      extraConnectorClass("test-name/my-connector", {
        setupComponent(args, component) {
          component.reopen({
            get hello() {
              return args.hello + " from setupComponent";
            },
          });
        },
      });

      await withSilencedDeprecationsAsync(
        "discourse.plugin-outlet-classic-hooks",
        async () => {
          await render(
            hbs`<PluginOutlet @name="test-name" @outletArgs={{hash hello="world"}} @defaultGlimmer={{true}} />`
          );
        }
      );

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText("");
    });

    test("uses custom component class if provided", async function (assert) {
      this.set("someBoolean", true);

      extraConnectorClass(
        "test-name/my-connector",
        class MyOutlet extends Component {
          static shouldRender(args) {
            return args.someBoolean;
          }

          get hello() {
            return this.args.outletArgs.hello + " from custom component";
          }
        }
      );

      await render(
        hbs`<PluginOutlet @name="test-name" @outletArgs={{hash hello="world" someBoolean=this.someBoolean}} />`
      );

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText("world from custom component");

      this.set("someBoolean", false);
      await settled();

      assert.dom(".outletArgHelloValue").doesNotExist();
    });

    test("uses custom templateOnly() if provided", async function (assert) {
      this.set("someBoolean", true);

      extraConnectorClass(
        "test-name/my-connector",
        Object.assign(templateOnly(), {
          shouldRender(args) {
            return args.someBoolean;
          },
        })
      );

      await render(
        hbs`<PluginOutlet @name="test-name" @outletArgs={{hash hello="world" someBoolean=this.someBoolean}} />`
      );

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText(""); // `this.` unavailable in templateOnly components

      this.set("someBoolean", false);
      await settled();

      assert.dom(".outletArgHelloValue").doesNotExist();
    });
  }
);

module(
  "Integration | Component | plugin-outlet | gjs class definitions",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      const template = hbs`<span class='gjs-test'>Hello world</span>`;
      const component = templateOnly();
      setComponentTemplate(template, component);

      registerTemporaryModule(
        `${CLASS_PREFIX}/test-name/my-connector`,
        component
      );
    });

    test("detects a gjs connector with no associated template file", async function (assert) {
      await render(hbs`<PluginOutlet @name="test-name" />`);

      assert.dom(".gjs-test").hasText("Hello world");
    });
  }
);
