import { tracked } from "@glimmer/tracking";
import {
  click,
  find,
  findAll,
  render,
  resetOnerror,
  settled,
  setupOnerror,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import {
  EngineProbe,
  probedEngine,
} from "discourse/tests/helpers/d-select-hosts";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";

const optionValues = () =>
  findAll("[role='option']").map((row) => row.dataset.value);
const rowLabels = () =>
  findAll(
    ".d-select__option, .d-select__divider, .d-select__group-header, .d-select__group-footer"
  ).map((row) =>
    row.classList.contains("d-select__divider") ? "DIV" : row.textContent.trim()
  );

module(
  "Integration | ui-kit | select | DSelect position and dividers",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      resetOnerror();
      disableVirtualization();
    });

    test("rendered end options follow text footers with option-only ARIA indices", async function (assert) {
      const options = [
        selectOption(
          { id: "source-end", name: "Source end", section: "A" },
          { position: "end", divider: "before" }
        ),
        { id: "apple", name: "Apple", section: "A" },
        { id: "beet", name: "Beet", section: "B" },
      ];
      const extraOptions = () => [
        selectOption(
          { id: "extra-end", name: "Extra end" },
          { position: "end", divider: "before" }
        ),
      ];
      const groupHeader = (key) => `Header ${key}`;
      const groupFooter = (key) => `Footer ${key}`;
      await render(
        <template>
          <DSelect
            @extraOptions={{extraOptions}}
            @groupBy="section"
            @groupFooter={{groupFooter}}
            @groupHeader={{groupHeader}}
            @options={{options}}
          />
        </template>
      );
      await dSelect().open();
      assert.deepEqual(
        rowLabels(),
        [
          "Header A",
          "Apple",
          "Footer A",
          "Header B",
          "Beet",
          "Footer B",
          "DIV",
          "Extra end",
          "DIV",
          "Source end",
        ],
        "end and its deliberate rules follow all source groups and footers"
      );
      assert.deepEqual(
        optionValues(),
        ["apple", "beet", "extra-end", "source-end"],
        "DOM option order ends with positioned options"
      );
      for (const [index, row] of findAll("[role='option']").entries()) {
        assert
          .dom(row)
          .hasAttribute(
            "aria-posinset",
            String(index + 1),
            "each option has its position among options"
          );
        assert
          .dom(row)
          .hasAttribute(
            "aria-setsize",
            "4",
            "text boundaries and dividers do not inflate size"
          );
        assert
          .dom(row)
          .hasAttribute(
            "data-logical-index",
            String(index),
            "navigation indices ignore structural rows"
          );
      }
      for (const row of findAll(
        ".d-select__divider, .d-select__group-header, .d-select__group-footer"
      )) {
        assert
          .dom(row)
          .doesNotHaveAttribute(
            "aria-posinset",
            "structural rows have no position"
          );
        assert
          .dom(row)
          .doesNotHaveAttribute("aria-setsize", "structural rows have no size");
      }
    });

    test("a non-match removes end actions and Enter cannot activate them", async function (assert) {
      const actions = [];
      const changes = [];
      const options = [{ id: "apple", name: "Apple" }];
      const extraOptions = () => [
        selectOption(
          { id: "remove", name: "Remove" },
          {
            position: "end",
            divider: "before",
            onSelect: () => actions.push("remove"),
          }
        ),
      ];
      const onChange = (...args) => changes.push(args);
      await render(
        <template>
          <DSelect
            @debounce={{false}}
            @extraOptions={{extraOptions}}
            @onChange={{onChange}}
            @options={{options}}
          />
        </template>
      );
      await dSelect().search("zz-no-match");
      assert
        .dom("[role='option']")
        .doesNotExist("end cannot be the only option under a query");
      assert
        .dom(".d-select__divider")
        .doesNotExist("the hidden owner leaves no divider");
      assert
        .dom(".d-select__empty")
        .exists("the non-match displays the empty state");
      assert
        .dom("[role='combobox']")
        .doesNotHaveAttribute(
          "aria-activedescendant",
          "the query advertises no end action as active"
        );
      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");
      assert.deepEqual(actions, [], "Enter cannot run the hidden end action");
      assert.deepEqual(
        changes,
        [],
        "Enter cannot change the value on a non-match"
      );
    });

    test("keyboard and pointer skip dividers and activate the final end option", async function (assert) {
      const actions = [];
      const changes = [];
      const options = [
        { id: "a", name: "A" },
        selectOption({ id: "b", name: "B" }, { divider: "before" }),
      ];
      const end = { id: "remove", name: "Remove" };
      const extraOptions = () => [
        selectOption(end, {
          position: "end",
          divider: "before",
          onSelect: (_control, record) => actions.push(record),
        }),
      ];
      const onChange = (...args) => changes.push(args);
      await render(
        <template>
          <DSelect
            @extraOptions={{extraOptions}}
            @onChange={{onChange}}
            @options={{options}}
            @variant="static"
          />
        </template>
      );
      await dSelect().open();
      assert
        .dom(".d-select__divider")
        .exists({ count: 2 }, "both deliberate gaps render");
      await triggerKeyEvent("[role='combobox']", "keydown", "Home");
      assert
        .dom("[role='option'].--active")
        .hasAttribute(
          "data-value",
          "a",
          "Home starts on the first ordinary option"
        );
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      assert
        .dom("[role='option'].--active")
        .hasAttribute("data-value", "b", "ArrowDown skips the first divider");
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      assert
        .dom("[role='option'].--active")
        .hasAttribute(
          "data-value",
          "remove",
          "ArrowDown skips the end divider"
        );
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowUp");
      assert
        .dom("[role='option'].--active")
        .hasAttribute("data-value", "b", "ArrowUp skips the divider too");
      for (const divider of findAll(".d-select__divider")) {
        assert
          .dom(divider)
          .hasAttribute("role", "presentation", "a divider is presentational");
        assert
          .dom(divider)
          .hasAttribute(
            "aria-hidden",
            "true",
            "a divider is silent to readers"
          );
        assert
          .dom(divider)
          .doesNotHaveAttribute(
            "tabindex",
            "a divider cannot become a tab stop"
          );
        await click(divider);
      }
      assert.deepEqual(actions, [], "clicking a divider runs no action");
      assert.deepEqual(changes, [], "clicking a divider selects no value");
      await triggerKeyEvent("[role='combobox']", "keydown", "End");
      assert
        .dom("[role='option'].--active")
        .hasAttribute(
          "data-value",
          "remove",
          "End reaches the final end option"
        );
      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");
      await dSelect().select("remove");
      assert.strictEqual(
        actions.length,
        2,
        "keyboard and pointer each activate the end action once"
      );
      assert.true(
        actions.every((record) => record === end),
        "both activation paths return the original record"
      );
      assert.deepEqual(changes, [], "an action never becomes a selected value");
    });

    test("open-list tracked position and divider changes rebuild without render errors", async function (assert) {
      const errors = [];
      setupOnerror((error) => errors.push(error));
      const settings = tracked({}, {});
      const action = { id: "action", name: "Action" };
      const options = () => [
        selectOption(action, settings.value),
        { id: "apple", name: "Apple" },
        { id: "pear", name: "Pear" },
      ];
      await render(<template><DSelect @options={{options}} /></template>);
      await dSelect().open();
      assert.deepEqual(
        optionValues(),
        ["action", "apple", "pear"],
        "the host begins with an ordinary option"
      );
      settings.value = { position: "end", divider: "before" };
      await settled();
      assert.deepEqual(
        rowLabels(),
        ["Apple", "Pear", "DIV", "Action"],
        "tracked settings move the existing option to end and draw its rule"
      );
      settings.value = { position: "sticky", divider: "after" };
      await settled();
      assert.deepEqual(
        optionValues(),
        ["action", "apple", "pear"],
        "the same open list reacts to sticky"
      );
      assert
        .dom("[data-value='action']")
        .hasClass("--sticky-last", "the sticky seam uses the renamed class");
      assert
        .dom(".d-select__divider")
        .doesNotExist("sticky-last styling replaces the requested seam rule");
      settings.value = { position: null, divider: "after" };
      await settled();
      assert.deepEqual(
        rowLabels(),
        ["Action", "DIV", "Apple", "Pear"],
        "clearing position draws an ordinary after rule"
      );
      assert
        .dom("[data-value='action']")
        .doesNotHaveClass(
          "--sticky-last",
          "clearing position removes sticky seam styling"
        );
      assert
        .dom("[role='listbox']")
        .exists("the list stays open through all transitions");
      assert.deepEqual(
        errors.map((error) => error.message),
        [],
        "the host reports no render or backtracking error"
      );
    });

    test("held end keeps ARIA size stable until the final rendered page", async function (assert) {
      const options = Array.from({ length: 60 }, (_, id) => ({
        id,
        name: `Option ${id}`,
      }));
      const load = (_query, { offset }) =>
        offset === 0
          ? { options, total: 61, hasMore: true }
          : {
              options: [{ id: 60, name: "Option 60" }],
              total: 61,
              hasMore: false,
            };
      const extraOptions = () => [
        selectOption(
          { id: "end", name: "End action" },
          { position: "end", divider: "before" }
        ),
      ];
      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 200px;
              overflow-y: auto;
            }
          </style>
          <EngineProbe
            @extraOptions={{extraOptions}}
            @load={{load}}
            @variant="static"
          />
        </template>
      );
      await dSelect().open();
      assert
        .dom("[data-value='end']")
        .doesNotExist("end waits while the source can grow");
      assert
        .dom(".d-select__divider")
        .doesNotExist("the held owner has no divider");
      assert
        .dom("[data-value='0']")
        .hasAttribute(
          "aria-posinset",
          "1",
          "a held end leaves the source first"
        );
      assert
        .dom("[data-value='0']")
        .hasAttribute("aria-setsize", "62", "the held end is already counted");
      assert.true(
        probedEngine().revealMore(),
        "the test requests the final page through the existing host probe"
      );
      await settled();
      await triggerKeyEvent("[role='combobox']", "keydown", "End");
      assert
        .dom("[data-value='end']")
        .hasAttribute(
          "aria-posinset",
          "62",
          "the end action takes the final position"
        );
      assert
        .dom("[data-value='end']")
        .hasAttribute(
          "aria-setsize",
          "62",
          "revealing end leaves set size unchanged"
        );
      assert
        .dom("[role='option'].--active")
        .hasAttribute(
          "data-value",
          "end",
          "End now reaches the revealed action"
        );
      assert
        .dom(".d-select__divider")
        .exists({ count: 1 }, "the divider appears with its owner");
    });

    test("end alone mounts the list so an empty first page can reach the next page", async function (assert) {
      enableVirtualization();
      const requests = [];
      const load = (_query, { page, offset }) => {
        requests.push({ page, offset });
        return page === 1
          ? { options: [], hasMore: true }
          : { options: [{ id: "apple", name: "Apple" }], hasMore: false };
      };
      const extraOptions = () => [
        selectOption({ id: "end", name: "End" }, { position: "end" }),
      ];
      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 200px;
              overflow-y: auto;
            }
          </style>
          <DSelect @extraOptions={{extraOptions}} @load={{load}} />
        </template>
      );
      await dSelect().open();
      assert.deepEqual(
        requests,
        [
          { page: 1, offset: 0 },
          { page: 2, offset: 0 },
        ],
        "the mounted end-only list requests the next page even with zero raw options"
      );
      assert
        .dom("[role='listbox']")
        .exists("the end option keeps the list mounted");
      assert
        .dom(".d-select__empty")
        .doesNotExist("the empty query never replaces end with an empty state");
      assert.deepEqual(
        optionValues(),
        ["apple", "end"],
        "the next page's source option precedes end"
      );
    });

    test("a divider inside the sticky region and all later sticky options stay pinned", async function (assert) {
      enableVirtualization();
      const options = [
        selectOption(
          { id: "s1", name: "S1" },
          { position: "sticky", divider: "after" }
        ),
        selectOption(
          { id: "s2", name: "S2" },
          { position: "sticky", divider: "before" }
        ),
        selectOption({ id: "s3", name: "S3" }, { position: "sticky" }),
        ...Array.from({ length: 100 }, (_, id) => ({
          id,
          name: `Option ${id}`,
        })),
      ];
      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 240px;
              overflow-y: auto;
            }
          </style>
          <DSelect @options={{options}} @variant="static" />
        </template>
      );
      await dSelect().open();
      assert
        .dom(".d-select__divider")
        .exists(
          { count: 1 },
          "one rule separates the first two pinned options"
        );
      assert
        .dom("[data-value='s3']")
        .hasClass(
          "--sticky-last",
          "the last option beyond the divider owns the seam"
        );
      assert
        .dom("[data-value='s1']")
        .doesNotHaveClass(
          "--sticky-last",
          "the divider does not end the sticky prefix"
        );
      const viewport = find(".d-virtual-list");
      viewport.scrollTop = viewport.scrollHeight;
      await triggerEvent(viewport, "scroll");
      assert.true(
        viewport.scrollTop > 0,
        "the probe actually scrolled the long list"
      );
      const box = viewport.getBoundingClientRect();
      for (const selector of [
        "[data-value='s1']",
        ".d-select__divider",
        "[data-value='s2']",
        "[data-value='s3']",
      ]) {
        const row = find(selector);
        assert
          .dom(selector)
          .exists("the pinned row remains mounted at the bottom of the source");
        const rect = row?.getBoundingClientRect();
        assert.true(
          rect?.top >= box.top - 1,
          `${selector} stays below the viewport top after scrolling`
        );
        assert.true(
          rect?.bottom <= box.bottom + 1,
          `${selector} stays above the viewport bottom after scrolling`
        );
      }
      await triggerKeyEvent("[role='combobox']", "keydown", "Home");
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      assert
        .dom("[role='option'].--active")
        .hasAttribute(
          "data-value",
          "s2",
          "keyboard navigation skips the pinned divider"
        );
      assert
        .dom("[data-value='s2']")
        .hasAttribute(
          "aria-posinset",
          "2",
          "a sticky divider takes no position"
        );
      assert
        .dom("[data-value='s2']")
        .hasAttribute("aria-setsize", "103", "a sticky divider takes no size");
    });
  }
);
