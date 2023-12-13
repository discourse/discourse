import { click, fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | file-size-input", function (hooks) {
  setupRenderingTest(hooks);

  test("file size unit selector kb", async function (assert) {
    this.set("value", 1024);
    this.set("max", 4096);
    this.set("onChangeSize", () => {});
    this.set("updateValidationMessage", () => {});

    await render(hbs`
      <FileSizeInput
        @sizeValueKB={{readonly this.value}}
        class="file-size-input-test"
        @onChangeSize={{this.onChangeSize}}
        @updateValidationMessage={{this.updateValidationMessage}}
        @max=4096
        @message=""
      />
    `);

    assert.dom(".file-size-input").hasValue("1024", "value is present");
  });

  test("file size unit selector", async function (assert) {
    this.set("value", 4096);
    this.set("max", 8192);
    this.set("onChangeSize", () => {});
    this.set("updateValidationMessage", () => {});

    await render(hbs`
      <FileSizeInput
        @sizeValueKB={{readonly this.value}}
        class="file-size-input-test"
        @onChangeSize={{this.onChangeSize}}
        @updateValidationMessage={{this.updateValidationMessage}}
        @max=4096
        @message=""
      />
    `);

    await click(".file-size-unit-selector");

    await selectKit(".file-size-unit-selector").expand();
    await selectKit(".file-size-unit-selector").selectRowByValue("kb");

    assert
      .dom(".file-size-input")
      .hasValue("4096", "value is change when then unit is changed");

    await click(".file-size-unit-selector");

    await selectKit(".file-size-unit-selector").expand();
    await selectKit(".file-size-unit-selector").selectRowByValue("mb");

    assert
      .dom(".file-size-input")
      .hasValue("4", "value is changed when the unit is changed");

    await click(".file-size-unit-selector");

    await selectKit(".file-size-unit-selector").expand();
    await selectKit(".file-size-unit-selector").selectRowByValue("gb");

    // TODO: Implement rounding or limit to X digits.
    assert
      .dom(".file-size-input")
      .hasValue(
        "0.00390625",
        "value is changed when the unit is changed to gb"
      );

    await click(".file-size-unit-selector");

    await selectKit(".file-size-unit-selector").expand();
    await selectKit(".file-size-unit-selector").selectRowByValue("mb");

    assert
      .dom(".file-size-input")
      .hasValue(
        "4",
        "value is changed backed to original size with no decimal places"
      );
  });

  test("file size input error message", async function (assert) {
    this.set("value", 4096);
    this.set("max", 8192);
    this.set("onChangeSize", () => {});

    let updateValidationMessage = (message) => {
      this.set("message", message);
    };
    this.set("updateValidationMessage", updateValidationMessage);

    await render(hbs`
      <FileSizeInput
        @sizeValueKB={{readonly this.value}}
        class="file-size-input-test"
        @onChangeSize={{this.onChangeSize}}
        @updateValidationMessage={{this.updateValidationMessage}}
        @max={{this.max}}
        @message={{this.message}}
      />
    `);

    await fillIn(".file-size-input", 12);

    assert.strictEqual(
      this.message,
      "12 MB is greater than the max allowed 8 MB",
      "A message is showed when the input is greater than the max"
    );

    await fillIn(".file-size-input", 4);

    assert.strictEqual(
      this.message,
      null,
      "The message is cleared when the input is less than the max"
    );
  });
});
