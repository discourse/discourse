import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import withEventValue from "discourse/helpers/with-event-value";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DCharCounter from "discourse/ui-kit/d-char-counter";

module("Integration | ui-kit | DCharCounter", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the number of characters", async function (assert) {
    this.value = "Hello World";
    this.max = 12;

    await render(
      <template>
        <DCharCounter @max={{this.max}} @value={{this.value}} />
      </template>
    );

    assert.dom(this.element).includesText("11/12");
  });

  test("updating value updates counter", async function (assert) {
    this.max = 50;

    await render(
      <template>
        <DCharCounter @max={{this.max}} @value={{this.charCounterContent}}>
          <textarea
            {{on "input" (withEventValue (fn (mut this.charCounterContent)))}}
          ></textarea>
        </DCharCounter>
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
    this.max = 10;
    this.value = "Hello World";

    await render(
      <template>
        <DCharCounter @max={{this.max}} @value={{this.value}} />
      </template>
    );

    assert.dom(".char-counter.exceeded").exists("exceeded class is applied");
  });

  test("accepts @max as a string", async function (assert) {
    await render(
      <template><DCharCounter @max="5" @value="Hello!" /></template>
    );

    assert.dom(".char-counter__ratio").hasText("6/5", "the ratio uses @max");
    assert
      .dom(".char-counter")
      .hasClass("exceeded", "a string @max is compared as a number");
  });

  test("counts a missing @value as zero", async function (assert) {
    await render(<template><DCharCounter @max={{5}} /></template>);

    assert.dom(".char-counter__ratio").hasText("0/5", "the count is zero");
    assert
      .dom(".char-counter")
      .doesNotHaveClass("exceeded", "a missing value is not exceeded");
  });
});
