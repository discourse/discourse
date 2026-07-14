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

  test("focus mode: focus on a descendant of an item resolves to that item", async function (assert) {
    // An item may contain its own focusable controls (an inline button, or the
    // trigger a closed popover just handed focus back to). Focus resting on such
    // a descendant should navigate from its containing item, not fall back to
    // the tab stop.
    await render(
      <template>
        <div
          role="tree"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=treeitem]"
          }}
        >
          <div class="a" role="treeitem">A</div>
          <div class="b" role="treeitem">
            B
            {{! Intentionally nests a focusable control in the item to exercise
              descendant-focus resolution. }}
            {{! eslint-disable-next-line ember/template-no-nested-interactive }}
            <span class="b-inner" tabindex="0">x</span>
          </div>
          <div class="c" role="treeitem">C</div>
        </div>
      </template>
    );

    // Focus a control *inside* item B (not B itself), then navigate.
    await focus(".b-inner");
    await triggerKeyEvent(".b-inner", "keydown", "ArrowRight");
    assert
      .dom(".c")
      .isFocused("ArrowRight navigates from the item containing the focus");
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

  test("focus mode: skips visibility:hidden items", async function (assert) {
    // `visibility: hidden` still participates in layout (so the offsetParent /
    // client-rects check passes) but cannot take focus — it must be skipped just
    // like `display: none`.
    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus orientation="horizontal" itemSelector="[role=option]"}}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option" style="visibility: hidden;">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");
    assert.dom(".c").isFocused("a visibility:hidden item is skipped");
  });

  test("focus mode: keys from an embedded editable are left alone", async function (assert) {
    // An item may embed a text field; its caret and selection keys — including
    // Home/End — must win over roving navigation. The modifier ignores keydowns
    // that originate from an editable target so the field behaves natively.
    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus orientation="horizontal" itemSelector="[role=option]"}}
        >
          <button class="a" role="option">A</button>
          <span class="b" role="option">
            {{! Intentionally embeds a text field in an item to exercise the
              editable-target guard. }}
            {{! eslint-disable-next-line ember/template-no-nested-interactive }}
            <input class="b-input" type="text" />
          </span>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    await focus(".b-input");
    await triggerKeyEvent(".b-input", "keydown", "ArrowRight");
    assert
      .dom(".b-input")
      .isFocused("ArrowRight from an embedded input does not navigate");

    await triggerKeyEvent(".b-input", "keydown", "Home");
    assert
      .dom(".b-input")
      .isFocused("Home from an embedded input does not jump to the first item");
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
      .dom(".a")
      .hasAttribute(
        "id",
        activeId,
        "first ArrowDown highlights the first option"
      );
    assert
      .dom(".a")
      .hasClass("--active", "the highlighted item gets the active class");
    assert.dom(".b").doesNotHaveClass("--active");
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
      "a",
      "Enter activates the highlighted (first) option, not the focused input"
    );
  });

  test("active mode: a changing item set clears a stale highlight", async function (assert) {
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
    // Highlight the first item, then swap the whole list out via tracked state.
    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    await click(".refilter");

    assert
      .dom(".search")
      .doesNotHaveAttribute(
        "aria-activedescendant",
        "a highlight whose item was filtered out is cleared, never left stale"
      );

    // A fresh ArrowDown reseeds the first option of the new list.
    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    const activeId = document
      .querySelector(".search")
      .getAttribute("aria-activedescendant");
    assert
      .dom(".opt-x")
      .hasAttribute("id", activeId, "ArrowDown reseeds the first live option");
  });

  test("active mode: autoActivateFirst highlights the first item on insert", async function (assert) {
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
            autoActivateFirst=true
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    assert
      .dom(".a")
      .hasClass(
        "--active",
        "the first item is highlighted without any keypress"
      );
    const activeId = document
      .querySelector(".search")
      .getAttribute("aria-activedescendant");
    assert.dom(".a").hasAttribute("id", activeId);
    assert.dom(".b").doesNotHaveClass("--active");
  });

  test("active mode: autoActivateFirst re-seeds the first item when the set changes", async function (assert) {
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
            autoActivateFirst=true
          }}
        >
          {{#each state.items key="@identity" as |item|}}
            <button class="opt-{{item}}" role="option">{{item}}</button>
          {{/each}}
        </div>
      </template>
    );

    assert
      .dom(".opt-a")
      .hasClass("--active", "first item highlighted initially");

    // Swap the whole list; the highlight re-seeds to the new first with no keypress.
    await click(".refilter");
    assert
      .dom(".opt-x")
      .hasClass("--active", "the highlight follows to the new first item");
    const activeId = document
      .querySelector(".search")
      .getAttribute("aria-activedescendant");
    assert.dom(".opt-x").hasAttribute("id", activeId);
  });

  test("active mode: without autoActivateFirst nothing is highlighted until an Arrow key", async function (assert) {
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

    assert.dom(".--active").doesNotExist("no highlight before interaction");
    assert.dom(".search").doesNotHaveAttribute("aria-activedescendant");
  });

  test("active mode: Space does not activate and is left for the input", async function (assert) {
    let activated = false;
    let spacePrevented = null;
    const onActivate = () => (activated = true);

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
            onActivate=(fn onActivate)
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    // Listener registered after the modifier's, so it observes whether the modifier
    // prevented the key — proving a Space reaches the input to be typed.
    document
      .querySelector(".search")
      .addEventListener(
        "keydown",
        (e) => e.key === " " && (spacePrevented = e.defaultPrevented)
      );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowDown"); // highlight .a
    await triggerKeyEvent(".search", "keydown", " ");

    assert.false(activated, "Space does not activate in a text combobox");
    assert.false(
      spacePrevented,
      "Space is not preventDefault-ed, so the character reaches the input"
    );
    assert
      .dom(".a")
      .hasClass("--active", "the highlight does not move on Space");
  });

  test("active mode: Home/End/Left/Right are left for the text caret", async function (assert) {
    const prevented = {};

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

    document
      .querySelector(".search")
      .addEventListener(
        "keydown",
        (e) => (prevented[e.key] = e.defaultPrevented)
      );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowDown"); // highlight .a

    for (const key of ["Home", "End", "ArrowLeft", "ArrowRight"]) {
      await triggerKeyEvent(".search", "keydown", key);
      assert.false(
        prevented[key],
        `${key} is left for the caret, not intercepted`
      );
    }
    assert
      .dom(".a")
      .hasClass("--active", "the highlight does not move on caret keys");
  });

  test("active mode: Enter with no highlight does not activate", async function (assert) {
    let activated = false;
    let enterPrevented = null;
    const onActivate = () => (activated = true);

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
        </div>
      </template>
    );

    document
      .querySelector(".search")
      .addEventListener(
        "keydown",
        (e) => e.key === "Enter" && (enterPrevented = e.defaultPrevented)
      );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "Enter");

    assert.false(activated, "Enter with nothing highlighted does not activate");
    assert.false(
      enterPrevented,
      "Enter falls through so the consumer can submit or create"
    );
  });

  test("active mode: first ArrowUp seeds the last option", async function (assert) {
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
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowUp");
    assert
      .dom(".c")
      .hasClass("--active", "ArrowUp from no highlight seeds the last option");
  });
});
