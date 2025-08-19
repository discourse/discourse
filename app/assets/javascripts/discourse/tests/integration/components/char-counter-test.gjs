import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CharCounter from "discourse/components/char-counter";
import withEventValue from "discourse/helpers/with-event-value";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | char-counter", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the number of characters", async function (assert) {
    const self = this;

    this.value = "Hello World";
    this.max = 12;

    await render(
      <template>
        <CharCounter @value={{self.value}} @max={{self.max}} />
      </template>
    );

    assert.dom(this.element).includesText("11/12");
  });

  test("updating value updates counter", async function (assert) {
    const self = this;

    this.max = 50;

    await render(
      <template>
        <CharCounter @value={{self.charCounterContent}} @max={{self.max}}>
          <textarea
            {{on "input" (withEventValue (fn (mut self.charCounterContent)))}}
          ></textarea>
        </CharCounter>
      </template>
    );

    assert
      .dom(this.element)
      .includesText("/50", "initial value appears as expected");

    await fillIn("textarea", "Hello World, this is a longer string");

    assert
      .dom(this.element)
      .includesText("36/50", "updated value appears as expected");
  });

  test("exceeding max length", async function (assert) {
    const self = this;

    this.max = 10;
    this.value = "Hello World";

    await render(
      <template>
        <CharCounter @value={{self.value}} @max={{self.max}} />
      </template>
    );

    assert.dom(".char-counter.exceeded").exists("exceeded class is applied");
  });
});
