import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { withSilencedDeprecationsAsync } from "discourse/lib/deprecated";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { registerTemporaryModule } from "../helpers/temporary-module-helper";

module("Integration | Initializers | plugin-component-templates", function () {
  module("template-only component definition behaviour", function (hooks) {
    let restoreDeprecation;

    hooks.beforeEach(() => {
      withSilencedDeprecationsAsync(
        "discourse.component-template-resolving",
        () => new Promise((resolve) => (restoreDeprecation = resolve))
      );

      registerTemporaryModule(
        `discourse/plugins/some-plugin-name/discourse/templates/components/plugin-template-only-definition`,
        hbs`classic component`
      );

      registerTemporaryModule(
        `discourse/plugins/some-plugin-name/discourse/components/plugin-split-component`,
        class extends Component {
          get message() {
            return "non-colocated component";
          }
        }
      );

      registerTemporaryModule(
        `discourse/plugins/some-plugin-name/discourse/templates/components/plugin-split-component`,
        hbs`<div class='test-class'>{{this.message}}</div>`
      );
    });

    hooks.afterEach(() => {
      restoreDeprecation();
    });

    setupRenderingTest(hooks);

    test("treats plugin template-only definition as classic component", async function (assert) {
      await render(hbs`<PluginTemplateOnlyDefinition class='test-class'/>`);
      assert
        .dom("div.test-class")
        .hasText(
          "classic component",
          "renders lone template as classic component"
        );

      await render(hbs`<PluginSplitComponent class='test-class'/>`);
      assert
        .dom("div.test-class")
        .hasText("non-colocated component", "renders split component/template");
    });
  });
});
