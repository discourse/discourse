import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import List from "discourse/admin/components/site-settings/list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";

module("Integration | Component | SiteSettings | List", function (hooks) {
  setupRenderingTest(hooks);

  test("takes typed values only when the setting allows any with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = { setting: "my_list", choices: ["a", "b"] };

    await render(
      <template>
        <List @allowAny={{false}} @setting={{setting}} @value="a" />
      </template>
    );

    await dSelect(".value-list .d-select").search("zed");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("the setting allows only its choices");
  });
});
