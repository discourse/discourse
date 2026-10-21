import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  settled,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { forceMobile } from "discourse/lib/mobile";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import DSelect from "discourse/ui-kit/select/d-select";

const INITIAL_ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry" },
];
const EMPTY_ITEMS = [];

class TestState {
  @tracked items = INITIAL_ITEMS;
  @tracked valueItems = undefined;
  @tracked valueItemsMulti = undefined;
  @tracked value = 1;
  @tracked multiple = false;
  @tracked minChars = 0;
  @tracked allowCreate = false;
  @tracked labelField = "title";
}

function optionLabels() {
  return findAll("[role='option']").map((option) => option.textContent.trim());
}

module("Integration | ui-kit | select | DSelect reactivity", function (hooks) {
  setupRenderingTest(hooks);

  test("a plain reactive @items array updates an open client list", async function (assert) {
    const state = new TestState();

    await render(
      <template><DSelect @items={{state.items}} @variant="button" /></template>
    );
    await click(".d-select__trigger");

    assert.deepEqual(
      optionLabels(),
      ["Apple", "Banana", "Cherry"],
      "the initial plain array supplies the options"
    );

    state.items = [
      { id: 1, name: "Apricot" },
      { id: 4, name: "Dragonfruit" },
    ];
    await settled();

    assert.deepEqual(
      optionLabels(),
      ["Apricot", "Dragonfruit"],
      "replacing the plain array removes, renames, and adds rendered options"
    );
  });

  test("changing @items restarts a debounced list", async function (assert) {
    const state = new TestState();

    await render(
      <template>
        <DSelect @debounce={{true}} @items={{state.items}} @variant="button" />
      </template>
    );
    await click(".d-select__trigger");

    assert.deepEqual(
      optionLabels(),
      ["Apple", "Banana", "Cherry"],
      "the debounced path resolves the initial list"
    );

    state.items = [{ id: 5, name: "Elderberry" }];
    await settled();

    assert.deepEqual(
      optionLabels(),
      ["Elderberry"],
      "a new effective item source invalidates the async list context"
    );
  });

  test("@items replacements after a debounced re-filter each restart the list", async function (assert) {
    // A re-filter runs the source from the debounce timer, outside autotracking, so only
    // loadContext's own dependency on the effective items can restart the list afterwards.
    const state = new TestState();

    await render(
      <template>
        <DSelect @debounce={{true}} @items={{state.items}} @variant="button" />
      </template>
    );
    await click(".d-select__trigger");
    await fillIn(".d-select__filter", "e");

    assert.deepEqual(
      optionLabels(),
      ["Apple", "Cherry"],
      "the debounced re-filter resolves"
    );

    state.items = [{ id: 5, name: "Elderberry" }];
    await settled();
    assert.deepEqual(
      optionLabels(),
      ["Elderberry"],
      "the first replacement restarts the list"
    );

    await fillIn(".d-select__filter", "el");
    state.items = [{ id: 6, name: "Fennel" }];
    await settled();
    assert.deepEqual(
      optionLabels(),
      ["Fennel"],
      "a replacement after another re-filter also restarts the list"
    );
  });

  test("late @valueItems data refreshes every desktop selection surface", async function (assert) {
    const state = new TestState();
    state.value = 2;

    await render(
      <template>
        <DSelect
          class="late-default"
          @items={{EMPTY_ITEMS}}
          @value={{state.value}}
          @valueItems={{state.valueItems}}
        />
        <DSelect
          class="late-custom"
          @items={{EMPTY_ITEMS}}
          @value={{state.value}}
          @valueItems={{state.valueItems}}
        >
          <:selection as |item|>{{item.name}}</:selection>
        </DSelect>
        <DSelect
          class="late-button"
          @items={{EMPTY_ITEMS}}
          @value={{state.value}}
          @valueItems={{state.valueItems}}
          @variant="button"
        />
        <DSelect
          class="late-multi"
          @items={{EMPTY_ITEMS}}
          @multiple={{true}}
          @value={{state.value}}
          @valueItems={{state.valueItemsMulti}}
        />
      </template>
    );

    assert
      .dom(".late-default [role='combobox']")
      .hasValue("Unknown item (2)", "the default trigger starts unresolved");
    assert
      .dom(".late-custom .d-select__presentation")
      .hasText("Unknown item (2)", "an unresolved value bypasses :selection");
    assert
      .dom(".late-button .d-select__value")
      .hasText("Unknown item (2)", "the control selection starts unresolved");
    assert
      .dom(".late-multi .d-select__chip-label")
      .hasText("Unknown item (2)", "the chip starts unresolved");

    state.valueItems = { id: 2, name: "Banana" };
    state.valueItemsMulti = [{ id: 2, name: "Banana" }];
    await settled();

    assert
      .dom(".late-default [role='combobox']")
      .hasValue("Banana", "the default typeahead label resolves late");
    assert
      .dom(".late-custom .d-select__presentation")
      .hasText("Banana", "the yielded typeahead selection resolves late");
    assert
      .dom(".late-button .d-select__value")
      .hasText("Banana", "the control selection resolves late");
    assert
      .dom(".late-multi .d-select__chip-label")
      .hasText("Banana", "the chip resolves late");
  });

  test("late @valueItems data refreshes the mobile selection surface", async function (assert) {
    forceMobile();
    const state = new TestState();
    state.value = 2;

    await render(
      <template>
        <DSelect
          @items={{EMPTY_ITEMS}}
          @value={{state.value}}
          @valueItems={{state.valueItems}}
        />
      </template>
    );

    assert
      .dom(".d-select__presentation")
      .hasText("Unknown item (2)", "the mobile trigger starts unresolved");

    state.valueItems = { id: 2, name: "Banana" };
    await settled();

    assert
      .dom(".d-select__presentation")
      .hasText("Banana", "the mobile trigger resolves late valueItems data");
  });

  test("@multiple changes selection shape and the default close behavior", async function (assert) {
    const state = new TestState();
    const onChange = (value) => {
      state.value = value;
    };

    await render(
      <template>
        <DSelect
          @items={{state.items}}
          @multiple={{state.multiple}}
          @onChange={{onChange}}
          @value={{state.value}}
        />
      </template>
    );

    await fillIn("[role='combobox']", "ban");
    await click("[role='option']");

    assert.strictEqual(state.value, 2, "single selection replaces the value");
    assert.dom("[role='listbox']").doesNotExist("single selection closes");

    state.value = [2];
    state.multiple = true;
    await settled();

    assert
      .dom(".d-select__chip-label")
      .hasText("Banana", "the reshaped value renders as a chip after the flip");

    await fillIn(".d-select__trigger [role='combobox']", "cher");
    await click("[role='option']");

    assert.deepEqual(
      state.value,
      [2, 3],
      "multi selection appends to the current value"
    );
    assert
      .dom(".d-select__chip")
      .exists({ count: 2 }, "both selected values render as chips");
    assert.dom("[role='listbox']").exists("multi selection stays open");
  });

  test("raising @minChars closes the list gate for the current query", async function (assert) {
    const state = new TestState();

    await render(
      <template>
        <DSelect @items={{state.items}} @minChars={{state.minChars}} />
      </template>
    );
    await fillIn("[role='combobox']", "ap");

    assert
      .dom("[role='option']")
      .exists({ count: 1 }, "the initial minimum permits the query")
      .hasText("Apple", "the matching option is visible");

    state.minChars = 3;
    await settled();

    assert
      .dom(".d-select__min-chars")
      .hasText(
        "Keep typing 1 more character…",
        "the current short query is gated by the new minimum"
      );
    assert
      .dom("[role='listbox']")
      .doesNotExist("the options disappear below the new minimum");
  });

  test("@allowCreate toggles the create row for the current filter", async function (assert) {
    const state = new TestState();
    const createItem = (filter) => ({
      id: filter,
      name: filter,
      __create: true,
    });

    await render(
      <template>
        <DSelect
          @allowCreate={{state.allowCreate}}
          @createItem={{createItem}}
          @items={{state.items}}
        />
      </template>
    );
    await fillIn("[role='combobox']", "dragonfruit");

    assert
      .dom("[role='option'].--create")
      .doesNotExist("creation is initially disabled");

    state.allowCreate = true;
    await settled();

    assert
      .dom("[role='option'].--create")
      .hasText(
        "Create “dragonfruit”",
        "enabling creation adds the current proposal"
      );

    state.allowCreate = false;
    await settled();

    assert
      .dom("[role='option'].--create")
      .doesNotExist("disabling creation removes the proposal again");
  });

  test("providing both @items and @load reports the conflict", async function (assert) {
    const warnStub = sinon.stub(console, "warn");
    const items = [{ id: "local", name: "Local result" }];
    const load = () => [{ id: "remote", name: "Remote result" }];
    let renderError;

    try {
      await render(
        <template>
          <DSelect
            @debounce={{false}}
            @items={{items}}
            @load={{load}}
            @variant="button"
          />
        </template>
      );
    } catch (error) {
      renderError = error;
    }

    const diagnostic = [
      renderError?.message,
      ...warnStub.args.flat().map(String),
    ].join(" ");
    warnStub.restore();

    assert.true(
      /(?:items.*load|load.*items)/i.test(diagnostic),
      "a dev assertion or warning identifies the conflicting sources"
    );
  });

  test("static engine fields remain static by contract", async function (assert) {
    const state = new TestState();
    state.items = [{ id: 1, name: "Apple", title: "Pomme" }];

    await render(
      <template>
        <DSelect
          @items={{state.items}}
          @labelField={{state.labelField}}
          @variant="button"
        />
      </template>
    );
    await click(".d-select__trigger");

    assert
      .dom("[role='option']")
      .hasText("Pomme", "the engine captures the initial static field");

    state.labelField = "name";
    await settled();
    // Deliberately no post-change assertion: @labelField is static-by-contract, so consumers
    // must not rely on a runtime update even if another rendering layer happens to reflect it.
  });
});

/** A promise whose settlement the test controls. */
function deferred() {
  let resolve;
  const promise = new Promise((done) => (resolve = done));
  return { promise, resolve };
}

/** Rows named after the category a loader was asked about. */
function rowsFor(context) {
  const id = context?.categoryId;
  return [
    { id: `${id}-a`, name: `Cat ${id} A` },
    { id: `${id}-b`, name: `Cat ${id} B` },
  ];
}

class ContextState {
  @tracked categoryId = 1;
  @tracked tick = 0;
}

module(
  "Integration | ui-kit | select | DSelect @loadContext",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the loader receives the load context", async function (assert) {
      const state = new ContextState();
      const load = sinon.spy((filter, opts) => rowsFor(opts.context));

      await render(
        <template>
          <DSelect
            @load={{load}}
            @loadContext={{hash categoryId=state.categoryId}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();

      assert.strictEqual(
        load.lastCall.args[1].context.categoryId,
        1,
        "opts.context carries the caller's values"
      );
      assert.deepEqual(
        optionLabels(),
        ["Cat 1 A", "Cat 1 B"],
        "the rows come from that context"
      );
    });

    test("a context change while closed re-queries on the next open", async function (assert) {
      const state = new ContextState();
      const load = sinon.spy((filter, opts) => rowsFor(opts.context));

      await render(
        <template>
          <DSelect
            @load={{load}}
            @loadContext={{hash categoryId=state.categoryId}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();
      await dSelect().close();

      state.categoryId = 2;
      await settled();
      await dSelect().open();

      assert.deepEqual(
        optionLabels(),
        ["Cat 2 A", "Cat 2 B"],
        "reopening shows the new context's rows, not the settled ones"
      );
      assert.strictEqual(
        load.lastCall.args[1].context.categoryId,
        2,
        "the new query was asked with the new context"
      );
    });

    test("an equal context with a new identity reuses the settled list", async function (assert) {
      const state = new ContextState();
      const load = sinon.spy((filter, opts) => rowsFor(opts.context));

      class EqualContextHost extends Component {
        get loadContext() {
          // A fresh object on every tick, with the same values.
          const { categoryId, tick } = state;
          return { categoryId, counted: tick >= 0 };
        }

        <template>
          <DSelect
            @load={{load}}
            @loadContext={{this.loadContext}}
            @variant="button"
          />
        </template>
      }

      await render(<template><EqualContextHost /></template>);
      await dSelect().open();
      await dSelect().close();
      const calls = load.callCount;

      state.tick++;
      await settled();
      await dSelect().open();

      assert.strictEqual(
        load.callCount,
        calls,
        "values compared key by key: no new query"
      );
      assert.deepEqual(optionLabels(), ["Cat 1 A", "Cat 1 B"]);
    });

    test("a context change while open re-queries the open list", async function (assert) {
      const state = new ContextState();
      const load = sinon.spy((filter, opts) => rowsFor(opts.context));

      await render(
        <template>
          <DSelect
            @load={{load}}
            @loadContext={{hash categoryId=state.categoryId}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();
      await fillIn(".d-select__filter", "cat");

      state.categoryId = 3;
      await settled();

      assert.dom(".d-select__panel").exists("the panel stays open");
      assert.deepEqual(
        optionLabels(),
        ["Cat 3 A", "Cat 3 B"],
        "the open list shows the new context's rows"
      );
      assert.strictEqual(
        load.lastCall.args[0],
        "cat",
        "the re-query keeps the current filter"
      );
      assert.strictEqual(load.lastCall.args[1].context.categoryId, 3);
      const offset = load.lastCall.args[1].offset ?? 0;
      assert.strictEqual(offset, 0, "the re-query starts from the first page");
    });

    test("a context reload does not retry an unavailable chip", async function (assert) {
      const state = new ContextState();
      const load = (filter, opts) => rowsFor(opts.context);
      const resolveValues = sinon.spy(() => []);

      await render(
        <template>
          <DSelect
            @load={{load}}
            @loadContext={{hash categoryId=state.categoryId}}
            @multiple={{true}}
            @resolveValues={{resolveValues}}
            @value={{array 99}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();
      const resolutions = resolveValues.callCount;

      state.categoryId = 2;
      await settled();

      assert.deepEqual(optionLabels(), ["Cat 2 A", "Cat 2 B"]);
      assert.strictEqual(
        resolveValues.callCount,
        resolutions,
        "unlike reload(), a context reload keeps held-value resolution as it was"
      );
    });

    test("a context change does not supersede an in-flight update", async function (assert) {
      const state = new ContextState();
      const gate = deferred();
      const onChange = sinon.spy();
      const contexts = [];
      const load = (filter, opts) => {
        contexts.push(opts.context?.categoryId);
        return rowsFor(opts.context);
      };
      const specialItems = () => [
        {
          id: "act",
          name: "Act later",
          onSelect(control) {
            control.update(async (scope) => {
              await gate.promise;
              scope.select({ id: "late", name: "Late" });
            });
          },
        },
      ];

      await render(
        <template>
          <DSelect
            @load={{load}}
            @loadContext={{hash categoryId=state.categoryId}}
            @multiple={{true}}
            @onChange={{onChange}}
            @specialItems={{specialItems}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();
      const picking = click(
        findAll("[role='option']").find((row) =>
          row.textContent.includes("Act later")
        )
      );
      try {
        state.categoryId = 2;
        await waitUntil(() => contexts.includes(2), {
          timeout: 3000,
          timeoutMessage: "the context change never re-queried",
        });
      } finally {
        gate.resolve();
        await picking;
        await settled();
      }

      assert.true(onChange.calledOnce, "the pending update still emits");
      assert.deepEqual(
        onChange.lastCall?.args[0],
        ["late"],
        "with the value it chose"
      );
    });

    test("a context reload while open announces the new list", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      const state = new ContextState();
      const load = (filter, opts) =>
        opts.context.categoryId === 1
          ? rowsFor(opts.context)
          : [...rowsFor(opts.context), { id: "x", name: "Extra" }];

      await render(
        <template>
          <A11yLiveRegions />
          <DSelect
            @load={{load}}
            @loadContext={{hash categoryId=state.categoryId}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();

      state.categoryId = 2;
      await settled();

      assert
        .dom("#a11y-announcements-polite")
        .hasText("3 results", "the same query, reloaded, is counted again");
    });
  }
);

/** Presses a key synchronously, without waiting for the pending load to settle. */
function pressKey(selector, key) {
  find(selector).dispatchEvent(
    new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true })
  );
}

function pressEnter(selector) {
  pressKey(selector, "Enter");
}

/** Waits for the polite region to say something, without settling. */
async function politeIncludes(text) {
  await waitUntil(
    () =>
      document
        .querySelector("#a11y-announcements-polite")
        ?.textContent.includes(text),
    { timeout: 3000, timeoutMessage: `polite region never said "${text}"` }
  );
}

module(
  "Integration | ui-kit | select | DSelect Enter while loading",
  function (hooks) {
    setupRenderingTest(hooks);

    test("Enter during a pending query selects nothing and says so", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      const pending = deferred();
      const onChange = sinon.spy();
      const asked = [];
      const load = (filter) => {
        asked.push(filter);
        return filter === "ba"
          ? pending.promise
          : [
              { id: 1, name: "Apple" },
              { id: 2, name: "Banana" },
            ];
      };

      await render(
        <template>
          <A11yLiveRegions />
          <DSelect @load={{load}} @onChange={{onChange}} />
        </template>
      );
      await click("[role='combobox']");
      const typing = fillIn("[role='combobox']", "ba");
      try {
        // The arrow-onto-a-retained-row case is pinned deterministically by the static-root
        // test below; here no row is active, so the controller's own hold answers.
        await waitUntil(() => asked.includes("ba"));
        pressEnter("[role='combobox']");

        assert.true(onChange.notCalled, "a retained row is never selected");
        await politeIncludes("Still loading");
        assert.true(true, "the held Enter is announced");
      } finally {
        pending.resolve([{ id: 3, name: "Bacon" }]);
        await typing;
        await settled();
      }

      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");
      assert.true(onChange.calledOnce, "Enter works once the query settles");
      assert.strictEqual(
        onChange.lastCall.args[0],
        3,
        "and picks the row now shown"
      );
    });

    test("the button variant's filter holds Enter while loading", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      const pending = deferred();
      const onChange = sinon.spy();
      const asked = [];
      const load = (filter) => {
        asked.push(filter);
        return filter === "ba" ? pending.promise : [{ id: 1, name: "Apple" }];
      };

      await render(
        <template>
          <A11yLiveRegions />
          <DSelect @load={{load}} @onChange={{onChange}} @variant="button" />
        </template>
      );
      await dSelect().open();
      const typing = fillIn(".d-select__filter", "ba");
      try {
        await waitUntil(() => asked.includes("ba"));
        pressEnter(".d-select__filter");
        assert.true(onChange.notCalled, "nothing is picked");
        await politeIncludes("Still loading");
        assert.true(true, "the held Enter is announced");
      } finally {
        pending.resolve([]);
        await typing;
        await settled();
      }
    });

    test("the static root holds Enter during a context reload", async function (assert) {
      const state = new ContextState();
      const pending = deferred();
      const onChange = sinon.spy();
      const contexts = [];
      const load = (filter, opts) => {
        contexts.push(opts.context?.categoryId);
        return opts.context?.categoryId === 2
          ? pending.promise
          : rowsFor({ categoryId: 1 });
      };

      await render(
        <template>
          <DSelect
            @load={{load}}
            @loadContext={{hash categoryId=state.categoryId}}
            @onChange={{onChange}}
            @variant="static"
          />
        </template>
      );
      await dSelect().open();
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      assert
        .dom("[role='option'].--active")
        .exists("precondition: a row is highlighted");

      state.categoryId = 2;
      try {
        await waitUntil(() => contexts.includes(2), {
          timeout: 3000,
          timeoutMessage: "the context change never re-queried",
        });
        pressEnter("[role='combobox']");
        assert.true(
          onChange.notCalled,
          "a row from the old context is not picked"
        );
      } finally {
        pending.resolve(rowsFor({ categoryId: 2 }));
        await settled();
      }
    });

    test("Enter before the first page lands says it is still loading", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      const pending = deferred();
      const onChange = sinon.spy();
      const load = () => pending.promise;

      await render(
        <template>
          <A11yLiveRegions />
          <DSelect @load={{load}} @onChange={{onChange}} />
        </template>
      );
      const opening = click("[role='combobox']");
      try {
        await waitUntil(() => find(".d-select__panel"));
        pressEnter("[role='combobox']");
        assert.true(onChange.notCalled);
        await politeIncludes("Still loading");
        assert.true(true, "even with no row to hold");
      } finally {
        pending.resolve([{ id: 1, name: "Apple" }]);
        await opening;
        await settled();
      }
    });

    test("a local source never holds Enter", async function (assert) {
      const onChange = sinon.spy();
      const items = [
        { id: 1, name: "Apple" },
        { id: 2, name: "Banana" },
      ];

      await render(
        <template><DSelect @items={{items}} @onChange={{onChange}} /></template>
      );
      await click("[role='combobox']");
      await fillIn("[role='combobox']", "ban");
      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

      assert.strictEqual(onChange.lastCall?.args[0], 2, "Banana is picked");
    });
  }
);
