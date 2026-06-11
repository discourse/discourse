import { next } from "@ember/runloop";
import { fillIn, focus, render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DOtp from "discourse/ui-kit/d-otp";

module("Integration | ui-kit | DOtp", function (hooks) {
  setupRenderingTest(hooks);

  test("renders 6 slots by default", async function (assert) {
    await render(<template><DOtp /></template>);

    assert.dom(".d-otp-slot").exists({ count: 6 });
  });

  test("renders custom number of slots", async function (assert) {
    await render(<template><DOtp @slots={{8}} /></template>);

    assert.dom(".d-otp-slot").exists({ count: 8 });
  });

  test("accepts input and fills slots", async function (assert) {
    await render(<template><DOtp /></template>);

    const input = this.element.querySelector(".d-otp-input");
    input.value = "123456";
    input.dispatchEvent(new Event("input"));

    await settled();

    assert.dom(".d-otp-slot:nth-child(1)").hasText("​ 1");
    assert.dom(".d-otp-slot:nth-child(2)").hasText("​ 2");
    assert.dom(".d-otp-slot:nth-child(3)").hasText("​ 3");
    assert.dom(".d-otp-slot:nth-child(4)").hasText("​ 4");
    assert.dom(".d-otp-slot:nth-child(5)").hasText("​ 5");
    assert.dom(".d-otp-slot:nth-child(6)").hasText("​ 6");
  });

  test("calls onFill when all slots are filled", async function (assert) {
    this.set("filledValue", null);
    this.onFillCallback = (value) => {
      this.set("filledValue", value);
    };

    await render(<template><DOtp @onFill={{this.onFillCallback}} /></template>);

    const input = this.element.querySelector(".d-otp-input");
    input.value = "123456";
    input.dispatchEvent(new Event("input"));

    await new Promise((resolve) => next(resolve));

    assert.strictEqual(this.filledValue, "123456");
  });

  test("calls onChange when filling slots", async function (assert) {
    this.set("value", null);

    this.onChangeCallback = (value) => {
      this.set("value", value);
    };

    await render(
      <template><DOtp @onChange={{this.onChangeCallback}} /></template>
    );

    const input = this.element.querySelector(".d-otp-input");
    input.value = "1";
    input.dispatchEvent(new Event("input"));

    await new Promise((resolve) => next(resolve));

    assert.strictEqual(this.value, "1");

    input.value = "12";
    input.dispatchEvent(new Event("input"));

    await new Promise((resolve) => next(resolve));

    assert.strictEqual(this.value, "12");
  });

  test("@autoFocus", async function (assert) {
    await render(<template><DOtp /></template>);

    await waitUntil(
      () =>
        document.activeElement === this.element.querySelector(".d-otp-input")
    );

    assert.dom(".d-otp-input").isFocused("autofocuses the input by default");

    await render(<template><DOtp @autoFocus={{false}} /></template>);

    assert
      .dom(".d-otp-input")
      .isNotFocused("does not autofocus when @autoFocus is false");
  });

  test("shows placeholder dashes for empty slots", async function (assert) {
    await render(<template><DOtp /></template>);
    await focus(".d-otp-input");

    assert.dom(".d-otp-slot:nth-child(1)").hasText("​");
    assert.dom(".d-otp-slot:nth-child(2)").hasText("​ -");
    assert.dom(".d-otp-slot:nth-child(3)").hasText("​ -");
    assert.dom(".d-otp-slot:nth-child(4)").hasText("​ -");
    assert.dom(".d-otp-slot:nth-child(5)").hasText("​ -");
    assert.dom(".d-otp-slot:nth-child(6)").hasText("​ -");
  });

  test("handles paste with spaces correctly", async function (assert) {
    await render(<template><DOtp /></template>);

    const input = this.element.querySelector(".d-otp-input");

    const pasteEvent = new Event("paste");
    pasteEvent.clipboardData = {
      getData: () => "1 2 3 4 5 6",
    };

    input.dispatchEvent(pasteEvent);

    await settled();

    assert.dom(".d-otp-slot:nth-child(1)").hasText("​ 1");
    assert.dom(".d-otp-slot:nth-child(2)").hasText("​ 2");
    assert.dom(".d-otp-slot:nth-child(3)").hasText("​ 3");
    assert.dom(".d-otp-slot:nth-child(4)").hasText("​ 4");
    assert.dom(".d-otp-slot:nth-child(5)").hasText("​ 5");
    assert.dom(".d-otp-slot:nth-child(6)").hasText("​ 6");
  });

  test("removes non-digit characters from paste", async function (assert) {
    await render(<template><DOtp /></template>);

    const input = this.element.querySelector(".d-otp-input");

    const pasteEvent = new Event("paste", { bubbles: true });
    pasteEvent.clipboardData = {
      getData: () => "a1-2-3-4-5-6",
    };
    input.dispatchEvent(pasteEvent);

    await settled();

    assert.dom(".d-otp-slot:nth-child(1)").hasText("​ 1");
    assert.dom(".d-otp-slot:nth-child(2)").hasText("​ 2");
    assert.dom(".d-otp-slot:nth-child(3)").hasText("​ 3");
    assert.dom(".d-otp-slot:nth-child(4)").hasText("​ 4");
    assert.dom(".d-otp-slot:nth-child(5)").hasText("​ 5");
    assert.dom(".d-otp-slot:nth-child(6)").hasText("​ 6");
  });

  test("supports custom normalization and grouped slots", async function (assert) {
    this.normalizeInput = (value) =>
      value.toUpperCase().replace(/[^A-Z0-9]/g, "");

    await render(
      <template>
        <DOtp
          @slots={{8}}
          @groupSize={{4}}
          @inputMode="text"
          @autocomplete="off"
          @normalizeInput={{this.normalizeInput}}
        />
      </template>
    );

    const input = this.element.querySelector(".d-otp-input");
    const pasteEvent = new Event("paste", { bubbles: true });
    pasteEvent.clipboardData = {
      getData: () => "ab12-cd34",
    };
    input.dispatchEvent(pasteEvent);

    await settled();

    assert.dom(".d-otp-slot").exists({ count: 8 });
    assert.dom(".d-otp-separator").exists({ count: 1 });
    assert.dom(".d-otp-input").hasAttribute("inputmode", "text");
    assert.dom(".d-otp-input").hasAttribute("autocomplete", "off");
    assert.dom(".d-otp-input").hasAttribute("spellcheck", "false");
    assert.dom(".d-otp-input").hasAttribute("autocorrect", "off");
    assert.dom(".d-otp-input").hasAttribute("autocapitalize", "off");
    assert.dom(".d-otp-slot[data-index='0']").hasText("​ A");
    assert.dom(".d-otp-slot[data-index='7']").hasText("​ 4");
  });

  test("allows editing after all slots are filled", async function (assert) {
    this.set("value", null);
    this.onChangeCallback = (value) => {
      this.set("value", value);
    };

    await render(
      <template><DOtp @onChange={{this.onChangeCallback}} /></template>
    );

    await fillIn(".d-otp-input", "123456");
    await fillIn(".d-otp-input", "12345");

    assert.strictEqual(this.value, "12345");
    assert.dom(".d-otp-slot:nth-child(6)").hasText("​ ");
  });

  test("removes all content when all is selected and backspace is pressed", async function (assert) {
    await render(<template><DOtp /></template>);

    const input = this.element.querySelector(".d-otp-input");
    await focus(input);
    input.value = "123456";
    input.dispatchEvent(new Event("input"));

    await settled();

    assert.dom(".d-otp-slot:nth-child(1)").hasText("​ 1");
    assert.dom(".d-otp-slot:nth-child(2)").hasText("​ 2");
    assert.dom(".d-otp-slot:nth-child(3)").hasText("​ 3");
    assert.dom(".d-otp-slot:nth-child(4)").hasText("​ 4");
    assert.dom(".d-otp-slot:nth-child(5)").hasText("​ 5");
    assert.dom(".d-otp-slot:nth-child(6)").hasText("​ 6");

    input.select();
    input.value = ""; // Simulate backspace key
    input.dispatchEvent(new Event("input"));

    await settled();

    assert.dom(".d-otp-slot:nth-child(1)").hasText("​ "); // first slot shows cursor
    assert.dom(".d-otp-slot:nth-child(2)").hasText("​ -");
    assert.dom(".d-otp-slot:nth-child(3)").hasText("​ -");
    assert.dom(".d-otp-slot:nth-child(4)").hasText("​ -");
    assert.dom(".d-otp-slot:nth-child(5)").hasText("​ -");
    assert.dom(".d-otp-slot:nth-child(6)").hasText("​ -");
  });
});
