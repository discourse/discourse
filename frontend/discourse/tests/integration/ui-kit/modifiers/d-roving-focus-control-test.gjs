import { findAll, render } from "@ember/test-helpers";
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
          <div
            class="controller"
            role="combobox"
            aria-controls="rf-lb"
            tabindex="0"
          ></div>
          <div
            id="rf-lb"
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              entryFocus="none"
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
          <div
            class="controller"
            role="combobox"
            aria-controls="rf-lb"
            tabindex="0"
          ></div>
          <div
            id="rf-lb"
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              entryFocus="none"
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

    test("rovingControl tabStop=false reports truthful API movement for non-focusable items", async function (assert) {
      let api;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              tabStop=false
              onRegisterApi=register
            }}
          >
            <div class="truthful-item" role="option">A</div>
            <div class="truthful-item" role="option">B</div>
            <div class="truthful-item" role="option">C</div>
          </div>
        </template>
      );

      const items = findAll(".truthful-item");
      for (const item of items) {
        item.removeAttribute("tabindex");
      }

      let previous = api.currentItem();
      for (const [index, item] of items.entries()) {
        assert.strictEqual(
          api.focusNext(),
          "moved",
          `step ${index + 1} reports a move`
        );
        const current = api.currentItem();
        assert.notStrictEqual(
          current,
          previous,
          `step ${index + 1} changes the cursor it reports`
        );
        assert.strictEqual(
          current,
          item,
          `step ${index + 1} advances to the measured item`
        );
        assert.dom(item).isFocused(`step ${index + 1} moves DOM focus`);
        previous = current;
      }

      const edgeCursor = api.currentItem();
      assert.strictEqual(
        api.focusNext(),
        "edge",
        "a step past the final item truthfully reports the edge"
      );
      assert.strictEqual(
        api.currentItem(),
        edgeCursor,
        "an edge result leaves the cursor unchanged"
      );
      assert
        .dom(".truthful-item[tabindex='0']")
        .doesNotExist("tabStop=false leaves every item outside the Tab order");
    });

    test("rovingControl tabStop=true focuses non-focusable items as the tab stop", async function (assert) {
      let api;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              tabStop=true
              onRegisterApi=register
            }}
          >
            <div class="tab-stop-item" role="option">A</div>
            <div class="tab-stop-item" role="option">B</div>
          </div>
        </template>
      );

      const items = findAll(".tab-stop-item");
      assert.true(api.focusFirst(), "focusFirst lands on the first item");
      assert.strictEqual(api.focusNext(), "moved", "focusNext moves once");
      assert.strictEqual(
        api.currentItem(),
        items[1],
        "the cursor reaches the second non-focusable item"
      );
      assert.dom(items[1]).isFocused("DOM focus follows the cursor");
      assert
        .dom(items[1])
        .hasAttribute(
          "tabindex",
          "0",
          "the focused non-focusable item is the Tab stop"
        );
      assert
        .dom(".tab-stop-item[tabindex='0']")
        .exists({ count: 1 }, "the group retains exactly one Tab stop");
    });

    test("rovingControl registers a frozen shared API object", async function (assert) {
      let api;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]" onRegisterApi=register}}
          >
            <button role="option">A</button>
          </div>
        </template>
      );

      const originalFocusNext = api.focusNext;
      assert.true(Object.isFrozen(api), "the shared API object is frozen");
      assert.throws(
        () => (api.focusNext = () => "moved"),
        TypeError,
        "strict-mode assignment cannot replace a shared API method"
      );
      if (api.focusNext !== originalFocusNext) {
        api.focusNext = originalFocusNext;
      }

      assert.throws(
        () => (api.injected = true),
        TypeError,
        "strict-mode assignment cannot extend the shared API object"
      );
      if ("injected" in api) {
        delete api.injected;
      }
    });
  }
);
