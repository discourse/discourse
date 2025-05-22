import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { registerTemporaryModule } from "../../helpers/temporary-module-helper";

const PREFIX = "discourse/plugins/some-plugin/templates/connectors";

module("Plugin Outlet - Decorator", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(() => {
    registerTemporaryModule(`${PREFIX}/my-outlet-name/foo`, hbs`FOO`);
    registerTemporaryModule(`${PREFIX}/my-outlet-name/bar`, hbs`BAR`);

    withPluginApi("0.8.38", (api) => {
      withSilencedDeprecations("discourse.decorate-plugin-outlet", () => {
        api.decoratePluginOutlet(
          "my-outlet-name",
          (elem, args) => {
            if (elem.classList.contains("foo")) {
              elem.style.backgroundColor = "yellow";
              elem.classList.toggle("has-value", !!args.value);
            }
          },
          { id: "yellow-decorator" }
        );
      });
    });
  });

  test("Calls the plugin callback with the rendered outlet", async function (assert) {
    await render(
      <template>
        <PluginOutlet @connectorTagName="div" @name="my-outlet-name" />
      </template>
    );

    assert.dom(".my-outlet-name-outlet.foo").exists();
    assert
      .dom(".my-outlet-name-outlet.foo")
      .hasAttribute("style", "background-color: yellow;");
    assert
      .dom(".my-outlet-name-outlet.bar")
      .doesNotHaveStyle("backgroundColor");

    await render(
      <template>
        <PluginOutlet
          @connectorTagName="div"
          @name="my-outlet-name"
          @outletArgs={{lazyHash value=true}}
        />
      </template>
    );

    assert.dom(".my-outlet-name-outlet.foo").hasClass("has-value");

    await render(
      <template>
        <PluginOutlet @connectorTagName="div" @name="my-outlet-name" />
      </template>
    );

    assert.dom(".my-outlet-name-outlet.foo").doesNotHaveClass("has-value");
  });
});
