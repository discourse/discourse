import {
  click,
  findAll,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import RovingFocusListboxExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/listbox";
import RovingFocusRadioGroupExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/radio-group";
import RovingFocusRemovableTagsExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/removable-tags";
import RovingFocusToolbarExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/toolbar";
import RovingFocusTreeExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/tree";

/**
 * The tier-1 conformance fixtures are plain semantic HTML, so anything that fails here is the
 * modifier rather than a component wrapped around it.
 */

function pressKey(element, key) {
  const event = new KeyboardEvent("keydown", {
    key,
    bubbles: true,
    cancelable: true,
  });
  element.dispatchEvent(event);
  return event;
}

function labels(selector) {
  return findAll(selector).map((el) => el.textContent.trim());
}

function tabStop() {
  return findAll(".roving-demo__item").find(
    (el) => el.getAttribute("tabindex") === "0"
  );
}

module(
  "Integration | Component | roving-focus examples | toolbar",
  function (hooks) {
    setupRenderingTest(hooks);

    test("enters on the first control", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      assert
        .dom(tabStop())
        .hasText(
          "Bold",
          "the toolbar convention is the first control unconditionally"
        );
    });

    test("a pointer press moves the tab stop it lands on", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      await click(findAll(".roving-demo__item")[1]);

      assert
        .dom(findAll(".roving-demo__item")[1])
        .hasAttribute(
          "aria-pressed",
          "true",
          "the native button activated on its own"
        );
      assert
        .dom(tabStop())
        .hasText(
          "Italic",
          "so Tab out and back returns to where the reader last was, not to where the cursor was seeded"
        );
    });

    test("arrows walk the bar, telling the two spellings of disabled apart", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      const first = findAll(".roving-demo__item")[0];
      first.focus();

      const visited = [document.activeElement.textContent.trim()];
      for (let i = 0; i < 5; i++) {
        await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
        visited.push(document.activeElement.textContent.trim());
      }

      assert.deepEqual(
        visited,
        ["Bold", "Italic", "Underline", "Copy", "Paste", "Authoring practices"],
        "Cut is skipped because the platform will not focus a disabled button, while Paste stays reachable so it can be discovered"
      );
    });

    test("the reachable disabled command is still not operable", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      const paste = findAll(".roving-demo__item").find(
        (el) => el.textContent.trim() === "Paste"
      );
      paste.focus();

      const event = new KeyboardEvent("keydown", {
        key: "Enter",
        bubbles: true,
        cancelable: true,
      });
      paste.dispatchEvent(event);

      assert.false(
        event.defaultPrevented,
        "the modifier declines to activate it, so nothing consumes the key on its behalf"
      );
    });

    test("End and Home reach the ends of the bar", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      findAll(".roving-demo__item")[0].focus();

      await triggerKeyEvent(document.activeElement, "keydown", "End");
      assert
        .dom(document.activeElement)
        .hasText("Authoring practices", "End reaches the last navigable item");

      await triggerKeyEvent(document.activeElement, "keydown", "Home");
      assert
        .dom(document.activeElement)
        .hasText("Bold", "Home reaches the first");
    });

    test("Space is left to the native button", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      const first = findAll(".roving-demo__item")[0];
      first.focus();

      const event = new KeyboardEvent("keydown", {
        key: " ",
        bubbles: true,
        cancelable: true,
      });
      first.dispatchEvent(event);

      assert.false(
        event.defaultPrevented,
        "no onActivate is passed, so the modifier does not claim Space and the button keeps its own activation"
      );
    });
  }
);

module(
  "Integration | Component | roving-focus examples | tree",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the cursor covers only the rows that are visible", async function (assert) {
      await render(<template><RovingFocusTreeExample @dir="ltr" /></template>);

      assert.deepEqual(
        labels(".roving-demo__row"),
        ["Components", "Button", "Select", "Modifiers"],
        "the collapsed parent contributes no rows"
      );

      const rows = findAll(".roving-demo__row");
      rows[0].focus();
      await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");

      assert
        .dom(document.activeElement)
        .hasText("Button", "the next visible row takes the cursor");
    });

    test("collapsing a parent takes its children out of the sequence", async function (assert) {
      await render(<template><RovingFocusTreeExample @dir="ltr" /></template>);

      const parent = findAll(".roving-demo__row")[0];
      parent.focus();
      await triggerKeyEvent(parent, "keydown", "ArrowLeft");

      assert.deepEqual(
        labels(".roving-demo__row"),
        ["Components", "Modifiers"],
        "the children are gone"
      );

      await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
      assert
        .dom(document.activeElement)
        .hasText("Modifiers", "the cursor steps to what is left");
    });

    test("the cross-axis keys mirror under rtl", async function (assert) {
      await render(<template><RovingFocusTreeExample @dir="rtl" /></template>);

      const parent = findAll(".roving-demo__row")[0];
      parent.focus();
      assert
        .dom(parent)
        .hasAttribute("aria-expanded", "true", "it starts expanded");

      await triggerKeyEvent(parent, "keydown", "ArrowRight");
      assert
        .dom(findAll(".roving-demo__row")[0])
        .hasAttribute(
          "aria-expanded",
          "false",
          "the arrow pointing away from the children closes them, which is ArrowRight here"
        );

      await triggerKeyEvent(
        findAll(".roving-demo__row")[0],
        "keydown",
        "ArrowLeft"
      );
      assert
        .dom(findAll(".roving-demo__row")[0])
        .hasAttribute(
          "aria-expanded",
          "true",
          "and the one pointing at them opens them, without the example resolving direction itself"
        );
    });
  }
);

module(
  "Integration | Component | roving-focus examples | listbox",
  function (hooks) {
    setupRenderingTest(hooks);

    test("enters on the option already chosen, not the first", async function (assert) {
      await render(<template><RovingFocusListboxExample /></template>);

      const seeded = findAll(".roving-demo__option").find(
        (el) => el.getAttribute("tabindex") === "0"
      );

      assert
        .dom(seeded)
        .hasAttribute(
          "data-option-id",
          "banana",
          "a listbox returns a reader to their own choice, which is the opposite of the toolbar convention"
        );
    });

    test("typing matches the name, and the decorative count is not part of it", async function (assert) {
      await render(<template><RovingFocusListboxExample /></template>);

      const rows = findAll(".roving-demo__option");
      rows[0].focus();

      pressKey(document.activeElement, "c");
      await settled();
      assert
        .dom(document.activeElement)
        .hasAttribute(
          "data-option-id",
          "cherry",
          "one character finds the first C"
        );

      const digit = pressKey(document.activeElement, "1");
      await settled();
      assert
        .dom(document.activeElement)
        .hasAttribute(
          "data-option-id",
          "cherry",
          "the counts belong to the text but not to any name, so a digit matches nothing"
        );
      assert.false(digit.defaultPrevented, "and the key is not consumed");
    });

    test("a second character narrows within the shared initial", async function (assert) {
      await render(<template><RovingFocusListboxExample /></template>);

      findAll(".roving-demo__option")[0].focus();

      pressKey(document.activeElement, "a");
      pressKey(document.activeElement, "p");
      await settled();

      assert
        .dom(document.activeElement)
        .hasAttribute(
          "data-option-id",
          "apricot",
          "ap passes over Apple, which only matches the first character"
        );
    });
  }
);

module(
  "Integration | Component | roving-focus examples | radio group",
  function (hooks) {
    setupRenderingTest(hooks);

    test("enters on the checked member", async function (assert) {
      await render(<template><RovingFocusRadioGroupExample /></template>);

      const seeded = findAll(".roving-demo__radio").find(
        (el) => el.getAttribute("tabindex") === "0"
      );

      assert
        .dom(seeded)
        .hasAttribute(
          "data-choice-id",
          "center",
          "aria-checked is the radio group spelling, and seeding has to read it"
        );
    });

    test("the choice follows the cursor", async function (assert) {
      await render(<template><RovingFocusRadioGroupExample /></template>);

      const center = findAll(".roving-demo__radio")[1];
      center.focus();
      await triggerKeyEvent(center, "keydown", "ArrowRight");

      assert
        .dom(document.activeElement)
        .hasAttribute("data-choice-id", "right", "the cursor moved");
      assert
        .dom(document.activeElement)
        .hasAttribute(
          "aria-checked",
          "true",
          "and the choice came with it, which is what this pattern expects"
        );
    });
  }
);

module(
  "Integration | Component | roving-focus examples | removable tags",
  function (hooks) {
    setupRenderingTest(hooks);

    test("removing the focused tag hands the cursor to the next one", async function (assert) {
      await render(<template><RovingFocusRemovableTagsExample /></template>);

      const tags = findAll(".roving-demo__tag");
      assert.strictEqual(tags.length, 4, "four to begin with");

      tags[1].focus();
      await click(tags[1]);

      assert.strictEqual(
        findAll(".roving-demo__tag").length,
        3,
        "the tag is gone"
      );
      assert
        .dom(document.activeElement)
        .hasText(
          "Release",
          "focus followed to what took its place rather than falling to the page"
        );
    });

    test("removing the last tag hands the cursor backwards", async function (assert) {
      await render(<template><RovingFocusRemovableTagsExample /></template>);

      const tags = findAll(".roving-demo__tag");
      const last = tags[tags.length - 1];
      last.focus();
      await click(last);

      assert
        .dom(document.activeElement)
        .hasText(
          "Release",
          "there is nothing after it, so the item before takes the cursor"
        );
    });

    test("emptying the group leaves focus alone rather than guessing", async function (assert) {
      await render(<template><RovingFocusRemovableTagsExample /></template>);

      for (let i = 0; i < 4; i++) {
        const remaining = findAll(".roving-demo__tag");
        remaining[0].focus();
        await click(remaining[0]);
      }

      assert.strictEqual(
        findAll(".roving-demo__tag").length,
        0,
        "every tag is gone"
      );
      assert
        .dom(".roving-demo__reset")
        .exists("and the group offers a way back");
    });
  }
);
