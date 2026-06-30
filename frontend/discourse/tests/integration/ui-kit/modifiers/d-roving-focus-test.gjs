import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { click, focus, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";

module("Integration | ui-kit | Modifier | dRovingFocus", function (hooks) {
  setupRenderingTest(hooks);

  test("focus mode: arrows move focus in DOM order, one tab stop", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus orientation="horizontal" itemSelector="[role=option]"}}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    assert
      .dom(".a")
      .hasAttribute("tabindex", "0", "first item is the tab stop");
    assert.dom(".b").hasAttribute("tabindex", "-1");

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");
    assert.dom(".b").isFocused("ArrowRight moves focus to the next item");
    assert.dom(".b").hasAttribute("tabindex", "0", "tab stop follows focus");
    assert.dom(".a").hasAttribute("tabindex", "-1");

    await triggerKeyEvent(".b", "keydown", "ArrowLeft");
    assert.dom(".a").isFocused("ArrowLeft moves focus to the previous item");
  });

  test("focus mode: grid down/up moves by the live column count", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus itemSelector="[role=option]"}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option">4</button>
        </div>
      </template>
    );

    await focus(".i0");
    await triggerKeyEvent(".i0", "keydown", "ArrowDown");
    assert.dom(".i3").isFocused("ArrowDown moves one row (3 columns) down");

    await triggerKeyEvent(".i3", "keydown", "ArrowUp");
    assert.dom(".i0").isFocused("ArrowUp moves one row up");

    // Ragged last row: down from index 1 (row 0) would be index 4 (exists);
    // down from index 2 would be index 5 (missing) -> clamp to last (index 4).
    await focus(".i2");
    await triggerKeyEvent(".i2", "keydown", "ArrowDown");
    assert
      .dom(".i4")
      .isFocused("ArrowDown past a ragged last row clamps to last");
  });

  test("focus mode: Home/End jump, no wrap by default at edges", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus orientation="horizontal" itemSelector="[role=option]"}}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "End");
    assert.dom(".c").isFocused("End jumps to the last item");

    await triggerKeyEvent(".c", "keydown", "ArrowRight");
    assert
      .dom(".c")
      .isFocused("ArrowRight at the last item does nothing (no wrap)");

    await triggerKeyEvent(".c", "keydown", "Home");
    assert.dom(".a").isFocused("Home jumps to the first item");
  });

  test("focus mode: wrap=true wraps at the edges", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=option]"
            wrap=true
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowLeft");
    assert
      .dom(".b")
      .isFocused("ArrowLeft from the first item wraps to the last");
  });

  test("columns override takes precedence over CSS derivation", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus itemSelector="[role=option]" columns=2}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
        </div>
      </template>
    );

    await focus(".i0");
    await triggerKeyEvent(".i0", "keydown", "ArrowDown");
    assert
      .dom(".i2")
      .isFocused("ArrowDown moves by the overridden column count (2)");
  });

  test("skips hidden and disabled items", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus orientation="horizontal" itemSelector="[role=option]"}}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option" disabled>B</button>
          <button class="c" role="option" style="display: none;">C</button>
          <button class="d" role="option">D</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");
    assert.dom(".d").isFocused("disabled and hidden items are skipped");
  });

  test("Enter and Space activate; other keys do not", async function (assert) {
    let activated = [];
    const onActivate = (el) => activated.push(el.className);

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=option]"
            onActivate=(fn onActivate)
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "Enter");
    await triggerKeyEvent(".a", "keydown", " ");
    assert.deepEqual(
      activated,
      ["a", "a"],
      "Enter and Space activate the current item"
    );

    await triggerKeyEvent(".a", "keydown", "Escape");
    assert.deepEqual(activated, ["a", "a"], "other keys do not activate");
  });

  test("active mode: focus stays on the controller, aria-activedescendant tracks", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" />
        <div
          role="listbox"
          {{dRovingFocus
            selectionMode="active"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowDown");

    assert.dom(".search").isFocused("focus stays on the search input");
    const activeId = document
      .querySelector(".search")
      .getAttribute("aria-activedescendant");
    assert.true(
      Boolean(activeId),
      "the controller carries aria-activedescendant"
    );
    assert
      .dom(".b")
      .hasAttribute("id", activeId, "it points at the highlighted item");
    assert
      .dom(".b")
      .hasClass("--active", "the highlighted item gets the active class");
    assert.dom(".a").doesNotHaveClass("--active");
  });

  test("active mode: Enter activates the highlighted item", async function (assert) {
    let activated = null;
    const onActivate = (el) => (activated = el.className);

    await render(
      <template>
        <input class="search" role="combobox" />
        <div
          role="listbox"
          {{dRovingFocus
            selectionMode="active"
            controllerElement=".search"
            itemSelector="[role=option]"
            onActivate=(fn onActivate)
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    await triggerKeyEvent(".search", "keydown", "Enter");
    assert.strictEqual(
      activated,
      "b",
      "Enter activates the highlighted (not focused) item"
    );
  });

  test("active mode: a changing item set resets the highlight to a live id", async function (assert) {
    class State {
      @tracked items = ["a", "b", "c"];
      @tracked key = 0;
    }
    const state = new State();
    const refilter = () => {
      state.items = ["x", "y"];
      state.key++;
    };

    await render(
      <template>
        <input class="search" role="combobox" />
        <button
          class="refilter"
          type="button"
          {{on "click" refilter}}
        >x</button>
        <div
          role="listbox"
          {{dRovingFocus
            selectionMode="active"
            controllerElement=".search"
            itemSelector="[role=option]"
            itemsKey=state.key
            activeClass="--active"
          }}
        >
          {{#each state.items as |item|}}
            <button class="opt-{{item}}" role="option">{{item}}</button>
          {{/each}}
        </div>
      </template>
    );

    await focus(".search");
    // Highlight the second item, then swap the whole list out via tracked state.
    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    await click(".refilter");

    const activeId = document
      .querySelector(".search")
      .getAttribute("aria-activedescendant");
    assert
      .dom(`#${activeId}`)
      .exists("aria-activedescendant points at an element that still exists");
  });
});
