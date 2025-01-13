import Component from "@ember/component";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import { withSilencedDeprecationsAsync } from "discourse/lib/deprecated";
import { registerTemporaryModule } from "discourse/tests/helpers/temporary-module-helper";

module("Plugin Outlet - Deprecated parentView", function (hooks) {
  setupRenderingTest(hooks);

  test("Can access parentView", async function (assert) {
    this.component = class AComponent extends Component {
      layout = hbs`<PluginOutlet @name="an-outlet" @connectorTagName="div" />`;
    };

    registerTemporaryModule(
      "discourse/templates/connectors/an-outlet/hello",
      hbs`<span class="hello-username">{{this.parentView.parentView.constructor.name}}</span>`
    );

    await withSilencedDeprecationsAsync(
      "discourse.plugin-outlet-parent-view",
      async () => {
        await render(hbs`<this.component />`);

        assert
          .dom(".hello-username")
          .hasText(
            "AComponent",
            "it renders a value from parentView.parentView"
          );
      }
    );
  });
});
