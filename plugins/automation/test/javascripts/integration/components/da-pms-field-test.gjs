import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | da-pms-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();
  });

  test("set value", async function (assert) {
    this.field = new AutomationFabricators(getOwner(this)).field({
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
