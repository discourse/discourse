import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSettingComponent from "discourse/admin/components/site-setting";
import SiteSetting from "discourse/admin/models/site-setting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | compact-list site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("mandatory values", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
        category: "foo",
        description: "Choose setting",
        placeholder: null,
        preview: null,
        secret: false,
        setting: "foo_bar",
        type: "compact_list",
        default: "admin",
        mandatory_values: "admin",
        value: "admin|moderator",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    await subject.expand();

    assert.dom(".selected-content button").hasClass("disabled");
  });
});
