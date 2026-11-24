import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DColorInput from "discourse/ui-kit/d-color-input";

const HEX = ".d-color-input__hex";
const PICKER = ".d-color-input__picker";

module("Integration | ui-kit | DColorInput", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the value without its #, and the # only when asked", async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DColorInput
          class="with-hash"
          @hashPrefix={{true}}
          @onChange={{noop}}
          @value="#FF0000"
        />
        <DColorInput class="bare" @onChange={{noop}} @value="00FF00" />
        <DColorInput
          class="named"
          @allowNamedColors={{true}}
          @onChange={{noop}}
          @value="Blue"
        />
      </template>
    );

    assert.dom(`${HEX}.with-hash`).hasValue("ff0000");
    assert.dom(`${HEX}.bare`).hasValue("00ff00", "hex shows in lowercase");
    assert
      .dom(`${HEX}.named`)
      .hasValue("Blue", "a field taking names shows what it holds");
    assert.dom(".d-color-input__prefix").exists({ count: 1 }, "one # prefix");
    assert
      .dom(".d-color-input__prefix + .with-hash")
      .exists("it sits before the field that asked for it");
  });

  test("reports what is typed, picked or pasted, without a # and in lowercase", async function (assert) {
    const changes = [];
    const onChange = (value) => changes.push(value);

    await render(
      <template><DColorInput @onChange={{onChange}} @value="" /></template>
    );

    await fillIn(HEX, "ABC");

    const picker = document.querySelector(PICKER);
    picker.value = "#aabbcc";
    picker.dispatchEvent(new Event("input", { bubbles: true }));

    const clipboardData = new DataTransfer();
    clipboardData.setData("text/plain", "#DDEEFF");
    await triggerEvent(HEX, "paste", { clipboardData });

    assert.deepEqual(changes, ["abc", "aabbcc", "ddeeff"]);
  });

  test("lowercases typing in place, keeping the caret", async function (assert) {
    const noop = () => {};

    await render(
      <template><DColorInput @onChange={{noop}} @value="" /></template>
    );

    const input = document.querySelector(HEX);
    input.value = "ABCDEF";
    input.setSelectionRange(2, 2);
    input.dispatchEvent(new Event("input", { bubbles: true }));

    assert.dom(HEX).hasValue("abcdef");
    assert.strictEqual(input.selectionStart, 2, "the caret stays put");
  });

  test("a pasted color replaces the field, without spaces or #", async function (assert) {
    const changes = [];
    const onChange = (value) => changes.push(value);

    await render(
      <template>
        <DColorInput @onChange={{onChange}} @value="abcdef" />
      </template>
    );

    const input = document.querySelector(HEX);
    input.setSelectionRange(2, 2);
    const clipboardData = new DataTransfer();
    clipboardData.setData("text/plain", " #F00 ");
    await triggerEvent(HEX, "paste", { clipboardData });

    assert.dom(HEX).hasValue("f00", "the field shows the pasted color");
    assert.deepEqual(changes, ["f00"]);
  });

  test("other pasted text goes in at the cursor, within the limit", async function (assert) {
    const changes = [];
    const onChange = (value) => changes.push(value);

    await render(
      <template>
        <DColorInput class="partial" @onChange={{onChange}} @value="ab" />
        <DColorInput class="alpha" @onChange={{onChange}} @value="" />
      </template>
    );

    const partial = document.querySelector(`${HEX}.partial`);
    partial.setSelectionRange(1, 1);
    let clipboardData = new DataTransfer();
    clipboardData.setData("text/plain", "CDEFGH");
    await triggerEvent(partial, "paste", { clipboardData });

    assert
      .dom(partial)
      .hasValue("acdefb", "only what fits goes in, where the cursor is");
    assert.strictEqual(partial.selectionStart, 5, "and the cursor follows it");

    clipboardData = new DataTransfer();
    clipboardData.setData("text/plain", "#FF0000AA");
    await triggerEvent(`${HEX}.alpha`, "paste", { clipboardData });

    assert
      .dom(`${HEX}.alpha`)
      .hasValue("ff0000", "a color with alpha keeps the 6 digits that fit");
    assert.deepEqual(changes, ["acdefb", "ff0000"]);
  });

  test("keeps pasted names as pasted, without spaces", async function (assert) {
    const changes = [];
    const onChange = (value) => changes.push(value);

    await render(
      <template>
        <DColorInput
          @allowNamedColors={{true}}
          @onChange={{onChange}}
          @value=""
        />
      </template>
    );

    const clipboardData = new DataTransfer();
    clipboardData.setData("text/plain", " cornflowerblue ");
    await triggerEvent(HEX, "paste", { clipboardData });

    assert.dom(HEX).hasValue("cornflowerblue");
    assert.deepEqual(changes, ["cornflowerblue"]);
  });

  test("keeps typed names as typed, and picks in lowercase", async function (assert) {
    const changes = [];
    const onChange = (value) => changes.push(value);

    await render(
      <template>
        <DColorInput
          @allowNamedColors={{true}}
          @onChange={{onChange}}
          @value=""
        />
      </template>
    );

    await fillIn(HEX, "Bee");

    const picker = document.querySelector(PICKER);
    picker.value = "#aabbcc";
    picker.dispatchEvent(new Event("input", { bubbles: true }));

    assert.deepEqual(changes, ["Bee", "aabbcc"]);
    assert.dom(HEX).hasValue("Bee");
  });

  test("the picker shows the color, or black when there is none", async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DColorInput class="short" @onChange={{noop}} @value="f00" />
        <DColorInput class="empty" @onChange={{noop}} @value="" />
        <DColorInput class="invalid" @onChange={{noop}} @value="zzz" />
        <DColorInput
          class="named"
          @allowNamedColors={{true}}
          @onChange={{noop}}
          @value="purple"
        />
        <DColorInput class="unnamed" @onChange={{noop}} @value="purple" />
      </template>
    );

    const pickerOf = (cls) =>
      document
        .querySelector(`${HEX}.${cls}`)
        .closest(".d-color-input")
        .querySelector(PICKER).value;

    assert.strictEqual(pickerOf("short"), "#ff0000", "a 3-digit code expands");
    assert.strictEqual(pickerOf("empty"), "#000000");
    assert.strictEqual(pickerOf("invalid"), "#000000");
    assert.strictEqual(
      pickerOf("named"),
      "#800080",
      "names resolve when allowed"
    );
    assert.strictEqual(pickerOf("unnamed"), "#000000", "and only then");
  });

  test("caps the field at 6 characters unless named colors are allowed", async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DColorInput class="hex" @onChange={{noop}} @value="" />
        <DColorInput
          class="named"
          @allowNamedColors={{true}}
          @onChange={{noop}}
          @value=""
        />
      </template>
    );

    assert.dom(`${HEX}.hex`).hasAttribute("maxlength", "6");
    assert.dom(`${HEX}.named`).doesNotHaveAttribute("maxlength");
  });

  test("names the picker, takes attributes on the field, and can be disabled", async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DColorInput
          aria-label="Link color"
          id="link-color"
          @disabled={{true}}
          @onChange={{noop}}
          @value="006699"
        />
      </template>
    );

    assert.dom(HEX).hasAttribute("id", "link-color");
    assert.dom(HEX).hasAria("label", "Link color");
    assert.dom(PICKER).hasAria("label", "Pick a color");
    assert.dom(HEX).isDisabled();
    assert.dom(PICKER).isDisabled();
  });

  test("the picker's icon contrasts with the color", async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DColorInput class="light" @onChange={{noop}} @value="FFFFFF" />
        <DColorInput class="dark" @onChange={{noop}} @value="000000" />
        <DColorInput class="none" @onChange={{noop}} @value="" />
        <DColorInput
          class="named"
          @allowNamedColors={{true}}
          @onChange={{noop}}
          @value="navy"
        />
      </template>
    );

    const wrapperOf = (cls) =>
      document
        .querySelector(`${HEX}.${cls}`)
        .closest(".d-color-input")
        .querySelector(".d-color-input__picker-wrapper");

    assert.dom(wrapperOf("light")).hasClass("--is-light");
    assert.dom(wrapperOf("dark")).hasClass("--is-dark");
    assert
      .dom(wrapperOf("none"))
      .hasClass(
        "--is-dark",
        "an empty field shows black, so the icon is light"
      );
    assert
      .dom(wrapperOf("named"))
      .hasClass("--is-dark", "a named color counts as the color it shows");
  });
});
