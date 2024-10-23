import EmberObject from "@ember/object";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | compact-list site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("mandatory values", async function (assert) {
    this.set(
      "setting",
      EmberObject.create({
        allowsNone: undefined,
        category: "foo",
        description: "Choose setting",
        overridden: false,
        placeholder: null,
        preview: null,
        secret: false,
        setting: "foo_bar",
        type: "compact_list",
        validValues: undefined,
        default: "admin",
        mandatory_values: "admin",
        value: "admin|moderator",
      })
    );

    await render(hbs`<SiteSetting @setting={{this.setting}} />`);

    const subject = selectKit(".list-setting");

    await subject.expand();

    assert.dom(".selected-content button").hasClass("disabled");
  });
});
