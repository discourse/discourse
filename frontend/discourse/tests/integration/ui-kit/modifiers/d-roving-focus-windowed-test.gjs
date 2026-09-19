import { focus, render, settled, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";

/** A mounted window of ten rows deep in a 5000-row logical list: data-index 100..109. */
const WINDOW_ROWS = Array.from({ length: 10 }, (_, i) => 100 + i);

/** A fully-mounted small list: data-index 0..9, logicalCount 10 (nothing off-window). */
const SMALL_ROWS = Array.from({ length: 10 }, (_, i) => i);

/**
 * The same ten-row window with one row disabled, so the rendered cell count and the navigable
 * count differ.
 */
const WINDOW_ROWS_ONE_DISABLED = WINDOW_ROWS.map((index) => ({
  index,
  disabled: index === 109 ? "true" : "false",
}));

module(
  "Integration | ui-kit | Modifier | dRovingFocus | windowed",
  function (hooks) {
    setupRenderingTest(hooks);

    test("focusLogicalIndex focuses a mounted logical index", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]" onRegisterApi=register}}
          >
            <button data-index="100" role="option">100</button>
            <button data-index="101" role="option">101</button>
            <button data-index="102" role="option">102</button>
            <button data-index="103" role="option">103</button>
            <button data-index="104" role="option">104</button>
            <button data-index="105" role="option">105</button>
            <button data-index="106" role="option">106</button>
            <button data-index="107" role="option">107</button>
            <button data-index="108" role="option">108</button>
            <button data-index="109" role="option">109</button>
          </div>
        </template>
      );

      assert.strictEqual(
        typeof api?.focusLogicalIndex,
        "function",
        "the registered api exposes focusLogicalIndex"
      );
      assert.true(
        api?.focusLogicalIndex?.(105),
        "focusLogicalIndex reports it landed on the mounted logical item"
      );
      await settled();
      assert
        .dom('[data-index="105"]')
        .isFocused("focusLogicalIndex moves DOM focus to the logical item");
      assert
        .dom('[data-index="105"]')
        .hasAttribute("tabindex", "0", "the logical item becomes the tab stop");
      assert
        .dom('[data-index="100"]')
        .hasAttribute("tabindex", "-1", "the previous tab stop is cleared");
    });

    test("focusLogicalIndex does not move when the logical index is outside the mounted window", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]" onRegisterApi=register}}
          >
            <button data-index="104" role="option">104</button>
            <button data-index="105" role="option">105</button>
            <button data-index="106" role="option">106</button>
          </div>
        </template>
      );

      assert.true(api.focusIndex(1), "the existing api seeds the middle item");
      await settled();
      assert
        .dom('[data-index="105"]')
        .isFocused("the cursor starts in the window");

      assert.strictEqual(
        typeof api?.focusLogicalIndex,
        "function",
        "the registered api exposes focusLogicalIndex"
      );
      assert.false(
        api?.focusLogicalIndex?.(5000),
        "focusLogicalIndex reports no mounted logical item"
      );
      await settled();
      assert
        .dom('[data-index="105"]')
        .isFocused("a missing logical index does not move the cursor");
      assert
        .dom('[data-index="105"]')
        .hasAttribute(
          "tabindex",
          "0",
          "a missing index preserves the tab stop"
        );
    });

    test("focusLogicalIndex falls back to positional indexes without data-index", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="grid"
            {{dRovingFocus
              itemSelector="[role=gridcell]"
              onRegisterApi=register
            }}
          >
            <div role="row"><button class="a" role="gridcell">A</button></div>
            <div role="row"><button class="b" role="gridcell">B</button></div>
            <div role="row"><button class="c" role="gridcell">C</button></div>
          </div>
        </template>
      );

      assert.strictEqual(
        typeof api?.focusLogicalIndex,
        "function",
        "the registered api exposes focusLogicalIndex"
      );
      assert.true(
        api?.focusLogicalIndex?.(2),
        "focusLogicalIndex reports it landed by position"
      );
      await settled();
      assert.dom(".c").isFocused("the positional fallback focuses index 2");
      assert
        .dom(".c")
        .hasAttribute(
          "tabindex",
          "0",
          "the positional item becomes the tab stop"
        );
    });

    test("focusLogicalIndex returns false for an empty group", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]" onRegisterApi=register}}
          ></div>
        </template>
      );

      assert.strictEqual(
        typeof api?.focusLogicalIndex,
        "function",
        "the registered api exposes focusLogicalIndex"
      );
      assert.false(
        api?.focusLogicalIndex?.(0),
        "focusLogicalIndex reports no item landed in an empty group"
      );
    });

    test("onBoundary fires at vertical edges and prevents the key", async function (assert) {
      const boundaries = [];
      const prevented = {};
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              onBoundary=onBoundary
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
          </div>
        </template>
      );

      document.querySelector(".list").addEventListener("keydown", (event) => {
        prevented[event.key] = event.defaultPrevented;
      });

      await focus(".b");
      await triggerKeyEvent(".b", "keydown", "ArrowDown");
      assert.deepEqual(
        boundaries,
        ["vertical:forward"],
        "ArrowDown at the end reaches forward"
      );
      assert.true(prevented.ArrowDown, "ArrowDown at the end is prevented");
      assert.dom(".b").isFocused("the cursor stays on the last item");

      await focus(".a");
      await triggerKeyEvent(".a", "keydown", "ArrowUp");
      assert.deepEqual(
        boundaries,
        ["vertical:forward", "vertical:backward"],
        "ArrowUp at the start reaches backward exactly once"
      );
      assert.true(prevented.ArrowUp, "ArrowUp at the start is prevented");
      assert.dom(".a").isFocused("the cursor stays on the first item");
    });

    test("onBoundary does not fire without a cursor and ArrowDown seeds the first item", async function (assert) {
      const boundaries = [];
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              tabStop=false
              onBoundary=onBoundary
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
          </div>
        </template>
      );

      await triggerKeyEvent(".a", "keydown", "ArrowDown");
      assert.deepEqual(
        boundaries,
        [],
        "ArrowDown without a cursor does not reach an edge"
      );
      assert
        .dom(".a")
        .isFocused("ArrowDown without a cursor seeds the first item");
    });

    test("onBoundary does not fire while moving within the list or wrapping", async function (assert) {
      const boundaries = [];
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              wrap=true
              onBoundary=onBoundary
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
            <button class="c" role="option">C</button>
          </div>
        </template>
      );

      await focus(".a");
      await triggerKeyEvent(".a", "keydown", "ArrowDown");
      assert.dom(".b").isFocused("ArrowDown moves within the list");
      assert.deepEqual(
        boundaries,
        [],
        "a non-edge move does not reach an edge"
      );

      await focus(".c");
      await triggerKeyEvent(".c", "keydown", "ArrowDown");
      assert.dom(".a").isFocused("ArrowDown wraps to the first item");

      await triggerKeyEvent(".a", "keydown", "ArrowUp");
      assert.dom(".c").isFocused("ArrowUp wraps to the last item");
      assert.deepEqual(
        boundaries,
        [],
        "wrapping suppresses the boundary callback"
      );
    });

    test("Home and End stay silent while horizontal edges fire onBoundary", async function (assert) {
      const boundaries = [];
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            style="display: grid; grid-template-columns: repeat(1, 40px);"
            {{dRovingFocus itemSelector="[role=option]" onBoundary=onBoundary}}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
            <button class="c" role="option">C</button>
          </div>
        </template>
      );

      // Home and End move without reporting anything, while the horizontal arrows at either end
      // report a boundary on their own axis. Each step also asserts where the cursor actually
      // landed, which is what would catch a key being mis-routed to the wrong axis.
      await focus(".b");
      await triggerKeyEvent(".b", "keydown", "Home");
      assert.dom(".a").isFocused("Home moves to the first item");

      await triggerKeyEvent(".a", "keydown", "End");
      assert.dom(".c").isFocused("End moves to the last item");

      await triggerKeyEvent(".c", "keydown", "ArrowRight");
      assert.dom(".c").isFocused("ArrowRight at the last item does not move");

      await focus(".a");
      await triggerKeyEvent(".a", "keydown", "ArrowLeft");
      assert.dom(".a").isFocused("ArrowLeft at the first item does not move");

      assert.deepEqual(
        boundaries,
        ["horizontal:forward", "horizontal:backward"],
        "only the two horizontal ends report, and they report the horizontal axis — Home and End reach no boundary at all"
      );
    });
  }
);

// Home/End/PageUp/PageDown must target the LOGICAL row (0 / `logicalCount-1` / ±one
// page) over the ABSOLUTE `data-index` set, not the mounted slice. An in-window target
// lands locally; an off-window target fires `onJump(target, direction)` so the consumer
// scrolls it in and refocuses. `logicalCount` absent ⇒ Home/End keep their positional behavior
// and the PAGE keys are not claimed at all, so a scrollable container pages natively; no
// `onJump` either way. Direction: Home/PageUp → "backward", End/PageDown → "forward". Page size =
// the mounted navigable count. In ACTIVE mode PageUp/PageDown always navigate the
// listbox; Home/End navigate it only when the controller is NON-editable (select-only
// combobox) and are left for the caret when it is editable (editable combobox).
module(
  "Integration | ui-kit | Modifier | dRovingFocus | logical jumps",
  function (hooks) {
    setupRenderingTest(hooks);

    test("focus mode: End jumps to the last logical row when it is off-window", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);
      const prevented = {};

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=5000
              onJump=onJump
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );
      document
        .querySelector(".list")
        .addEventListener(
          "keydown",
          (e) => (prevented[e.key] = e.defaultPrevented)
        );

      await focus('[data-index="105"]');
      await triggerKeyEvent('[data-index="105"]', "keydown", "End");

      assert.deepEqual(
        jumps,
        [[4999, "forward"]],
        "End fires onJump for the last logical row (5000-1)"
      );
      assert.true(
        prevented.End,
        "End is prevented (the consumer owns the scroll)"
      );
      assert
        .dom('[data-index="105"]')
        .isFocused(
          "focus stays on the current row until the consumer refocuses post-scroll"
        );
    });

    test("focus mode: Home jumps to logical row 0 when it is off-window", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);
      const prevented = {};

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=5000
              onJump=onJump
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );
      document
        .querySelector(".list")
        .addEventListener(
          "keydown",
          (e) => (prevented[e.key] = e.defaultPrevented)
        );

      await focus('[data-index="105"]');
      await triggerKeyEvent('[data-index="105"]', "keydown", "Home");

      assert.deepEqual(
        jumps,
        [[0, "backward"]],
        "Home fires onJump for logical row 0"
      );
      assert.true(prevented.Home, "Home is prevented");
    });

    test("focus mode: PageDown pages down by the mounted count and clamps to the last logical row", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=5000
              onJump=onJump
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );

      await focus('[data-index="105"]');
      await triggerKeyEvent('[data-index="105"]', "keydown", "PageDown");

      assert.deepEqual(
        jumps,
        [[115, "forward"]],
        "PageDown targets current (105) + page size (10 mounted rows)"
      );
    });

    test("focus mode: PageDown clamps to the last logical row", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);

      // 105 + a 10-row page overshoots a 112-row list, so this is the fixture that actually
      // reaches `Math.min`. The 5000-row case above is an ordinary increment and would still
      // pass with the clamp deleted.
      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=112
              onJump=onJump
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );

      await focus('[data-index="105"]');
      await triggerKeyEvent('[data-index="105"]', "keydown", "PageDown");

      assert.deepEqual(
        jumps,
        [[111, "forward"]],
        "PageDown clamps to the last logical row (112-1) instead of overshooting to 115"
      );
    });

    test("focus mode: PageUp pages up by the mounted count", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=5000
              onJump=onJump
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );

      await focus('[data-index="105"]');
      await triggerKeyEvent('[data-index="105"]', "keydown", "PageUp");

      assert.deepEqual(
        jumps,
        [[95, "backward"]],
        "PageUp targets current (105) - page size (10)"
      );
    });

    test("focus mode: an in-window logical End lands locally without firing onJump", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=10
              onJump=onJump
            }}
          >
            {{#each SMALL_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );

      await focus('[data-index="3"]');
      await triggerKeyEvent('[data-index="3"]', "keydown", "End");

      assert.deepEqual(jumps, [], "an in-window target does not fire onJump");
      assert
        .dom('[data-index="9"]')
        .isFocused("End moves the cursor to the mounted last logical row");
    });

    test("without logicalCount: Home/End stay positional over the mounted rows and never fire onJump", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              onJump=onJump
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
            <button class="c" role="option">C</button>
          </div>
        </template>
      );

      await focus(".b");
      await triggerKeyEvent(".b", "keydown", "End");
      assert.dom(".c").isFocused("End goes to the last mounted item");

      await triggerKeyEvent(".c", "keydown", "Home");
      assert.dom(".a").isFocused("Home goes to the first mounted item");

      assert.deepEqual(
        jumps,
        [],
        "no logicalCount ⇒ no windowing ⇒ onJump never fires"
      );
    });

    test("active mode, non-editable controller: Home navigates the listbox (select-only combobox)", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);
      const prevented = {};

      await render(
        <template>
          <div
            aria-controls="rf-lb"
            class="ctrl"
            role="combobox"
            tabindex="0"
          ></div>
          <div
            class="list"
            id="rf-lb"
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              entryFocus="none"
              controllerElement=".ctrl"
              itemSelector="[role=option]"
              activeClass="--active"
              logicalCount=5000
              onJump=onJump
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );
      document
        .querySelector(".ctrl")
        .addEventListener(
          "keydown",
          (e) => (prevented[e.key] = e.defaultPrevented)
        );

      await focus(".ctrl");
      await triggerKeyEvent(".ctrl", "keydown", "ArrowDown"); // seed the cursor on 100

      await triggerKeyEvent(".ctrl", "keydown", "Home");
      assert.deepEqual(
        jumps,
        [[0, "backward"]],
        "Home navigates the listbox when the controller has no caret"
      );
      assert.true(
        prevented.Home,
        "Home is prevented for a select-only combobox"
      );
    });

    test("active mode, editable controller: Home/End are left for the caret; PageDown still navigates the listbox", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);
      const prevented = {};

      await render(
        <template>
          <input aria-controls="rf-lb" class="search" role="combobox" />
          <div
            class="list"
            id="rf-lb"
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              entryFocus="none"
              controllerElement=".search"
              itemSelector="[role=option]"
              activeClass="--active"
              logicalCount=5000
              onJump=onJump
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );
      document
        .querySelector(".search")
        .addEventListener(
          "keydown",
          (e) => (prevented[e.key] = e.defaultPrevented)
        );

      await focus(".search");
      await triggerKeyEvent(".search", "keydown", "ArrowDown"); // seed the cursor on 100

      await triggerKeyEvent(".search", "keydown", "Home");
      await triggerKeyEvent(".search", "keydown", "End");
      assert.deepEqual(
        jumps,
        [],
        "Home/End do not navigate the listbox on an editable combobox"
      );
      assert.false(prevented.Home, "Home is left for the input caret");
      assert.false(prevented.End, "End is left for the input caret");

      await triggerKeyEvent(".search", "keydown", "PageDown");
      assert.deepEqual(
        jumps,
        [[110, "forward"]],
        "PageDown pages the listbox even on an editable combobox (100 + 10)"
      );
      assert.true(prevented.PageDown, "PageDown is prevented");
    });

    test("without logicalCount the page keys are left to the scroll container", async function (assert) {
      const prevented = {};

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus orientation="vertical" itemSelector="[role=option]"}}
          >
            {{#each SMALL_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );
      document
        .querySelector(".list")
        .addEventListener(
          "keydown",
          (e) => (prevented[e.key] = e.defaultPrevented)
        );

      await focus('[data-index="5"]');
      await triggerKeyEvent('[data-index="5"]', "keydown", "PageDown");
      assert
        .dom('[data-index="5"]')
        .isFocused(
          "PageDown does not move the cursor without a logical row count"
        );
      assert.false(
        prevented.PageDown,
        "and it falls through so the container can page natively"
      );

      await triggerKeyEvent('[data-index="5"]', "keydown", "PageUp");
      assert
        .dom('[data-index="5"]')
        .isFocused("PageUp does not move the cursor either");
      assert.false(prevented.PageUp, "and it falls through too");
    });

    test("a page is the mounted navigable count, not the rendered cell count", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=5000
              onJump=onJump
            }}
          >
            {{#each WINDOW_ROWS_ONE_DISABLED key="index" as |row|}}
              <button
                aria-disabled={{row.disabled}}
                data-index={{row.index}}
                role="option"
              >{{row.index}}</button>
            {{/each}}
          </div>
        </template>
      );

      await focus('[data-index="105"]');
      await triggerKeyEvent('[data-index="105"]', "keydown", "PageDown");

      // Ten rows are rendered but one is disabled, so a page is nine.
      assert.deepEqual(
        jumps,
        [[114, "forward"]],
        "a disabled placeholder does not lengthen the page"
      );
    });

    test("a page key with no cursor pages from the mounted window", async function (assert) {
      const jumps = [];
      const onJump = (target, direction) => jumps.push([target, direction]);

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=5000
              onJump=onJump
              tabStop=false
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );

      // No cursor, so there is no current logical row to page from. Anchoring on -1 would
      // page to row 9 — backwards past the window on a PageDown.
      await triggerKeyEvent('[data-index="100"]', "keydown", "PageDown");

      assert.deepEqual(
        jumps,
        [[110, "forward"]],
        "PageDown pages forward from the window's first row, not from -1"
      );
    });

    test("a jump key is left alone when there is no onJump to service it", async function (assert) {
      const prevented = {};

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=5000
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button data-index={{n}} role="option">{{n}}</button>
            {{/each}}
          </div>
        </template>
      );
      document
        .querySelector(".list")
        .addEventListener(
          "keydown",
          (e) => (prevented[e.key] = e.defaultPrevented)
        );

      await focus('[data-index="105"]');
      await triggerKeyEvent('[data-index="105"]', "keydown", "End");

      // The target is off-window and no consumer can scroll it in, so swallowing the key
      // would make End do nothing at all.
      assert.false(
        prevented.End,
        "an unserviceable jump falls through instead of becoming a dead key"
      );
      assert
        .dom('[data-index="105"]')
        .isFocused(
          "an unserviceable End leaves the cursor on its mounted starting row"
        );
    });

    test("focusLogicalIndex refuses an out-of-range index on an unstamped group", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=5000
              onRegisterApi=register
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
            <button class="c" role="option">C</button>
          </div>
        </template>
      );

      // Nothing is stamped, so the index is positional — but positional addressing must be
      // bounds-checked, not clamped: reporting success here would tell a windowed consumer the
      // jump had been serviced when the row was never reached.
      assert.false(
        api.focusLogicalIndex(4999),
        "an index past the mounted rows reports no landing"
      );
      assert
        .dom(".c")
        .isNotFocused("and the cursor is not clamped onto the last row");

      assert.true(api.focusLogicalIndex(2), "an in-range index still lands");
      assert.dom(".c").isFocused("on the row at that position");
    });

    test("a logical index prefers data-logical-index over data-index", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=5000
              onRegisterApi=register
            }}
          >
            <button
              class="a"
              data-index="0"
              data-logical-index="40"
              role="option"
            >A</button>
            <button
              class="b"
              data-index="1"
              data-logical-index="41"
              role="option"
            >B</button>
          </div>
        </template>
      );

      // A windowed list with non-option rows stamps its own option ordinal, which must win over
      // the raw virtualizer index.
      assert.true(
        api.focusLogicalIndex(41),
        "the logical ordinal identifies the row"
      );
      assert.dom(".b").isFocused("and the cursor lands on it");

      assert.false(
        api.focusLogicalIndex(1),
        "the raw virtualizer index is not what is addressed"
      );
    });

    test("a logical index matches its row however the attribute is written", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              logicalCount=5000
              onRegisterApi=register
            }}
          >
            <button class="r1" data-index="0105" role="option">105</button>
            <button class="r2" data-index="106" role="option">106</button>
          </div>
        </template>
      );

      assert.true(
        api.focusLogicalIndex(105),
        "a zero-padded index still identifies its row"
      );
      assert.dom(".r1").isFocused("and the cursor lands on it");
    });

    test("focusLogicalIndex declines a fractional index on an unstamped list", async function (assert) {
      let api = null;
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
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
            <button class="c" role="option">C</button>
          </div>
        </template>
      );

      assert.false(
        api.focusLogicalIndex(1.5),
        "a fractional index reports false instead of landing between rows"
      );
      await settled();
      assert
        .dom(".a")
        .hasAttribute(
          "tabindex",
          "0",
          "the seeded tab stop is untouched by the declined call"
        );
    });
  }
);
