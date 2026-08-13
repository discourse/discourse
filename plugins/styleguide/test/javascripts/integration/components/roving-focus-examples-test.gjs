import { click, findAll, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import RovingFocusToolbarExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/toolbar";
import RovingFocusTreeExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/tree";

/**
 * The tier-1 conformance fixtures are plain semantic HTML, so anything that fails here is the
 * modifier rather than a component wrapped around it.
 */

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

    test("the cross-axis keys are physical, so they do not mirror under rtl", async function (assert) {
      await render(<template><RovingFocusTreeExample @dir="rtl" /></template>);

      const parent = findAll(".roving-demo__row")[0];
      assert
        .dom(parent)
        .hasAttribute("aria-expanded", "true", "it starts expanded");

      await triggerKeyEvent(parent, "keydown", "ArrowLeft");
      assert
        .dom(findAll(".roving-demo__row")[0])
        .hasAttribute(
          "aria-expanded",
          "false",
          "ArrowLeft still collapses under rtl, where it points at the children rather than away from them"
        );

      // Pinning today's behaviour rather than endorsing it. A cross-axis event resolved
      // logically would swap these two, and this is the assertion that changes with it.
      await triggerKeyEvent(
        findAll(".roving-demo__row")[0],
        "keydown",
        "ArrowRight"
      );
      assert
        .dom(findAll(".roving-demo__row")[0])
        .hasAttribute("aria-expanded", "true", "and ArrowRight still expands");
    });
  }
);
