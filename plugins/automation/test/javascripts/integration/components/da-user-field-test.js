import { module, test } from "qunit";
import { hbs } from "ember-cli-htmlbars";
import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "discourse/plugins/discourse-automation/discourse/lib/fabricators";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | da-user-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = fabricators.automation();

    pretender.get("/u/search/users", () =>
      response({
        users: [
          {
            username: "sam",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
        ],
      })
    );
  });

  test("set value", async function (assert) {
    this.field = fabricators.field({
      component: "user",
    });

    await render(
      hbs`<AutomationField @automation={{this.automation}} @field={{this.field}} />`
    );

    await selectKit().expand();
    await selectKit().fillInFilter("sam");
    await selectKit().selectRowByValue("sam");

    assert.strictEqual(this.field.metadata.value, "sam");
  });
});
