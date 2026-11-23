import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSettingComponent from "discourse/admin/components/site-setting";
import CompactList from "discourse/admin/components/site-settings/compact-list";
import SiteSetting from "discourse/admin/models/site-setting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

module("Integration | Component | compact-list site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("mandatory values", async function (assert) {
    this.setting = SiteSetting.create({
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
    });

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    await subject.expand();

    assert.dom(".selected-content button").hasClass("disabled");
  });

  test("with valid_values from enum class", async function (assert) {
    this.setting = SiteSetting.create({
      category: "foo",
      description: "Choose LLMs",
      placeholder: null,
      preview: null,
      secret: false,
      setting: "test_llm_list",
      type: "compact_list",
      default: "",
      value: "1|2",
      valid_values: [
        { name: "Model One", value: 1 },
        { name: "Model Two", value: 2 },
        { name: "Model Three", value: 3 },
      ],
    });

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    await subject.expand();

    assert.strictEqual(subject.rowByIndex(0).name(), "Model Three");
    assert.dom(".selected-content .selected-choice").exists({ count: 2 });
  });

  test("empty valid_values falls back to standard choices", async function (assert) {
    this.setting = SiteSetting.create({
      category: "foo",
      description: "Choose items",
      placeholder: null,
      preview: null,
      secret: false,
      setting: "test_list",
      type: "compact_list",
      default: "",
      value: "a|b",
      valid_values: [],
      choices: ["a", "b", "c"],
    });

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    await subject.expand();

    assert.strictEqual(subject.rowByIndex(0).name(), "c");
    assert.dom(".selected-content .selected-choice").exists({ count: 2 });
  });

  test("valid_values converts integer values to strings for comparison", async function (assert) {
    this.setting = SiteSetting.create({
      category: "foo",
      description: "Choose items",
      placeholder: null,
      preview: null,
      secret: false,
      setting: "test_list",
      type: "compact_list",
      default: "",
      value: "42",
      valid_values: [
        { name: "Item Forty-Two", value: 42 },
        { name: "Item Forty-Three", value: 43 },
      ],
    });

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    await subject.expand();

    // value "42" (string) should match valid_values 42 (integer)
    assert.dom(".selected-content .selected-choice").exists({ count: 1 });
    assert.strictEqual(subject.rowByIndex(0).name(), "Item Forty-Three");
  });

  test("the control offers choices, takes typed entries and keeps removed ones with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const value = tracked("a|b");
    const setting = {
      setting: "foo_bar",
      choices: ["a", "b"],
      mandatory_values: "a",
    };
    const changes = [];
    const changeValue = (newValue) => {
      changes.push(newValue);
      value.value = newValue;
    };

    await render(
      <template>
        <CompactList
          @allowAny={{true}}
          @changeValueCallback={{changeValue}}
          @label="Foo bar"
          @setting={{setting}}
          @value={{value.value}}
        />
      </template>
    );

    assert
      .dom(".d-select__chip[data-value='a']")
      .hasClass("--locked", "a mandatory value can't be removed");

    await dSelect(".d-select").search("custom");
    await click("[role='option'].--create");
    await dSelect(".d-select").close();
    await dSelect(".d-select").remove("custom");
    assert.deepEqual(changes, ["a|b|custom", "a|b"], "reports each list");

    await dSelect(".d-select").open();
    assert
      .dom("[role='option'][data-value='custom']")
      .exists("a removed typed entry stays on offer");
  });

  test("the control refuses typed entries when the setting does, and follows @disabled, with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = { setting: "foo_bar", choices: ["a", "b"] };
    const disabled = tracked(false);
    const changeValue = () => {};

    await render(
      <template>
        <CompactList
          @allowAny={{false}}
          @changeValueCallback={{changeValue}}
          @disabled={{disabled.value}}
          @label="Foo bar"
          @setting={{setting}}
          @value="a"
        />
      </template>
    );

    await dSelect(".d-select").search("custom");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("no typed entry is offered");

    await dSelect(".d-select").close();
    disabled.value = true;
    await settled();
    assert
      .dom(".d-select [role='combobox']")
      .isDisabled("the picker follows the setting's disabled state");
  });

  test("the control names the query that matched no choice, with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = { setting: "foo_bar", choices: ["a", "b"] };
    const changeValue = () => {};

    await render(
      <template>
        <CompactList
          @allowAny={{false}}
          @changeValueCallback={{changeValue}}
          @label="Foo bar"
          @setting={{setting}}
          @value="a"
        />
      </template>
    );

    await dSelect(".d-select").search("zzz");
    assert
      .dom(".d-select__empty")
      .hasText(i18n("d_select.no_results_for", { query: "zzz" }));
  });

  test("the control draws no colour squares, whatever the setting is named", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = { setting: "category_colors" };
    const changeValue = () => {};

    await render(
      <template>
        <CompactList
          @allowAny={{true}}
          @changeValueCallback={{changeValue}}
          @label="Category colors"
          @setting={{setting}}
          @value="f00|nope"
        />
      </template>
    );

    assert
      .dom(".d-select__chip[data-value='f00'] .d-select__chip-label")
      .hasText("f00", "a held value shows only itself");
    assert
      .dom(".d-select__chip [style]")
      .doesNotExist("with nothing coloured beside it");
  });
});
