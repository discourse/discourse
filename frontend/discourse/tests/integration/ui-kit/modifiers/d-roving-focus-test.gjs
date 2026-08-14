import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import {
  click,
  focus,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
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

  // For a caller whose item is unchanged but whose context is not — a row reporting a different
  // position in a different set. Re-asserting the same `aria-activedescendant` is a no-op, so the
  // attribute has to actually change for anything to observe it.
  test("active mode: reannounceActive drops and restores the cursor", async function (assert) {
    let api;
    const register = (value) => (api = value);

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
            controllerElement=".search"
            itemSelector="[role=option]"
            onRegisterApi=register
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    const search = document.querySelector(".search");
    assert.false(
      api.reannounceActive(),
      "with no cursor there is nothing to read again"
    );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    const activeId = search.getAttribute("aria-activedescendant");

    assert.true(api.reannounceActive(), "reports that it acted");
    assert
      .dom(".search")
      .doesNotHaveAttribute(
        "aria-activedescendant",
        "the cursor is dropped synchronously"
      );

    await settled();
    assert
      .dom(".search")
      .hasAttribute(
        "aria-activedescendant",
        activeId,
        "and restored to the same row a tick later"
      );

    // A cursor id outlives its row. Acting here would drop the attribute and report success while
    // reading nothing, and a caller that treats success as "the row said it" would go silent.
    document.querySelectorAll("[role=option]").forEach((el) => el.remove());
    assert.false(
      api.reannounceActive(),
      "a cursor whose row is gone is not read again"
    );
    assert
      .dom(".search")
      .hasAttribute(
        "aria-activedescendant",
        activeId,
        "and the attribute is left alone rather than dropped for nothing"
      );
  });

  // The restore is owed to the row that was active when it was requested. A reader who moves in
  // the meantime must not be dragged back.
  test("active mode: a cursor move outruns a pending reannounce", async function (assert) {
    let api;
    const register = (value) => (api = value);

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
            controllerElement=".search"
            itemSelector="[role=option]"
            onRegisterApi=register
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowDown");

    api.reannounceActive();
    await triggerKeyEvent(".search", "keydown", "ArrowDown");

    assert
      .dom(".search")
      .hasAttribute(
        "aria-activedescendant",
        document.querySelector(".b").id,
        "the cursor sits where the reader moved it, not where it was asked to be restored"
      );
  });

  test("active mode: focus stays on the controller, aria-activedescendant tracks", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
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
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
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
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <button
          class="refilter"
          type="button"
          {{on "click" refilter}}
        >x</button>
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
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

  test("active mode: entryFocus=first highlights the first item on insert", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
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

  // A windowed list installs this modifier on a container that is still empty: the virtualizer
  // has not measured its viewport yet, so the rows arrive a frame later. The seed ran against
  // nothing, found nothing to activate, and no key changes when the rows land — so the list is
  // presented with no cursor at all, and the reader's first arrow press is spent putting one on
  // row one instead of moving off it.
  test("active mode: a container that gains its items after install still seeds", async function (assert) {
    const state = new (class {
      @tracked items = [];
    })();

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="first"
          }}
        >
          {{#each state.items key="id" as |item|}}
            <button
              class="opt"
              role="option"
              id={{item.id}}
            >{{item.id}}</button>
          {{/each}}
        </div>
      </template>
    );

    assert.dom(".opt").doesNotExist("the container installs with no items");

    state.items = [{ id: "a" }, { id: "b" }];
    await settled();

    assert
      .dom("#a")
      .hasClass("--active", "the first item is highlighted once items arrive");
    assert
      .dom(".search")
      .hasAttribute(
        "aria-activedescendant",
        "a",
        "the controller points at the first item once items arrive"
      );
  });

  // The other half of the rule above, and the reason it cannot simply re-seed whenever the item
  // set changes: a windowed list republishes its rows on every scroll, so a blanket re-seed would
  // throw a reader who has arrowed down back to the top of the list.
  test("active mode: items arriving later never move a cursor the reader has placed", async function (assert) {
    // Starts EMPTY so the pending-seed observer is genuinely armed. Starting with items
    // present means `#reconcileActive` seeds and returns before ever arming it, so no
    // modifier code runs when the set later changes and the test proves nothing about the
    // one-shot guard.
    const state = new (class {
      @tracked items = [];
    })();

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="first"
          }}
        >
          {{#each state.items key="id" as |item|}}
            <button
              class="opt"
              role="option"
              id={{item.id}}
            >{{item.id}}</button>
          {{/each}}
        </div>
      </template>
    );

    await focus(".search");

    state.items = [{ id: "a" }, { id: "b" }];
    await settled();
    assert
      .dom("#a")
      .hasClass(
        "--active",
        "the armed observer seeds once the first items arrive"
      );

    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    assert.dom("#b").hasClass("--active", "the reader moved the cursor to b");

    state.items = [...state.items, { id: "c" }];
    await settled();

    assert
      .dom("#b")
      .hasClass("--active", "a later item set leaves the placed cursor alone");
    assert
      .dom(".search")
      .hasAttribute(
        "aria-activedescendant",
        "b",
        "the controller still points at the reader's row"
      );
  });

  test("active mode: entryFocus=selected-or-first prefers the selected item over the first", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="selected-or-first"
          }}
        >
          <button class="a" role="option" aria-selected="false">A</button>
          <button class="b" role="option" aria-selected="true">B</button>
        </div>
      </template>
    );

    assert
      .dom(".b")
      .hasClass(
        "--active",
        "the user's existing choice wins over the first row"
      );
    assert.dom(".a").doesNotHaveClass("--active");
    const activeId = document
      .querySelector(".search")
      .getAttribute("aria-activedescendant");
    assert.dom(".b").hasAttribute("id", activeId);
  });

  test("active mode: entryFocus=selected-or-none restores a selection without seeding a first item", async function (assert) {
    // A list that waits for the reader to act takes no first-item fallback. That rule exists to
    // avoid highlighting an arbitrary row; a restored selection is not arbitrary.
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="selected-or-none"
          }}
        >
          <button class="a" role="option" aria-selected="false">A</button>
          <button class="b" role="option" aria-selected="true">B</button>
        </div>
      </template>
    );

    assert.dom(".b").hasClass("--active", "the selection is restored");
  });

  test("active mode: entryFocus=selected-or-none leaves the cursor empty when nothing is selected", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="selected-or-none"
          }}
        >
          <button class="a" role="option" aria-selected="false">A</button>
          <button class="b" role="option" aria-selected="false">B</button>
        </div>
      </template>
    );

    assert.dom(".a").doesNotHaveClass("--active");
    assert.dom(".b").doesNotHaveClass("--active");
    assert
      .dom(".search")
      .doesNotHaveAttribute(
        "aria-activedescendant",
        "no selection and no first-item fallback means no cursor"
      );
  });

  test("active mode: entryFocus=selected-or-first does not move a cursor the user has set", async function (assert) {
    // `itemsKey` is what makes this test mean what its name says: without a reconcile after the
    // arrow key, nothing could possibly drag the cursor back and the assertion would only be
    // restating that ArrowDown moved it.
    const state = new (class {
      @tracked key = 1;
    })();

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            itemsKey=state.key
            entryFocus="selected-or-first"
          }}
        >
          <button class="a" role="option" aria-selected="false">A</button>
          <button class="b" role="option" aria-selected="true">B</button>
          <button class="c" role="option" aria-selected="false">C</button>
        </div>
      </template>
    );

    assert.dom(".b").hasClass("--active", "seeded on the selection");

    await triggerKeyEvent(".search", "keydown", "ArrowDown");

    assert
      .dom(".c")
      .hasClass("--active", "the user's arrow key moves off the selection");

    state.key = 2;
    await settled();

    assert
      .dom(".c")
      .hasClass("--active", "a reconcile keeps the cursor the user placed");
    assert
      .dom(".b")
      .doesNotHaveClass("--active", "and the preference does not drag it back");
  });

  test("active mode: itemsKey preserves a survivor but resetKey re-seeds the first item", async function (assert) {
    const state = new (class {
      @tracked itemsKey = 0;
      @tracked resetKey = 0;
    })();

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="first"
            itemsKey=state.itemsKey
            resetKey=state.resetKey
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    assert.dom(".b").hasClass("--active", "the reader placed the cursor on b");

    state.itemsKey++;
    await settled();

    assert
      .dom(".b")
      .hasClass(
        "--active",
        "an ordinary item reconciliation keeps the surviving cursor"
      );

    state.resetKey++;
    await settled();

    assert
      .dom(".a")
      .hasClass(
        "--active",
        "a new question applies the first-item entry policy afresh"
      );
    assert
      .dom(".b")
      .doesNotHaveClass(
        "--active",
        "the survivor does not outrank an explicit reset"
      );
  });

  test("active mode: resetKey re-seeds a marked row under selected-or-first", async function (assert) {
    const state = new (class {
      @tracked resetKey = 0;
    })();

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="selected-or-first"
            resetKey=state.resetKey
          }}
        >
          <button class="a" role="option" aria-selected="false">A</button>
          <button class="b" role="option" aria-selected="true">B</button>
          <button class="c" role="option" aria-selected="false">C</button>
        </div>
      </template>
    );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    assert
      .dom(".c")
      .hasClass("--active", "the reader moved past the selection");

    state.resetKey++;
    await settled();

    assert
      .dom(".b")
      .hasClass(
        "--active",
        "a new question restores the marked row before considering the first"
      );
    assert
      .dom(".c")
      .doesNotHaveClass(
        "--active",
        "a surviving cursor does not carry across an explicit reset"
      );
  });

  test("active mode: entryFocus=first re-seeds the first item when the set changes", async function (assert) {
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
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <button
          class="refilter"
          type="button"
          {{on "click" refilter}}
        >x</button>
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            itemsKey=state.key
            activeClass="--active"
            entryFocus="first"
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

  test("active mode: entryFocus=none highlights nothing until an Arrow key", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
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
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
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
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
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
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
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
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
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

  test("active mode: onBoundary reports only vertical group exits", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) => boundaries.push([direction, axis]);

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="first"
            wrap=false
            onBoundary=onBoundary
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    await triggerKeyEvent(".search", "keydown", "ArrowDown");

    assert.deepEqual(
      boundaries,
      [["forward", "vertical"]],
      "leaving the last option reports a forward vertical boundary"
    );

    await triggerKeyEvent(".search", "keydown", "ArrowRight");
    await triggerKeyEvent(".search", "keydown", "ArrowLeft");

    assert.deepEqual(
      boundaries,
      [["forward", "vertical"]],
      "horizontal caret keys never masquerade as listbox boundaries"
    );
    assert
      .dom(".b")
      .hasClass("--active", "horizontal caret keys leave the cursor in place");

    await triggerKeyEvent(".search", "keydown", "ArrowUp");
    await triggerKeyEvent(".search", "keydown", "ArrowUp");

    assert.deepEqual(
      boundaries,
      [
        ["forward", "vertical"],
        ["backward", "vertical"],
      ],
      "leaving the first option reports a backward vertical boundary"
    );
  });

  test("focus mode with tabStop=false: every item is -1, never a tab stop", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=option]"
            tabStop=false
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    assert
      .dom(".a")
      .hasAttribute("tabindex", "-1", "the first item is not made a tab stop");
    assert.dom(".b").hasAttribute("tabindex", "-1");
    assert.dom(".c").hasAttribute("tabindex", "-1");

    // The -1 is what keeps items programmatically focusable, so arrow navigation
    // still works — but the newly-focused item never becomes tabindex 0.
    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");
    assert
      .dom(".b")
      .isFocused("ArrowRight still moves focus with tabStop=false");
    assert
      .dom(".b")
      .hasAttribute("tabindex", "-1", "the focused item stays -1, never 0");
    assert.dom(".a").hasAttribute("tabindex", "-1");
  });

  test("focus mode: entryFocus=none deliberately leaves no tab stop", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus itemSelector="[role=option]" entryFocus="none"}}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    assert
      .dom(".a")
      .hasAttribute(
        "tabindex",
        "-1",
        "without an entry fallback the first row stays out of the tab sequence"
      );
    assert
      .dom(".b")
      .hasAttribute(
        "tabindex",
        "-1",
        "without an entry fallback no later row becomes an accidental tab stop"
      );
    assert
      .dom('[role="option"][tabindex="0"]')
      .doesNotExist("the group deliberately contributes no tab stop");
  });

  test("focus mode: selected-or-none supplies a tab stop only for a marked row", async function (assert) {
    await render(
      <template>
        <div
          class="unmarked"
          role="listbox"
          {{dRovingFocus
            itemSelector="[role=option]"
            entryFocus="selected-or-none"
          }}
        >
          <button
            class="unmarked-a"
            role="option"
            aria-selected="false"
          >A</button>
          <button
            class="unmarked-b"
            role="option"
            aria-selected="false"
          >B</button>
        </div>
        <div
          class="marked"
          role="listbox"
          {{dRovingFocus
            itemSelector="[role=option]"
            entryFocus="selected-or-none"
          }}
        >
          <button
            class="marked-a"
            role="option"
            aria-selected="false"
          >A</button>
          <button class="marked-b" role="option" aria-selected="true">B</button>
        </div>
      </template>
    );

    assert
      .dom(".unmarked-a")
      .hasAttribute(
        "tabindex",
        "-1",
        "an unmarked first row cannot become the missing selection"
      );
    assert
      .dom(".unmarked-b")
      .hasAttribute(
        "tabindex",
        "-1",
        "no later unmarked row is used as a fallback either"
      );
    assert
      .dom('.unmarked [tabindex="0"]')
      .doesNotExist("an unmarked group deliberately contributes no tab stop");
    assert
      .dom(".marked-b")
      .hasAttribute(
        "tabindex",
        "0",
        "a real selection restores the group's tab stop"
      );
    assert
      .dom(".marked-a")
      .hasAttribute(
        "tabindex",
        "-1",
        "the first row does not outrank the restored selection"
      );
  });

  test("focus mode: onBoundary fires at a horizontal edge with the travel direction", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=option]"
            onBoundary=onBoundary
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".b");
    await triggerKeyEvent(".b", "keydown", "ArrowRight");
    assert.deepEqual(
      boundaries,
      ["horizontal:forward"],
      "ArrowRight past the last item exits forward"
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowLeft");
    assert.deepEqual(
      boundaries,
      ["horizontal:forward", "horizontal:backward"],
      "ArrowLeft past the first item exits backward"
    );
  });

  test("focus mode: onBoundary does not fire on a vertical key or with no cursor", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=option]"
            onBoundary=onBoundary
            tabStop=false
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    // tabStop=false leaves no tab stop, so with nothing focused the cursor is -1.
    // Arrowing with no cursor must not report an edge exit.
    await triggerKeyEvent(".a", "keydown", "ArrowLeft");
    assert.deepEqual(boundaries, [], "ArrowLeft with no cursor does not exit");

    // Under horizontal orientation a vertical key is not ours. A silent `onBoundary` alone would
    // hold even with the orientation gate deleted, since the group has only two items and
    // ArrowDown from the first would land on the second rather than an edge — so the
    // load-bearing assertion is that the cursor DID NOT MOVE.
    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowDown");
    assert
      .dom(".a")
      .isFocused(
        "ArrowDown under horizontal orientation does not move the cursor"
      );
    assert.deepEqual(
      boundaries,
      [],
      "and reports no boundary on an axis the group does not claim"
    );
  });

  test("focus mode: onRegisterApi yields focus controls that move focus", async function (assert) {
    let api = null;
    const register = (value) => (api = value);

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=option]"
            tabStop=false
            onRegisterApi=register
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    assert.strictEqual(
      typeof api?.focusFirst,
      "function",
      "the api is registered on insert"
    );

    assert.true(api.focusFirst(), "focusFirst reports it landed on an item");
    await settled();
    assert.dom(".a").isFocused("focusFirst moves DOM focus to the first item");

    assert.true(api.focusLast(), "focusLast reports it landed on an item");
    await settled();
    assert.dom(".c").isFocused("focusLast moves DOM focus to the last item");

    assert.true(api.focusIndex(1), "focusIndex reports it landed on an item");
    await settled();
    assert.dom(".b").isFocused("focusIndex moves DOM focus to the given index");
  });

  test("focus mode: the api is revoked and inert after teardown", async function (assert) {
    let api = null;
    let revoked = false;
    const register = (value) => {
      if (value === null) {
        revoked = true;
      } else {
        api = value;
      }
    };

    const state = new (class {
      @tracked show = true;
    })();

    await render(
      <template>
        {{#if state.show}}
          <div
            role="listbox"
            {{dRovingFocus
              orientation="horizontal"
              itemSelector="[role=option]"
              tabStop=false
              onRegisterApi=register
            }}
          >
            <button class="a" role="option">A</button>
          </div>
        {{/if}}
      </template>
    );

    assert.strictEqual(
      typeof api?.focusFirst,
      "function",
      "the api is registered while mounted"
    );

    state.show = false;
    await settled();

    assert.true(revoked, "onRegisterApi(null) is called on teardown");

    // The container is destroyed on every modal close on mobile; a stale api call
    // must find no items and report it never landed rather than throw on items[last].
    assert.false(api.focusFirst(), "a stale focusFirst reports no item landed");
    assert.false(api.focusLast(), "a stale focusLast reports no item landed");
    assert.false(
      api.focusIndex(0),
      "a stale focusIndex reports no item landed"
    );
  });

  test("grid: ArrowDown inside the last row reaches the edge instead of jumping sideways", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus itemSelector="[role=option]" onBoundary=onBoundary}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option">4</button>
          <button class="i5" role="option">5</button>
        </div>
      </template>
    );

    // A rectangular 3x2 grid: i3 is already on the last row, so there is nothing below it.
    await focus(".i3");
    await triggerKeyEvent(".i3", "keydown", "ArrowDown");

    assert.dom(".i3").isFocused("ArrowDown from the last row does not move");
    assert.deepEqual(
      boundaries,
      ["vertical:forward"],
      "it reports the bottom edge rather than clamping laterally to the last item"
    );
  });

  test("grid: ArrowRight stops at a row edge without reporting a group exit", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus itemSelector="[role=option]" onBoundary=onBoundary}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option">4</button>
          <button class="i5" role="option">5</button>
        </div>
      </template>
    );

    // i2 closes row 0. A row edge is not the end of the group, so the cursor stops and
    // nothing is reported: `onBoundary` means "leaving the group", and firing it from an
    // interior row would drag a consumer's focus out mid-traversal.
    await focus(".i2");
    await triggerKeyEvent(".i2", "keydown", "ArrowRight");
    assert
      .dom(".i2")
      .isFocused("ArrowRight at a row edge does not wrap onto the next row");
    assert.deepEqual(boundaries, [], "and a row edge is not a group exit");

    // The true end of the group still reports one.
    await focus(".i5");
    await triggerKeyEvent(".i5", "keydown", "ArrowRight");
    assert.deepEqual(
      boundaries,
      ["horizontal:forward"],
      "the last item still exits forward"
    );
  });

  test("horizontal orientation never row-clamps, however the items wrap visually", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    // The multi-chips shape: a horizontal group whose items wrap onto several lines. Visual
    // rows are not logical rows, so clamping must key off `orientation`, never geometry.
    await render(
      <template>
        <div
          role="listbox"
          style="display: flex; flex-wrap: wrap; width: 80px;"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=option]"
            onBoundary=onBoundary
          }}
        >
          <button class="i0" role="option" style="width: 30px;">0</button>
          <button class="i1" role="option" style="width: 30px;">1</button>
          <button class="i2" role="option" style="width: 30px;">2</button>
          <button class="i3" role="option" style="width: 30px;">3</button>
        </div>
      </template>
    );

    await focus(".i2");
    await triggerKeyEvent(".i2", "keydown", "ArrowRight");
    assert
      .dom(".i3")
      .isFocused("a wrapped horizontal group keeps moving across lines");
    assert.deepEqual(
      boundaries,
      [],
      "and does not report an exit mid-traversal"
    );
  });

  test("grid: geometry follows the rendered cells, not the navigable ones", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus itemSelector="[role=option]"}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option" aria-disabled="true">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option">4</button>
          <button class="i5" role="option">5</button>
        </div>
      </template>
    );

    // An `aria-disabled` cell still occupies its grid cell, so the row below i0 is i3.
    // Indexing the navigable-only set would count i1 out and land on i4 instead.
    await focus(".i0");
    await triggerKeyEvent(".i0", "keydown", "ArrowDown");
    assert
      .dom(".i3")
      .isFocused("ArrowDown lands in the same column of the next row");
  });

  test("grid: a column count derived from CSS ignores named grid lines", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: [start] 40px [mid] 40px [end];"
          {{dRovingFocus itemSelector="[role=option]"}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
        </div>
      </template>
    );

    // Two tracks, three line names. Counting the names makes this read as five columns.
    await focus(".i0");
    await triggerKeyEvent(".i0", "keydown", "ArrowDown");
    assert
      .dom(".i2")
      .isFocused("ArrowDown moves by two tracks, not by the token count");
  });

  // The container is a real three-track CSS grid, so a derivation that ignored the orientation
  // would find three columns and step ArrowDown three items at a time.
  test("a non-grid orientation derives no column count", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus orientation="vertical" itemSelector="[role=option]"}}
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
      .dom(".i1")
      .isFocused(
        "a vertical list has no second axis, so ArrowDown steps one item"
      );
  });

  test("active mode steps one item at a time even over a grid", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
          }}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option">4</button>
          <button class="i5" role="option">5</button>
        </div>
      </template>
    );

    // Active mode leaves ArrowLeft/ArrowRight to the controller's caret, so a second axis
    // would strand every item outside the first column.
    await focus(".search");
    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    assert
      .dom(".i0")
      .hasClass("--active", "the first ArrowDown seeds the first item");

    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    assert
      .dom(".i1")
      .hasClass("--active", "and the next steps one item, not one row");
  });

  test("focus mode: wrapping backwards with no cursor lands on the last item", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=option]"
            tabStop=false
            wrap=true
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    // `tabStop=false` with nothing focused means no cursor, so ArrowLeft seeds the far end.
    await triggerKeyEvent(".a", "keydown", "ArrowLeft");
    assert
      .dom(".c")
      .isFocused("ArrowLeft with no cursor wraps to the last item");
  });

  test("focus mode: a chorded key is left alone", async function (assert) {
    const activated = [];
    const onActivate = (item) => activated.push(item.className);
    const prevented = {};

    await render(
      <template>
        <div
          class="list"
          role="listbox"
          {{dRovingFocus
            orientation="vertical"
            itemSelector="[role=option]"
            onActivate=onActivate
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );
    document
      .querySelector(".list")
      .addEventListener(
        "keydown",
        (e) => (prevented[e.key] = e.defaultPrevented)
      );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "Enter", { metaKey: true });
    assert.deepEqual(
      activated,
      [],
      "Cmd+Enter is a submit chord, not an activation"
    );
    assert.false(prevented.Enter, "and it reaches the surrounding handler");

    await triggerKeyEvent(".a", "keydown", "ArrowDown", { altKey: true });
    assert.dom(".a").isFocused("Alt+ArrowDown does not navigate");
  });

  // While an IME is composing, the browser still reports the arrows and Enter the candidate
  // window is using to choose a character. Acting on them navigates the group out from under a
  // reader who is mid-word, and swallows the commit.
  test("focus mode: keys mid-composition are left to the IME", async function (assert) {
    const activated = [];
    const onActivate = (item) => activated.push(item.className);
    const prevented = {};

    await render(
      <template>
        <div
          class="list"
          role="listbox"
          {{dRovingFocus
            orientation="vertical"
            itemSelector="[role=option]"
            onActivate=onActivate
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );
    document
      .querySelector(".list")
      .addEventListener(
        "keydown",
        (e) => (prevented[e.key] = e.defaultPrevented)
      );

    await focus(".a");

    for (const key of ["ArrowDown", "ArrowUp"]) {
      await triggerEvent(".a", "keydown", { key, isComposing: true });
      assert.dom(".a").isFocused(`${key} mid-composition does not navigate`);
      assert.false(
        prevented[key],
        `${key} mid-composition is left for the candidate window`
      );
    }

    await triggerEvent(".a", "keydown", { key: "Enter", isComposing: true });
    assert.deepEqual(
      activated,
      [],
      "Enter mid-composition commits a candidate rather than activating"
    );
    assert.false(prevented.Enter, "and it reaches the IME un-prevented");
  });

  test("active mode: keys mid-composition leave the highlight alone", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
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
    assert
      .dom(".a")
      .hasClass("--active", "the highlight starts on the first item");

    await triggerEvent(".search", "keydown", {
      key: "ArrowDown",
      isComposing: true,
    });

    assert
      .dom(".a")
      .hasClass(
        "--active",
        "composing ArrowDown does not advance the highlight"
      );
    assert
      .dom(".search")
      .hasAttribute(
        "aria-activedescendant",
        document.querySelector(".a").id,
        "and the controller still points at the unmoved item"
      );
  });

  test("focus mode: wrapping onto the only navigable item is not an exit", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);
    const changes = [];
    const onActiveChange = (item) => changes.push(item?.className ?? null);

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=option]"
            wrap=true
            onBoundary=onBoundary
            onActiveChange=onActiveChange
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option" aria-disabled="true">B</button>
        </div>
      </template>
    );

    await focus(".a");
    changes.length = 0;
    await triggerKeyEvent(".a", "keydown", "ArrowRight");

    assert.dom(".a").isFocused("the only navigable item keeps the cursor");
    assert.deepEqual(
      boundaries,
      [],
      "a wrapping group does not report an exit, even when the wrap lands where it started"
    );
    assert.deepEqual(
      changes,
      [],
      "and a cursor that did not move reports no change"
    );
  });

  test("active mode navigates vertically whatever the orientation says", async function (assert) {
    // Active mode never claims the horizontal arrows, so honouring a horizontal orientation
    // would leave the group with no working arrow key and therefore no way to seed a cursor.
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
            orientation="horizontal"
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
    assert.dom(".a").hasClass("--active", "ArrowDown still seeds the cursor");

    await triggerKeyEvent(".search", "keydown", "ArrowDown");
    assert.dom(".b").hasClass("--active", "and still advances it");
  });

  test("a superseded onRegisterApi callback is told its registration ended", async function (assert) {
    const first = [];
    const second = [];
    const registerFirst = (value) => first.push(value);
    const registerSecond = (value) => second.push(value);
    const state = new (class {
      @tracked useFirst = true;
    })();

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            itemSelector="[role=option]"
            onRegisterApi=(if state.useFirst registerFirst registerSecond)
          }}
        >
          <button class="a" role="option">A</button>
        </div>
      </template>
    );

    assert.strictEqual(first.length, 1, "the first callback is registered");
    assert.notStrictEqual(first[0], null, "with a live api");

    state.useFirst = false;
    await settled();

    assert.strictEqual(
      first[1],
      null,
      "the superseded callback is told the registration ended"
    );
    assert.notStrictEqual(second[0], null, "and the new one receives the api");
  });

  test("focus mode: an author-supplied tab stop survives the first render", async function (assert) {
    await render(
      <template>
        <div role="listbox" {{dRovingFocus itemSelector="[role=option]"}}>
          <button class="a" role="option" tabindex="-1">A</button>
          <button class="b" role="option" tabindex="-1">B</button>
          <button class="c" role="option" tabindex="0">C</button>
        </div>
      </template>
    );

    assert
      .dom(".c")
      .hasAttribute(
        "tabindex",
        "0",
        "the tab stop the author placed is preserved rather than relocated to the first item"
      );
    assert.dom(".a").hasAttribute("tabindex", "-1");
  });

  test("focus mode: re-seeding prefers the item holding DOM focus over an authored tab stop", async function (assert) {
    const state = new (class {
      @tracked showEarlier = false;
      @tracked itemsKey = 0;
    })();

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus itemSelector="[role=option]" itemsKey=state.itemsKey}}
        >
          <button class="start" role="option">Start</button>
          {{#if state.showEarlier}}
            <button
              class="authored"
              role="option"
              tabindex="0"
            >Authored</button>
          {{/if}}
          <button class="middle" role="option">Middle</button>
          <button class="end" role="option">End</button>
        </div>
      </template>
    );

    await focus(".middle");
    state.showEarlier = true;
    state.itemsKey++;
    await settled();

    assert
      .dom(".middle")
      .isFocused(
        "the row containing DOM focus remains the reader's current position"
      );
    assert
      .dom(".middle")
      .hasAttribute(
        "tabindex",
        "0",
        "the tab stop follows the focused row through reconciliation"
      );
    assert
      .dom(".authored")
      .hasAttribute(
        "tabindex",
        "-1",
        "an earlier authored zero is demoted instead of stealing the established cursor"
      );
  });

  test("focus mode: itemsKey preserves a survivor but resetKey re-picks the tab stop", async function (assert) {
    const state = new (class {
      @tracked itemsKey = 0;
      @tracked resetKey = 0;
    })();

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            itemSelector="[role=option]"
            entryFocus="first"
            itemsKey=state.itemsKey
            resetKey=state.resetKey
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    await focus(".c");
    state.itemsKey++;
    await settled();

    assert
      .dom(".c")
      .hasAttribute(
        "tabindex",
        "0",
        "an ordinary item reconciliation keeps the surviving tab stop"
      );

    state.resetKey++;
    await settled();

    assert
      .dom(".a")
      .hasAttribute(
        "tabindex",
        "0",
        "a new question applies the first-item entry policy afresh"
      );
    assert
      .dom(".c")
      .hasAttribute(
        "tabindex",
        "-1",
        "the surviving row no longer owns the tab stop after a reset"
      );
  });

  test("focus mode: a shifted key is left for text selection", async function (assert) {
    const activated = [];
    const onActivate = (item) => activated.push(item.className);

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="vertical"
            itemSelector="[role=option]"
            onActivate=onActivate
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowDown", { shiftKey: true });
    assert.dom(".a").isFocused("Shift+ArrowDown does not navigate");

    await triggerKeyEvent(".a", "keydown", "Enter", { shiftKey: true });
    assert.deepEqual(activated, [], "and Shift+Enter does not activate");
  });

  test("focus mode: Enter on a control inside an item is left to that control", async function (assert) {
    const activated = [];
    const onActivate = (item) => activated.push(item.className);
    const prevented = {};

    await render(
      <template>
        <div
          class="list"
          role="listbox"
          {{dRovingFocus
            orientation="vertical"
            itemSelector="[role=option]"
            onActivate=onActivate
          }}
        >
          <div class="a" role="option" tabindex="-1">
            A
            {{! Intentionally nests a real control in the item: the point of the test is that
              its own Enter handling survives. }}
            {{! eslint-disable-next-line ember/template-no-nested-interactive }}
            <button class="a-remove" type="button">remove</button>
          </div>
          <div class="b" role="option" tabindex="-1">B</div>
        </div>
      </template>
    );
    document
      .querySelector(".list")
      .addEventListener(
        "keydown",
        (e) => (prevented[e.key] = e.defaultPrevented)
      );

    await focus(".a-remove");
    await triggerKeyEvent(".a-remove", "keydown", "Enter");

    assert.deepEqual(
      activated,
      [],
      "Enter on a nested button does not activate the row"
    );
    assert.false(
      prevented.Enter,
      "and the button keeps its own native activation"
    );
  });

  test("focus mode: horizontal arrows follow the writing direction", async function (assert) {
    await render(
      <template>
        <div
          dir="rtl"
          role="listbox"
          {{dRovingFocus orientation="horizontal" itemSelector="[role=option]"}}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    // In RTL the visual start is the right-hand edge, so ArrowLeft advances through DOM order.
    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowLeft");
    assert.dom(".b").isFocused("ArrowLeft moves forward in an RTL group");

    await triggerKeyEvent(".b", "keydown", "ArrowRight");
    assert.dom(".a").isFocused("and ArrowRight moves back");
  });

  // The reported direction is LOGICAL, so it is derived from which key advances DOM order, not
  // from which physical arrow was pressed. An implementation keyed on "ArrowRight means forward"
  // reports "backward" here.
  test("focus mode: an RTL boundary reports the logical direction", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          dir="rtl"
          role="listbox"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[role=option]"
            onBoundary=onBoundary
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".b");
    await triggerKeyEvent(".b", "keydown", "ArrowLeft");
    assert.deepEqual(
      boundaries,
      ["horizontal:forward"],
      "ArrowLeft past the last item in DOM order is a FORWARD horizontal boundary in RTL"
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");
    assert.deepEqual(
      boundaries,
      ["horizontal:forward", "horizontal:backward"],
      "and ArrowRight past the first item is backward"
    );
  });

  // The vertical axis used to be a separate callback, so a grid consumer that wired only the
  // horizontal one heard nothing at the bottom row. One callback reports both, which is why the
  // axis is not optional.
  test("grid: a vertical group edge reports the vertical axis", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus itemSelector="[role=option]" onBoundary=onBoundary}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option">4</button>
          <button class="i5" role="option">5</button>
        </div>
      </template>
    );

    await focus(".i4");
    await triggerKeyEvent(".i4", "keydown", "ArrowDown");
    assert.dom(".i4").isFocused("the bottom row has nowhere further to go");
    assert.deepEqual(
      boundaries,
      ["vertical:forward"],
      "the bottom row reports a forward VERTICAL boundary, not a horizontal one"
    );

    await focus(".i1");
    await triggerKeyEvent(".i1", "keydown", "ArrowUp");
    assert.deepEqual(
      boundaries,
      ["vertical:forward", "vertical:backward"],
      "and the top row reports backward on the same axis"
    );
  });

  test("grid: a wrapping flex container warns that it has no second axis", async function (assert) {
    const warn = sinon.stub(console, "warn");

    await render(
      <template>
        <div
          role="listbox"
          style="display: flex; flex-wrap: wrap; width: 80px;"
          {{dRovingFocus itemSelector="[role=option]"}}
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

    assert.true(
      warn.calledOnce,
      "a wrapping flex group says it cannot find its second axis"
    );
    assert.true(
      warn.firstCall.args[0].includes("wrapping flex"),
      "and names the layout it could not measure"
    );

    await triggerKeyEvent(".i1", "keydown", "ArrowDown");
    assert.true(
      warn.calledOnce,
      "and does not repeat itself on every keystroke"
    );
  });

  test("grid: a real CSS grid does not warn", async function (assert) {
    const warn = sinon.stub(console, "warn");

    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(2, 40px);"
          {{dRovingFocus itemSelector="[role=option]"}}
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

    assert.dom(".i2").isFocused("the second axis works");
    assert.false(warn.called, "so nothing is warned about");
  });

  test("a plain one-column list does not warn", async function (assert) {
    const warn = sinon.stub(console, "warn");

    await render(
      <template>
        <div role="listbox" {{dRovingFocus itemSelector="[role=option]"}}>
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
        </div>
      </template>
    );

    await focus(".i0");
    await triggerKeyEvent(".i0", "keydown", "ArrowDown");

    assert.dom(".i1").isFocused("one column steps one item");
    assert.false(
      warn.called,
      "a block container resolving to one column is correct, not a degradation"
    );
  });

  test("focus mode: an item disabled while it holds the tab stop does not keep it", async function (assert) {
    const state = new (class {
      @tracked disabled = false;
    })();

    await render(
      <template>
        <div role="listbox" {{dRovingFocus itemSelector="[role=option]"}}>
          <button class="a" role="option">A</button>
          <button
            class="b"
            role="option"
            aria-disabled={{if state.disabled "true" "false"}}
          >B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");
    assert.dom(".b").hasAttribute("tabindex", "0", "b holds the tab stop");

    state.disabled = true;
    await settled();
    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");

    assert
      .dom(".b")
      .hasAttribute(
        "tabindex",
        "-1",
        "a row that left the navigable set is demoted, not left as a second tab stop"
      );
  });

  test("focus mode: the tab stop prefers the selected item over the first", async function (assert) {
    await render(
      <template>
        <div role="listbox" {{dRovingFocus itemSelector="[role=option]"}}>
          <button class="a" role="option" aria-selected="false">A</button>
          <button class="b" role="option" aria-selected="true">B</button>
          <button class="c" role="option" aria-selected="false">C</button>
        </div>
      </template>
    );

    // Natively-focusable elements report `tabIndex === 0` with no attribute, so reading the
    // property rather than the attribute makes this preference unreachable for buttons.
    assert
      .dom(".b")
      .hasAttribute("tabindex", "0", "the selected item is the tab stop");
    assert
      .dom(".a")
      .hasAttribute("tabindex", "-1", "and the first item is not");
  });

  test("focus mode: entryFocus=first ignores a marked item", async function (assert) {
    await render(
      <template>
        {{! Deliberately unroled: the modifier reads no roles, and the lint rule forbids
          buttons inside a toolbar role even though that is what the pattern is made of. }}
        <div
          {{dRovingFocus
            orientation="horizontal"
            itemSelector="[data-control]"
            entryFocus="first"
          }}
        >
          <button class="a" data-control>A</button>
          <button class="b" data-control aria-current="page">B</button>
          <button class="c" data-control>C</button>
        </div>
      </template>
    );

    // Toolbar and menubar enter on the first control unconditionally. A button marking the
    // current view is not a selection, and must not take the tab stop off the first one.
    assert
      .dom(".a")
      .hasAttribute("tabindex", "0", "the first control keeps the tab stop");
    assert
      .dom(".b")
      .hasAttribute("tabindex", "-1", "the marked control does not steal it");
  });

  test("focus mode: the tab stop prefers the checked radio over the first", async function (assert) {
    await render(
      <template>
        <div role="radiogroup" {{dRovingFocus itemSelector="[role=radio]"}}>
          <button class="a" role="radio" aria-checked="false">A</button>
          <button class="b" role="radio" aria-checked="true">B</button>
          <button class="c" role="radio" aria-checked="false">C</button>
        </div>
      </template>
    );

    assert
      .dom(".b")
      .hasAttribute("tabindex", "0", "the checked radio is the tab stop");
    assert
      .dom(".a")
      .hasAttribute("tabindex", "-1", "and the first radio is not");
  });

  test("focus mode: an item inside a disabled fieldset is not a target", async function (assert) {
    await render(
      <template>
        {{! An unroled container: a fieldset is the only way to inherit the disabled state,
          and it would otherwise have to sit between a listbox and its options. The predicate
          under test does not care about roles. }}
        <div {{dRovingFocus itemSelector=".opt"}}>
          <button class="opt a" type="button">A</button>
          <fieldset disabled>
            <button class="opt b" type="button">B</button>
          </fieldset>
          <button class="opt c" type="button">C</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");
    assert
      .dom(".c")
      .isFocused(
        "a button disabled through its fieldset cannot take focus, so it is skipped"
      );
  });

  test("focus mode: an inert item is not a target", async function (assert) {
    await render(
      <template>
        <div {{dRovingFocus itemSelector=".opt"}}>
          <button class="opt a" type="button">A</button>
          <button class="opt b" type="button" inert>B</button>
          <button class="opt c" type="button">C</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");

    assert
      .dom(".c")
      .isFocused("an inert button cannot take focus, so it is skipped");
  });

  test("focus mode: clicking an item moves the tab stop onto it", async function (assert) {
    await render(
      <template>
        <div role="listbox" {{dRovingFocus itemSelector="[role=option]"}}>
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    assert
      .dom(".a")
      .hasAttribute("tabindex", "0", "the first item starts as the tab stop");

    await click(".c");

    assert
      .dom(".c")
      .hasAttribute("tabindex", "0", "the clicked item becomes the tab stop");
    assert
      .dom(".a")
      .hasAttribute("tabindex", "-1", "and the previous holder gives it up");
  });

  test("focus mode: focus arriving without a pointer also moves the tab stop", async function (assert) {
    await render(
      <template>
        <div role="listbox" {{dRovingFocus itemSelector="[role=option]"}}>
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
          <button class="c" role="option">C</button>
        </div>
      </template>
    );

    await focus(".c");

    // Programmatic focus, with no pointer event at all: a fix that only widened the pointer
    // handler would leave the tab stop behind here.
    assert
      .dom(".c")
      .hasAttribute("tabindex", "0", "the focused item becomes the tab stop");
    assert.dom(".a").hasAttribute("tabindex", "-1");
  });

  // Focus persistence. Removals are driven straight through tracked state rather than by
  // clicking a button, because clicking one moves focus onto it and would hide the very
  // condition these tests turn on: focus falling to the body.
  class RemovableItems {
    @tracked items = ["a", "b", "c"];
    @tracked key = 0;

    remove(name) {
      this.items = this.items.filter((item) => item !== name);
      this.key++;
    }
  }

  test("focus mode: removing the focused item moves focus to the one that follows", async function (assert) {
    const state = new RemovableItems();

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus itemSelector="[role=option]" itemsKey=state.key}}
        >
          {{#each state.items key="@identity" as |item|}}
            <button class="opt-{{item}}" role="option">{{item}}</button>
          {{/each}}
        </div>
      </template>
    );

    await focus(".opt-b");
    state.remove("b");
    await settled();

    assert
      .dom(".opt-c")
      .isFocused("focus lands on the item that took the removed one's place");
  });

  test("focus mode: restoreLostFocus=false leaves a removed cursor on the body", async function (assert) {
    const state = new (class {
      @tracked items = ["a", "b", "c"];
      @tracked itemsKey = 0;
    })();

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            itemSelector="[role=option]"
            itemsKey=state.itemsKey
            restoreLostFocus=false
          }}
        >
          {{#each state.items key="@identity" as |item|}}
            <button class="opt-{{item}}" role="option">{{item}}</button>
          {{/each}}
        </div>
      </template>
    );

    await focus(".opt-b");
    state.items = state.items.filter((item) => item !== "b");
    state.itemsKey++;
    await settled();

    assert.strictEqual(
      document.activeElement,
      document.body,
      "the opt-out leaves focus lost for the consumer to place elsewhere"
    );
  });

  test("focus mode: a removal declined by the opt-out is forgotten, not deferred", async function (assert) {
    const state = new (class {
      @tracked items = ["a", "b", "c"];
      @tracked itemsKey = 0;
      @tracked restore = false;
    })();

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            itemSelector="[role=option]"
            itemsKey=state.itemsKey
            restoreLostFocus=state.restore
          }}
        >
          {{#each state.items key="@identity" as |item|}}
            <button class="opt-{{item}}" role="option">{{item}}</button>
          {{/each}}
        </div>
      </template>
    );

    await focus(".opt-b");
    state.items = state.items.filter((item) => item !== "b");
    state.itemsKey++;
    await settled();

    state.restore = true;
    state.itemsKey++;
    await settled();

    assert.strictEqual(
      document.activeElement,
      document.body,
      "enabling restoration later must not act on a removal that was declined at the time"
    );
  });

  test("focus mode: removing the focused last item falls back to the previous one", async function (assert) {
    const state = new RemovableItems();

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus itemSelector="[role=option]" itemsKey=state.key}}
        >
          {{#each state.items key="@identity" as |item|}}
            <button class="opt-{{item}}" role="option">{{item}}</button>
          {{/each}}
        </div>
      </template>
    );

    await focus(".opt-c");
    state.remove("c");
    await settled();

    assert
      .dom(".opt-b")
      .isFocused("there is no following item, so the cursor steps back");
  });

  test("focus mode: a removal does not reclaim focus the reader moved away", async function (assert) {
    const state = new RemovableItems();

    await render(
      <template>
        <button class="outside" type="button">outside</button>
        <div
          role="listbox"
          {{dRovingFocus itemSelector="[role=option]" itemsKey=state.key}}
        >
          {{#each state.items key="@identity" as |item|}}
            <button class="opt-{{item}}" role="option">{{item}}</button>
          {{/each}}
        </div>
      </template>
    );

    await focus(".opt-b");
    await focus(".outside");
    state.remove("b");
    await settled();

    // The whole feature turns on focus having been LOST, not merely on an item disappearing.
    // Without that condition this steals focus back out of wherever the reader went.
    assert
      .dom(".outside")
      .isFocused("focus deliberately moved out of the group is left alone");
  });

  test("focus mode: removing an item the reader is not on leaves focus where it is", async function (assert) {
    const state = new RemovableItems();

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus itemSelector="[role=option]" itemsKey=state.key}}
        >
          {{#each state.items key="@identity" as |item|}}
            <button class="opt-{{item}}" role="option">{{item}}</button>
          {{/each}}
        </div>
      </template>
    );

    await focus(".opt-c");
    state.remove("a");
    await settled();

    assert
      .dom(".opt-c")
      .isFocused("an unrelated removal is not an occasion to move the cursor");
  });

  test("focus mode: replacing the whole item set does not move focus", async function (assert) {
    class State {
      @tracked items = ["a", "b", "c"];
      @tracked key = 0;
    }
    const state = new State();

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus itemSelector="[role=option]" itemsKey=state.key}}
        >
          {{#each state.items key="@identity" as |item|}}
            <button class="opt-{{item}}" role="option">{{item}}</button>
          {{/each}}
        </div>
      </template>
    );

    await focus(".opt-b");
    state.items = ["x", "y", "z"];
    state.key++;
    await settled();

    // Every previous item is gone, so this is a new question rather than a deletion. Seeding
    // never yanks focus on a re-render, and restoring here would drop the reader into a result
    // set they never navigated to.
    assert
      .dom(".opt-x")
      .isNotFocused("a wholesale replacement is not a removal to recover from");
    assert
      .dom(".opt-y")
      .isNotFocused("and no other member of the new set takes focus either");
  });

  test("active mode with no focus indicator at all warns", async function (assert) {
    const warn = sinon.stub(console, "warn");

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
            controllerElement=".search"
            itemSelector="[role=option]"
          }}
        >
          <button class="a" role="option">A</button>
        </div>
      </template>
    );

    // In active mode DOM focus stays on the controller, so with neither activeClass nor
    // onActiveChange there is nothing drawing a focus indicator anywhere.
    assert.true(
      warn.called,
      "a group that can render no focus indicator says so"
    );
  });

  test("active mode: fallbackSkipsMarked seeds past a marked first item", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="first"
            fallbackSkipsMarked=true
          }}
        >
          <button class="a" role="option" aria-selected="true">A</button>
          <button class="b" role="option" aria-selected="false">B</button>
        </div>
      </template>
    );

    // Seeding the held row would arm the very first Enter to discard it, in a group whose
    // activation toggles.
    assert
      .dom(".b")
      .hasClass("--active", "the fallback lands past the marked row");
    assert.dom(".a").doesNotHaveClass("--active");
  });

  test("active mode warns when the cursor is unreachable from the controller", async function (assert) {
    const warn = sinon.stub(console, "warn");

    await render(
      <template>
        {{! No aria-controls and no aria-owns, so the list is a sibling the controller has no
          permitted relationship with. }}
        <input class="lonely" role="combobox" />
        <div
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".lonely"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="first"
          }}
        >
          <button class="a" role="option">A</button>
        </div>
      </template>
    );

    assert.true(
      warn.called,
      "an activedescendant that ARIA does not let the controller reach is reported"
    );
  });

  test("active mode does not warn when aria-owns reaches the cursor", async function (assert) {
    const warn = sinon.stub(console, "warn");

    await render(
      <template>
        <input class="owner" role="combobox" aria-owns="owned-option" />
        <div
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".owner"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="first"
          }}
        >
          <button id="owned-option" class="a" role="option">A</button>
        </div>
      </template>
    );

    // Containment is not the only permitted relationship, so a sibling list that is explicitly
    // owned must pass.
    assert.false(warn.called, "aria-owns is one of the three ARIA permits");
  });

  test("active mode does not warn when the consumer renders its own indicator", async function (assert) {
    const warn = sinon.stub(console, "warn");
    const noop = () => {};

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            entryFocus="none"
            controllerElement=".search"
            itemSelector="[role=option]"
            onActiveChange=noop
          }}
        >
          <button class="a" role="option">A</button>
        </div>
      </template>
    );

    // Reporting the cursor is the other legitimate way to draw the indicator, so only the
    // absence of both is a problem.
    assert.false(
      warn.called,
      "reporting the cursor is indicator enough; only the absence of both is a problem"
    );
  });

  test("active mode: a changed activeClass is removed from the row that had it", async function (assert) {
    const state = new (class {
      @tracked cls = "--active";
    })();

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass=state.cls
            entryFocus="first"
          }}
        >
          <button class="a" role="option">A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    assert.dom(".a").hasClass("--active", "seeded with the first class");

    state.cls = "--highlight";
    await settled();

    assert.dom(".a").hasClass("--highlight", "the new class is applied");
    assert
      .dom(".a")
      .doesNotHaveClass("--active", "and the previous one is swept off");
  });

  test("switching focusStrategy leaves no state from the previous mode", async function (assert) {
    const state = new (class {
      @tracked mode = "active-descendant";
    })();

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          role="listbox"
          {{dRovingFocus
            focusStrategy=state.mode
            controllerElement=".search"
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

    assert.dom(".a").hasClass("--active", "active mode seeded a highlight");

    state.mode = "roving-tabindex";
    await settled();

    assert
      .dom(".search")
      .doesNotHaveAttribute(
        "aria-activedescendant",
        "leaving active mode drops the controller's cursor"
      );
    assert
      .dom(".a")
      .doesNotHaveClass("--active", "and the highlight class goes with it");
  });

  test("active mode: a non-primary pointer press does not move the cursor", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
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

    assert.dom(".a").hasClass("--active", "seeded on the first item");

    await triggerEvent(".b", "mousedown", { button: 2 });

    assert
      .dom(".a")
      .hasClass("--active", "a right-click leaves the cursor where it was");
  });

  test("active mode: onActiveChange identifies pointer and keyboard placement", async function (assert) {
    const changes = [];
    const onActiveChange = (item, meta) =>
      changes.push([item?.dataset.label ?? null, meta]);

    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="first"
            onActiveChange=onActiveChange
          }}
        >
          <button class="a" role="option" data-label="a">A</button>
          <button class="b" role="option" data-label="b">B</button>
          <button class="c" role="option" data-label="c">C</button>
        </div>
      </template>
    );

    changes.length = 0;
    await focus(".search");
    await triggerEvent(".b", "mousedown", { button: 0 });
    await triggerKeyEvent(".search", "keydown", "ArrowDown");

    assert.deepEqual(
      changes,
      [
        ["b", { pointer: true }],
        ["c", { pointer: false }],
      ],
      "pointer placement can stay visually quiet while the following keyboard move is revealed"
    );
  });

  test("focusIndex reports failure for an index that is not a number", async function (assert) {
    let api = null;
    const register = (value) => (api = value);

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus itemSelector="[role=option]" onRegisterApi=register}}
        >
          <button class="a" role="option">A</button>
        </div>
      </template>
    );

    assert.false(api.focusIndex(NaN), "NaN reports no item landed");
    assert.false(
      api.focusIndex(1.5),
      "a fractional index reports no item landed"
    );
    assert.dom(".a").isNotFocused("and neither moved the cursor");
  });

  test("active mode leaves author-supplied tabindex alone", async function (assert) {
    // The internal mode starts as focus, so an active-mode group crosses a mode boundary on its
    // very first run. Nothing may be handed back for a mode that never wrote anything, or the
    // author's own tabindex values are stripped and items they excluded become tab stops.
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-lb" />
        <div
          id="rf-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector="[role=option]"
            activeClass="--active"
            entryFocus="first"
          }}
        >
          <button class="a" role="option" tabindex="-1">A</button>
          <button class="b" role="option" tabindex="-1">B</button>
        </div>
      </template>
    );

    assert.dom(".a").hasClass("--active", "active mode seeded its highlight");
    assert
      .dom(".a")
      .hasAttribute("tabindex", "-1", "the author's tabindex survives");
    assert
      .dom(".b")
      .hasAttribute("tabindex", "-1", "on every item, not just the active one");
  });

  test("grid: a blocked column reaches the edge instead of sliding into another column", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus itemSelector="[role=option]" onBoundary=onBoundary}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option" aria-disabled="true">4</button>
          <button class="i5" role="option">5</button>
          <button class="i6" role="option">6</button>
          <button class="i7" role="option" aria-disabled="true">7</button>
          <button class="i8" role="option">8</button>
        </div>
      </template>
    );

    // A full 3x3 grid: every column exists in the last row, so nothing is ragged. Column 1 is
    // blocked all the way down, which is a vertical edge — not licence to land in column 2.
    await focus(".i1");
    await triggerKeyEvent(".i1", "keydown", "ArrowDown");

    assert.dom(".i1").isFocused("the cursor stays in its own column");
    assert.deepEqual(
      boundaries,
      ["vertical:forward"],
      "and reports the bottom edge rather than moving diagonally"
    );
  });

  test("grid: a column blocked above a ragged last row does not skip into it", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus itemSelector="[role=option]" onBoundary=onBoundary}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option">4</button>
          <button class="i5" role="option" aria-disabled="true">5</button>
          <button class="i6" role="option">6</button>
        </div>
      </template>
    );

    // Rows are [i0 i1 i2] [i3 i4 i5] [i6]. The cell below i2 is i5, which EXISTS but is blocked,
    // so the column is genuinely exhausted. The ragged fallback is for a column that ran out,
    // and must not fire here and drop the cursor two rows down into a different column.
    await focus(".i2");
    await triggerKeyEvent(".i2", "keydown", "ArrowDown");

    assert.dom(".i2").isFocused("the cursor stays put");
    assert.deepEqual(
      boundaries,
      ["vertical:forward"],
      "and reports the bottom of its column rather than skipping a row"
    );
  });

  test("grid: a last row with nothing navigable in it is an edge, not a sideways move", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(2, 40px);"
          {{dRovingFocus itemSelector="[role=option]" onBoundary=onBoundary}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option" aria-disabled="true">4</button>
        </div>
      </template>
    );

    // Rows are [i0 i1] [i2 i3] [i4]. The only cell below i2 is disabled, so there is nowhere to
    // go — and the fallback must not reach sideways to i2's own neighbour i3.
    await focus(".i2");
    await triggerKeyEvent(".i2", "keydown", "ArrowDown");

    assert.dom(".i2").isFocused("the cursor stays put");
    assert.deepEqual(
      boundaries,
      ["vertical:forward"],
      "and it reports the bottom edge rather than stepping across its own row"
    );
  });

  test("grid: a rectangular grid takes no ragged fallback when the cell below is the last one", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus itemSelector="[role=option]" onBoundary=onBoundary}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option">4</button>
          <button class="i5" role="option" aria-disabled="true">5</button>
        </div>
      </template>
    );

    // Rows are [i0 i1 i2] [i3 i4 i5], so the grid is rectangular and i2's column DOES exist in
    // the last row, merely blocked. This sits exactly on the boundary where the ragged guard's
    // strict comparison is the only thing holding the fallback shut: relax it and the cursor
    // slides diagonally to i4.
    await focus(".i2");
    await triggerKeyEvent(".i2", "keydown", "ArrowDown");

    assert.dom(".i2").isFocused("the cursor stays in its own column");
    assert.deepEqual(
      boundaries,
      ["vertical:forward"],
      "and a blocked cell at the end of a full grid is an edge, not a ragged row"
    );
  });

  test("grid: a ragged last row takes no fallback when the cursor's own column is merely blocked", async function (assert) {
    const boundaries = [];
    const onBoundary = (direction, axis) =>
      boundaries.push(`${axis}:${direction}`);

    await render(
      <template>
        <div
          role="listbox"
          style="display: grid; grid-template-columns: repeat(3, 40px);"
          {{dRovingFocus itemSelector="[role=option]" onBoundary=onBoundary}}
        >
          <button class="i0" role="option">0</button>
          <button class="i1" role="option">1</button>
          <button class="i2" role="option">2</button>
          <button class="i3" role="option">3</button>
          <button class="i4" role="option">4</button>
          <button class="i5" role="option">5</button>
          <button class="i6" role="option">6</button>
          <button class="i7" role="option" aria-disabled="true">7</button>
        </div>
      </template>
    );

    // Rows are [i0 i1 i2] [i3 i4 i5] [i6 i7]. The last row IS ragged, but i4's column still
    // reaches it, since i7 exists and is only disabled, so the fallback must stay shut. Again on
    // the boundary: relaxing the guard walks back to i6 and changes column.
    await focus(".i4");
    await triggerKeyEvent(".i4", "keydown", "ArrowDown");

    assert.dom(".i4").isFocused("the cursor stays in its own column");
    assert.deepEqual(
      boundaries,
      ["vertical:forward"],
      "and a ragged row only rescues a column that is absent, not one that is blocked"
    );
  });

  test("Enter does not activate a row that has become disabled under the cursor", async function (assert) {
    const activated = [];
    const onActivate = (item) => activated.push(item.className);
    const state = new (class {
      @tracked disabled = false;
    })();

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="vertical"
            itemSelector="[role=option]"
            onActivate=onActivate
          }}
        >
          <button
            class="a"
            role="option"
            aria-disabled={{if state.disabled "true" "false"}}
          >A</button>
          <button class="b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".a");
    // `aria-disabled` does not remove focusability, so the row keeps DOM focus and stays the
    // cursor's position even though it is no longer a legal target.
    state.disabled = true;
    await settled();

    await triggerKeyEvent(".a", "keydown", "Enter");
    assert.deepEqual(
      activated,
      [],
      "a disabled row is not activatable, however the cursor came to rest on it"
    );
  });

  test('disabledItems="focusable" lets the cursor reach an aria-disabled item', async function (assert) {
    await render(
      <template>
        <div
          role="toolbar"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector=".item"
            disabledItems="focusable"
          }}
        >
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <button class="item a">A</button>
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <button class="item b" aria-disabled="true">B</button>
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <button class="item c">C</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");

    assert
      .dom(document.activeElement)
      .hasClass(
        "b",
        "moving focus is how a screen reader user discovers the control is there at all"
      );
  });

  test('disabledItems="focusable" still refuses to activate the item', async function (assert) {
    const activated = [];
    const onActivate = (item) => activated.push(item.className);

    await render(
      <template>
        <div
          role="toolbar"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector=".item"
            disabledItems="focusable"
            onActivate=onActivate
          }}
        >
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <button class="item a">A</button>
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <button class="item b" aria-disabled="true">B</button>
        </div>
      </template>
    );

    await focus(".b");
    await triggerKeyEvent(".b", "keydown", "Enter");

    assert.deepEqual(
      activated,
      [],
      "reachable and activatable are separate, so the policy widens only the first"
    );
  });

  test('disabledItems="focusable" cannot resurrect a natively disabled control', async function (assert) {
    await render(
      <template>
        <div
          role="toolbar"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector=".item"
            disabledItems="focusable"
          }}
        >
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <button class="item a">A</button>
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <button class="item b" disabled>B</button>
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <button class="item c">C</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");

    assert
      .dom(document.activeElement)
      .hasClass(
        "c",
        "the platform refuses focus to a disabled control, so no policy here can offer it"
      );
  });

  test("onCrossAxis reports the horizontal arrows a vertical group does not use", async function (assert) {
    const seen = [];
    const onCrossAxis = (direction, item) =>
      seen.push(`${direction}:${item.className}`);

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="vertical"
            itemSelector=".item"
            onCrossAxis=onCrossAxis
          }}
        >
          <button class="item a" role="option">A</button>
          <button class="item b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");
    await triggerKeyEvent(".a", "keydown", "ArrowLeft");

    assert.deepEqual(
      seen,
      ["forward:item a", "backward:item a"],
      "the resting item comes with the direction, so the consumer need not re-read activeElement"
    );
  });

  test("onCrossAxis mirrors its direction in a right-to-left group", async function (assert) {
    const seen = [];
    const onCrossAxis = (direction) => seen.push(direction);

    await render(
      <template>
        <div
          role="listbox"
          dir="rtl"
          {{dRovingFocus
            orientation="vertical"
            itemSelector=".item"
            onCrossAxis=onCrossAxis
          }}
        >
          <button class="item a" role="option">A</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowLeft");

    assert.deepEqual(
      seen,
      ["forward"],
      "the arrow pointing at where children would be is the forward one, whichever key that is"
    );
  });

  test("onCrossAxis reports the vertical arrows a horizontal group does not use", async function (assert) {
    const seen = [];
    const onCrossAxis = (direction) => seen.push(direction);

    await render(
      <template>
        <div
          role="listbox"
          dir="rtl"
          {{dRovingFocus
            orientation="horizontal"
            itemSelector=".item"
            onCrossAxis=onCrossAxis
          }}
        >
          <button class="item a" role="option">A</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowDown");

    assert.deepEqual(
      seen,
      ["forward"],
      "a menubar opens its submenu downward, and the vertical axis never mirrors"
    );
  });

  test("onCrossAxis prevents the default only when the consumer says it acted", async function (assert) {
    const handled = [];
    const onCrossAxis = (direction) => {
      handled.push(direction);
      return direction === "forward";
    };

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="vertical"
            itemSelector=".item"
            onCrossAxis=onCrossAxis
          }}
        >
          <button class="item a" role="option">A</button>
        </div>
      </template>
    );

    await focus(".a");
    const item = document.querySelector(".a");

    const acted = new KeyboardEvent("keydown", {
      key: "ArrowRight",
      bubbles: true,
      cancelable: true,
    });
    item.dispatchEvent(acted);

    const declined = new KeyboardEvent("keydown", {
      key: "ArrowLeft",
      bubbles: true,
      cancelable: true,
    });
    item.dispatchEvent(declined);

    assert.true(acted.defaultPrevented, "a handled key is consumed");
    assert.false(
      declined.defaultPrevented,
      "an unhandled one keeps bubbling, which is what a leaf node or an already-collapsed row needs"
    );
  });

  test("onCrossAxis never fires for a grid, which navigates both axes", async function (assert) {
    const seen = [];
    const onCrossAxis = (direction) => seen.push(direction);

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="grid"
            itemSelector=".item"
            onCrossAxis=onCrossAxis
          }}
        >
          <button class="item a" role="option">A</button>
          <button class="item b" role="option">B</button>
        </div>
      </template>
    );

    await focus(".a");
    await triggerKeyEvent(".a", "keydown", "ArrowRight");
    await triggerKeyEvent(".b", "keydown", "ArrowDown");

    assert.deepEqual(
      seen,
      [],
      "there is no unused axis to report, so a grid consumer never has to distinguish one"
    );
  });

  test("fallbackSkipsMarked seeds the tab stop past a marked item", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          aria-multiselectable="true"
          {{dRovingFocus
            orientation="vertical"
            itemSelector=".item"
            entryFocus="first"
            fallbackSkipsMarked=true
          }}
        >
          <button class="item a" role="option" aria-selected="true">A</button>
          <button class="item b" role="option" aria-selected="false">B</button>
        </div>
      </template>
    );

    assert
      .dom(".b")
      .hasAttribute(
        "tabindex",
        "0",
        "activation toggles in a multi-select list, so entry avoids arming the first Enter to remove a value"
      );
  });

  test("fallbackSkipsMarked does not skip a restored selection", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          aria-multiselectable="true"
          {{dRovingFocus
            orientation="vertical"
            itemSelector=".item"
            entryFocus="selected-or-first"
            fallbackSkipsMarked=true
          }}
        >
          <button class="item a" role="option" aria-selected="false">A</button>
          <button class="item b" role="option" aria-selected="true">B</button>
        </div>
      </template>
    );

    assert
      .dom(".b")
      .hasAttribute(
        "tabindex",
        "0",
        "the reader's marked row is restored before the first-item fallback is considered"
      );
    assert
      .dom(".a")
      .hasAttribute(
        "tabindex",
        "-1",
        "skipping marked fallbacks does not replace an existing selection with the first row"
      );
  });

  test("fallbackSkipsMarked still seeds when every item is marked", async function (assert) {
    await render(
      <template>
        <div
          role="listbox"
          aria-multiselectable="true"
          {{dRovingFocus
            orientation="vertical"
            itemSelector=".item"
            entryFocus="first"
            fallbackSkipsMarked=true
          }}
        >
          <button class="item a" role="option" aria-selected="true">A</button>
          <button class="item b" role="option" aria-selected="true">B</button>
        </div>
      </template>
    );

    assert
      .dom(".a")
      .hasAttribute(
        "tabindex",
        "0",
        "an empty seed would take the group out of the tab sequence entirely, which is worse than seeding a marked item"
      );
  });

  test("entry ignores aria-current tokens that mean not current", async function (assert) {
    const emptyToken = "";

    await render(
      <template>
        <div
          role="listbox"
          {{dRovingFocus
            orientation="vertical"
            itemSelector=".item"
            entryFocus="selected-or-first"
          }}
        >
          <button
            class="item a"
            role="option"
            aria-current={{emptyToken}}
          >A</button>
          <button class="item b" role="option" aria-current="false">B</button>
          <button class="item c" role="option" aria-current="page">C</button>
          <button class="item d" role="option">D</button>
        </div>
      </template>
    );

    assert
      .dom(".a")
      .hasAttribute(
        "aria-current",
        "",
        "the empty token is genuinely present on the first row"
      );
    assert
      .dom(".c")
      .hasAttribute(
        "tabindex",
        "0",
        "only a token that means current marks the row the entry seed prefers"
      );
  });

  test("fallbackSkipsMarked does not treat aria-current=false as marked", async function (assert) {
    await render(
      <template>
        <input class="search" role="combobox" aria-controls="rf-current-lb" />
        <div
          id="rf-current-lb"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=".search"
            itemSelector=".item"
            activeClass="--active"
            entryFocus="first"
            fallbackSkipsMarked=true
          }}
        >
          <button class="item a" role="option" aria-current="false">A</button>
          <button class="item b" role="option" aria-current="false">B</button>
        </div>
      </template>
    );

    assert
      .dom(".a")
      .hasClass(
        "--active",
        "rows that only say they are not current leave the fallback free to seed"
      );
  });

  test("changing itemSelector releases the items it no longer matches", async function (assert) {
    const state = new (class {
      @tracked selector = ".one";
    })();

    await render(
      <template>
        <div role="listbox" {{dRovingFocus itemSelector=state.selector}}>
          <button class="one a" role="option">A</button>
          <button class="two b" role="option">B</button>
        </div>
      </template>
    );

    assert.dom(".a").hasAttribute("tabindex", "0", "the first set is seeded");

    state.selector = ".two";
    await settled();

    assert
      .dom(".b")
      .hasAttribute("tabindex", "0", "the new set takes over the tab stop");
    assert
      .dom(".a")
      .doesNotHaveAttribute(
        "tabindex",
        "and the old set is released rather than left as a second tab stop"
      );
  });
});
