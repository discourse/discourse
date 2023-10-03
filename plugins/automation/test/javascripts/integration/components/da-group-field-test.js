import { module, test } from "qunit";
import { hbs } from "ember-cli-htmlbars";
import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "discourse/plugins/discourse-automation/discourse/lib/fabricators";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | da-group-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = fabricators.automation();

    pretender.get("/groups/search.json", () => {
      return response([
        {
          id: 1,
          name: "cats",
          flair_url: "fa-bars",
          flair_bg_color: "CC000A",
          flair_color: "FFFFFA",
        },
      ]);
    });
  });

  test("set value", async function (assert) {
    this.field = fabricators.field({ component: "group" });

    await render(
      hbs`<AutomationField @automation={{this.automation}} @field={{this.field}} />`
    );

    await selectKit().expand();
    await selectKit().selectRowByValue(1);

    assert.strictEqual(this.field.metadata.value, 1);
  });
});
