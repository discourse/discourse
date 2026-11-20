import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import Enum from "discourse/admin/components/site-settings/enum";
import SiteSetting from "discourse/admin/models/site-setting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | SiteSettings | Enum", function (hooks) {
  setupRenderingTest(hooks);

  test("reports the picked value and follows @value", async function (assert) {
    const settingValue = tracked("simple");
    const setting = SiteSetting.create({
      setting: "tag_style",
      type: "enum",
      valid_values: [
        { name: "Simple", value: "simple" },
        { name: "Box", value: "box" },
      ],
    });
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      settingValue.value = value;
    };

    await render(
      <template>
        <Enum
          @changeValueCallback={{changeValue}}
          @setting={{setting}}
          @value={{settingValue.value}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue("box");

    assert.deepEqual(changes, ["box"], "reports the picked value");

    settingValue.value = "simple";
    await settled();

    assert.strictEqual(
      selectKit().header().value(),
      "simple",
      "renders a value set by the caller"
    );
  });

  test("picks with the new select controls, keeping each value's type", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const settingValue = tracked(5);
    const setting = SiteSetting.create({
      setting: "my_number_enum",
      type: "enum",
      valid_values: ["", { name: "Five", value: 5 }, { name: "Six", value: 6 }],
    });
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      settingValue.value = value;
    };

    await render(
      <template>
        <Enum
          @changeValueCallback={{changeValue}}
          @label="My number enum"
          @setting={{setting}}
          @value={{settingValue.value}}
        />
      </template>
    );

    assert.dom(".d-select").hasAttribute("data-name", "Five");
    assert
      .dom(".d-select input[role='combobox']")
      .hasAria("label", "My number enum");

    await dSelect(".d-select").select("6");
    assert.deepEqual(changes, [6], "reports the choice's own value");

    settingValue.value = 5;
    await settled();
    assert
      .dom(".d-select")
      .hasAttribute("data-name", "Five", "follows a value set by the caller");

    await dSelect(".d-select").open();
    await click("[role='option'].--none");
    assert.deepEqual(
      changes,
      [6, null],
      "a blank valid value offers none, which reports no value"
    );
  });

  test("is disabled with its setting under the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = SiteSetting.create({
      setting: "tag_style",
      type: "enum",
      valid_values: [{ name: "Simple", value: "simple" }],
    });
    const noop = () => {};

    await render(
      <template>
        <Enum
          @changeValueCallback={{noop}}
          @disabled={{true}}
          @setting={{setting}}
          @value="simple"
        />
      </template>
    );

    assert.dom(".d-select input[role='combobox']").isDisabled();
  });

  test("can be cleared when its default is blank, with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = SiteSetting.create({
      setting: "onebox_locale",
      type: "enum",
      default: "",
      valid_values: [
        { name: "English", value: "en" },
        { name: "French", value: "fr" },
      ],
    });
    const changes = [];
    const changeValue = (value) => changes.push(value);

    await render(
      <template>
        <Enum
          @changeValueCallback={{changeValue}}
          @setting={{setting}}
          @value="fr"
        />
      </template>
    );

    await dSelect(".d-select").clear();
    assert.deepEqual(changes, [null], "clearing restores the blank value");
  });

  test("can't be cleared when its default is a value, with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = SiteSetting.create({
      setting: "tag_style",
      type: "enum",
      default: "simple",
      valid_values: [
        { name: "Simple", value: "simple" },
        { name: "Box", value: "box" },
      ],
    });
    const noop = () => {};

    await render(
      <template>
        <Enum @changeValueCallback={{noop}} @setting={{setting}} @value="box" />
      </template>
    );

    assert.dom(".d-select__clear").doesNotExist();
  });
});
