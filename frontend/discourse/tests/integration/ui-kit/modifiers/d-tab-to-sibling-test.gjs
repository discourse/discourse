import { find, focus, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dTabToSibling from "discourse/ui-kit/modifiers/d-tab-to-sibling";

module("Integration | ui-kit | Modifier | dTabToSibling", function (hooks) {
  setupRenderingTest(hooks);

  test("focuses next sibling when Tab is pressed", async function (assert) {
    await render(
      <template>
        <div class="container">
          <div class="first-item" tabindex="0" {{dTabToSibling}}>First</div>
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
          <div class="second-item" tabindex="0" {{dTabToSibling}}>Second</div>
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
          <div class="first-item" tabindex="0" {{dTabToSibling}}>First</div>
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
          <button class="first-button" {{dTabToSibling}}>First Button</button>
          <input class="input-field" type="text" />
          <a class="link-element" href="#">Link</a>
        </div>
      </template>
    );

    await focus(".first-button");
    await triggerKeyEvent(".first-button", "keydown", "Tab");

    assert
      .dom(".input-field")
      .isFocused("Should focus input field after Tab from button");
  });

  test("skips hidden and disabled siblings", async function (assert) {
    await render(
      <template>
        <div class="container">
          <div class="first-item" tabindex="0" {{dTabToSibling}}>First</div>
          <div class="hidden-item" hidden tabindex="0">Hidden</div>
          <button class="disabled-button" disabled>Disabled</button>
          <div class="last-item" tabindex="0">Last</div>
        </div>
      </template>
    );

    await focus(".first-item");
    await triggerKeyEvent(".first-item", "keydown", "Tab");

    assert
      .dom(".last-item")
      .isFocused("Should skip the hidden and disabled siblings");
  });

  test("prevents the default Tab behavior only when a sibling takes focus", async function (assert) {
    const defaultPrevented = [];

    await render(
      <template>
        <div class="container">
          <div class="first-item" tabindex="0" {{dTabToSibling}}>First</div>
          <div class="last-item" tabindex="0" {{dTabToSibling}}>Last</div>
        </div>
      </template>
    );

    // Bubbling to the container runs after the modifier's own listener.
    find(".container").addEventListener("keydown", (event) =>
      defaultPrevented.push(event.defaultPrevented)
    );

    await focus(".first-item");
    await triggerKeyEvent(".first-item", "keydown", "Tab");

    await focus(".last-item");
    await triggerKeyEvent(".last-item", "keydown", "Tab");

    assert.deepEqual(
      defaultPrevented,
      [true, false],
      "the browser handles Tab when there is no next sibling"
    );
    assert.dom(".last-item").isFocused("focus stays on the last item");
  });

  test("ignores non-Tab key events", async function (assert) {
    await render(
      <template>
        <div class="container">
          <div class="first-item" tabindex="0" {{dTabToSibling}}>First</div>
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
