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

  test("with valid_values from enum class", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
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
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    await subject.expand();

    assert.strictEqual(subject.rowByIndex(0).name(), "Model Three");
    assert.dom(".selected-content .selected-choice").exists({ count: 2 });
  });

  test("empty valid_values falls back to standard choices", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
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
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    await subject.expand();

    assert.strictEqual(subject.rowByIndex(0).name(), "c");
    assert.dom(".selected-content .selected-choice").exists({ count: 2 });
  });

  test("valid_values converts integer values to strings for comparison", async function (assert) {
    this.set(
      "setting",
      SiteSetting.create({
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
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    await subject.expand();

    // value "42" (string) should match valid_values 42 (integer)
    assert.dom(".selected-content .selected-choice").exists({ count: 1 });
    assert.strictEqual(subject.rowByIndex(0).name(), "Item Forty-Three");
  });
});
