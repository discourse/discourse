import { tracked } from "@glimmer/tracking";
import { click, fillIn, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSettingSimpleList from "discourse/admin/components/site-settings/simple-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | SiteSettings | SimpleList", function (hooks) {
  setupRenderingTest(hooks);

  test("reports changes as a pipe-joined string and follows @value", async function (assert) {
    const settingValue = tracked("a|b");
    const setting = {};
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      settingValue.value = value;
    };

    await render(
      <template>
        <SiteSettingSimpleList
          @changeValueCallback={{changeValue}}
          @setting={{setting}}
          @value={{settingValue.value}}
        />
      </template>
    );

    await fillIn(".add-value-input", "c");
    await click(".add-value-btn");

    assert.deepEqual(changes, ["a|b|c"], "reports the new list");

    settingValue.value = "z";
    await settled();

    assert
      .dom(".values .value-input")
      .hasValue("z", "renders a value set by the caller");
  });
});
