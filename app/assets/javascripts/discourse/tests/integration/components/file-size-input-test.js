import { click, fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | file-size-input", function (hooks) {
  setupRenderingTest(hooks);

  test("file size unit selector", async function (assert) {
    this.set("value", 4096);
    this.set("max", 8192);
    this.set("onChangeSize", function () {});
    this.set("updateValidationMessage", function () {});

    await render(hbs`
      <FileSizeInput
        @sizeValueKB={{readonly this.value}}
        @classNames="file-size-input-test"
        @onChangeSize={{this.onChangeSize}}
        @updateValidationMessage={{this.updateValidationMessage}}
        @max=4096
        @message=""
      />
    `);

    await click(".file-size-unit-selector");

    await selectKit(".file-size-unit-selector").expand();
    await selectKit(".file-size-unit-selector").selectRowByValue("kb");

    let fileSize = this.element.querySelector(".file-size-input").value;

    assert.equal(fileSize, 4096, "value is changed when the unit is changed");

    await click(".file-size-unit-selector");

    await selectKit(".file-size-unit-selector").expand();
    await selectKit(".file-size-unit-selector").selectRowByValue("mb");

    fileSize = this.element.querySelector(".file-size-input").value;

    assert.equal(fileSize, 4, "value is changed when the unit is changed");
  });

  test("file size input error message", async function (assert) {
    this.set("value", 4096);
    this.set("max", 8192);
    this.set("onChangeSize", function () {});
    this.set("message", "");

    let updateValidationMessage = function (message) {
      this.set("message", message);
    };
    this.set("updateValidationMessage", updateValidationMessage);

    await render(hbs`
      <FileSizeInput
        @sizeValueKB={{readonly this.value}}
        @classNames="file-size-input-test"
        @onChangeSize={{this.onChangeSize}}
        @updateValidationMessage={{this.updateValidationMessage}}
        @max={{this.max}}
        @message={{this.message}}
      />
    `);

    await fillIn(".file-size-input", 12);

    assert.equal(
      this.get("message"),
      "12 MB is greater than the max allowed 8 MB",
      "A message is showed when the input is greater than the max"
    );

    await fillIn(".file-size-input", 4);

    assert.equal(
      this.get("message"),
      null,
      "The message is cleared when the input is less than the max"
    );
  });
});
