import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSettingComponent from "discourse/admin/components/site-setting";
import SiteSetting from "discourse/admin/models/site-setting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | group site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
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
        description: "Choose a group",
        placeholder: null,
        preview: null,
        secret: false,
        setting: "foo_bar",
        type: "group",
        value: "1",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    const subject = selectKit(".combo-box");

    assert.strictEqual(
      subject.header().value(),
      "1",
      "it selects the setting's value"
    );

    await subject.expand();
    await subject.selectRowByValue("2");

    assert.strictEqual(
      subject.header().value(),
      "2",
      "it allows selecting a single group from the list of choices"
    );
    assert.strictEqual(
      this.setting.buffered.get("value"),
      "2",
      "it stores the selected group id as a string"
    );

    await click(subject.header().el().querySelector(".btn-clear"));

    assert.strictEqual(
      this.setting.buffered.get("value"),
      "",
      "clearing the selection stores an empty string"
    );
  });

  test("disallowed groups", async function (assert) {
    this.site.groups = [
      {
        id: 0,
        name: "everyone",
      },
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
        description: "Choose a group",
        placeholder: null,
        preview: null,
        secret: false,
        setting: "foo_bar",
        type: "group",
        disallowed_groups: "0",
        value: "",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{this.setting}} /></template>
    );

    const subject = selectKit(".combo-box");

    await subject.expand();

    assert.false(
      subject.rowByValue("0").exists(),
      "disallowed group is not in the list"
    );
    assert.true(
      subject.rowByValue("1").exists(),
      "allowed group is in the list"
    );
    assert.true(
      subject.rowByValue("2").exists(),
      "allowed group is in the list"
    );
  });
});
