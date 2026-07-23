import { focus, render, settled, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";

// A mounted window of ten rows deep in a 5000-row logical list: data-index 100..109.
const WINDOW_ROWS = Array.from({ length: 10 }, (_, i) => 100 + i);
// A fully-mounted small list: data-index 0..9, logicalCount 10 (nothing off-window).
const SMALL_ROWS = Array.from({ length: 10 }, (_, i) => i);

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
            <button role="option" data-index="100">100</button>
            <button role="option" data-index="101">101</button>
            <button role="option" data-index="102">102</button>
            <button role="option" data-index="103">103</button>
            <button role="option" data-index="104">104</button>
            <button role="option" data-index="105">105</button>
            <button role="option" data-index="106">106</button>
            <button role="option" data-index="107">107</button>
            <button role="option" data-index="108">108</button>
            <button role="option" data-index="109">109</button>
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
            <button role="option" data-index="104">104</button>
            <button role="option" data-index="105">105</button>
            <button role="option" data-index="106">106</button>
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

    test("onEdgeReach fires at vertical edges and prevents the key", async function (assert) {
      const edges = [];
      const prevented = {};
      const onEdgeReach = (direction) => edges.push(direction);

      await render(
        <template>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              onEdgeReach=onEdgeReach
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
        edges,
        ["forward"],
        "ArrowDown at the end reaches forward"
      );
      assert.true(prevented.ArrowDown, "ArrowDown at the end is prevented");
      assert.dom(".b").isFocused("the cursor stays on the last item");

      await focus(".a");
      await triggerKeyEvent(".a", "keydown", "ArrowUp");
      assert.deepEqual(
        edges,
        ["forward", "backward"],
        "ArrowUp at the start reaches backward exactly once"
      );
      assert.true(prevented.ArrowUp, "ArrowUp at the start is prevented");
      assert.dom(".a").isFocused("the cursor stays on the first item");
    });

    test("onEdgeReach does not fire without a cursor and ArrowDown seeds the first item", async function (assert) {
      const edges = [];
      const onEdgeReach = (direction) => edges.push(direction);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              tabStop=false
              onEdgeReach=onEdgeReach
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
          </div>
        </template>
      );

      await triggerKeyEvent(".a", "keydown", "ArrowDown");
      assert.deepEqual(
        edges,
        [],
        "ArrowDown without a cursor does not reach an edge"
      );
      assert
        .dom(".a")
        .isFocused("ArrowDown without a cursor seeds the first item");
    });

    test("onEdgeReach does not fire while moving within the list or wrapping", async function (assert) {
      const edges = [];
      const onEdgeReach = (direction) => edges.push(direction);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              wrap=true
              onEdgeReach=onEdgeReach
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
      assert.deepEqual(edges, [], "a non-edge move does not reach an edge");

      await focus(".c");
      await triggerKeyEvent(".c", "keydown", "ArrowDown");
      assert.dom(".a").isFocused("ArrowDown wraps to the first item");

      await triggerKeyEvent(".a", "keydown", "ArrowUp");
      assert.dom(".c").isFocused("ArrowUp wraps to the last item");
      assert.deepEqual(edges, [], "wrapping suppresses edge callbacks");
    });

    test("Home, End, and horizontal keys do not fire onEdgeReach", async function (assert) {
      const edges = [];
      const exits = [];
      const onEdgeReach = (direction) => edges.push(direction);
      const onExit = (direction) => exits.push(direction);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              itemSelector="[role=option]"
              columns=1
              onEdgeReach=onEdgeReach
              onExit=onExit
            }}
          >
            <button class="a" role="option">A</button>
            <button class="b" role="option">B</button>
            <button class="c" role="option">C</button>
          </div>
        </template>
      );

      await focus(".b");
      await triggerKeyEvent(".b", "keydown", "Home");
      await triggerKeyEvent(".a", "keydown", "End");
      assert.deepEqual(edges, [], "Home and End do not reach a vertical edge");

      await triggerKeyEvent(".c", "keydown", "ArrowRight");
      await focus(".a");
      await triggerKeyEvent(".a", "keydown", "ArrowLeft");
      assert.deepEqual(
        edges,
        [],
        "horizontal edge keys do not reach a vertical edge"
      );
      assert.deepEqual(
        exits,
        ["forward", "backward"],
        "horizontal edge keys remain onExit's domain"
      );
    });
  }
);

// Oracle for U-D change A: logical (windowed) keyboard navigation (4b).
//
// Home/End/PageUp/PageDown must target the LOGICAL row (0 / `logicalCount-1` / ±one
// page) over the ABSOLUTE `data-index` set, not the mounted slice. An in-window target
// lands locally; an off-window target fires `onJump(target, direction)` so the consumer
// scrolls it in and refocuses. `logicalCount` absent ⇒ today's positional behavior, no
// `onJump`. Direction: Home/PageUp → "backward", End/PageDown → "forward". Page size =
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
              <button role="option" data-index={{n}}>{{n}}</button>
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
              <button role="option" data-index={{n}}>{{n}}</button>
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
              <button role="option" data-index={{n}}>{{n}}</button>
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
              <button role="option" data-index={{n}}>{{n}}</button>
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
              <button role="option" data-index={{n}}>{{n}}</button>
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
          <div class="ctrl" role="combobox" tabindex="0"></div>
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              selectionMode="active"
              controllerElement=".ctrl"
              itemSelector="[role=option]"
              activeClass="--active"
              logicalCount=5000
              onJump=onJump
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button role="option" data-index={{n}}>{{n}}</button>
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
          <input class="search" role="combobox" />
          <div
            class="list"
            role="listbox"
            {{dRovingFocus
              selectionMode="active"
              controllerElement=".search"
              itemSelector="[role=option]"
              activeClass="--active"
              logicalCount=5000
              onJump=onJump
            }}
          >
            {{#each WINDOW_ROWS as |n|}}
              <button role="option" data-index={{n}}>{{n}}</button>
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
  }
);
