import { tracked } from "@glimmer/tracking";
import { find, focus, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";

function focusCallsOn(focusSpy, selector) {
  const element = document.querySelector(selector);
  return focusSpy
    .getCalls()
    .filter((call) => call.thisValue === element)
    .map((call) => call.args);
}

module("Integration | ui-kit | Modifier | dAutoFocus", function (hooks) {
  setupRenderingTest(hooks);

  test("focuses the element when it is inserted", async function (assert) {
    await render(<template><input class="target" {{dAutoFocus}} /></template>);

    assert.dom(".target").isFocused("the element receives focus");
    assert
      .dom(".target")
      .hasAttribute("autofocus", "", "the element is marked as autofocus");
  });

  test("focuses elements that are not form controls", async function (assert) {
    await render(
      <template>
        <h2 class="target" tabindex="-1" {{dAutoFocus}}>Title</h2>
      </template>
    );

    assert.dom(".target").isFocused("a focusable heading receives focus");
  });

  test("prevents scrolling by default", async function (assert) {
    const focusSpy = sinon.spy(HTMLElement.prototype, "focus");

    await render(<template><input class="target" {{dAutoFocus}} /></template>);

    assert.deepEqual(
      focusCallsOn(focusSpy, ".target"),
      [[{ preventScroll: true }]],
      "focus is requested without scrolling"
    );
  });

  test("allows scrolling when preventScroll is false", async function (assert) {
    const focusSpy = sinon.spy(HTMLElement.prototype, "focus");

    await render(
      <template>
        <input class="target" {{dAutoFocus preventScroll=false}} />
      </template>
    );

    assert.deepEqual(
      focusCallsOn(focusSpy, ".target"),
      [[{ preventScroll: false }]],
      "focus is requested with scrolling allowed"
    );
  });

  test("selects the text when selectText is set", async function (assert) {
    await render(
      <template>
        <input class="target" value="hello" {{dAutoFocus selectText=true}} />
      </template>
    );

    const target = find(".target");
    assert.strictEqual(target.selectionStart, 0, "selection starts at 0");
    assert.strictEqual(target.selectionEnd, 5, "selection covers the value");
  });

  test("does not select the text by default", async function (assert) {
    const selectSpy = sinon.spy(HTMLInputElement.prototype, "select");

    await render(
      <template><input class="target" value="hello" {{dAutoFocus}} /></template>
    );

    assert.true(selectSpy.notCalled, "the text is left unselected");
  });

  test("focuses only once when its arguments change", async function (assert) {
    const selectText = tracked(false);

    await render(
      <template>
        <input class="target" {{dAutoFocus selectText=selectText.value}} />
        <button class="other" type="button">Other</button>
      </template>
    );

    await focus(".other");
    selectText.value = true;
    await settled();

    assert
      .dom(".other")
      .isFocused("an update does not steal focus back to the element");
  });
});
