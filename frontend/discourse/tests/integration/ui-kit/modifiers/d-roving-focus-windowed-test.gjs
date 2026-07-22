import { focus, render, settled, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";

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
