import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import {
  blur,
  click,
  fillIn,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import ValueList from "discourse/admin/components/value-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

module("Integration | Component | ValueList", function (hooks) {
  setupRenderingTest(hooks);

  test("adding a value", async function (assert) {
    this.values = "vinkas\nosama";

    await render(<template><ValueList @values={{this.values}} /></template>);

    await selectKit().expand();
    await selectKit().fillInFilter("eviltrout");
    await selectKit().keyboard("Enter");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert.strictEqual(
      this.values,
      "vinkas\nosama\neviltrout",
      "it adds the value to the list of values"
    );
  });

  test("changing a value", async function (assert) {
    this.values = "vinkas\nosama";

    await render(<template><ValueList @values={{this.values}} /></template>);

    await fillIn(".values .value[data-index='1'] .value-input", "jarek");
    await blur(".values .value[data-index='1'] .value-input");

    assert.dom(".values .value[data-index='1'] .value-input").hasValue("jarek");
    assert.deepEqual(this.values, "vinkas\njarek", "updates the value list");
  });

  test("removing a value", async function (assert) {
    this.values = "vinkas\nosama";

    await render(<template><ValueList @values={{this.values}} /></template>);

    await click(".values .value[data-index='0'] .remove-value-btn");

    assert
      .dom(".values .value")
      .exists({ count: 1 }, "removes the value from the list of values");

    assert.strictEqual(this.values, "osama", "it removes the expected value");

    await selectKit().expand();

    assert
      .dom(".select-kit-collection li.select-kit-row span.name")
      .hasText("vinkas", "it adds the removed value to choices");
  });

  test("selecting a value", async function (assert) {
    this.values = "vinkas\nosama";
    this.choices = ["maja", "michael"];

    await render(
      <template>
        <ValueList @choices={{this.choices}} @values={{this.values}} />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue("maja");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert.strictEqual(
      this.values,
      "vinkas\nosama\nmaja",
      "it adds the value to the list of values"
    );
  });

  test("array support", async function (assert) {
    const values = tracked(["vinkas", "osama"]);

    await render(
      <template>
        <ValueList @inputType="array" @values={{values.value}} />
      </template>
    );

    await selectKit().expand();
    await selectKit().fillInFilter("eviltrout");
    await selectKit().selectRowByValue("eviltrout");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert.deepEqual(
      values.value,
      ["vinkas", "osama", "eviltrout"],
      "it adds the value to the list of values"
    );
  });

  test("delimiter support", async function (assert) {
    this.values = "vinkas|osama";

    await render(
      <template>
        <ValueList @inputDelimiter="|" @values={{this.values}} />
      </template>
    );

    await selectKit().expand();
    await selectKit().fillInFilter("eviltrout");
    await selectKit().keyboard("Enter");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert.strictEqual(
      this.values,
      "vinkas|osama|eviltrout",
      "it adds the value to the list of values"
    );
  });

  test("adds picked and typed values with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.values = "vinkas\nosama";
    this.choices = ["", "maja", "michael", "osama"];

    await render(
      <template>
        <ValueList @choices={{this.choices}} @values={{this.values}} />
      </template>
    );

    const add = ".value-list .d-select";
    await dSelect(add).open();
    assert.deepEqual(
      [...document.querySelectorAll("[role='option']")].map(
        (row) => row.dataset.value
      ),
      ["maja", "michael"],
      "offers the choices the list doesn't hold, never a blank one"
    );

    await dSelect(add).select("maja");
    assert.strictEqual(this.values, "vinkas\nosama\nmaja", "adds a choice");
    assert
      .dom(add)
      .hasAttribute("data-name", "", "the add field holds nothing afterwards");

    await dSelect(add).search("eviltrout");
    await click("[role='option'].--create");
    assert.strictEqual(
      this.values,
      "vinkas\nosama\nmaja\neviltrout",
      "adds a typed value"
    );

    await click(".values .value[data-index='0'] .remove-value-btn");
    await dSelect(add).open();
    assert
      .dom("[role='option'][data-value='vinkas']")
      .exists("offers a removed value again");
  });

  test("refuses typed values it can't store with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const allowAny = tracked(false);
    this.values = "a";

    await render(
      <template>
        <ValueList
          @allowAny={{allowAny.value}}
          @choices={{array "b"}}
          @inputDelimiter="|"
          @values={{this.values}}
        />
      </template>
    );

    const add = ".value-list .d-select";
    await dSelect(add).search("zed");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("a list that allows only its choices takes no typed value");
    assert
      .dom(".d-select__empty")
      .hasText(
        i18n("admin.site_settings.value_list.not_a_choice", { value: "zed" }),
        "and says why"
      );

    allowAny.value = true;
    await dSelect(add).search("x|y");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("a value can't hold the list's separator");
    assert
      .dom(".d-select__empty")
      .hasText(
        i18n("admin.site_settings.compact_list.not_allowed"),
        "and says why"
      );

    await dSelect(add).search("zed");
    assert.dom("[role='option'].--create").exists("any other value is taken");
  });

  test("adds typed values from a text field when the list has no choices, with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.values = "a|b";

    await render(
      <template>
        <ValueList @inputDelimiter="|" @values={{this.values}} />
      </template>
    );

    assert
      .dom(".value-list .d-select")
      .doesNotExist("no dropdown when there is nothing to suggest");
    assert
      .dom(".value-list .add-value-input")
      .hasAttribute(
        "placeholder",
        i18n("admin.site_settings.simple_list.add_item")
      );

    await fillIn(".value-list .add-value-input", "c");
    const enter = new KeyboardEvent("keydown", {
      key: "Enter",
      bubbles: true,
      cancelable: true,
    });
    document.querySelector(".value-list .add-value-input").dispatchEvent(enter);
    await settled();
    assert.strictEqual(this.values, "a|b|c", "Enter adds the value");
    assert.true(
      enter.defaultPrevented,
      "and doesn't also submit a form around the list"
    );
    assert
      .dom(".value-list .add-value-input")
      .hasValue("", "and clears the field");

    await fillIn(".value-list .add-value-input", "d");
    await click(".value-list .add-value-btn");
    assert.strictEqual(this.values, "a|b|c|d", "the button adds it too");

    await fillIn(".value-list .add-value-input", "x|y");
    assert
      .dom(".value-list .add-value-btn")
      .isDisabled("a value can't hold the list's separator");
    await triggerKeyEvent(".value-list .add-value-input", "keydown", "Enter");
    assert.strictEqual(this.values, "a|b|c|d", "Enter doesn't add it either");

    await click(".values .value[data-index='0'] .remove-value-btn");
    assert
      .dom(".value-list .d-select")
      .doesNotExist("removing a value keeps the text field");
  });

  test("names the text field and follows the disabled state with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const disabled = tracked(false);
    this.values = "a";

    await render(
      <template>
        <ValueList
          @addKey="admin.site_settings.add_url"
          @disabled={{disabled.value}}
          @values={{this.values}}
        />
      </template>
    );

    assert
      .dom(".value-list .add-value-input")
      .hasAttribute("placeholder", i18n("admin.site_settings.add_url"))
      .hasAria("label", i18n("admin.site_settings.add_url"));

    await fillIn(".value-list .add-value-input", "b");
    disabled.value = true;
    await settled();

    assert.dom(".value-list .add-value-input").isDisabled();
    assert
      .dom(".value-list .add-value-btn")
      .isDisabled("even with a value typed");
  });

  test("hides the add field once every choice is held and nothing else is allowed, with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.values = "a|b";

    await render(
      <template>
        <ValueList
          @allowAny={{false}}
          @choices={{array "a" "b"}}
          @inputDelimiter="|"
          @values={{this.values}}
        />
      </template>
    );

    assert
      .dom(".value-list .d-select")
      .doesNotExist("there is nothing left to add");
    assert.dom(".value-list .add-value-input").doesNotExist();

    await click(".values .value[data-index='0'] .remove-value-btn");
    assert
      .dom(".value-list .d-select")
      .exists("removing a choice offers it again");
  });

  test("keeps the choice field when the last choice is added, if typed values are allowed, with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.values = "a";

    await render(
      <template>
        <ValueList
          @choices={{array "a" "b"}}
          @inputDelimiter="|"
          @values={{this.values}}
        />
      </template>
    );

    await dSelect(".value-list .d-select").select("b");
    assert.strictEqual(this.values, "a|b");
    assert
      .dom(".value-list .d-select")
      .exists("the field doesn't turn into a text field under the user");

    await dSelect(".value-list .d-select").open();
    assert
      .dom(".d-select__empty")
      .hasText(
        i18n("admin.site_settings.compact_list.placeholder"),
        "with every choice held, it asks for a typed value"
      );
  });
});
