import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import SiteSettingComponent from "admin/components/site-setting";
import SiteSetting from "admin/models/site-setting";

module("Integration | Component | group-list site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    const self = this;

    this.site.groups = [
      {
        id: 1,
        name: "Donuts",
      },
      {
        id: 2,
        name: "Cheese cake",
      },
    ];

    this.set(
      "setting",
      SiteSetting.create({
        category: "foo",
        default: "",
        description: "Choose groups",
        placeholder: null,
        preview: null,
        secret: false,
        setting: "foo_bar",
        type: "group_list",
        value: "1",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    assert.strictEqual(
      subject.header().value(),
      "1",
      "it selects the setting's value"
    );

    await subject.expand();
    await subject.selectRowByValue("2");

    assert.strictEqual(
      subject.header().value(),
      "1,2",
      "it allows to select a setting from the list of choices"
    );
  });

  test("mandatory values", async function (assert) {
    const self = this;

    this.site.groups = [
      {
        id: 1,
        name: "Donuts",
      },
      {
        id: 2,
        name: "Cheese cake",
      },
    ];

    this.set(
      "setting",
      SiteSetting.create({
        category: "foo",
        default: "",
        description: "Choose groups",
        placeholder: null,
        preview: null,
        secret: false,
        setting: "foo_bar",
        type: "group_list",
        mandatory_values: "1",
        value: "1",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    assert.strictEqual(
      subject.header().value(),
      "1",
      "it selects the setting's value"
    );

    await subject.expand();
    await subject.selectRowByValue("2");

    assert.dom(".selected-content button").hasClass("disabled");
  });
});
