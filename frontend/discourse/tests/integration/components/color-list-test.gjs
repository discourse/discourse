import { tracked } from "@glimmer/tracking";
import {
  blur,
  click,
  fillIn,
  render,
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

    assert.deepEqual(shownColors(), ["FF0000", "00FF00", "0000FF"]);
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

    await fillIn(rowHex(1), "abcdef");
    assert.deepEqual(
      this.changes,
      [["FF0000", "ABCDEF", "0000FF"]],
      "a 6-digit color replaces the row's, in uppercase, keeping its position"
    );

    await fillIn(rowHex(1), "abc");
    assert.strictEqual(this.changes.length, 1, "a 3-digit color waits");
    await blur(rowHex(1));
    assert.deepEqual(
      this.changes.at(-1),
      ["FF0000", "AABBCC", "0000FF"],
      "and expands when the field is left"
    );

    await fillIn(rowHex(1), "zz");
    await blur(rowHex(1));
    assert.strictEqual(this.changes.length, 2, "an invalid color is not kept");
    assert.dom(rowHex(1)).hasValue("AABBCC", "the field shows the color again");

    const picker = document.querySelector(
      `${rowSelector(0)} .d-color-input__picker`
    );
    picker.value = "#123456";
    picker.dispatchEvent(new Event("input", { bubbles: true }));
    assert.deepEqual(
      this.changes.at(-1),
      ["123456", "AABBCC", "0000FF"],
      "the picker edits the row too"
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
      .isDisabled("a color the list holds can't be added twice");
    assert.dom(ADD_BUTTON).hasAttribute("title", "Already in the list");

    await fillIn(ADD_HEX, "zz");
    assert.dom(ADD_BUTTON).isDisabled("nor something that isn't a color");

    await fillIn(ADD_HEX, "abc");
    await click(ADD_BUTTON);
    assert.deepEqual(this.changes, [["FF0000", "00FF00", "0000FF", "AABBCC"]]);
    assert.dom(ADD_HEX).hasValue("", "the field empties for the next one");

    await fillIn(ADD_HEX, "123456");
    await triggerKeyEvent(ADD_HEX, "keydown", "Enter");
    assert.deepEqual(this.changes.at(-1), [
      "FF0000",
      "00FF00",
      "0000FF",
      "AABBCC",
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
    assert.deepEqual(this.changes.at(-1), ["00FF00", "FF0000", "0000FF"]);

    await click(`${rowSelector(2)} .d-reorderable-list__remove`);
    assert.deepEqual(this.changes.at(-1), ["00FF00", "FF0000"]);
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
