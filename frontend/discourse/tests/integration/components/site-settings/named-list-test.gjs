import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import NamedList from "discourse/admin/components/site-settings/named-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | SiteSettings | NamedList", function (hooks) {
  setupRenderingTest(hooks);

  test("reports changes as a pipe-joined string and follows @value", async function (assert) {
    const settingValue = tracked("1");
    const setting = {
      setting: "named_list_setting",
      choices: [
        { name: "One", value: "1" },
        { name: "Two", value: "2" },
      ],
    };
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      settingValue.value = value;
    };

    await render(
      <template>
        <NamedList
          @changeValueCallback={{changeValue}}
          @setting={{setting}}
          @value={{settingValue.value}}
        />
      </template>
    );

    const subject = selectKit(".list-setting");
    await subject.expand();
    await subject.selectRowByValue("2");

    assert.deepEqual(changes, ["1|2"], "reports the new list");

    settingValue.value = "2";
    await settled();

    assert.strictEqual(
      subject.header().value(),
      "2",
      "renders a value set by the caller"
    );
  });
});
