import { tracked } from "@glimmer/tracking";
import {
  clearRender,
  focus,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";

module(
  "Integration | ui-kit | Modifier | dRovingFocus | lifecycle",
  function (hooks) {
    setupRenderingTest(hooks);

    test("replacing the active controller preserves the cursor and rebinds navigation", async function (assert) {
      const state = new (class {
        @tracked controller = ".first-controller";
      })();
      const changes = [];
      const onActiveChange = (item) => changes.push(item);

      await render(
        <template>
          <input
            class="first-controller"
            role="combobox"
            aria-controls="lifecycle-list"
          />
          <input
            class="second-controller"
            role="combobox"
            aria-controls="lifecycle-list"
          />
          <div
            id="lifecycle-list"
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              controllerElement=state.controller
              itemSelector="[role=option]"
              activeClass="--active"
              entryFocus="first"
              onActiveChange=onActiveChange
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
          </div>
        </template>
      );

      const activeId = document.querySelector(".a").id;
      changes.length = 0;
      state.controller = ".second-controller";
      await settled();

      assert
        .dom(".first-controller")
        .doesNotHaveAttribute(
          "aria-activedescendant",
          "the outgoing controller releases the cursor"
        );
      assert
        .dom(".second-controller")
        .hasAttribute(
          "aria-activedescendant",
          activeId,
          "the replacement controller receives the existing cursor"
        );
      assert
        .dom(".a")
        .hasClass("--active", "the active item remains highlighted");
      assert.deepEqual(
        changes,
        [],
        "replacing the controller does not report a cursor move"
      );

      await triggerKeyEvent(".first-controller", "keydown", "ArrowDown");
      assert.dom(".a").hasClass("--active", "the old listener is removed");

      await triggerKeyEvent(".second-controller", "keydown", "ArrowDown");
      assert.dom(".b").hasClass("--active", "the new controller navigates");
    });

    test("replacing the controller cancels a pending reannouncement", async function (assert) {
      const state = new (class {
        @tracked controller = ".first-controller";
      })();
      let api;
      const register = (value) => (api = value);

      await render(
        <template>
          <input
            class="first-controller"
            role="combobox"
            aria-controls="lifecycle-list"
          />
          <input
            class="second-controller"
            role="combobox"
            aria-controls="lifecycle-list"
          />
          <div
            id="lifecycle-list"
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              controllerElement=state.controller
              itemSelector="[role=option]"
              activeClass="--active"
              entryFocus="first"
              onRegisterApi=register
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
          </div>
        </template>
      );

      const activeId = document.querySelector(".a").id;
      assert.true(api.reannounceActive(), "the reannouncement is scheduled");

      state.controller = ".second-controller";
      await settled();

      assert
        .dom(".first-controller")
        .doesNotHaveAttribute(
          "aria-activedescendant",
          "the pending callback never republishes onto the old controller"
        );
      assert
        .dom(".second-controller")
        .hasAttribute(
          "aria-activedescendant",
          activeId,
          "the current controller retains the existing cursor"
        );
      assert.dom(".a").hasClass("--active", "the cursor is not reseeded");
    });

    test("leaving active mode disarms a pending seed", async function (assert) {
      const state = new (class {
        @tracked mode = "active-descendant";
        @tracked items = [];
      })();

      await render(
        <template>
          <input
            class="controller"
            role="combobox"
            aria-controls="lifecycle-list"
          />
          <div
            id="lifecycle-list"
            role="listbox"
            {{dRovingFocus
              focusStrategy=state.mode
              controllerElement=".controller"
              itemSelector="[role=option]"
              activeClass="--active"
              entryFocus="first"
              itemsKey=state.items
            }}
          >
            {{#each state.items key="id" as |item|}}
              <button role="option" id={{item.id}}>{{item.id}}</button>
            {{/each}}
          </div>
        </template>
      );

      state.mode = "roving-tabindex";
      await settled();
      state.items = [{ id: "a" }, { id: "b" }];
      await settled();

      assert
        .dom(".controller")
        .doesNotHaveAttribute(
          "aria-activedescendant",
          "rows arriving later do not revive the active cursor"
        );
      assert.dom("#a").doesNotHaveClass("--active", "no highlight is added");
      assert
        .dom("#a")
        .hasAttribute(
          "tabindex",
          "0",
          "the current roving strategy seeds normally"
        );
      assert
        .dom("#a")
        .isNotFocused("the stale observer does not move DOM focus");
    });

    test("entryFocus none disarms a pending seed", async function (assert) {
      const state = new (class {
        @tracked entryFocus = "first";
        @tracked items = [];
      })();

      await render(
        <template>
          <input
            class="controller"
            role="combobox"
            aria-controls="lifecycle-list"
          />
          <div
            id="lifecycle-list"
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              controllerElement=".controller"
              itemSelector="[role=option]"
              activeClass="--active"
              entryFocus=state.entryFocus
              itemsKey=state.items
            }}
          >
            {{#each state.items key="id" as |item|}}
              <button role="option" id={{item.id}}>{{item.id}}</button>
            {{/each}}
          </div>
        </template>
      );

      state.entryFocus = "none";
      await settled();
      state.items = [{ id: "a" }];
      await settled();

      assert
        .dom(".controller")
        .doesNotHaveAttribute(
          "aria-activedescendant",
          "the pending observer respects the current entry policy"
        );
      assert.dom("#a").doesNotHaveClass("--active", "nothing is highlighted");
    });

    test("active selector replacement releases every artifact from the old scope", async function (assert) {
      const state = new (class {
        @tracked selector = ".first-item";
      })();

      await render(
        <template>
          <input
            class="controller"
            role="combobox"
            aria-controls="lifecycle-list"
          />
          <div
            id="lifecycle-list"
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              controllerElement=".controller"
              itemSelector=state.selector
              activeClass="--active"
              entryFocus="first"
            }}
          >
            <div role="option" class="first-item">A</div>
            <div role="option" class="second-item">B</div>
            <div role="option" class="author-item" id="author-id">C</div>
          </div>
        </template>
      );

      const firstId = document.querySelector(".first-item").id;
      assert.true(Boolean(firstId), "the first scope receives a minted id");

      state.selector = ".second-item";
      await settled();

      assert
        .dom(".first-item")
        .doesNotHaveClass("--active", "the old highlight is removed");
      assert
        .dom(".first-item")
        .doesNotHaveAttribute("id", "the old modifier-minted id is removed");
      assert
        .dom(".second-item")
        .hasClass("--active", "the replacement scope is seeded");
      assert
        .dom(".controller")
        .hasAttribute(
          "aria-activedescendant",
          document.querySelector(".second-item").id,
          "the controller points into the replacement scope"
        );
      assert
        .dom(".author-item")
        .hasAttribute(
          "id",
          "author-id",
          "an author-owned id remains untouched"
        );
    });

    test("a delayed seed uses the latest callback", async function (assert) {
      const firstChanges = [];
      const secondChanges = [];
      const firstCallback = (item) => firstChanges.push(item);
      const secondCallback = (item) => secondChanges.push(item);
      const state = new (class {
        @tracked callback = firstCallback;
        @tracked items = [];
      })();

      await render(
        <template>
          <input
            class="controller"
            role="combobox"
            aria-controls="lifecycle-list"
          />
          <div
            id="lifecycle-list"
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              controllerElement=".controller"
              itemSelector="[role=option]"
              activeClass="--active"
              entryFocus="first"
              itemsKey=state.items
              onActiveChange=state.callback
            }}
          >
            {{#each state.items key="id" as |item|}}
              <button role="option" id={{item.id}}>{{item.id}}</button>
            {{/each}}
          </div>
        </template>
      );

      firstChanges.length = 0;
      state.callback = secondCallback;
      await settled();
      state.items = [{ id: "a" }];
      await settled();

      assert.deepEqual(
        firstChanges,
        [],
        "the superseded callback is not retained"
      );
      assert.deepEqual(
        secondChanges,
        [null, document.querySelector("#a")],
        "the current callback receives the empty cursor and the delayed seed"
      );
    });

    test("strategy round trips leave only the current strategy artifacts", async function (assert) {
      const state = new (class {
        @tracked mode = "active-descendant";
      })();

      await render(
        <template>
          <input
            class="controller"
            role="combobox"
            aria-controls="lifecycle-list"
          />
          <div
            id="lifecycle-list"
            role="listbox"
            {{dRovingFocus
              focusStrategy=state.mode
              controllerElement=".controller"
              itemSelector="[role=option]"
              activeClass="--active"
              entryFocus="first"
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
          </div>
        </template>
      );

      state.mode = "roving-tabindex";
      await settled();
      assert.dom(".a").doesNotHaveClass("--active", "active state is released");
      assert
        .dom(".a")
        .hasAttribute("tabindex", "0", "the roving strategy owns the item");

      state.mode = "active-descendant";
      await settled();

      assert
        .dom(".a")
        .doesNotHaveAttribute("tabindex", "the roving artifact is released");
      assert.dom(".a").hasClass("--active", "active mode seeds again");
      assert
        .dom(".controller")
        .hasAttribute(
          "aria-activedescendant",
          document.querySelector(".a").id,
          "only the current active cursor remains"
        );
    });

    test("teardown cancels pending active work and preserves author ids", async function (assert) {
      let api;
      const register = (value) => (api = value);

      await render(
        <template>
          <input
            class="controller"
            role="combobox"
            aria-controls="lifecycle-list"
          />
          <div
            id="lifecycle-list"
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              controllerElement=".controller"
              itemSelector="[role=option]"
              activeClass="--active"
              entryFocus="first"
              onRegisterApi=register
            }}
          >
            <button class="minted" role="option">A</button>
            <button class="authored" role="option" id="authored-id">B</button>
          </div>
        </template>
      );

      assert.true(api.reannounceActive(), "a reannouncement is pending");
      const controller = document.querySelector(".controller");
      const minted = document.querySelector(".minted");
      const authored = document.querySelector(".authored");

      await clearRender();

      assert.false(
        controller.hasAttribute("aria-activedescendant"),
        "teardown removes the controller cursor"
      );
      assert.false(
        minted.hasAttribute("id"),
        "the modifier-minted id is removed"
      );
      assert.strictEqual(
        authored.id,
        "authored-id",
        "the author-owned id is preserved"
      );
      assert.false(
        minted.classList.contains("--active"),
        "the active class is removed"
      );
    });

    test("tabStop toggles without moving the roving cursor", async function (assert) {
      const state = new (class {
        @tracked tabStop = true;
      })();

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="horizontal"
              itemSelector="[role=option]"
              tabStop=state.tabStop
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
          </div>
        </template>
      );

      await focus(".b");
      state.tabStop = false;
      await settled();

      assert.dom(".b").isFocused("the cursor remains on the focused item");
      assert
        .dom("[role=option][tabindex='0']")
        .doesNotExist("the group leaves the Tab sequence");

      state.tabStop = true;
      await settled();

      assert.dom(".b").isFocused("restoring the tab stop does not move focus");
      assert
        .dom(".b")
        .hasAttribute("tabindex", "0", "the cursor becomes the tab stop again");
    });
  }
);
