import { module, test } from "qunit";
import { hbs } from "ember-cli-htmlbars";
import { click, fillIn, render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "discourse/plugins/discourse-automation/discourse/lib/fabricators";

module("Integration | Component | da-pms-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = fabricators.automation();
  });

  test("set value", async function (assert) {
    this.field = fabricators.field({
      component: "pms",
    });

    await render(
      hbs`<AutomationField @automation={{this.automation}} @field={{this.field}} />`
    );

    await click(".insert-pm");

    await fillIn(".pm-title", "title");
    await fillIn(".d-editor-input", "raw");
    await fillIn(".pm-delay", 6);
    await click(".pm-prefers-encrypt", 6);

    assert.deepEqual(this.field.metadata.value, [
      {
        delay: "6",
        prefers_encrypt: false,
        raw: "raw",
        title: "title",
      },
    ]);
  });
});
