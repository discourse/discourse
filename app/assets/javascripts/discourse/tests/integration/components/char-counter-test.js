import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fillIn, render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | char-counter", function (hooks) {
  setupRenderingTest(hooks);

  test("character counter shows the number of characters in value property", async function (assert) {
    this.value = "Hello World";
    this.max = 12;
    await render(
      hbs`<CharCounter @value={{this.value}} @max={{this.max}}></CharCounter>`
    );
    assert.strictEqual("11/12", this.element.innerText);
  });

  test("updating value with textarea updates counter", async function (assert) {
    this.max = 50;

    await render(
      hbs`<CharCounter @value={{this.charCounterContent}} @max={{this.max}}><textarea {{on "input" (action (mut this.charCounterContent) value="target.value")}}></textarea></CharCounter>`
    );
    assert.strictEqual(
      "/50",
      this.element.innerText.trim(),
      "initial value appears as expected"
    );
    await fillIn("textarea", "Hello World, this is a longer string");

    assert.strictEqual(
      "36/50",
      this.element.innerText.trim(),
      "updated value appears as expected"
    );
  });

  test("exceeding max applies classes", async function (assert) {
    this.max = 10;
    this.value = "Hello World";

    await render(
      hbs`<CharCounter @value={{this.value}} @max={{this.max}}></CharCounter>`
    );

    assert.strictEqual(
      query(".char-counter").classList.contains("exceeded"),
      true,
      "exceeded styling is applied when value exceeds max"
    );
  });
});
