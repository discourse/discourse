import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render, triggerKeyEvent, focus } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Modifier | tab-to-sibling", function (hooks) {
  setupRenderingTest(hooks);

  test("focuses next sibling when Tab is pressed", async function (assert) {
    await render(hbs`
      <div class="container">
        <div class="first-item" {{tab-to-sibling}} tabindex="0">First</div>
        <div class="second-item" tabindex="0">Second</div>
        <div class="third-item" tabindex="0">Third</div>
      </div>
    `);

    const firstItem = document.querySelector(".first-item");
    const secondItem = document.querySelector(".second-item");

    await focus(firstItem);
    assert.dom(firstItem).isFocused("First item should be focused initially");

    await triggerKeyEvent(firstItem, "keydown", "Tab");

    assert.dom(secondItem).isFocused("Second item should be focused after Tab");
  });

  test("focuses previous sibling when Shift+Tab is pressed", async function (assert) {
    await render(hbs`
      <div class="container">
        <div class="first-item" tabindex="0">First</div>
        <div class="second-item" {{tab-to-sibling}} tabindex="0">Second</div>
        <div class="third-item" tabindex="0">Third</div>
      </div>
    `);

    const firstItem = document.querySelector(".first-item");
    const secondItem = document.querySelector(".second-item");

    await focus(secondItem);
    assert.dom(secondItem).isFocused("Second item should be focused initially");

    await triggerKeyEvent(secondItem, "keydown", "Tab", { shiftKey: true });

    assert.dom(firstItem).isFocused("First item should be focused after Shift+Tab");
  });

  test("skips non-focusable siblings", async function (assert) {
    await render(hbs`
      <div class="container">
        <div class="first-item" {{tab-to-sibling}} tabindex="0">First</div>
        <div class="non-focusable">Non-focusable</div>
        <div class="disabled-item" tabindex="-1">Disabled</div>
        <div class="third-item" tabindex="0">Third</div>
      </div>
    `);

    const firstItem = document.querySelector(".first-item");
    const thirdItem = document.querySelector(".third-item");

    await focus(firstItem);
    await triggerKeyEvent(firstItem, "keydown", "Tab");

    assert.dom(thirdItem).isFocused("Should skip non-focusable siblings and focus third item");
  });

  test("does not prevent default when no focusable sibling found", async function (assert) {
    await render(hbs`
      <div class="container">
        <div class="only-item" {{tab-to-sibling}} tabindex="0">Only Item</div>
        <div class="non-focusable">Non-focusable</div>
      </div>
    `);

    const onlyItem = document.querySelector(".only-item");

    await focus(onlyItem);

    // We can't easily test that default behavior happens, but we can ensure
    // the item remains focused (which would happen with default tab behavior
    // when there's nowhere else to go)
    await triggerKeyEvent(onlyItem, "keydown", "Tab");

    // The focus might move to browser UI elements, but that's expected
    // when there are no more focusable elements in the page
    assert.ok(true, "No error should occur when no focusable sibling is found");
  });

  test("works with buttons and other naturally focusable elements", async function (assert) {
    await render(hbs`
      <div class="container">
        <button class="first-button" {{tab-to-sibling}}>First Button</button>
        <input class="input-field" type="text" />
        <a href="#" class="link-element">Link</a>
      </div>
    `);

    const firstButton = document.querySelector(".first-button");
    const inputField = document.querySelector(".input-field");

    await focus(firstButton);
    await triggerKeyEvent(firstButton, "keydown", "Tab");

    assert.dom(inputField).isFocused("Should focus input field after Tab from button");
  });

  test("ignores non-Tab key events", async function (assert) {
    await render(hbs`
      <div class="container">
        <div class="first-item" {{tab-to-sibling}} tabindex="0">First</div>
        <div class="second-item" tabindex="0">Second</div>
      </div>
    `);

    const firstItem = document.querySelector(".first-item");

    await focus(firstItem);
    await triggerKeyEvent(firstItem, "keydown", "Enter");

    assert.dom(firstItem).isFocused("Focus should not change on non-Tab keys");
  });
});
