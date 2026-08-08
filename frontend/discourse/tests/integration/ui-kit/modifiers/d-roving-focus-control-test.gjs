import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";

module(
  "Integration | ui-kit | Modifier | dRovingFocus | roving control",
  function (hooks) {
    setupRenderingTest(hooks);

    test("rovingControl clear removes every active-mode cursor effect and is idempotent", async function (assert) {
      let api;
      const changes = [];
      const register = (value) => (api = value);
      const onActiveChange = (item) => changes.push(item);

      await render(
        <template>
          <div class="controller" role="combobox" tabindex="0"></div>
          <div
            role="listbox"
            {{dRovingFocus
              selectionMode="active"
              controllerElement=".controller"
              itemSelector="[role=option]"
              activeClass="--active"
              onActiveChange=onActiveChange
              onRegisterApi=register
            }}
          >
            <button class="item" role="option">A</button>
            <button class="item" role="option">B</button>
            <button class="item" role="option">C</button>
          </div>
        </template>
      );

      const items = api.items();
      const target = items[Math.floor(items.length / 2)];
      assert.true(
        api.focusIndex(api.indexOf(target)),
        "the existing API places a cursor to clear"
      );
      changes.length = 0;

      assert.true(api.clear(), "clear reports that it removed a cursor");
      assert.strictEqual(api.currentItem(), null, "the API cursor is gone");
      assert
        .dom(".controller")
        .doesNotHaveAttribute(
          "aria-activedescendant",
          "the controller no longer advertises a cursor"
        );
      assert
        .dom(target)
        .doesNotHaveClass("--active", "the cleared item loses activeClass");
      assert.deepEqual(
        changes,
        [null],
        "onActiveChange receives exactly the active-mode clear signal"
      );

      assert.false(api.clear(), "a second clear reports there was no cursor");
      assert.deepEqual(
        changes,
        [null],
        "an empty clear emits no duplicate change signal"
      );
    });

    test("rovingControl focusNext seeds from the start after clear", async function (assert) {
      let api;
      const register = (value) => (api = value);

      await render(
        <template>
          <div class="controller" role="combobox" tabindex="0"></div>
          <div
            role="listbox"
            {{dRovingFocus
              selectionMode="active"
              controllerElement=".controller"
              itemSelector="[role=option]"
              activeClass="--active"
              onRegisterApi=register
            }}
          >
            <button class="item" role="option">A</button>
            <button class="item" role="option">B</button>
            <button class="item" role="option">C</button>
          </div>
        </template>
      );

      const items = api.items();
      const first = items[0];
      const last = items[items.length - 1];
      assert.true(
        api.focusElement(last),
        "the cursor starts at the measured end"
      );
      assert.true(api.clear(), "the end cursor is cleared");
      assert.strictEqual(
        api.focusNext(),
        "moved",
        "focusNext treats the cleared state as seedless"
      );
      assert.strictEqual(
        api.currentItem(),
        first,
        "focusNext seeds the measured first item rather than advancing from the old cursor"
      );
      assert
        .dom(".controller")
        .hasAttribute(
          "aria-activedescendant",
          first.id,
          "the controller points at the newly seeded first item"
        );
    });

    test("rovingControl clear is a focus-mode no-op that preserves DOM focus", async function (assert) {
      let api;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              onRegisterApi=register
            }}
          >
            <button class="item" role="option">A</button>
            <button class="item" role="option">B</button>
            <button class="item" role="option">C</button>
          </div>
        </template>
      );

      const items = api.items();
      const target = items[items.length - 1];
      assert.true(
        api.focusElement(target),
        "the existing API places DOM focus before clear"
      );

      // In focus mode the cursor is DOM focus. Clearing without blur would not clear it, while
      // blurring would strand keyboard users on body, so this mode deliberately does nothing.
      assert.false(api.clear(), "focus mode reports that it cleared nothing");
      assert.dom(target).isFocused("DOM focus remains on the measured item");
      assert.strictEqual(
        api.currentItem(),
        target,
        "the focus-mode cursor remains the focused item"
      );
      assert
        .dom(target)
        .hasAttribute("tabindex", "0", "the focused item remains the tab stop");
    });
  }
);
