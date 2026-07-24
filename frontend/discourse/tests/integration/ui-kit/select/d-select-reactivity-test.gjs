import { tracked } from "@glimmer/tracking";
import { click, fillIn, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSelect from "discourse/ui-kit/select/d-select";

const INITIAL_ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry" },
];
const EMPTY_ITEMS = [];

class TestState {
  @tracked items = INITIAL_ITEMS;
  @tracked selected = undefined;
  @tracked selectedMulti = undefined;
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
    await click(".d-combobox__trigger");

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
        <DSelect @items={{state.items}} @debounce={{true}} @variant="button" />
      </template>
    );
    await click(".d-combobox__trigger");

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

  test("two successive @items replacements each restart a debounced list", async function (assert) {
    // The first replacement can restart via DAsyncContent's accidentally-synchronous first
    // computation; the SECOND must restart too, which requires loadContext to synchronously
    // depend on the effective items rather than relying on that one-time autotrack.
    const state = new TestState();

    await render(
      <template>
        <DSelect @items={{state.items}} @debounce={{true}} @variant="button" />
      </template>
    );
    await click(".d-combobox__trigger");

    assert.deepEqual(
      optionLabels(),
      ["Apple", "Banana", "Cherry"],
      "the debounced list resolves the initial items"
    );

    state.items = [{ id: 5, name: "Elderberry" }];
    await settled();
    assert.deepEqual(
      optionLabels(),
      ["Elderberry"],
      "the first replacement restarts the debounced list"
    );

    state.items = [{ id: 6, name: "Fig" }];
    await settled();
    assert.deepEqual(
      optionLabels(),
      ["Fig"],
      "a second replacement also restarts the debounced list"
    );
  });

  test("late @selected data refreshes every desktop selection surface", async function (assert) {
    const state = new TestState();
    state.value = 2;

    await render(
      <template>
        <DSelect
          class="late-default"
          @items={{EMPTY_ITEMS}}
          @value={{state.value}}
          @selected={{state.selected}}
        />
        <DSelect
          class="late-custom"
          @items={{EMPTY_ITEMS}}
          @value={{state.value}}
          @selected={{state.selected}}
        >
          <:selection as |item|>{{item.name}}</:selection>
        </DSelect>
        <DSelect
          class="late-button"
          @items={{EMPTY_ITEMS}}
          @value={{state.value}}
          @selected={{state.selected}}
          @variant="button"
        />
        <DSelect
          class="late-multi"
          @items={{EMPTY_ITEMS}}
          @value={{state.value}}
          @selected={{state.selectedMulti}}
          @multiple={{true}}
        />
      </template>
    );

    assert
      .dom(".late-default [role='combobox']")
      .hasValue("2 (unavailable)", "the default trigger starts unresolved");
    assert
      .dom(".late-custom .d-combobox__presentation")
      .hasText("2", "the yielded selection starts unresolved");
    assert
      .dom(".late-button .d-combobox__value")
      .hasText("2 Unavailable", "the control selection starts unresolved");
    assert
      .dom(".late-multi .d-combobox__chip-label")
      .hasText("2 Unavailable", "the chip starts unresolved");

    state.selected = { id: 2, name: "Banana" };
    state.selectedMulti = [{ id: 2, name: "Banana" }];
    await settled();

    assert
      .dom(".late-default [role='combobox']")
      .hasValue("Banana", "the default typeahead label resolves late");
    assert
      .dom(".late-custom .d-combobox__presentation")
      .hasText("Banana", "the yielded typeahead selection resolves late");
    assert
      .dom(".late-button .d-combobox__value")
      .hasText("Banana", "the control selection resolves late");
    assert
      .dom(".late-multi .d-combobox__chip-label")
      .hasText("Banana", "the chip resolves late");
  });

  test("late @selected data refreshes the mobile selection surface", async function (assert) {
    forceMobile();
    const state = new TestState();
    state.value = 2;

    await render(
      <template>
        <DSelect
          @items={{EMPTY_ITEMS}}
          @value={{state.value}}
          @selected={{state.selected}}
        />
      </template>
    );

    assert
      .dom(".d-combobox__presentation")
      .hasText("2 Unavailable", "the mobile trigger starts unresolved");

    state.selected = { id: 2, name: "Banana" };
    await settled();

    assert
      .dom(".d-combobox__presentation")
      .hasText("Banana", "the mobile trigger resolves late selected data");
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
          @value={{state.value}}
          @multiple={{state.multiple}}
          @onChange={{onChange}}
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
      .dom(".d-combobox__chip-label")
      .hasText("Banana", "the reshaped value renders as a chip after the flip");

    await fillIn(".d-combobox__trigger [role='combobox']", "cher");
    await click("[role='option']");

    assert.deepEqual(
      state.value,
      [2, 3],
      "multi selection appends to the current value"
    );
    assert
      .dom(".d-combobox__chip")
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
      .dom(".d-combobox__min-chars")
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
      name: `Create ${filter}`,
      __create: true,
    });

    await render(
      <template>
        <DSelect
          @items={{state.items}}
          @allowCreate={{state.allowCreate}}
          @createItem={{createItem}}
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
        "Create dragonfruit",
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
            @items={{items}}
            @load={{load}}
            @debounce={{false}}
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
    await click(".d-combobox__trigger");

    assert
      .dom("[role='option']")
      .hasText("Pomme", "the engine captures the initial static field");

    state.labelField = "name";
    await settled();
    // Deliberately no post-change assertion: @labelField is static-by-contract, so consumers
    // must not rely on a runtime update even if another rendering layer happens to reflect it.
  });
});
