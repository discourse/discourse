import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import FileSizeInput from "discourse/admin/components/file-size-input";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | FileSizeInput", function (hooks) {
  setupRenderingTest(hooks);

  for (const [sizeKB, shown, unit] of [
    [1023, "1023", "kb"],
    [1024, "1", "mb"],
    [1024 * 1024, "1", "gb"],
  ]) {
    test(`shows ${sizeKB} KB as ${shown} ${unit}`, async function (assert) {
      await render(
        <template><FileSizeInput @sizeValueKB={{sizeKB}} /></template>
      );

      assert.dom(".file-size-input").hasValue(shown);
      assert.strictEqual(
        selectKit(".file-size-unit-selector").header().value(),
        unit
      );
    });
  }

  test("file size unit selector", async function (assert) {
    this.value = 4096;
    this.max = 8192;
    this.onChangeSize = () => {};

    await render(
      <template>
        <FileSizeInput
          class="file-size-input-test"
          @max="4096"
          @onChangeSize={{this.onChangeSize}}
          @sizeValueKB={{readonly this.value}}
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
    const value = 4096;
    const max = 8192;
    const min = 2048;
    let message;
    const onChangeSize = (_size, newMessage) => {
      message = newMessage;
    };

    await render(
      <template>
        <FileSizeInput
          class="file-size-input-test"
          @max={{max}}
          @min={{min}}
          @onChangeSize={{onChangeSize}}
          @sizeValueKB={{readonly value}}
        />
      </template>
    );

    await fillIn(".file-size-input", 12);

    assert.strictEqual(
      message,
      "12 MB is greater than the max allowed 8 MB",
      "A message is showed when the input is greater than the max"
    );

    await fillIn(".file-size-input", 4);

    assert.strictEqual(
      message,
      undefined,
      "The message is cleared when the input is less than the max"
    );

    await fillIn(".file-size-input", 1);

    assert.strictEqual(
      message,
      "1 MB is smaller than the min allowed 2 MB",
      "A message is showed when the input is smaller than the min"
    );
  });
});
