import { tracked } from "@glimmer/tracking";
import {
  click,
  fillIn,
  find,
  findAll,
  focus,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DMenu from "discourse/float-kit/components/d-menu";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import { settledAfterFrame } from "discourse/tests/helpers/qunit-helpers";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DSelectList from "discourse/ui-kit/select/d-select-list";

const FRUIT = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry" },
  { id: 4, name: "Date" },
];

/** An async source over a fixed list that records each query it receives. */
function fruitLoader(calls = []) {
  return async (filter) => {
    calls.push(filter);
    const query = (filter ?? "").toLowerCase();
    return FRUIT.filter((item) => item.name.toLowerCase().includes(query));
  };
}

/**
 * A source that answers at once until `hold()`, then waits for `release()`. A held request keeps
 * a test waiter open, so while one is pending the test must not await a settling helper.
 */
function gatedLoader() {
  const pending = [];
  let holding = false;
  const answer = (filter) =>
    FRUIT.filter((item) =>
      item.name.toLowerCase().includes((filter ?? "").toLowerCase())
    );
  const load = async (filter) => {
    if (!holding) {
      return answer(filter);
    }
    return new Promise((resolve) =>
      pending.push(() => resolve(answer(filter)))
    );
  };
  return {
    load,
    hold: () => (holding = true),
    release: () => {
      holding = false;
      pending.splice(0).forEach((fn) => fn());
    },
  };
}

/** Moves focus without waiting for settledness, for use while a request is held open. */
function moveFocusNow(to) {
  const from = document.activeElement;
  from?.dispatchEvent(new FocusEvent("blur", { relatedTarget: to }));
  from?.dispatchEvent(
    new FocusEvent("focusout", { bubbles: true, relatedTarget: to })
  );
  to.focus();
  to.dispatchEvent(new FocusEvent("focus", { relatedTarget: from }));
  to.dispatchEvent(
    new FocusEvent("focusin", { bubbles: true, relatedTarget: from })
  );
}

/** Runs a helper and returns the event a window listener saw after every handler ran. */
async function dispatched(eventType, trigger) {
  let seen;
  const record = (event) => (seen = event);
  window.addEventListener(eventType, record);
  try {
    await trigger();
  } finally {
    window.removeEventListener(eventType, record);
  }
  return seen;
}

function root(selector = ".d-select.--list") {
  return find(selector);
}

function input(scope = ".d-select.--list") {
  return find(`${scope} input[role="combobox"]`);
}

function listbox(scope = ".d-select.--list") {
  return find(`${scope} [role="listbox"]`);
}

function rows(scope = ".d-select.--list") {
  return findAll(`${scope} [role="option"]`);
}

function rowNames(scope) {
  return rows(scope).map((row) => row.textContent.trim());
}

function activeRow(scope = ".d-select.--list") {
  return find(`${scope} [role="option"].--active`);
}

function chips(scope = ".d-select.--list") {
  return findAll(`${scope} .d-select__strip-item`);
}

async function type(text, scope) {
  await fillIn(input(scope), text);
}

module("Integration | ui-kit | select | DSelectList", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.a11y = this.owner.lookup("service:a11y");
    this.announce = sinon.spy(this.a11y, "announce");
  });

  module("structure", function () {
    test("DSelectList renders in place with no trigger and no popup", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      assert.dom(".d-select.--list").exists("the list root renders");
      assert.dom(".d-select__trigger").doesNotExist("there is no trigger");
      assert.dom(".d-select__content").doesNotExist("there is no popup");
      assert
        .dom(root())
        .doesNotHaveAttribute("role", "the root has no role")
        .doesNotHaveAttribute("tabindex", "the root is not a tab stop");
      assert.dom(input()).hasAttribute("aria-autocomplete", "list");
      assert
        .dom(input())
        .hasAria("label", "Fruit", "the search is named by the label");
      assert.notStrictEqual(
        document.activeElement,
        input(),
        "nothing is focused after render"
      );
    });

    test("DSelectList keeps its list out of the tab order", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      assert.dom(listbox()).hasAttribute("tabindex", "-1");
    });

    test("DSelectList ties aria-expanded and aria-controls to a rendered listbox", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      assert.dom(input()).hasAria("expanded", "true");
      assert
        .dom(input())
        .hasAria("controls", listbox().id, "controls the rendered listbox");

      await type("zzz");

      assert.dom(listbox()).doesNotExist("no rows, no listbox");
      assert
        .dom(input())
        .doesNotHaveAria("controls", "no reference to a missing listbox");
      assert
        .dom(input())
        .doesNotHaveAria("expanded", "true", "not expanded without a listbox");
    });

    test("DSelectList stays in place when the mobile modal would apply", async function (assert) {
      forceMobile();
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      assert.dom(".d-modal").doesNotExist("no modal");
      assert.dom(".d-select.--list [role='listbox']").exists("list in place");
    });

    test("DSelectList shows held values on the root", async function (assert) {
      const held = tracked([1, 3]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <DSelectList
            @items={{FRUIT}}
            @label="Fruit"
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      assert.dom(root()).hasAttribute("data-value", "1,3");
      assert.dom(root()).hasAttribute("data-name", "Apple,Cherry");
    });
  });

  module("keyboard and selection", function () {
    test("DSelectList activates a row only with focus and a query", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      assert.strictEqual(activeRow(), null, "nothing active at rest");
      await focus(input());
      assert.strictEqual(activeRow(), null, "nothing active without a query");
      await type("an");
      assert.dom(activeRow()).hasText("Banana", "the first match is active");
      assert
        .dom(input())
        .hasAria("activedescendant", activeRow().id, "the input points at it");
    });

    test("DSelectList selects with the arrow keys and Enter, and clears the query", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      await focus(input());
      await type("a");
      await triggerKeyEvent(input(), "keydown", "ArrowDown");
      await triggerKeyEvent(input(), "keydown", "Enter");

      assert.deepEqual(held.value, [2], "the second match was selected");
      assert.dom(input()).hasValue("", "an add clears the query");
      assert.strictEqual(
        document.activeElement,
        input(),
        "focus stays in the search"
      );
    });

    test("DSelectList leaves Home and End to the text caret", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      await focus(input());
      await type("a");
      const before = activeRow().textContent.trim();
      const end = await dispatched("keydown", () =>
        triggerKeyEvent(input(), "keydown", "End")
      );
      assert.false(end?.defaultPrevented, "End is not consumed");
      assert.dom(activeRow()).hasText(before, "the cursor did not move");
    });

    test("DSelectList removes held items from the strip and with Backspace", async function (assert) {
      const held = tracked([1, 2, 3]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <DSelectList
            @items={{FRUIT}}
            @label="Fruit"
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      assert.strictEqual(chips().length, 3, "every held item has a chip");
      await click(chips()[0].querySelector("button"));
      assert.deepEqual(held.value, [2, 3], "the chip removed its item");

      await focus(input());
      await triggerKeyEvent(input(), "keydown", "Backspace");
      assert.deepEqual(held.value, [2], "Backspace removed the last item");
    });

    test("DSelectList moves between the search and the strip with the arrow keys", async function (assert) {
      const held = tracked([1, 2]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <DSelectList
            @items={{FRUIT}}
            @label="Fruit"
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      await focus(input());
      await triggerKeyEvent(input(), "keydown", "ArrowLeft");
      assert.true(
        find(".d-select.--list .d-select__strip").contains(
          document.activeElement
        ),
        "ArrowLeft at the start moves into the strip"
      );

      await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
      assert.strictEqual(
        document.activeElement,
        input(),
        "ArrowDown from the strip returns to the search"
      );
    });
  });

  module("hideSelected and listHeader", function () {
    test("DSelectList hideSelected moves picked rows out of the list without a reload", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const calls = [];
      const load = fruitLoader(calls);
      await render(
        <template>
          <DSelectList
            @hideSelected={{true}}
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      const requests = calls.length;
      await click(rows().find((row) => row.textContent.includes("Banana")));
      assert.deepEqual(held.value, [2], "Banana was picked");
      assert.false(
        rowNames().includes("Banana"),
        "the picked row left the list"
      );

      await click(chips()[0].querySelector("button"));
      assert.true(rowNames().includes("Banana"), "the removed row came back");
      assert.strictEqual(calls.length, requests, "no request in between");
    });

    test("DSelectList hideSelected drops the per-row selection marker", async function (assert) {
      const held = tracked([1]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <DSelectList
            @hideSelected={{true}}
            @items={{FRUIT}}
            @label="Fruit"
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      assert.strictEqual(rows().length, 3, "the held row is left out");
      assert
        .dom(".d-select.--list .d-select__option-selected-icon")
        .doesNotExist(
          "no row carries a marker that could only ever read unselected"
        );
    });

    test("DSelectList listHeader shows with an empty query from a load source", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          >
            <:listHeader as |state|>
              {{#unless state.filter}}
                <span class="test-suggested">Suggested</span>
              {{/unless}}
            </:listHeader>
          </DSelectList>
        </template>
      );

      assert.dom(".test-suggested").exists("shown with an empty query");
      assert
        .dom(".d-select.--list [role='listbox'] .test-suggested")
        .doesNotExist("the header sits outside the listbox");

      await focus(input());
      await type("an");
      assert.dom(".test-suggested").doesNotExist("hidden while typing");
    });
  });

  module("pointer", function () {
    test("DSelectList keeps focus in its search when a row is pressed", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      await focus(input());
      await type("a");
      const row = rows()[0];
      const down = await dispatched("mousedown", () =>
        triggerEvent(row, "mousedown")
      );
      assert.true(down?.defaultPrevented, "the press does not move focus");
      await click(row);
      await type("Ch");

      assert.strictEqual(
        document.activeElement,
        input(),
        "the search kept focus"
      );
      assert.dom(input()).hasValue("Ch", "typing goes to the search");
    });

    test("DSelectList takes focus from a sibling when its row is pressed", async function (assert) {
      const first = tracked([]);
      const setFirst = (next) => (first.value = next);
      const second = tracked([]);
      const setSecond = (next) => (second.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <div class="test-a">
            <DSelectList
              @label="First"
              @load={{load}}
              @onChange={{setFirst}}
              @value={{first.value}}
            />
          </div>
          <div class="test-b">
            <DSelectList
              @label="Second"
              @load={{load}}
              @onChange={{setSecond}}
              @value={{second.value}}
            />
          </div>
        </template>
      );

      await focus(input(".test-a"));
      const row = rows(".test-b")[0];
      await triggerEvent(row, "mousedown");
      await click(row);

      assert.strictEqual(
        document.activeElement,
        input(".test-b"),
        "focus moved to the second search"
      );
      await type("Ch", ".test-b");
      assert.dom(input(".test-b")).hasValue("Ch", "typing goes to the second");
      assert.dom(input(".test-a")).hasValue("", "the first is untouched");
    });
  });

  module("at rest", function () {
    test("DSelectList clears its cursor when focus leaves and re-seeds on return", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
          <button class="test-outside" type="button">Outside</button>
        </template>
      );

      await focus(input());
      await type("an");
      assert.dom(activeRow()).exists("active while focused");

      await focus(".test-outside");

      assert.strictEqual(activeRow(), null, "no active row at rest");
      assert
        .dom(input())
        .doesNotHaveAria("activedescendant", "no active descendant at rest");
      assert.dom(input()).hasValue("an", "the query is kept");

      await focus(input());

      assert.dom(activeRow()).exists("the cursor seeds again on return");
    });

    test("DSelectList seeds nothing for results that settle after focus left", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const gate = gatedLoader();
      const load = gate.load;
      await render(
        <template>
          <DSelectList
            @debounce={{false}}
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
          <button class="test-outside" type="button">Outside</button>
        </template>
      );

      await focus(input());
      gate.hold();
      fillIn(input(), "an");
      await new Promise((resolve) => setTimeout(resolve, 0));
      moveFocusNow(find(".test-outside"));
      gate.release();
      await settled();

      assert.dom(".d-select.--list [role='option']").exists("results arrived");
      assert.strictEqual(activeRow(), null, "nothing was seeded at rest");
    });

    test("DSelectList clears its cursor when an outside change reaches the cap", async function (assert) {
      const held = tracked([1]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <DSelectList
            @items={{FRUIT}}
            @label="Fruit"
            @maximum={{2}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      await focus(input());
      await type("e");
      assert.dom(activeRow()).exists("active below the cap");

      held.value = [1, 2];
      await settled();
      assert.strictEqual(activeRow(), null, "no active row at the cap");
    });

    test("DSelectList keeps focus ownership when a middle chip is removed", async function (assert) {
      const held = tracked([1, 2, 3]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <DSelectList
            @items={{FRUIT}}
            @label="Fruit"
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      await focus(input());
      await type("e");
      await click(chips()[1].querySelector("button"));

      assert.true(
        root().contains(document.activeElement),
        "focus stayed inside the select"
      );
      await focus(input());
      assert.dom(activeRow()).exists("the cursor is still available");
    });
  });

  module("announcements", function () {
    test("DSelectList speaks nothing when rendered", async function (assert) {
      const first = tracked([]);
      const setFirst = (next) => (first.value = next);
      const second = tracked([]);
      const setSecond = (next) => (second.value = next);
      const load = fruitLoader();
      await render(
        <template>
          <DSelectList
            @label="First"
            @load={{load}}
            @onChange={{setFirst}}
            @value={{first.value}}
          />
          <DSelectList
            @label="Second"
            @load={{load}}
            @onChange={{setSecond}}
            @value={{second.value}}
          />
        </template>
      );

      assert.strictEqual(this.announce.callCount, 0, "rendering is silent");
    });

    // A query that matches nothing reports "no results" without moving the cursor. A narrowing
    // query would move it, and the moved row announces itself in place of the count.
    test("DSelectList reports results while focused and drops a late report after focus moves", async function (assert) {
      const first = tracked([]);
      const setFirst = (next) => (first.value = next);
      const second = tracked([]);
      const setSecond = (next) => (second.value = next);
      const gate = gatedLoader();
      const load = gate.load;
      await render(
        <template>
          <div class="test-a">
            <DSelectList
              @debounce={{false}}
              @label="First"
              @load={{load}}
              @onChange={{setFirst}}
              @value={{first.value}}
            />
          </div>
          <div class="test-b">
            <DSelectList
              @items={{FRUIT}}
              @label="Second"
              @onChange={{setSecond}}
              @value={{second.value}}
            />
          </div>
        </template>
      );
      await focus(input(".test-a"));
      await type("zzz", ".test-a");
      assert.true(
        this.announce.called,
        "a query in the focused select reports its results"
      );

      this.announce.resetHistory();
      gate.hold();
      fillIn(input(".test-a"), "qqq");
      await new Promise((resolve) => setTimeout(resolve, 0));
      moveFocusNow(input(".test-b"));
      moveFocusNow(input(".test-a"));
      moveFocusNow(input(".test-b"));
      gate.release();
      await settled();

      const spoken = this.announce.getCalls().map((call) => call.args[0]);
      assert.deepEqual(
        spoken,
        [],
        `the first select's late report is dropped: ${spoken.join(" | ")}`
      );
    });

    test("DSelectList always speaks an add, even while unfocused", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <DSelectList
            @items={{FRUIT}}
            @label="Fruit"
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      this.announce.resetHistory();
      await click(rows()[0]);

      const spoken = this.announce.getCalls().map((call) => call.args[0]);
      assert.true(
        spoken.some((text) => text.includes("Apple")),
        `the add is spoken: ${spoken.join(" | ")}`
      );
    });

    test("DSelectList renders and speaks nothing for an empty query with no rows", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const load = async () => [];
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      await focus(input());

      assert.dom(".d-select.--list .d-select__empty").doesNotExist();
      assert.strictEqual(this.announce.callCount, 0, "nothing is spoken");

      await type("zzz");
      assert
        .dom(".d-select.--list .d-select__empty")
        .exists("a query with no rows still says so");
    });
  });

  module("lifecycle and reload", function () {
    test("DSelectList reloads when its load context changes, focused or not", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const context = tracked({ scope: "a" });
      const calls = [];
      const load = async (filter, { context: requestContext }) => {
        calls.push(requestContext?.scope);
        return FRUIT;
      };
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @loadContext={{context.value}}
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      context.value = { scope: "b" };
      await settled();
      assert.strictEqual(calls.at(-1), "b", "reloaded while unfocused");

      await focus(input());
      context.value = { scope: "c" };
      await settled();
      assert.strictEqual(calls.at(-1), "c", "reloaded while focused");
    });

    test("DSelectList footer state has no close", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      let footer;
      const capture = (state) => {
        footer = state;
      };
      await render(
        <template>
          <DSelectList
            @items={{FRUIT}}
            @label="Fruit"
            @onChange={{setHeld}}
            @value={{held.value}}
          >
            <:footer as |state|>
              {{capture state}}
            </:footer>
          </DSelectList>
        </template>
      );

      assert.strictEqual(footer?.close, undefined, "no close in the state");
      assert.false(footer?.hasValue, "the state is live");
    });
  });

  module("locked", function () {
    test("DSelectList disabled locks the input and rows", async function (assert) {
      const held = tracked([1]);
      const onChange = sinon.spy();
      await render(
        <template>
          <DSelectList
            @disabled={{true}}
            @items={{FRUIT}}
            @label="Fruit"
            @onChange={{onChange}}
            @value={{held.value}}
          />
        </template>
      );

      assert.dom(input()).isDisabled();
      assert.dom(rows()[0]).hasAria("disabled", "true");
      await click(rows()[1]);
      assert.false(onChange.called, "a row press changes nothing");
    });

    test("DSelectList readonly keeps the input readable but blocks changes", async function (assert) {
      const held = tracked([1]);
      const onChange = sinon.spy();
      await render(
        <template>
          <DSelectList
            @items={{FRUIT}}
            @label="Fruit"
            @onChange={{onChange}}
            @readonly={{true}}
            @value={{held.value}}
          />
        </template>
      );

      assert.dom(input()).hasAttribute("readonly");
      assert.dom(rows()[0]).hasAria("disabled", "true");
      await click(rows()[1]);
      await focus(input());
      await triggerKeyEvent(input(), "keydown", "Backspace");
      assert.false(onChange.called, "nothing changes");
    });
  });

  module("escape", function () {
    test("DSelectList leaves Escape alone when standalone", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <DSelectList
            @items={{FRUIT}}
            @label="Fruit"
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      await focus(input());
      const event = await dispatched("keydown", () =>
        triggerKeyEvent(input(), "keydown", "Escape")
      );
      assert.false(
        event?.defaultPrevented,
        "Escape reaches the page unconsumed"
      );
    });

    test("DSelectList lets a containing menu close on Escape", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <DMenu @identifier="test-panel" @inline={{true}} @label="Open panel">
            <:content>
              <DSelectList
                @items={{FRUIT}}
                @label="Fruit"
                @onChange={{setHeld}}
                @value={{held.value}}
              />
            </:content>
          </DMenu>
        </template>
      );

      await click(".fk-d-menu__trigger");
      assert.dom(".d-select.--list").exists("the panel is open");
      await focus(input());
      await triggerKeyEvent(input(), "keydown", "Escape");
      assert.dom(".d-select.--list").doesNotExist("the menu closed");
    });
  });

  module("two in one container", function () {
    test("DSelectList instances keep independent queries, values and cursors", async function (assert) {
      const first = tracked([]);
      const setFirst = (next) => (first.value = next);
      const second = tracked([]);
      const setSecond = (next) => (second.value = next);
      await render(
        <template>
          <div class="test-a">
            <DSelectList
              @items={{FRUIT}}
              @label="First"
              @onChange={{setFirst}}
              @value={{first.value}}
            />
          </div>
          <div class="test-b">
            <DSelectList
              @items={{FRUIT}}
              @label="Second"
              @onChange={{setSecond}}
              @value={{second.value}}
            />
          </div>
        </template>
      );

      await focus(input(".test-a"));
      await type("an", ".test-a");
      await triggerKeyEvent(input(".test-a"), "keydown", "Enter");
      await focus(input(".test-b"));
      await type("Ch", ".test-b");

      assert.deepEqual(first.value, [2], "the first picked Banana");
      assert.deepEqual(second.value, [], "the second picked nothing");
      assert.dom(input(".test-b")).hasValue("Ch");
      assert.strictEqual(activeRow(".test-a"), null, "the first is at rest");
      assert.dom(activeRow(".test-b")).hasText("Cherry");
    });
  });

  module("rows", function () {
    test("DSelectList virtualized by default loads the next page at the end", async function (assert) {
      // The suite renders lists unwindowed by default; the end-of-list signal needs windowing.
      enableVirtualization();
      try {
        const held = tracked([]);
        const setHeld = (next) => (held.value = next);
        const many = Array.from({ length: 120 }, (_, i) => ({
          id: i + 1,
          name: `Item ${i + 1}`,
        }));
        const offsets = [];
        const load = async (filter, { offset = 0, limit = 50 }) => {
          offsets.push(offset);
          return {
            items: many.slice(offset, offset + limit),
            hasMore: offset + limit < many.length,
          };
        };
        await render(
          <template>
            <DSelectList
              @label="Items"
              @load={{load}}
              @onChange={{setHeld}}
              @value={{held.value}}
            />
          </template>
        );

        const scroller = find(".d-select.--list .d-virtual-list");
        assert.true(
          rows().length < many.length,
          "the virtualized list mounts a window"
        );
        scroller.scrollTop = scroller.scrollHeight;
        await triggerEvent(scroller, "scroll");
        await settledAfterFrame();

        assert.true(offsets.length > 1, "scrolling to the end loaded a page");
      } finally {
        disableVirtualization();
      }
    });

    test("DSelectList static renders every row in normal flow", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const many = Array.from({ length: 80 }, (_, i) => ({
        id: i + 1,
        name: `Item ${i + 1}`,
      }));
      await render(
        <template>
          <DSelectList
            @items={{many}}
            @label="Items"
            @onChange={{setHeld}}
            @value={{held.value}}
            @virtualized={{false}}
          />
        </template>
      );

      assert.strictEqual(rows().length, many.length, "every row renders");
      assert.true(
        rows().every(
          (row) => !row.style.position && !row.style.transform && !row.style.top
        ),
        "no row carries positioning styles"
      );
      assert.dom(listbox()).hasAttribute("tabindex", "-1");
    });

    test("DSelectList static warns about a paginating source", async function (assert) {
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      const warn = sinon.stub(console, "warn");
      const load = async () => ({ items: FRUIT, hasMore: true });
      await render(
        <template>
          <DSelectList
            @label="Fruit"
            @load={{load}}
            @onChange={{setHeld}}
            @value={{held.value}}
            @virtualized={{false}}
          />
        </template>
      );

      assert.true(
        warn
          .getCalls()
          .some((call) => /DSelectList/.test(String(call.args[0]))),
        "a debug warning names the component"
      );
      assert.strictEqual(rows().length, FRUIT.length, "the first page shows");
    });

    for (const virtualized of [true, false]) {
      test(`DSelectList scrolls the active row into view (virtualized: ${virtualized})`, async function (assert) {
        const held = tracked([]);
        const setHeld = (next) => (held.value = next);
        const many = Array.from({ length: 60 }, (_, i) => ({
          id: i + 1,
          name: `Item ${i + 1}`,
        }));
        await render(
          <template>
            <DSelectList
              @items={{many}}
              @label="Items"
              @onChange={{setHeld}}
              @value={{held.value}}
              @virtualized={{virtualized}}
            />
          </template>
        );

        await focus(input());
        await type("Item");
        await triggerKeyEvent(input(), "keydown", "PageDown");

        const active = activeRow();
        assert.dom(active).hasText("Item 60", "the last row is active");
        const box = active.getBoundingClientRect();
        const view = listbox()
          .closest(".d-select__options, .d-virtual-list, [role='listbox']")
          .getBoundingClientRect();
        assert.true(
          box.bottom <= view.bottom + 1,
          "the row's bottom is visible"
        );
        assert.true(box.top >= view.top - 1, "the row's top is visible");
      });
    }
  });

  module("customizations and bridge", function (nested) {
    setupLegacyBridgeCallbacks(nested);

    test("DSelectList applies a select-customizations spec for its kind", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forKind("test-list", (spec) =>
              spec.content((items) => [...items, { id: 99, name: "Extra" }])
            )
        );
      });
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <DSelectList
            @items={{FRUIT}}
            @kind="test-list"
            @label="Fruit"
            @onChange={{setHeld}}
            @value={{held.value}}
          />
        </template>
      );

      assert.true(rowNames().includes("Extra"), "the customization applied");
    });

    test("DSelectList hands the legacy bridge its root on every call", async function (assert) {
      const elements = [];
      withPluginApi((api) => {
        api.modifySelectKit("test-list").appendContent((selectKit) => {
          elements.push(selectKit.element);
        });
      });
      const held = tracked([]);
      const setHeld = (next) => (held.value = next);
      await render(
        <template>
          <section class="test-host">
            <DSelectList
              @items={{FRUIT}}
              @kind="test-list"
              @label="Fruit"
              @onChange={{setHeld}}
              @value={{held.value}}
            />
          </section>
        </template>
      );
      await focus(input());
      await type("a");

      assert.true(elements.length > 1, "the bridge ran more than once");
      assert.true(
        elements.every((element) => element === root()),
        "every call, the first included, received the root"
      );
      assert.true(
        !!elements[0]?.closest(".test-host"),
        "closest() from the root reaches an ancestor"
      );
    });

    test("DSelectList refuses bridge mutations while locked", async function (assert) {
      let bridge;
      withPluginApi((api) => {
        api.modifySelectKit("test-list").appendContent((selectKit) => {
          bridge = selectKit;
        });
      });
      const held = tracked([]);
      const onChange = sinon.spy();
      await render(
        <template>
          <DSelectList
            @disabled={{true}}
            @items={{FRUIT}}
            @kind="test-list"
            @label="Fruit"
            @onChange={{onChange}}
            @value={{held.value}}
          />
        </template>
      );

      bridge.selectKit.select(2);
      await settled();
      assert.false(onChange.called, "the locked select ignored the bridge");
    });
  });
});
