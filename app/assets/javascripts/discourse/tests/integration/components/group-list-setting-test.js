import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { hbs } from "ember-cli-htmlbars";
import EmberObject from "@ember/object";

module("Integration | Component | group-list site-setting", function (hooks) {
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
      EmberObject.create({
        allowsNone: undefined,
        category: "foo",
        default: "",
        description: "Choose groups",
        overridden: false,
        placeholder: null,
        preview: null,
        secret: false,
        setting: "foo_bar",
        type: "group_list",
        validValues: undefined,
        value: "1",
      })
    );

    await render(hbs`<SiteSetting @setting={{this.setting}} />`);

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
});
