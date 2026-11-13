import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | DaUserField", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();

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
    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "user",
    });

    await render(
      <template>
        <AutomationField
          @automation={{this.automation}}
          @field={{this.field}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().fillInFilter("sam");
    await selectKit().selectRowByValue("sam");

    assert.strictEqual(this.field.metadata.value, "sam");
  });

  module("with the new select controls", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("set value", async function (assert) {
      this.field = new AutomationFabricators(getOwner(this)).field({
        component: "user",
      });
      this.field.metadata.value = undefined;

      await render(
        <template>
          <AutomationField
            @automation={{this.automation}}
            @field={{this.field}}
          />
        </template>
      );

      const user = dSelect(".user-field .d-select");
      await user.search("sam");
      await user.selectByName("sam");

      assert.strictEqual(this.field.metadata.value, "sam");
    });

    test("offers the trigger's contexts before any user", async function (assert) {
      this.field = new AutomationFabricators(getOwner(this)).field({
        component: "user",
        name: "creator",
        accepted_contexts: ["post_creator", "updated_user"],
      });
      this.field.metadata.value = undefined;

      await render(
        <template>
          <AutomationField
            @automation={{this.automation}}
            @field={{this.field}}
          />
        </template>
      );

      const user = dSelect(".user-field .d-select");
      await user.open();
      assert.deepEqual(
        [...document.querySelectorAll("[role='option']")].map(
          (row) => row.dataset.value
        ),
        ["post_creator", "updated_user"]
      );

      await user.select("updated_user");
      assert.strictEqual(this.field.metadata.value, "updated_user");
    });
  });
});
