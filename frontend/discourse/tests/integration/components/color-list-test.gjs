import { tracked } from "@glimmer/tracking";
import {
  blur,
  click,
  fillIn,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import ColorList from "discourse/admin/components/color-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  handleSelector,
  moveViaChord,
  rowSelector,
} from "discourse/tests/helpers/ui-kit/reorderable-list-helper";

const ADD_HEX = ".color-list__add .d-color-input__hex";
const ADD_BUTTON = ".color-list__add-btn";

function rowHex(index) {
  return `${rowSelector(index)} .d-color-input__hex`;
}

function shownColors() {
  return [
    ...document.querySelectorAll(
      ".color-list [data-reorderable-key] .d-color-input__hex"
    ),
  ].map((input) => input.value);
}

module("Integration | Component | ColorList", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.values = tracked("FF0000|00FF00|0000FF");
    this.changes = [];
    this.onChange = (colors) => {
      this.changes.push([...colors]);
      this.values.value = colors.join("|");
    };
  });

  test("shows each color in order, in its own named color input", async function (assert) {
    await render(
      <template>
        <ColorList @onChange={{this.onChange}} @values={{this.values.value}} />
      </template>
    );

    assert.deepEqual(
      shownColors(),
      ["ff0000", "00ff00", "0000ff"],
      "stored colors show in lowercase"
    );
    assert.dom(rowHex(1)).hasAria("label", "Color 2");
    assert.dom(`${rowSelector(1)} .d-color-input__prefix`).exists();
    assert.dom(rowHex(1)).hasAttribute("maxlength", "6");
    assert
      .dom(".color-list__add .d-reorderable-list__handle-slot")
      .exists("the new color starts where the rows' colors do");
  });

  test("edits a color in place, only once it is a whole color", async function (assert) {
    await render(
      <template>
        <ColorList @onChange={{this.onChange}} @values={{this.values.value}} />
      </template>
    );

    await fillIn(rowHex(1), "ABCDEF");
    assert.deepEqual(
      this.changes,
      [["ff0000", "abcdef", "0000ff"]],
      "a 6-digit color replaces the row's, keeping its position, and the list is saved in lowercase"
    );

    await fillIn(rowHex(1), "ABC");
    assert.strictEqual(this.changes.length, 1, "a 3-digit color waits");
    await blur(rowHex(1));
    assert.deepEqual(
      this.changes.at(-1),
      ["ff0000", "aabbcc", "0000ff"],
      "and expands when the field is left"
    );

    await fillIn(rowHex(1), "zz");
    await blur(rowHex(1));
    assert.strictEqual(this.changes.length, 2, "an invalid color is not kept");
    assert.dom(rowHex(1)).hasValue("aabbcc", "the field shows the color again");

    const picker = document.querySelector(
      `${rowSelector(0)} .d-color-input__picker`
    );
    picker.value = "#123456";
    picker.dispatchEvent(new Event("input", { bubbles: true }));
    assert.deepEqual(
      this.changes.at(-1),
      ["123456", "aabbcc", "0000ff"],
      "the picker edits the row too"
    );
  });

  test("leaving a row unchanged saves nothing, even when stored in uppercase", async function (assert) {
    await render(
      <template>
        <ColorList @onChange={{this.onChange}} @values={{this.values.value}} />
      </template>
    );

    await triggerEvent(rowHex(1), "focus");
    await blur(rowHex(1));

    assert.deepEqual(this.changes, []);
    assert.dom(rowHex(1)).hasValue("00ff00");
  });

  test("a pasted color edits a row like a typed one", async function (assert) {
    const paste = async (selector, text) => {
      const input = document.querySelector(selector);
      input.select();
      const clipboardData = new DataTransfer();
      clipboardData.setData("text/plain", text);
      await triggerEvent(input, "paste", { clipboardData });
    };

    await render(
      <template>
        <ColorList @onChange={{this.onChange}} @values={{this.values.value}} />
      </template>
    );

    await paste(rowHex(1), " #123456 ");
    assert.deepEqual(
      this.changes,
      [["ff0000", "123456", "0000ff"]],
      "a whole color is kept at once"
    );

    await paste(rowHex(1), "#F00");
    assert.dom(rowHex(1)).hasValue("f00", "a short one shows as pasted");
    await blur(rowHex(1));
    assert.deepEqual(
      this.changes.at(-1),
      ["ff0000", "ff0000", "0000ff"],
      "and expands when the field is left"
    );
  });

  test("adds a new color at the end", async function (assert) {
    await render(
      <template>
        <ColorList @onChange={{this.onChange}} @values={{this.values.value}} />
      </template>
    );

    let enterPrevented = null;
    document
      .querySelector(".color-list")
      .addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
          enterPrevented = event.defaultPrevented;
        }
      });

    assert.dom(ADD_HEX).hasAria("label", "New color");
    assert.dom(ADD_BUTTON).isDisabled("nothing to add yet");

    await fillIn(ADD_HEX, "00ff00");
    assert
      .dom(ADD_BUTTON)
      .isDisabled("a color the list holds can't be added twice, in any case");
    assert.dom(ADD_BUTTON).hasAttribute("title", "Already in the list");

    await fillIn(ADD_HEX, "zz");
    assert.dom(ADD_BUTTON).isDisabled("nor something that isn't a color");

    await fillIn(ADD_HEX, "abc");
    await click(ADD_BUTTON);
    assert.deepEqual(this.changes, [["ff0000", "00ff00", "0000ff", "aabbcc"]]);
    assert.dom(ADD_HEX).hasValue("", "the field empties for the next one");

    await fillIn(ADD_HEX, "123456");
    await triggerKeyEvent(ADD_HEX, "keydown", "Enter");
    assert.deepEqual(this.changes.at(-1), [
      "ff0000",
      "00ff00",
      "0000ff",
      "aabbcc",
      "123456",
    ]);
    assert.true(enterPrevented, "Enter adds without submitting the form");
  });

  test("moves and removes colors", async function (assert) {
    await render(
      <template>
        <ColorList @onChange={{this.onChange}} @values={{this.values.value}} />
      </template>
    );

    await moveViaChord(0, "down");
    assert.deepEqual(this.changes.at(-1), ["00ff00", "ff0000", "0000ff"]);

    await click(`${rowSelector(2)} .d-reorderable-list__remove`);
    assert.deepEqual(this.changes.at(-1), ["00ff00", "ff0000"]);
  });

  test("can't be changed while disabled", async function (assert) {
    await render(
      <template>
        <ColorList
          @disabled={{true}}
          @onChange={{this.onChange}}
          @values={{this.values.value}}
        />
      </template>
    );

    assert.dom(rowHex(0)).isDisabled();
    assert.dom(handleSelector(0)).doesNotExist();
    assert.dom(`${rowSelector(0)} .d-reorderable-list__remove`).doesNotExist();
    assert.dom(ADD_HEX).isDisabled();
    assert.dom(ADD_BUTTON).isDisabled();
  });
});
