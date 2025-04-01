import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import SiteSettingComponent from "admin/components/site-setting";
import SiteSetting from "admin/models/site-setting";

module("Integration | Component | compact-list site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("mandatory values", async function (assert) {
    const self = this;

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
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    await subject.expand();

    assert.dom(".selected-content button").hasClass("disabled");
  });
});
