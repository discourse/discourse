import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import DfpCategorySettingForm from "discourse/plugins/discourse-adplugin/admin/components/dfp-category-setting-form";

module("Integration | Component | DfpCategorySettingForm", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.transitions = [];
    this.owner.lookup("service:router").transitionTo = (...args) =>
      this.transitions.push(args);
    this.model = {
      setting: {
        id: 1,
        category_id: 3,
        gam_adunit: "/123456789/example.com/forums",
        gam_keywords: "sports",
        gtm_taxonomy: "forums/sports",
      },
      settings: [],
    };
  });

  test("uses the standard admin form and primary save action", async function (assert) {
    await render(
      <template><DfpCategorySettingForm @model={{this.model}} /></template>
    );

    assert.form().field("category_id").exists("the category field renders");
    assert.form().field("gam_adunit").exists("the ad unit field renders");
    assert.form().field("gam_keywords").exists("the keywords field renders");
    assert.form().field("gtm_taxonomy").exists("the taxonomy field renders");
    assert
      .dom('.dfp-category-setting-form button[type="submit"]')
      .hasClass("btn-primary", "Save uses the standard primary button style")
      .hasText("Save", "the button has a specific label");
  });

  test("saves edited values and navigates back to the list", async function (assert) {
    pretender.put(
      "/admin/plugins/pluginad/dfp_category_settings/1",
      (request) => {
        const body = new URLSearchParams(request.requestBody);

        assert.strictEqual(
          body.get("gam_keywords"),
          "sports,premium",
          "the edited keywords are submitted"
        );

        return response({
          dfp_category_setting: {
            ...this.model.setting,
            gam_keywords: "sports,premium",
          },
        });
      }
    );

    await render(
      <template><DfpCategorySettingForm @model={{this.model}} /></template>
    );

    await formKit().field("gam_keywords").fillIn("sports,premium");
    await formKit().submit();

    assert.deepEqual(
      this.transitions.map((t) => t[0]),
      ["adminPlugins.show.dfpSettings.index"],
      "navigates back to the list only after the save succeeds"
    );
  });

  test("keeps the edits and stays on the form when the save fails", async function (assert) {
    pretender.put("/admin/plugins/pluginad/dfp_category_settings/1", () =>
      response(422, { errors: ["Category has already been taken"] })
    );

    await render(
      <template><DfpCategorySettingForm @model={{this.model}} /></template>
    );

    await formKit().field("gam_keywords").fillIn("sports,premium");
    await formKit().submit();

    assert.strictEqual(
      this.transitions.length,
      0,
      "does not navigate away after a failed save"
    );
    assert.strictEqual(
      formKit().field("gam_keywords").value(),
      "sports,premium",
      "the unsaved edit is preserved so the dirty-form guard still protects it"
    );
  });
});
