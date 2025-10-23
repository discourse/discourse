import { fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import NumberField from "discourse/components/number-field";
import { withSilencedDeprecationsAsync } from "discourse/lib/deprecated";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | number-field", function (hooks) {
  setupRenderingTest(hooks);

  test("number field", async function (assert) {
    this.set("value", 123);

    await withSilencedDeprecationsAsync("discourse.number-field", async () => {
      const self = this;

      await render(
        <template>
          <NumberField @value={{self.value}} @classNames="number-field-test" />
        </template>
      );
    });

    await fillIn(".number-field-test", "33");

    assert.strictEqual(
      this.get("value"),
      33,
      "value is changed when the input is a valid number"
    );

    await fillIn(".number-field-test", "");
    await triggerKeyEvent(".number-field-test", "keydown", 66); // b

    assert.strictEqual(
      this.get("value"),
      "",
      "value is cleared when the input is NaN"
    );
  });

  test("number field | min value", async function (assert) {
    this.set("value", "");

    await withSilencedDeprecationsAsync("discourse.number-field", async () => {
      const self = this;

      await render(
        <template>
          <NumberField
            @value={{self.value}}
            @classNames="number-field-test"
            @min="1"
          />
        </template>
      );
    });

    await triggerKeyEvent(".number-field-test", "keydown", 189); // -
    await triggerKeyEvent(".number-field-test", "keydown", 49); // 1

    assert.strictEqual(
      this.get("value"),
      "",
      "value is cleared when the input is less than the min"
    );

    await withSilencedDeprecationsAsync("discourse.number-field", async () => {
      const self = this;

      await render(
        <template>
          <NumberField
            @value={{self.value}}
            @classNames="number-field-test"
            @min="-10"
          />
        </template>
      );
    });

    await fillIn(".number-field-test", "-1");

    assert.strictEqual(
      this.get("value"),
      -1,
      "negative input allowed when min is negative"
    );
  });
});
