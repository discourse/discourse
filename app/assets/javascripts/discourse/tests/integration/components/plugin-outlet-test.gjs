import Component from "@glimmer/component";
import templateOnly from "@ember/component/template-only";
import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import sinon from "sinon";
import PluginOutlet from "discourse/components/plugin-outlet";
import deprecatedOutletArgument from "discourse/helpers/deprecated-outlet-argument";
import {
  extraConnectorClass,
  extraConnectorComponent,
} from "discourse/lib/plugin-connectors";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { registerTemporaryModule } from "discourse/tests/helpers/temporary-module-helper";
import deprecated, {
  withSilencedDeprecations,
  withSilencedDeprecationsAsync,
} from "discourse-common/lib/deprecated";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "../../helpers/raise-on-deprecation";

const TEMPLATE_PREFIX = "discourse/plugins/some-plugin/templates/connectors";
const CLASS_PREFIX = "discourse/plugins/some-plugin/connectors";

module("Integration | Component | plugin-outlet", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    registerTemporaryModule(`${CLASS_PREFIX}/test-name/hello`, {
      actions: {
        sayHello() {
          this.set("hello", `${this.hello || ""}hello!`);
        },
      },
    });

    registerTemporaryModule(`${CLASS_PREFIX}/test-name/hi`, {
      setupComponent() {
        this.appEvents.on("hi:sayHi", this, this.say);
      },

      teardownComponent() {
        this.appEvents.off("hi:sayHi", this, this.say);
      },

      actions: {
        say() {
          this.set("hi", "hi!");
        },

        sayHi() {
          this.appEvents.trigger("hi:sayHi");
        },
      },
    });

    registerTemporaryModule(`${CLASS_PREFIX}/test-name/conditional-render`, {
      shouldRender(args, context, owner) {
        return (
          args.shouldDisplay ||
          context.siteSettings.always_display ||
          owner.lookup("service:site-settings").alternativeAccess
        );
      },
    });

    registerTemporaryModule(
      `${TEMPLATE_PREFIX}/test-name/hello`,
      hbs`
        <span class="hello-username">{{this.username}}</span>
        <button
          type="button"
          class="say-hello"
          {{on "click" (action "sayHello")}}
        ></button>
        <button
          type="button"
          class="say-hello-using-this"
          {{on "click" this.sayHello}}
        ></button>
        <span class="hello-result">{{this.hello}}</span>
      `
    );

    registerTemporaryModule(
      `${TEMPLATE_PREFIX}/test-name/hi`,
      hbs`
        <button
          type="button"
          class="say-hi"
          {{on "click" (action "sayHi")}}
        ></button>
        <span class="hi-result">{{this.hi}}</span>
      `
    );

    registerTemporaryModule(
      `${TEMPLATE_PREFIX}/test-name/conditional-render`,
      hbs`
        <span class="conditional-render">I only render sometimes</span>
      `
    );

    registerTemporaryModule(
      `${TEMPLATE_PREFIX}/outlet-with-default/my-connector`,
      hbs`
        <span class="result">Plugin implementation{{#if @outletArgs.yieldCore}}
            {{yield}}{{/if}}</span>
      `
    );

    registerTemporaryModule(
      `${TEMPLATE_PREFIX}/outlet-with-default/clashing-connector`,
      hbs`This will override my-connector and raise an error`
    );
  });

  test("Renders a template into the outlet", async function (assert) {
    await render(hbs`<PluginOutlet @name="test-name" />`);

    assert
      .dom(".hello-username")
      .exists({ count: 1 }, "renders the hello outlet");
    assert
      .dom(".conditional-render")
      .doesNotExist("doesn't render conditional outlet");

    await click(".say-hello");
    assert.dom(".hello-result").hasText("hello!", "actions delegate properly");

    await click(".say-hello-using-this");
    assert
      .dom(".hello-result")
      .hasText(
        "hello!hello!",
        "actions are made available on `this` and are bound correctly"
      );

    await click(".say-hi");
    assert.dom(".hi-result").hasText("hi!", "actions delegate properly");
  });

  module(
    "as a wrapper around a default core implementation",
    function (innerHooks) {
      innerHooks.beforeEach(function () {
        this.consoleErrorStub = sinon.stub(console, "error");

        this.set("shouldDisplay", false);
        this.set("yieldCore", false);
        this.set("enableClashingConnector", false);

        registerTemporaryModule(
          `${CLASS_PREFIX}/outlet-with-default/my-connector`,
          {
            shouldRender(args) {
              return args.shouldDisplay;
            },
          }
        );

        registerTemporaryModule(
          `${CLASS_PREFIX}/outlet-with-default/clashing-connector`,
          {
            shouldRender(args) {
              return args.enableClashingConnector;
            },
          }
        );

        this.template = hbs`
          <PluginOutlet
            @name="outlet-with-default"
            @outletArgs={{hash
              shouldDisplay=this.shouldDisplay
              yieldCore=this.yieldCore
              enableClashingConnector=this.enableClashingConnector
            }}
          >
            <span class="result">Core implementation</span>
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

      test("can render content in a automatic outlet generated before the wrapped content", async function (assert) {
        registerTemporaryModule(
          `${TEMPLATE_PREFIX}/outlet-with-default__before/my-connector`,
          hbs`
            <span class="before-result">Before wrapped content</span>
          `
        );

        await render(hbs`
          <PluginOutlet
            @name="outlet-with-default"
            @outletArgs={{hash shouldDisplay=true}}
          >
            <span class="result">Core implementation</span>
          </PluginOutlet>
        `);

        assert.dom(".result").hasText("Plugin implementation");
        assert.dom(".before-result").hasText("Before wrapped content");
      });

      test("can render multiple connector `before` the same wrapped content", async function (assert) {
        registerTemporaryModule(
          `${TEMPLATE_PREFIX}/outlet-with-default__before/my-connector`,
          hbs`
            <span class="before-result">First connector before the wrapped
              content</span>
          `
        );
        registerTemporaryModule(
          `${TEMPLATE_PREFIX}/outlet-with-default__before/my-connector2`,
          hbs`
            <span class="before-result2">Second connector before the wrapped
              content</span>
          `
        );

        await render(hbs`
          <PluginOutlet
            @name="outlet-with-default"
            @outletArgs={{hash shouldDisplay=true}}
          >
            <span class="result">Core implementation</span>
          </PluginOutlet>
        `);

        assert.dom(".result").hasText("Plugin implementation");
        assert
          .dom(".before-result")
          .hasText("First connector before the wrapped content");
        assert
          .dom(".before-result2")
          .hasText("Second connector before the wrapped content");
      });

      test("can render content in a automatic outlet generated after the wrapped content", async function (assert) {
        registerTemporaryModule(
          `${TEMPLATE_PREFIX}/outlet-with-default__after/my-connector`,
          hbs`
            <span class="after-result">After wrapped content</span>
          `
        );

        await render(hbs`
          <PluginOutlet
            @name="outlet-with-default"
            @outletArgs={{hash shouldDisplay=true}}
          >
            <span class="result">Core implementation</span>
          </PluginOutlet>
        `);

        assert.dom(".result").hasText("Plugin implementation");
        assert.dom(".after-result").hasText("After wrapped content");
      });

      test("can render multiple connector `after` the same wrapped content", async function (assert) {
        registerTemporaryModule(
          `${TEMPLATE_PREFIX}/outlet-with-default__after/my-connector`,
          hbs`
            <span class="after-result">First connector after the wrapped content</span>
          `
        );
        registerTemporaryModule(
          `${TEMPLATE_PREFIX}/outlet-with-default__after/my-connector2`,
          hbs`
            <span class="after-result2">Second connector after the wrapped
              content</span>
          `
        );

        await render(hbs`
          <PluginOutlet
            @name="outlet-with-default"
            @outletArgs={{hash shouldDisplay=true}}
          >
            <span class="result">Core implementation</span>
          </PluginOutlet>
        `);

        assert.dom(".result").hasText("Plugin implementation");
        assert
          .dom(".after-result")
          .hasText("First connector after the wrapped content");
        assert
          .dom(".after-result2")
          .hasText("Second connector after the wrapped content");
      });
    }
  );

  test("Renders wrapped implementation if no connectors are registered", async function (assert) {
    await render(<template>
      <PluginOutlet @name="outlet-with-no-registrations">
        <span class="result">Core implementation</span>
      </PluginOutlet>
    </template>);

    assert.dom(".result").hasText("Core implementation");
  });

  test("Reevaluates shouldRender for argument changes", async function (assert) {
    this.set("shouldDisplay", false);
    await render(hbs`
      <PluginOutlet
        @name="test-name"
        @outletArgs={{hash shouldDisplay=this.shouldDisplay}}
      />
    `);
    assert
      .dom(".conditional-render")
      .doesNotExist("doesn't render conditional outlet");

    this.set("shouldDisplay", true);
    await settled();
    assert.dom(".conditional-render").exists("renders conditional outlet");
  });

  test("Reevaluates shouldRender for other autotracked changes", async function (assert) {
    await render(hbs`<PluginOutlet @name="test-name" />`);
    assert
      .dom(".conditional-render")
      .doesNotExist("doesn't render conditional outlet");

    getOwner(this).lookup("service:site-settings").always_display = true;
    await settled();
    assert.dom(".conditional-render").exists("renders conditional outlet");
  });

  test("shouldRender receives an owner argument", async function (assert) {
    await render(hbs`<PluginOutlet @name="test-name" />`);
    assert
      .dom(".conditional-render")
      .doesNotExist("doesn't render conditional outlet");

    getOwner(this).lookup("service:site-settings").alternativeAccess = true;
    await settled();
    assert.dom(".conditional-render").exists("renders conditional outlet");
  });

  test("Other outlets are not re-rendered", async function (assert) {
    this.set("shouldDisplay", false);
    await render(hbs`
      <PluginOutlet
        @name="test-name"
        @outletArgs={{hash shouldDisplay=this.shouldDisplay}}
      />
    `);

    const otherOutletElement = query(".hello-username");
    otherOutletElement.someUniqueProperty = true;

    this.set("shouldDisplay", true);
    await settled();
    assert.dom(".conditional-render").exists("renders conditional outlet");

    assert.true(
      query(".hello-username").someUniqueProperty,
      "other outlet is left untouched"
    );
  });

  module("deprecated arguments", function (innerHooks) {
    innerHooks.beforeEach(function () {
      this.consoleWarnStub = sinon.stub(console, "warn");
      disableRaiseOnDeprecation();
    });

    innerHooks.afterEach(function () {
      this.consoleWarnStub.restore();
      enableRaiseOnDeprecation();
    });

    test("deprecated parameters with default message", async function (assert) {
      await render(<template>
        <PluginOutlet
          @name="test-name"
          @deprecatedArgs={{hash
            shouldDisplay=(deprecatedOutletArgument value=true)
          }}
        />
      </template>);

      // deprecated argument still works
      assert.dom(".conditional-render").exists("renders conditional outlet");

      assert.strictEqual(
        this.consoleWarnStub.callCount,
        1,
        "console warn was called once"
      );
      assert.strictEqual(
        this.consoleWarnStub.calledWith(
          "Deprecation notice: outlet arg `shouldDisplay` is deprecated on the outlet `test-name` [deprecation id: discourse.plugin-connector.deprecated-arg]"
        ),
        true,
        "logs the default message to the console"
      );
    });

    test("deprecated parameters with custom deprecation data", async function (assert) {
      await render(<template>
        <PluginOutlet
          @name="test-name"
          @deprecatedArgs={{hash
            shouldDisplay=(deprecatedOutletArgument
              value=true
              message="The 'shouldDisplay' is deprecated on this test"
              id="discourse.plugin-connector.deprecated-arg.test"
              since="3.3.0.beta4-dev"
              dropFrom="3.4.0"
            )
          }}
        />
      </template>);

      // deprecated argument still works
      assert.dom(".conditional-render").exists("renders conditional outlet");

      assert.strictEqual(
        this.consoleWarnStub.callCount,
        1,
        "console warn was called once"
      );
      assert.strictEqual(
        this.consoleWarnStub.calledWith(
          sinon.match(/The 'shouldDisplay' is deprecated on this test/)
        ),
        true,
        "logs the custom deprecation message to the console"
      );
      assert.strictEqual(
        this.consoleWarnStub.calledWith(
          sinon.match(
            /deprecation id: discourse.plugin-connector.deprecated-arg.test/
          )
        ),
        true,
        "logs custom deprecation id"
      );
      assert.strictEqual(
        this.consoleWarnStub.calledWith(
          sinon.match(/deprecated since Discourse 3.3.0.beta4-dev/)
        ),
        true,
        "logs deprecation since information"
      );
      assert.strictEqual(
        this.consoleWarnStub.calledWith(
          sinon.match(/removal in Discourse 3.4.0/)
        ),
        true,
        "logs dropFrom information"
      );
    });

    test("silence nested deprecations", async function (assert) {
      const deprecatedData = {
        get display() {
          deprecated("Test message", {
            id: "discourse.deprecation-that-should-not-be-logged",
          });
          return true;
        },
      };

      await render(<template>
        <PluginOutlet
          @name="test-name"
          @deprecatedArgs={{hash
            shouldDisplay=(deprecatedOutletArgument
              value=deprecatedData.display
              silence="discourse.deprecation-that-should-not-be-logged"
            )
          }}
        />
      </template>);

      // deprecated argument still works
      assert.dom(".conditional-render").exists("renders conditional outlet");

      assert.strictEqual(
        this.consoleWarnStub.callCount,
        1,
        "console warn was called once"
      );
      assert.strictEqual(
        this.consoleWarnStub.calledWith(
          sinon.match(
            /deprecation id: discourse.deprecation-that-should-not-be-logged/
          )
        ),
        false,
        "does not log silence deprecation"
      );
      assert.strictEqual(
        this.consoleWarnStub.calledWith(
          sinon.match(
            /deprecation id: discourse.plugin-connector.deprecated-arg/
          )
        ),
        true,
        "logs expected deprecation"
      );
    });

    test("unused arguments", async function (assert) {
      await render(<template>
        <PluginOutlet
          @name="test-name"
          @outletArgs={{hash shouldDisplay=true}}
          @deprecatedArgs={{hash
            argNotUsed=(deprecatedOutletArgument value=true)
          }}
        />
      </template>);

      // deprecated argument still works
      assert.dom(".conditional-render").exists("renders conditional outlet");

      assert.strictEqual(
        this.consoleWarnStub.callCount,
        0,
        "console warn not called"
      );
    });
  });
});

module(
  "Integration | Component | plugin-outlet | connector class definitions",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      registerTemporaryModule(
        `${TEMPLATE_PREFIX}/test-name/my-connector`,
        hbs`
          <span class="outletArgHelloValue">{{@outletArgs.hello}}</span>
          <span class="thisHelloValue">{{this.hello}}</span>`
      );
    });

    test("uses classic PluginConnector by default", async function (assert) {
      await render(hbs`
        <PluginOutlet @name="test-name" @outletArgs={{hash hello="world"}} />
      `);

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText("world");
    });

    test("uses templateOnly by default when @defaultGlimmer=true", async function (assert) {
      await render(hbs`
        <PluginOutlet
          @name="test-name"
          @outletArgs={{hash hello="world"}}
          @defaultGlimmer={{true}}
        />
      `);

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText(""); // `this.` unavailable in templateOnly components
    });

    test("uses simple object if provided", async function (assert) {
      this.set("someBoolean", true);

      registerTemporaryModule(`${CLASS_PREFIX}/test-name/my-connector`, {
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

      await render(hbs`
        <PluginOutlet
          @name="test-name"
          @outletArgs={{hash hello="world" someBoolean=this.someBoolean}}
        />
      `);

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText("world from setupComponent");

      this.set("someBoolean", false);
      await settled();

      assert.dom(".outletArgHelloValue").doesNotExist();
    });

    test("ignores classic hooks for glimmer components", async function (assert) {
      registerTemporaryModule(`${CLASS_PREFIX}/test-name/my-connector`, {
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
          await render(<template>
            <PluginOutlet
              @name="test-name"
              @outletArgs={{hash hello="world"}}
              @defaultGlimmer={{true}}
            />
          </template>);
        }
      );

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText("");
    });

    test("uses custom component class if provided", async function (assert) {
      this.set("someBoolean", true);

      registerTemporaryModule(
        `${CLASS_PREFIX}/test-name/my-connector`,
        class MyOutlet extends Component {
          static shouldRender(args) {
            return args.someBoolean;
          }

          get hello() {
            return this.args.outletArgs.hello + " from custom component";
          }
        }
      );

      await render(hbs`
        <PluginOutlet
          @name="test-name"
          @outletArgs={{hash hello="world" someBoolean=this.someBoolean}}
        />
      `);

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText("world from custom component");

      this.set("someBoolean", false);
      await settled();

      assert.dom(".outletArgHelloValue").doesNotExist();
    });

    test("uses custom templateOnly() if provided", async function (assert) {
      this.set("someBoolean", true);

      registerTemporaryModule(
        `${CLASS_PREFIX}/test-name/my-connector`,
        Object.assign(templateOnly(), {
          shouldRender(args) {
            return args.someBoolean;
          },
        })
      );

      await render(hbs`
        <PluginOutlet
          @name="test-name"
          @outletArgs={{hash hello="world" someBoolean=this.someBoolean}}
        />
      `);

      assert.dom(".outletArgHelloValue").hasText("world");
      assert.dom(".thisHelloValue").hasText(""); // `this.` unavailable in templateOnly components

      this.set("someBoolean", false);
      await settled();

      assert.dom(".outletArgHelloValue").doesNotExist();
    });

    module("deprecated arguments", function (innerHooks) {
      innerHooks.beforeEach(function () {
        this.consoleWarnStub = sinon.stub(console, "warn");
        disableRaiseOnDeprecation();
      });

      innerHooks.afterEach(function () {
        this.consoleWarnStub.restore();
        enableRaiseOnDeprecation();
      });

      test("using classic PluginConnector by default", async function (assert) {
        await render(hbs`
        <PluginOutlet @name="test-name" @deprecatedArgs={{hash hello=(deprecated-outlet-argument value="world")}} />
      `);

        // deprecated argument still works
        assert.dom(".outletArgHelloValue").hasText("world");
        assert.dom(".thisHelloValue").hasText("world");

        assert.strictEqual(
          this.consoleWarnStub.callCount,
          2,
          "console warn was called twice"
        );
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            "Deprecation notice: outlet arg `hello` is deprecated on the outlet `test-name` [deprecation id: discourse.plugin-connector.deprecated-arg]"
          ),
          true,
          "logs the expected message for @outletArgs.hello"
        );
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            "Deprecation notice: outlet arg `hello` is deprecated on the outlet `test-name` [used on connector discourse/plugins/some-plugin/templates/connectors/test-name/my-connector] [deprecation id: discourse.plugin-connector.deprecated-arg]"
          ),
          true,
          "logs the expected message for this.hello"
        );
      });

      test("using templateOnly by default when @defaultGlimmer=true", async function (assert) {
        await render(hbs`
        <PluginOutlet
          @name="test-name"
          @deprecatedArgs={{hash hello=(deprecated-outlet-argument value="world")}}
          @defaultGlimmer={{true}}
        />
      `);

        // deprecated argument still works
        assert.dom(".outletArgHelloValue").hasText("world");
        assert.dom(".thisHelloValue").hasText(""); // `this.` unavailable in templateOnly components

        assert.strictEqual(
          this.consoleWarnStub.callCount,
          1,
          "console warn was called once"
        );
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            "Deprecation notice: outlet arg `hello` is deprecated on the outlet `test-name` [deprecation id: discourse.plugin-connector.deprecated-arg]"
          ),
          true,
          "logs the expected message for @outletArgs.hello"
        );
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            "Deprecation notice: outlet arg `hello` is deprecated on the outlet `test-name` [used on connector discourse/plugins/some-plugin/templates/connectors/test-name/my-connector] [deprecation id: discourse.plugin-connector.deprecated-arg]"
          ),
          false,
          "does not log the message for this.hello"
        );
      });

      test("using simple object when provided", async function (assert) {
        registerTemporaryModule(`${CLASS_PREFIX}/test-name/my-connector`, {
          setupComponent(args, component) {
            component.reopen({
              get hello() {
                return args.hello + " from setupComponent";
              },
            });
          },
        });

        await render(hbs`
        <PluginOutlet @name="test-name" @deprecatedArgs={{hash hello=(deprecated-outlet-argument value="world")}} />
      `);

        // deprecated argument still works
        assert.dom(".outletArgHelloValue").hasText("world");
        assert.dom(".thisHelloValue").hasText("world from setupComponent");

        assert.strictEqual(
          this.consoleWarnStub.callCount,
          2,
          "console warn was called twice"
        );
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            "Deprecation notice: outlet arg `hello` is deprecated on the outlet `test-name` [deprecation id: discourse.plugin-connector.deprecated-arg]"
          ),
          true,
          "logs the expected message for @outletArgs.hello"
        );
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            "Deprecation notice: outlet arg `hello` is deprecated on the outlet `test-name` [used on connector discourse/plugins/some-plugin/connectors/test-name/my-connector] [deprecation id: discourse.plugin-connector.deprecated-arg]"
          ),
          true,
          "logs the expected message for this.hello"
        );
      });

      test("using custom component class if provided", async function (assert) {
        registerTemporaryModule(
          `${CLASS_PREFIX}/test-name/my-connector`,
          class MyOutlet extends Component {
            get hello() {
              return this.args.outletArgs.hello + " from custom component";
            }
          }
        );

        await render(hbs`
        <PluginOutlet @name="test-name" @deprecatedArgs={{hash hello=(deprecated-outlet-argument value="world")}} />
      `);

        // deprecated argument still works
        assert.dom(".outletArgHelloValue").hasText("world");
        assert.dom(".thisHelloValue").hasText("world from custom component");

        assert.strictEqual(
          this.consoleWarnStub.callCount,
          2,
          "console warn was called twice"
        );
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            "Deprecation notice: outlet arg `hello` is deprecated on the outlet `test-name` [deprecation id: discourse.plugin-connector.deprecated-arg]"
          ),
          true,
          "logs the expected message for @outletArgs.hello"
        );
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            "Deprecation notice: outlet arg `hello` is deprecated on the outlet `test-name` [deprecation id: discourse.plugin-connector.deprecated-arg]"
          ),
          true,
          "logs the expected message for this.hello"
        );
      });

      test("using custom templateOnly() if provided", async function (assert) {
        registerTemporaryModule(
          `${CLASS_PREFIX}/test-name/my-connector`,
          templateOnly()
        );

        await render(hbs`
        <PluginOutlet @name="test-name" @deprecatedArgs={{hash hello=(deprecated-outlet-argument value="world")}} />
      `);

        // deprecated argument still works
        assert.dom(".outletArgHelloValue").hasText("world");
        assert.dom(".thisHelloValue").hasText(""); // `this.` unavailable in templateOnly components

        assert.strictEqual(
          this.consoleWarnStub.callCount,
          1,
          "console warn was called twice"
        );
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            "Deprecation notice: outlet arg `hello` is deprecated on the outlet `test-name` [deprecation id: discourse.plugin-connector.deprecated-arg]"
          ),
          true,
          "logs the expected message for @outletArgs.hello"
        );
      });

      test("unused arguments", async function (assert) {
        await render(hbs`
          <PluginOutlet @name="test-name" @outletArgs={{hash hello="world"}} @deprecatedArgs={{hash argNotUsed=(deprecated-outlet-argument value="not used")}} />
        `);

        // deprecated argument still works
        assert.dom(".outletArgHelloValue").hasText("world");
        assert.dom(".thisHelloValue").hasText("world");

        assert.strictEqual(
          this.consoleWarnStub.callCount,
          0,
          "console warn was called twice"
        );
      });
    });
  }
);

module(
  "Integration | Component | plugin-outlet | gjs class definitions",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      registerTemporaryModule(
        `${CLASS_PREFIX}/test-name/my-connector`,
        <template><span class="gjs-test">Hello world</span></template>
      );
    });

    test("detects a gjs connector with no associated template file", async function (assert) {
      await render(<template><PluginOutlet @name="test-name" /></template>);

      assert.dom(".gjs-test").hasText("Hello world");
    });
  }
);

module(
  "Integration | Component | plugin-outlet | extraConnectorComponent",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      extraConnectorComponent("test-name", <template>
        <span class="gjs-test">Hello world from gjs</span>
      </template>);
    });

    test("renders the component in the outlet", async function (assert) {
      await render(<template><PluginOutlet @name="test-name" /></template>);
      assert.dom(".gjs-test").hasText("Hello world from gjs");
    });

    test("throws errors for invalid components", function (assert) {
      assert.throws(() => {
        extraConnectorComponent("test-name/blah", <template>
          hello world
        </template>);
      }, /invalid outlet name/);

      assert.throws(() => {
        extraConnectorComponent("test-name", {});
      }, /klass is not an Ember component/);

      assert.throws(() => {
        extraConnectorComponent("test-name", class extends Component {});
      }, /connector component has no associated template/);
    });
  }
);

module("Integration | Component | plugin-outlet | tagName", function (hooks) {
  setupRenderingTest(hooks);

  test("supports the `@tagName` argument", async function (assert) {
    await withSilencedDeprecationsAsync(
      "discourse.plugin-outlet-tag-name",
      async () =>
        await render(<template>
          <PluginOutlet @name="test-name" @tagName="div" />
        </template>)
    );
    assert.dom("div").exists();
  });
});

module(
  "Integration | Component | plugin-outlet | legacy extraConnectorClass",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      registerTemporaryModule(
        `${TEMPLATE_PREFIX}/test-name/my-legacy-connector`,
        hbs`
          <span class="legacy-test">Hello world {{this.someVar}}</span>
        `
      );

      withSilencedDeprecations(
        "discourse.register-connector-class-legacy",
        () =>
          extraConnectorClass("test-name/my-legacy-connector", {
            setupComponent(outletArgs, component) {
              component.set("someVar", "from legacy");
            },
          })
      );
    });

    test("links up template with extra connector class", async function (assert) {
      await render(hbs`<PluginOutlet @name="test-name" />`);
      assert.dom(".legacy-test").hasText("Hello world from legacy");
    });
  }
);
