import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { withSilencedDeprecationsAsync } from "discourse/lib/deprecated";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { registerTemporaryModule } from "../helpers/temporary-module-helper";

module("Integration | Initializers | plugin-component-templates", function () {
  module("template-only component definition behaviour", function (hooks) {
    hooks.beforeEach(() => {
      registerTemporaryModule(
        `discourse/plugins/some-plugin-name/discourse/templates/components/plugin-template-only-definition`,
        hbs`classic component`
      );
    });

    setupRenderingTest(hooks);

    test("treats plugin template-only definition as classic component", async function (assert) {
      await withSilencedDeprecationsAsync(
        "component-template-resolving",
        async () => {
          await render(hbs`<PluginTemplateOnlyDefinition class='test-class'/>`);
          assert
            .dom("div.test-class")
            .hasText("classic component", "renders as classic component");
        }
      );
    });
  });
});
