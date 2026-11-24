import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import NamedList from "discourse/admin/components/site-settings/named-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
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

  test("shows choice names and reports the list with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const settingValue = tracked("1|legacy");
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
          @allowAny={{false}}
          @changeValueCallback={{changeValue}}
          @label="Named list setting"
          @setting={{setting}}
          @value={{settingValue.value}}
        />
      </template>
    );

    assert
      .dom(".d-select")
      .hasAttribute(
        "data-name",
        "One,legacy",
        "a choice shows its name, and a held value without one shows as itself"
      );
    assert
      .dom(".d-select [role='combobox']")
      .hasAria("label", "Named list setting", "the picker is named");

    await dSelect(".d-select").select("2");
    assert.deepEqual(changes, ["1|legacy|2"], "reports the values, not names");

    settingValue.value = "2";
    await settled();
    assert
      .dom(".d-select")
      .hasAttribute("data-name", "Two", "follows a value set by the caller");
  });

  test("takes typed values only when the setting allows any with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = {
      setting: "named_list_setting",
      choices: [{ name: "One", value: "1" }],
    };
    const allowAny = tracked(false);
    const changes = [];
    const changeValue = (value) => changes.push(value);

    await render(
      <template>
        <NamedList
          @allowAny={{allowAny.value}}
          @changeValueCallback={{changeValue}}
          @setting={{setting}}
          @value="1"
        />
      </template>
    );

    await dSelect(".d-select").search("custom");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("a closed list offers no typed value");

    allowAny.value = true;
    await settled();
    await dSelect(".d-select").search("custom");
    await click("[role='option'].--create");
    assert.deepEqual(changes, ["1|custom"], "an open list takes it");
  });

  test("can't be changed while disabled with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = {
      setting: "named_list_setting",
      choices: [{ name: "One", value: "1" }],
    };
    const noop = () => {};

    await render(
      <template>
        <NamedList
          @changeValueCallback={{noop}}
          @disabled={{true}}
          @setting={{setting}}
          @value="1"
        />
      </template>
    );

    assert.dom(".d-select [role='combobox']").isDisabled();
  });
});
