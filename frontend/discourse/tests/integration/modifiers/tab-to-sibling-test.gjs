import { focus, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import tabToSibling from "discourse/modifiers/tab-to-sibling";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Modifier | tabToSibling", function (hooks) {
  setupRenderingTest(hooks);

  test("focuses next sibling when Tab is pressed", async function (assert) {
    await render(
      <template>
        <div class="container">
          <div class="first-item" {{tabToSibling}} tabindex="0">First</div>
          <div class="second-item" tabindex="0">Second</div>
          <div class="third-item" tabindex="0">Third</div>
        </div>
      </template>
    );

    await focus(".first-item");

    assert
      .dom(".first-item")
      .isFocused("First item should be focused initially");

    await triggerKeyEvent(".first-item", "keydown", "Tab");

    assert
      .dom(".second-item")
      .isFocused("Second item should be focused after Tab");
  });

  test("focuses previous sibling when Shift+Tab is pressed", async function (assert) {
    await render(
      <template>
        <div class="container">
          <div class="first-item" tabindex="0">First</div>
          <div class="second-item" {{tabToSibling}} tabindex="0">Second</div>
          <div class="third-item" tabindex="0">Third</div>
        </div>
      </template>
    );

    await focus(".second-item");

    assert
      .dom(".second-item")
      .isFocused("Second item should be focused initially");

    await triggerKeyEvent(".second-item", "keydown", "Tab", { shiftKey: true });

    assert
      .dom(".first-item")
      .isFocused("First item should be focused after Shift+Tab");
  });

  test("skips non-focusable siblings", async function (assert) {
    await render(
      <template>
        <div class="container">
          <div class="first-item" {{tabToSibling}} tabindex="0">First</div>
          <div class="non-focusable">Non-focusable</div>
          <div class="disabled-item" tabindex="-1">Disabled</div>
          <div class="third-item" tabindex="0">Third</div>
        </div>
      </template>
    );

    await focus(".first-item");
    await triggerKeyEvent(".first-item", "keydown", "Tab");

    assert
      .dom(".third-item")
      .isFocused("Should skip non-focusable siblings and focus third item");
  });

  test("works with buttons and other naturally focusable elements", async function (assert) {
    await render(
      <template>
        <div class="container">
          <button class="first-button" {{tabToSibling}}>First Button</button>
          <input class="input-field" type="text" />
          <a href="#" class="link-element">Link</a>
        </div>
      </template>
    );

    await focus(".first-button");
    await triggerKeyEvent(".first-button", "keydown", "Tab");

    assert
      .dom(".input-field")
      .isFocused("Should focus input field after Tab from button");
  });

  test("ignores non-Tab key events", async function (assert) {
    await render(
      <template>
        <div class="container">
          <div class="first-item" {{tabToSibling}} tabindex="0">First</div>
          <div class="second-item" tabindex="0">Second</div>
        </div>
      </template>
    );

    await focus(".first-item");
    await triggerKeyEvent(".first-item", "keydown", "Enter");

    assert
      .dom(".first-item")
      .isFocused("Focus should not change on non-Tab keys");
  });
});
