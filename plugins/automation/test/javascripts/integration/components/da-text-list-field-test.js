import { module, test } from "qunit";
import { hbs } from "ember-cli-htmlbars";
import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "discourse/plugins/discourse-automation/discourse/lib/fabricators";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | da-text-list-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = fabricators.automation();
  });

  test("set value", async function (assert) {
    this.field = fabricators.field({
      component: "text_list",
    });

    await render(
      hbs`<AutomationField @automation={{this.automation}} @field={{this.field}} />`
    );
    await selectKit().expand();
    await selectKit().fillInFilter("test");
    await selectKit().selectRowByValue("test");

    assert.deepEqual(this.field.metadata.value, ["test"]);
  });
});
