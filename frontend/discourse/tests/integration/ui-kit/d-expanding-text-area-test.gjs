import { tracked } from "@glimmer/tracking";
import { fillIn, render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";

module("Integration | ui-kit | DExpandingTextArea", function (hooks) {
  setupRenderingTest(hooks);

  test("mirrors @value into the wrapper for sizing", async function (assert) {
    const value = tracked("first line");

    await render(
      <template><DExpandingTextArea @value={{value.value}} /></template>
    );

    assert.dom("textarea").hasValue("first line", "the textarea shows @value");
    assert
      .dom(".expanding-text-area")
      .hasAttribute(
        "data-replicated-value",
        "first line",
        "the wrapper mirrors @value"
      );

    value.value = "second line";
    await rerender();

    assert
      .dom(".expanding-text-area")
      .hasAttribute(
        "data-replicated-value",
        "second line",
        "the mirror follows @value"
      );
  });

  test("passes the deprecated args to the textarea", async function (assert) {
    await render(
      <template>
        <DExpandingTextArea
          @autocorrect="on"
          @class="custom"
          @maxlength="20"
          @name="reason"
          @rows="3"
        />
      </template>
    );

    assert
      .dom("textarea")
      .hasClass("--expandable", "the textarea keeps its own class")
      .hasClass("custom", "@class is added")
      .hasAttribute("autocorrect", "on", "@autocorrect is set")
      .hasAttribute("maxlength", "20", "@maxlength is set")
      .hasAttribute("name", "reason", "@name is set")
      .hasAttribute("rows", "3", "@rows is set");
  });

  test("attributes reach the textarea", async function (assert) {
    await render(
      <template>
        <DExpandingTextArea placeholder="Write here" rows="5" />
      </template>
    );

    assert
      .dom("textarea")
      .hasAttribute("placeholder", "Write here", "attributes are applied")
      .hasAttribute("rows", "5", "an attribute sets rows without @rows");
  });

  test("calls @input on input", async function (assert) {
    const typed = [];
    const onInput = (event) => typed.push(event.target.value);

    await render(
      <template><DExpandingTextArea @input={{onInput}} /></template>
    );
    await fillIn("textarea", "hello");

    assert.deepEqual(typed, ["hello"], "@input receives the input event");
  });

  test("focuses the textarea with @autoFocus", async function (assert) {
    await render(
      <template><DExpandingTextArea @autoFocus={{true}} /></template>
    );

    assert.dom("textarea").isFocused("the textarea takes focus");
  });
});
