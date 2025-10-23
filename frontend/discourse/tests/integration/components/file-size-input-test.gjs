import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import FileSizeInput from "admin/components/file-size-input";

module("Integration | Component | file-size-input", function (hooks) {
  setupRenderingTest(hooks);

  test("file size unit selector kb", async function (assert) {
    const self = this;

    this.set("value", 1023);
    this.set("max", 4096);
    this.set("onChangeSize", () => {});
    this.set("setValidationMessage", () => {});

    await render(
      <template>
        <FileSizeInput
          @sizeValueKB={{readonly self.value}}
          class="file-size-input-test"
          @onChangeSize={{self.onChangeSize}}
          @setValidationMessage={{self.setValidationMessage}}
          @max="4096"
        />
      </template>
    );

    assert.dom(".file-size-input").hasValue("1023", "value is present");
    assert.strictEqual(
      selectKit(".file-size-unit-selector").header().value(),
      "kb",
      "the default unit is kb"
    );
  });

  test("file size unit is mb when the starting value is 1mb or more", async function (assert) {
    const self = this;

    this.set("value", 1024);
    this.set("onChangeSize", () => {});
    this.set("setValidationMessage", () => {});

    await render(
      <template>
        <FileSizeInput
          @sizeValueKB={{readonly self.value}}
          class="file-size-input-test"
          @onChangeSize={{self.onChangeSize}}
          @setValidationMessage={{self.setValidationMessage}}
          @max="4096"
        />
      </template>
    );

    assert.dom(".file-size-input").hasValue("1", "value is present");
    assert.strictEqual(
      selectKit(".file-size-unit-selector").header().value(),
      "mb",
      "the default unit is mb"
    );
  });

  test("file size unit is gb when the starting value is 1gb or more", async function (assert) {
    const self = this;

    this.set("value", 1024 * 1024);
    this.set("onChangeSize", () => {});
    this.set("setValidationMessage", () => {});

    await render(
      <template>
        <FileSizeInput
          @sizeValueKB={{readonly self.value}}
          class="file-size-input-test"
          @onChangeSize={{self.onChangeSize}}
          @setValidationMessage={{self.setValidationMessage}}
          @max="4096"
        />
      </template>
    );

    assert.dom(".file-size-input").hasValue("1", "value is present");
    assert.strictEqual(
      selectKit(".file-size-unit-selector").header().value(),
      "gb",
      "the default unit is gb"
    );
  });

  test("file size unit selector", async function (assert) {
    const self = this;

    this.set("value", 4096);
    this.set("max", 8192);
    this.set("onChangeSize", () => {});
    this.set("setValidationMessage", () => {});

    await render(
      <template>
        <FileSizeInput
          @sizeValueKB={{readonly self.value}}
          class="file-size-input-test"
          @onChangeSize={{self.onChangeSize}}
          @setValidationMessage={{self.setValidationMessage}}
          @max="4096"
        />
      </template>
    );

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
    const self = this;

    this.set("value", 4096);
    this.set("max", 8192);
    this.set("min", 2048);
    this.set("onChangeSize", () => {});

    let setValidationMessage = (message) => {
      this.set("message", message);
    };
    this.set("setValidationMessage", setValidationMessage);

    await render(
      <template>
        <FileSizeInput
          @sizeValueKB={{readonly self.value}}
          class="file-size-input-test"
          @onChangeSize={{self.onChangeSize}}
          @setValidationMessage={{self.setValidationMessage}}
          @max={{self.max}}
          @min={{self.min}}
        />
      </template>
    );

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

    await fillIn(".file-size-input", 1);

    assert.strictEqual(
      this.message,
      "1 MB is smaller than the min allowed 2 MB",
      "A message is showed when the input is smaller than the min"
    );
  });
});
