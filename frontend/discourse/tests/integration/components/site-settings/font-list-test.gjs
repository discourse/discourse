import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import FontList from "discourse/admin/components/site-settings/font-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";

module("Integration | Component | SiteSettings | FontList", function (hooks) {
  setupRenderingTest(hooks);

  test("shows each font in its own typeface and reports the pick with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = {
      setting: "heading_font",
      choices: [
        { value: "arial", name: "Arial" },
        { value: "times_new_roman", name: "Times New Roman" },
      ],
    };
    const changes = [];
    const changeValue = (value) => changes.push(value);

    await render(
      <template>
        <FontList
          @changeValueCallback={{changeValue}}
          @label="Heading font"
          @setting={{setting}}
          @value="arial"
        />
      </template>
    );

    assert.dom(".d-select").hasAttribute("data-name", "Arial");
    assert
      .dom(".d-select [role='combobox']")
      .hasAria("label", "Heading font", "the picker is named");
    assert
      .dom(".d-select")
      .hasClass("body-font-arial", "the held font is drawn in its typeface");

    await dSelect(".d-select").select("times_new_roman");
    assert.deepEqual(changes, ["times_new_roman"], "reports the key");
  });

  test("can't be changed while disabled with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = {
      setting: "base_font",
      choices: [{ value: "arial", name: "Arial" }],
    };
    const noop = () => {};

    await render(
      <template>
        <FontList
          @changeValueCallback={{noop}}
          @disabled={{true}}
          @setting={{setting}}
          @value="arial"
        />
      </template>
    );

    assert.dom(".d-select [role='combobox']").isDisabled();
  });
});
