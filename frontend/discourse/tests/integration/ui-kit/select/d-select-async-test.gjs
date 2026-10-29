import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  rerender,
  resetOnerror,
  settled,
  setupOnerror,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { forceMobile } from "discourse/lib/mobile";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  EngineProbe,
  ITEMS,
  probedEngine,
} from "discourse/tests/helpers/d-select-hosts";
import DSelect from "discourse/ui-kit/select/d-select";

const resolveNone = () => Promise.resolve([]);

module("Integration | ui-kit | select | DSelect (async)", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    resetOnerror();
  });

  test("synchronous resolvers supply the desktop typeahead label", async function (assert) {
    const resolveValue = (value) => ({ id: value, name: `Topic #${value}` });
    const resolveValues = (values) =>
      values.map((value) => ({ id: value, name: `Category #${value}` }));

    await render(
      <template>
        <DSelect
          class="sync-resolve-value"
          @items={{array}}
          @resolveValue={{resolveValue}}
          @value={{123}}
        />
        <DSelect
          class="sync-resolve-values"
          @items={{array}}
          @resolveValues={{resolveValues}}
          @value={{456}}
        />
      </template>
    );

    assert
      .dom(".sync-resolve-value [role='combobox']")
      .hasValue(
        "Topic #123",
        "the synchronously resolveValue label reaches the plain input"
      );
    assert
      .dom(".sync-resolve-values [role='combobox']")
      .hasValue(
        "Category #456",
        "the synchronously resolveValues label reaches the plain input"
      );
  });

  test("a held async value remains readable after the control remounts", async function (assert) {
    class RemountHost extends Component {
      @tracked mounted = true;
      value = "en";

      @action
      load() {
        return Promise.resolve([]);
      }

      @action
      resolveValue(value) {
        return { id: value, name: "English (US)" };
      }

      @action
      toggle() {
        this.mounted = !this.mounted;
      }

      <template>
        {{#if this.mounted}}
          <DSelect
            @load={{this.load}}
            @minChars={{3}}
            @resolveValue={{this.resolveValue}}
            @value={{this.value}}
          />
        {{/if}}
        <button class="toggle" type="button" {{on "click" this.toggle}}>
          Toggle
        </button>
      </template>
    }

    await render(<template><RemountHost /></template>);

    assert
      .dom("[role='combobox']")
      .hasValue("English (US)", "the initial held value resolves");

    await click(".toggle");
    await click(".toggle");

    assert
      .dom("[role='combobox']")
      .hasValue("English (US)", "the held value resolves after remounting");
  });

  test("a synchronous resolver's label follows a later @value change", async function (assert) {
    const resolveValue = (value) => ({ id: value, name: `Topic #${value}` });

    class SyncHost extends Component {
      @tracked value = 1;

      @action
      bump() {
        this.value = 2;
      }

      <template>
        <DSelect
          @items={{array}}
          @resolveValue={{resolveValue}}
          @value={{this.value}}
        />
        <button
          class="bump"
          type="button"
          {{on "click" this.bump}}
        >bump</button>
      </template>
    }

    await render(<template><SyncHost /></template>);
    assert
      .dom("[role='combobox']")
      .hasValue("Topic #1", "the initial synchronous label renders");

    await click(".bump");
    assert
      .dom("[role='combobox']")
      .hasValue(
        "Topic #2",
        "a value change re-resolves rather than showing the stale label"
      );
  });

  test("an unresolvable single value shows the held value as unavailable, not a flash", async function (assert) {
    const resolveValue = () => Promise.reject(new Error("403"));

    await render(
      <template>
        <DSelect @items={{array}} @resolveValue={{resolveValue}} @value={{7}} />
      </template>
    );

    assert
      .dom("[role='combobox']")
      .hasValue(
        "Unknown item (7)",
        "the held value is shown as unknown rather than blanking"
      );
    assert
      .dom(".d-select__trigger [role='alert']")
      .doesNotExist(
        "a rejected resolve does not flash an error inside the trigger"
      );
  });

  // `@load` answers queries; it is never asked "what is id 2". A select that can mount holding a
  // value therefore needs an identity mechanism, and with none the value can never resolve — the
  // trigger reads "(unavailable)" for the life of the page. It fails only after a reload, long
  // after the session that picked the value looked correct, which is why it asserts rather than
  // degrading quietly.
  test("asserts when an async source has no way to resolve a held value", async function (assert) {
    let fired = false;
    setupOnerror((error) => {
      fired = true;
      assert.true(
        error.message.includes("@resolveValue"),
        "the assertion names the missing argument"
      );
    });

    const load = () => Promise.resolve([{ id: 1, name: "One" }]);

    await render(<template><DSelect @load={{load}} @value={{2}} /></template>);

    assert.true(fired, "the misconfiguration asserts during render");
  });

  // The assert must be silent wherever the consumer HAS supplied a way to resolve, including
  // the cases that merely look like the broken one. A false positive here is worse than no
  // assert at all: it throws on working code.
  test("does not assert when an identity mechanism is supplied", async function (assert) {
    let fired = false;
    setupOnerror(() => (fired = true));

    const load = () => Promise.resolve([{ id: 1, name: "One" }]);
    const resolveValue = (value) => ({ id: value, name: `Topic #${value}` });
    // Declared but still empty: the late-arrival pattern mid-flight, which must not be
    // mistaken for supplying nothing.
    const pendingValueItems = undefined;

    await render(
      <template>
        <DSelect
          class="with-resolver"
          @load={{load}}
          @resolveValue={{resolveValue}}
          @value={{2}}
        />
        <DSelect
          class="with-pending-value-items"
          @load={{load}}
          @value={{2}}
          @valueItems={{pendingValueItems}}
        />
        {{! A client source resolves from its own list, so a missing id is data, not config. }}
        <DSelect class="client" @items={{ITEMS}} @value={{99}} />
      </template>
    );

    assert.false(fired, "no assertion fires when resolution is expressible");
    assert
      .dom(".with-resolver [role='combobox']")
      .hasValue("Topic #2", "the resolver still supplies the label");
  });

  test("asserts when a multi-select mounts holding values it cannot resolve", async function (assert) {
    let fired = false;
    setupOnerror((error) => {
      fired = true;
      assert.true(
        error.message.includes("@resolveValue"),
        "the assertion names the missing argument"
      );
    });

    const load = () => Promise.resolve([{ id: 1, name: "One" }]);

    await render(
      <template>
        <DSelect @load={{load}} @multiple={{true}} @value={{array 2}} />
      </template>
    );

    assert.true(fired, "the misconfiguration asserts during render");
  });

  // The broken configuration is only broken once a value is held at mount. Mounting empty and
  // picking from the list is the session where everything looks right, so it must stay quiet.
  test("does not assert when an async-only select mounts empty and a value is picked", async function (assert) {
    let error;
    setupOnerror((e) => (error = e));

    const load = () => Promise.resolve([{ id: 1, name: "One" }]);

    class PickHost extends Component {
      @tracked value = null;

      @action
      onChange(value) {
        this.value = value;
      }

      <template>
        <DSelect
          class="pick"
          @load={{load}}
          @onChange={{this.onChange}}
          @value={{this.value}}
        />
        <DSelect
          class="empty-multi"
          @load={{load}}
          @multiple={{true}}
          @value={{(array)}}
        />
      </template>
    }

    await render(<template><PickHost /></template>);

    assert.strictEqual(
      error?.message,
      undefined,
      "an empty mount does not assert"
    );

    await fillIn(".pick [role='combobox']", "One");
    await click("[role='option']");

    assert.strictEqual(
      error?.message,
      undefined,
      "a picked value does not assert"
    );
    assert
      .dom(".pick [role='combobox']")
      .hasValue("One", "the picked value resolves from the loaded rows");
  });

  test("a :skeletonItem block replaces each placeholder row of the first load", async function (assert) {
    let resolveLoad;
    const load = () => new Promise((resolve) => (resolveLoad = resolve));

    await render(
      <template>
        <DSelect @load={{load}}>
          <:skeletonItem><span
              class="custom-loading-row"
            ></span></:skeletonItem>
        </DSelect>
      </template>
    );
    const typing = fillIn("[role='combobox']", "x");
    await waitFor(".d-select__skeleton");

    const rows = findAll(".d-select__skeleton");
    assert.true(rows.length > 0, "the first load shows placeholder rows");
    assert.strictEqual(
      findAll(".d-select__skeleton .custom-loading-row").length,
      rows.length,
      "every placeholder row renders the block"
    );
    assert
      .dom(".d-select__skeleton .d-skeleton")
      .doesNotExist("the default bar is replaced");

    resolveLoad([]);
    await typing;
  });

  test("multi renders resolved chips plus an unavailable chip for an id that cannot resolve", async function (assert) {
    const resolveValues = (values) =>
      Promise.resolve(
        values.filter((v) => v === 1).map((v) => ({ id: v, name: "One" }))
      );

    await render(
      <template>
        <DSelect
          @items={{array}}
          @multiple={{true}}
          @resolveValues={{resolveValues}}
          @value={{array 1 2}}
        />
      </template>
    );

    assert.dom(".d-select__chip").exists({ count: 2 }, "one chip per held id");
    assert
      .dom(".d-select__unresolved")
      .exists(
        { count: 1 },
        "the id that cannot resolve renders as unavailable"
      );
    assert
      .dom(".d-select__unresolved")
      .hasText(
        "Unknown item (2)",
        "the chip says what it is in visible text, keeping ids distinct"
      );
    assert
      .dom(".d-select__unresolved .d-icon")
      .doesNotExist("no icon stands in for the text");
    assert
      .dom(".d-select__unresolved")
      .doesNotHaveAttribute("title", "no tooltip repeats it");
    assert
      .dom(".d-select__unresolved .sr-only")
      .doesNotExist("no hidden text differs from what is shown");
  });

  test("an unresolved chip with a named fallback shows that name as-is", async function (assert) {
    const createUnresolvedItem = (value) => ({
      id: value,
      name: "Deleted user",
    });

    await render(
      <template>
        <DSelect
          @createUnresolvedItem={{createUnresolvedItem}}
          @items={{array}}
          @multiple={{true}}
          @resolveValues={{resolveNone}}
          @value={{array 2}}
        />
      </template>
    );

    assert
      .dom(".d-select__unresolved")
      .hasText("Deleted user", "a named fallback already explains itself");
  });

  test("removing an unresolved chip announces it by its label", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    class RemoveHost extends Component {
      @tracked value = [2];

      @action
      onChange(value) {
        this.value = value;
      }

      <template>
        <A11yLiveRegions />
        <DSelect
          @items={{array}}
          @multiple={{true}}
          @onChange={{this.onChange}}
          @resolveValues={{resolveNone}}
          @value={{this.value}}
        />
      </template>
    }

    await render(<template><RemoveHost /></template>);
    await click(".d-select__chip-remove");

    assert
      .dom("#a11y-announcements-polite")
      .hasText("Removed Unknown item (2)", "the announcement names it");
  });

  test("a single button trigger shows and names an unresolved value the same way", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{array}}
          @resolveValues={{resolveNone}}
          @value={{7}}
          @variant="button"
        />
      </template>
    );

    assert
      .dom(".d-select__trigger .d-select__unresolved")
      .hasText("Unknown item (7)", "the visible text");
    assert.true(
      find(".d-select__trigger")
        .getAttribute("aria-label")
        .endsWith("Unknown item (7)"),
      "the accessible name ends with the same text"
    );
  });

  test("@valueItems seeds part of an async multi selection", async function (assert) {
    const resolvedValues = [];
    const valueItems = { id: 1, name: "One" };
    const resolveValues = (values) => {
      resolvedValues.push(...values);
      return Promise.resolve(
        values.map((value) => ({ id: value, name: "Two" }))
      );
    };

    await render(
      <template>
        <DSelect
          @items={{array}}
          @multiple={{true}}
          @resolveValues={{resolveValues}}
          @value={{array 1 2}}
          @valueItems={{valueItems}}
        />
      </template>
    );

    assert
      .dom(".d-select__chip")
      .exists({ count: 2 }, "both selected values render as chips");
    assert.deepEqual(
      resolvedValues,
      [2],
      "only the value missing from @valueItems is resolved"
    );
  });

  test("a custom createUnresolvedItem names the fallback on every surface", async function (assert) {
    const resolveValue = () => Promise.reject(new Error("404"));
    const createUnresolvedItem = (id) => ({ id, name: `Topic #${id}` });

    await render(
      <template>
        <DSelect
          @createUnresolvedItem={{createUnresolvedItem}}
          @items={{array}}
          @resolveValue={{resolveValue}}
          @value={{123}}
        />
      </template>
    );

    assert
      .dom("[role='combobox']")
      .hasValue(
        "Topic #123",
        "the named fallback reaches the plain input, with no generic suffix"
      );
  });

  test("a throwing createUnresolvedItem uses the default unavailable label", async function (assert) {
    const resolveValue = () => Promise.reject(new Error("404"));
    const createUnresolvedItem = () => {
      throw new Error("builder failed");
    };

    await render(
      <template>
        <DSelect
          @createUnresolvedItem={{createUnresolvedItem}}
          @items={{array}}
          @resolveValue={{resolveValue}}
          @value={{123}}
        />
      </template>
    );

    assert
      .dom("[role='combobox']")
      .hasValue(
        "Unknown item (123)",
        "the default fallback is used when the builder throws"
      );
  });

  test("resolving a fallback label keeps the focused input mounted", async function (assert) {
    let resolveSelection;
    const selectionPromise = new Promise((resolve) => {
      resolveSelection = resolve;
    });
    const resolveValue = () => selectionPromise;

    const renderPromise = render(
      <template>
        <DSelect @items={{array}} @resolveValue={{resolveValue}} @value={{2}} />
      </template>
    );
    await waitFor("[role='combobox']");

    const input = find("[role='combobox']");
    input.focus();
    resolveSelection({ id: 2, name: "Banana" });
    await renderPromise;

    assert.strictEqual(
      find("[role='combobox']"),
      input,
      "the resolution updates the existing input"
    );
    assert.strictEqual(
      document.activeElement,
      input,
      "the input keeps focus while its label resolves"
    );
    assert
      .dom(input)
      .hasValue("Banana", "the resolved fallback becomes the input value");
    assert.strictEqual(
      input.selectionStart,
      input.selectionEnd,
      "a label arriving under an already-focused input is not auto-selected"
    );
  });

  test("an error can be retried without changing the query", async function (assert) {
    let requestCount = 0;
    let retryFilter;
    let resolveRetry;
    const retryPromise = new Promise((resolve) => {
      resolveRetry = resolve;
    });
    const load = (filter) => {
      requestCount++;

      if (requestCount === 1) {
        return Promise.reject(new Error("The first request failed"));
      }

      retryFilter = filter;
      return retryPromise;
    };

    await render(
      <template>
        <DSelect @load={{load}}>
          <:selection as |item|>
            {{~item.name~}}
          </:selection>
          <:item as |item|>
            {{~item.name~}}
          </:item>
        </DSelect>
      </template>
    );
    await fillIn("[role='combobox']", "ban");

    assert
      .dom(".d-select__error .d-icon-triangle-exclamation")
      .exists("the first request displays the muted async error state");
    assert
      .dom(".d-select__retry")
      .hasText("Retry", "the error offers a recovery action");

    const retryClick = click(".d-select__retry");
    await waitFor(".d-select__skeleton");
    assert
      .dom(".d-select__skeleton")
      .exists("retry transitions back through the loading state");
    resolveRetry(ITEMS.filter((item) => item.name === "Banana"));
    await retryClick;

    assert.dom(".d-select__error").doesNotExist("the error is cleared");
    assert.strictEqual(requestCount, 2, "retry makes one additional request");
    assert.strictEqual(retryFilter, "ban", "retry preserves the current query");
    assert
      .dom("[role='option']")
      .exists({ count: 1 }, "the successful retry displays its results")
      .hasText("Banana");
  });
});

module(
  "Integration | ui-kit | select | DSelect (error state)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the default error state is a muted inline message, not the alert box", async function (assert) {
      const load = () => Promise.reject(new Error("boom"));
      await render(<template><DSelect @load={{load}} /></template>);
      await fillIn("[role='combobox']", "x");

      assert.dom(".d-select__error").exists();
      assert
        .dom(".d-select__error .d-icon-triangle-exclamation")
        .exists("the error shows a muted icon");
      assert
        .dom(".d-select__error [role='alert']")
        .doesNotExist("the heavy alert box is gone");
      assert
        .dom(".d-select__retry.btn-flat")
        .exists("the retry is a low-emphasis button");
    });

    test("@retryable={{false}} hides the retry button", async function (assert) {
      const load = () => Promise.reject(new Error("boom"));
      await render(
        <template><DSelect @load={{load}} @retryable={{false}} /></template>
      );
      await fillIn("[role='combobox']", "x");

      assert.dom(".d-select__error").exists("the error still renders");
      assert
        .dom(".d-select__retry")
        .doesNotExist("a non-retryable source hides the retry");
    });

    test("an :error block replaces the default and its retry action reloads", async function (assert) {
      let calls = 0;
      const load = () => {
        calls++;
        return calls === 1
          ? Promise.reject(new Error("boom"))
          : Promise.resolve([{ id: 1, name: "Apple" }]);
      };
      await render(
        <template>
          <DSelect @load={{load}}>
            <:error as |error retry|>
              <div class="custom-error">{{error.message}}</div>
              <button
                class="custom-retry"
                type="button"
                {{on "click" retry}}
              >go</button>
            </:error>
            <:item as |item|>
              {{~item.name~}}
            </:item>
          </DSelect>
        </template>
      );
      await fillIn("[role='combobox']", "x");

      assert
        .dom(".custom-error")
        .hasText("boom", "the :error block renders with the error");
      assert
        .dom(".d-select__error .d-icon-triangle-exclamation")
        .doesNotExist("the default body is replaced by the block");

      await click(".custom-retry");
      assert
        .dom("[role='option']")
        .exists({ count: 1 }, "the yielded retry action reloads the source");
    });

    // The guarantee the block shape exists for. `:error` used to replace the whole container,
    // so supplying one silently dropped the alert role and the failure stopped being announced
    // — invisible to anyone not listening to it.
    test("an :error block cannot drop the alert role", async function (assert) {
      const load = () => Promise.reject(new Error("boom"));

      await render(
        <template>
          <DSelect @load={{load}}>
            <:error>
              <span class="custom-error">Could not load</span>
            </:error>
          </DSelect>
        </template>
      );
      await fillIn("[role='combobox']", "x");

      assert
        .dom(".d-select__error[role='alert']")
        .exists("the component keeps the alert container around the block");
      assert
        .dom(".d-select__error .custom-error")
        .hasText("Could not load", "the block supplies the contents");
      assert
        .dom(".d-select__error .d-select__error-message")
        .doesNotExist("the default message gives way to the block");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (:selectionLoading)",
  function (hooks) {
    setupRenderingTest(hooks);

    let release;
    const resolveValue = (value) =>
      new Promise(
        (resolve) => (release = () => resolve({ id: value, name: "Banana" }))
      );
    const resolveValues = (values) =>
      new Promise(
        (resolve) =>
          (release = () =>
            resolve(values.map((id) => ({ id, name: "Banana" }))))
      );

    const releasePending = () => release?.();

    hooks.beforeEach(function () {
      release = undefined;
    });

    // One case per surface that shows a placeholder while a held value resolves.
    const cases = [
      {
        name: "the desktop typeahead",
        Host: <template>
          <DSelect @items={{array}} @resolveValue={{resolveValue}} @value={{2}}>
            <:selectionLoading><span
                class="custom-selection-loading"
              ></span></:selectionLoading>
          </DSelect>
        </template>,
      },
      {
        name: "the desktop typeahead with a :selection block",
        Host: <template>
          <DSelect @items={{array}} @resolveValue={{resolveValue}} @value={{2}}>
            <:selection as |item|>
              {{~item.name~}}
            </:selection>
            <:selectionLoading><span
                class="custom-selection-loading"
              ></span></:selectionLoading>
          </DSelect>
        </template>,
      },
      {
        name: "the mobile typeahead",
        mobile: true,
        Host: <template>
          <DSelect @items={{array}} @resolveValue={{resolveValue}} @value={{2}}>
            <:selectionLoading><span
                class="custom-selection-loading"
              ></span></:selectionLoading>
          </DSelect>
        </template>,
      },
      {
        name: "the button trigger",
        Host: <template>
          <DSelect
            @items={{array}}
            @resolveValue={{resolveValue}}
            @value={{2}}
            @variant="button"
          >
            <:selectionLoading><span
                class="custom-selection-loading"
              ></span></:selectionLoading>
          </DSelect>
        </template>,
      },
      {
        name: "a chip",
        Host: <template>
          <DSelect
            @items={{array}}
            @multiple={{true}}
            @resolveValues={{resolveValues}}
            @value={{array 2}}
          >
            <:selectionLoading><span
                class="custom-selection-loading"
              ></span></:selectionLoading>
          </DSelect>
        </template>,
      },
    ];

    for (const { name, Host, mobile } of cases) {
      test(`a :selectionLoading block replaces the placeholder in ${name}`, async function (assert) {
        if (mobile) {
          forceMobile();
        }

        const rendering = render(<template><Host /></template>);
        try {
          await waitFor(".custom-selection-loading");

          assert
            .dom(".custom-selection-loading")
            .exists("the block renders while the value resolves");
          assert
            .dom(".d-select__trigger .d-skeleton")
            .doesNotExist("the default bar is replaced");
        } finally {
          // Settle the render even when an assertion above throws, so a failure stays in
          // this test instead of leaving a pending render to break the ones after it.
          releasePending();
          await rendering;
        }

        assert
          .dom(".custom-selection-loading")
          .doesNotExist("the block goes once the value resolves");
      });
    }
  }
);

module(
  "Integration | ui-kit | select | DSelect (:unresolved)",
  function (hooks) {
    setupRenderingTest(hooks);

    // Every surface that renders a held item, each with a `:selection` block, so the tests show
    // that an unresolved item never reaches `:selection`.
    const surfaces = [
      {
        name: "a chip",
        Plain: <template>
          <DSelect
            @items={{array}}
            @multiple={{true}}
            @resolveValues={{resolveNone}}
            @value={{array 2}}
          >
            <:selection as |item|><span class="custom-selection">
                {{~item.name~}}
              </span></:selection>
          </DSelect>
        </template>,
        Custom: <template>
          <DSelect
            @items={{array}}
            @multiple={{true}}
            @resolveValues={{resolveNone}}
            @value={{array 2}}
          >
            <:selection as |item|><span class="custom-selection">
                {{~item.name~}}
              </span></:selection>
            <:unresolved as |item|><span class="custom-unresolved">Missing
                {{item.id~}}
              </span></:unresolved>
          </DSelect>
        </template>,
      },
      {
        name: "the button trigger",
        Plain: <template>
          <DSelect
            @items={{array}}
            @resolveValues={{resolveNone}}
            @value={{2}}
            @variant="button"
          >
            <:selection as |item|><span class="custom-selection">
                {{~item.name~}}
              </span></:selection>
          </DSelect>
        </template>,
        Custom: <template>
          <DSelect
            @items={{array}}
            @resolveValues={{resolveNone}}
            @value={{2}}
            @variant="button"
          >
            <:selection as |item|><span class="custom-selection">
                {{~item.name~}}
              </span></:selection>
            <:unresolved as |item|><span class="custom-unresolved">Missing
                {{item.id~}}
              </span></:unresolved>
          </DSelect>
        </template>,
      },
      {
        name: "the desktop typeahead",
        Plain: <template>
          <DSelect @items={{array}} @resolveValues={{resolveNone}} @value={{2}}>
            <:selection as |item|><span class="custom-selection">
                {{~item.name~}}
              </span></:selection>
          </DSelect>
        </template>,
        Custom: <template>
          <DSelect @items={{array}} @resolveValues={{resolveNone}} @value={{2}}>
            <:selection as |item|><span class="custom-selection">
                {{~item.name~}}
              </span></:selection>
            <:unresolved as |item|><span class="custom-unresolved">Missing
                {{item.id~}}
              </span></:unresolved>
          </DSelect>
        </template>,
      },
      {
        name: "the mobile typeahead",
        mobile: true,
        Plain: <template>
          <DSelect @items={{array}} @resolveValues={{resolveNone}} @value={{2}}>
            <:selection as |item|><span class="custom-selection">
                {{~item.name~}}
              </span></:selection>
          </DSelect>
        </template>,
        Custom: <template>
          <DSelect @items={{array}} @resolveValues={{resolveNone}} @value={{2}}>
            <:selection as |item|><span class="custom-selection">
                {{~item.name~}}
              </span></:selection>
            <:unresolved as |item|><span class="custom-unresolved">Missing
                {{item.id~}}
              </span></:unresolved>
          </DSelect>
        </template>,
      },
    ];

    for (const { name, Plain, Custom, mobile } of surfaces) {
      test(`without :unresolved, ${name} shows the built-in label, not :selection`, async function (assert) {
        if (mobile) {
          forceMobile();
        }

        await render(<template><Plain /></template>);

        assert
          .dom(".custom-selection")
          .doesNotExist(":selection never receives an unresolved item");
        assert
          .dom(".d-select__unresolved")
          .hasText("Unknown item (2)", "the built-in label is used");
      });

      test(`with :unresolved, ${name} renders that block`, async function (assert) {
        if (mobile) {
          forceMobile();
        }

        await render(<template><Custom /></template>);

        assert
          .dom(".custom-unresolved")
          .hasText("Missing 2", "the block receives the unresolved item");
        assert
          .dom(".custom-selection")
          .doesNotExist(":selection never receives an unresolved item");
      });
    }
  }
);

module("Integration | ui-kit | select | DSelect (async)", function () {
  module("a pending update on mobile", function (hooks) {
    setupRenderingTest(hooks);

    for (const multiple of [false, true]) {
      test(`an empty mobile ${multiple ? "multi" : "single"} shows pending selection feedback`, async function (assert) {
        forceMobile();
        let release;
        const gate = new Promise((resolve) => (release = resolve));
        const items = [
          {
            id: "suggest",
            name: "Suggest",
            onSelect(control) {
              control.close();
              control.update(async () => {
                await gate;
              });
            },
          },
        ];
        await render(
          <template>
            <DSelect
              @items={{items}}
              @multiple={{multiple}}
              @placeholder="Pick a value"
            />
          </template>
        );
        await click(".d-select__trigger");
        const clicking = click(".d-select__option");
        try {
          await waitFor(".d-select__pending-icon", { timeout: 2000 });
          assert
            .dom(".d-select__trigger .d-skeleton")
            .exists("an empty selection still has a loading slot");
          assert
            .dom(".d-select__trigger")
            .hasAttribute("aria-busy", "true", "the mobile trigger is busy");
          assert
            .dom(".d-select__placeholder")
            .doesNotExist("the placeholder is replaced");
        } finally {
          release();
          await clicking;
        }
        assert
          .dom(".d-select__trigger")
          .doesNotHaveAttribute(
            "aria-busy",
            "the mobile trigger finishes loading"
          );
      });
    }
  });
});

module(
  "Integration | ui-kit | select | DSelect (async) loading inputs",
  function (hooks) {
    setupRenderingTest(hooks);

    /** Dispatches without waiting for an unresolved source's test waiter. */
    function press(key, selector = "[role='combobox']") {
      find(selector).dispatchEvent(
        new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true })
      );
    }

    test("own key counts and nested identity determine reloads", async function (assert) {
      const inherited = { ignored: 1 };
      const reference = {};
      const context = tracked(
        Object.assign(Object.create(inherited), { reference })
      );
      const calls = [];
      const load = (_filter, opts) => {
        calls.push(opts.context);
        return ITEMS;
      };

      await render(
        <template>
          <DSelect @load={{load}} @loadContext={{context.value}} />
        </template>
      );
      await click("[role='combobox']");
      const initial = calls.length;

      context.value = { reference };
      await settled();
      assert.strictEqual(calls.length, initial, "inherited keys are ignored");

      context.value = { reference, extra: undefined };
      await settled();
      assert.strictEqual(
        calls.length,
        initial + 1,
        "an added undefined key counts"
      );

      context.value = { reference };
      await settled();
      assert.strictEqual(
        calls.length,
        initial + 2,
        "removing that key counts too"
      );

      context.value = { reference: {} };
      await settled();
      assert.strictEqual(
        calls.length,
        initial + 3,
        "nested objects compare by identity"
      );
    });

    test("an equal array re-derived after a pick neither reloads nor moves the list", async function (assert) {
      class State {
        @tracked value = [];
        @tracked exclude = [1000];
      }
      const state = new State();
      let loads = 0;
      const load = () => {
        loads++;
        return Array.from({ length: 60 }, (_, id) => ({
          id,
          name: `Row ${id}`,
        }));
      };
      // Call sites derive the excluded ids afresh on every render, so each pick hands the
      // select a new array with the same contents.
      const onChange = (value) => {
        state.value = value;
        state.exclude = [1000];
      };

      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 200px;
              overflow-y: auto;
            }
          </style>
          <DSelect
            @load={{load}}
            @loadContext={{hash exclude=state.exclude}}
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{state.value}}
          />
        </template>
      );
      await click("[role='combobox']");
      const initial = loads;
      const viewport = find(".d-virtual-list");
      viewport.scrollTop = 400;
      await settled();
      const top = viewport.scrollTop;
      assert.true(top > 0, "the list was scrolled");

      const visible = findAll("[role='option']").find((option) => {
        const box = option.getBoundingClientRect();
        const frame = viewport.getBoundingClientRect();
        return box.top >= frame.top && box.bottom <= frame.bottom;
      });
      await click(visible);

      assert.strictEqual(state.value.length, 1, "the pick was kept");
      assert.strictEqual(loads, initial, "the equal array did not reload");
      assert.strictEqual(
        find(".d-virtual-list").scrollTop,
        top,
        "the list keeps its scroll position"
      );
    });

    test("arrays in the context compare by their elements", async function (assert) {
      const nested = [1];
      const context = tracked({ ids: [1, 2], nested: [nested] });
      let loads = 0;
      const load = () => {
        loads++;
        return ITEMS;
      };

      await render(
        <template>
          <DSelect @load={{load}} @loadContext={{context.value}} />
        </template>
      );
      await click("[role='combobox']");
      const initial = loads;

      context.value = { ids: [1, 2], nested: [nested] };
      await settled();
      assert.strictEqual(loads, initial, "equal elements do not reload");

      context.value = { ids: [1, 3], nested: [nested] };
      await settled();
      assert.strictEqual(
        loads,
        initial + 1,
        "a changed element of the same length reloads"
      );

      context.value = { ids: [1, 3], nested: [[1]] };
      await settled();
      assert.strictEqual(
        loads,
        initial + 2,
        "elements compare by identity, one level deep"
      );
    });

    test("an array changed in place still reloads", async function (assert) {
      const ids = [1, 2];
      const context = tracked({ ids });
      let loads = 0;
      const load = () => {
        loads++;
        return ITEMS;
      };

      await render(
        <template>
          <DSelect @load={{load}} @loadContext={{context.value}} />
        </template>
      );
      await click("[role='combobox']");
      const initial = loads;
      press("Escape");
      await settled();

      ids[1] = 3;
      await click("[role='combobox']");
      assert.strictEqual(
        loads,
        initial + 1,
        "the next open notices an element changed under the same reference"
      );

      press("Escape");
      await settled();
      ids[1] = 4;
      context.value = { ids: [1, 4] };
      await settled();
      await click("[role='combobox']");
      assert.strictEqual(
        loads,
        initial + 2,
        "an in-place change still counts when an equal array replaces it"
      );
    });

    test("every page uses the first request's context snapshot", async function (assert) {
      const context = { categoryId: 1 };
      const requests = [];
      const load = (_filter, opts) => {
        requests.push(opts.context);
        return {
          items: Array.from({ length: 50 }, (_, i) => ({
            id: (opts.offset ?? 0) + i,
            name: `Row ${(opts.offset ?? 0) + i}`,
          })),
          total: 150,
        };
      };
      await render(
        <template>
          <EngineProbe @load={{load}} @loadContext={{context}} />
        </template>
      );
      await click("[role='combobox']");
      const snapshot = requests[0];
      context.categoryId = 2;
      probedEngine().revealMore();
      await settled();
      assert.true(requests.length > 1, "another page was requested");
      assert.true(
        requests.every(
          (request) => request === snapshot && request.categoryId === 1
        ),
        "all pages share the original snapshot, despite mutation of the caller's object"
      );

      press("Escape");
      await settled();
      await click("[role='combobox']");
      assert.strictEqual(
        requests.at(-1).categoryId,
        2,
        "the next open notices mutation"
      );
      assert.notStrictEqual(
        requests.at(-1),
        snapshot,
        "the new query owns a new snapshot"
      );
    });

    test("retained rows hold keyboard activation before the skeleton", async function (assert) {
      let resolve;
      let requested = false;
      let activeId;
      const pending = new Promise((r) => (resolve = r));
      const changes = [];
      const load = (filter) => {
        if (filter) {
          // Run before the shortened feedback timer replaces the retained rows in tests.
          press("ArrowDown");
          activeId = find("[role='combobox']").getAttribute(
            "aria-activedescendant"
          );
          press("Enter");
          requested = true;
          return pending;
        }
        return ITEMS;
      };
      const onChange = (value) => changes.push(value);
      await render(
        <template>
          <DSelect @debounce={{false}} @load={{load}} @onChange={{onChange}} />
        </template>
      );
      await click("[role='combobox']");
      const typing = fillIn("[role='combobox']", "ba");
      try {
        await waitUntil(() => requested);
        assert.true(
          Boolean(activeId),
          "the pending query's Enter targeted a retained active row"
        );
        assert.deepEqual(changes, [], "the retained active row cannot emit");
      } finally {
        resolve([{ id: 99, name: "Bacon" }]);
        await typing;
      }
      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");
      assert.deepEqual(
        changes,
        [99],
        "settled results are activated only by a fresh Enter"
      );
    });

    test("repeated skeleton Enter is delivered again in the mobile modal", async function (assert) {
      forceMobile();
      disableClearA11yAnnouncementsInTests();
      let resolve;
      const pending = new Promise((r) => (resolve = r));
      const load = () => pending;
      const a11y = this.owner.lookup("service:a11y");
      const reports = () =>
        a11y.announcementHistory.filter(
          (record) =>
            record.text.includes("Still loading") && !record.superseded
        );
      await render(
        <template><A11yLiveRegions /><DSelect @load={{load}} /></template>
      );
      const opening = click(".d-select__trigger");
      try {
        await waitUntil(() => find(".d-select__panel input"));
        press("Enter", ".d-select__panel input");
        await waitUntil(() => reports().length === 1);
        assert.dom("#a11y-announcements-polite").includesText("Still loading");
        press("Enter", ".d-select__panel input");
        await waitUntil(
          () =>
            reports().length === 2 &&
            a11y.politeMessage?.includes("Still loading")
        );
        assert.strictEqual(
          reports().length,
          2,
          "both presses reached the polite region"
        );
      } finally {
        resolve(ITEMS);
        await opening;
      }
    });

    test("Enter during reveal still activates an existing row", async function (assert) {
      let resolve;
      let requested = false;
      const pending = new Promise((r) => (resolve = r));
      const changes = [];
      const load = (_filter, { offset = 0 }) => {
        if (offset) {
          requested = true;
          return pending;
        }
        return {
          items: Array.from({ length: 50 }, (_, id) => ({
            id,
            name: `Row ${id}`,
          })),
          total: 100,
        };
      };
      const onChange = (value) => changes.push(value);
      await render(
        <template>
          <EngineProbe @load={{load}} @onChange={{onChange}} />
        </template>
      );
      await click("[role='combobox']");
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      const active = Number(find("[role='option'].--active").dataset.value);
      probedEngine().revealMore();
      try {
        await waitUntil(() => requested);
        press("Enter");
        assert.deepEqual(
          changes,
          [active],
          "a reveal does not hold the visible row"
        );
      } finally {
        resolve({ items: [], hasMore: false });
        await settled();
      }
    });

    test("a context reload announces even an unchanged result count", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      const context = tracked({ categoryId: 1 });
      const load = () => ITEMS;
      const a11y = this.owner.lookup("service:a11y");
      const counts = () =>
        a11y.announcementHistory.filter((r) => r.text === "3 results");
      await render(
        <template>
          <A11yLiveRegions /><DSelect
            @load={{load}}
            @loadContext={{context.value}}
            @variant="button"
          />
        </template>
      );
      await click(".d-select__trigger");
      assert.strictEqual(
        counts().length,
        1,
        "opening announces the initial count"
      );
      context.value = { categoryId: 2 };
      await settled();
      assert.strictEqual(
        counts().length,
        2,
        "a new context is news even with the same count"
      );
    });

    test("below minChars keeps the typing hint instead of announcing loading", async function (assert) {
      let resolve;
      let requested = false;
      const pending = new Promise((r) => (resolve = r));
      const load = () => {
        requested = true;
        return pending;
      };
      const a11y = this.owner.lookup("service:a11y");
      await render(
        <template>
          <A11yLiveRegions /><DSelect @load={{load}} @minChars={{2}} />
        </template>
      );
      await click("[role='combobox']");
      const typing = fillIn("[role='combobox']", "ab");
      let clearing;
      try {
        await waitUntil(() => requested);
        clearing = fillIn("[role='combobox']", "a");
        await waitUntil(() => find(".d-select__min-chars"));
        press("Enter");
        const delivery = a11y.announce("Typing hint check", "polite");
        await waitUntil(() =>
          a11y.announcementHistory.some((r) => r.delivered.includes(delivery))
        );
        assert.false(
          a11y.announcementHistory.some((r) =>
            r.text.includes("Still loading")
          ),
          "below the threshold stays silent about loading"
        );
      } finally {
        resolve(ITEMS);
        await typing;
        await clearing;
      }
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (loadingLabel)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("loadingLabel captions the loading skeleton with a spinner", async function (assert) {
      let resolveLoad;
      const load = () => new Promise((resolve) => (resolveLoad = resolve));

      await render(
        <template>
          <DSelect
            @load={{load}}
            @loadingLabel="Generating suggestions"
            @skeletonCount={{3}}
          />
        </template>
      );
      const typing = fillIn("[role='combobox']", "x");
      await waitFor(".d-select__skeleton");

      assert
        .dom(".d-select__loading-status")
        .hasAttribute("role", "status")
        .hasText("Generating suggestions");
      assert
        .dom(".d-select__loading-status .d-select__pending-icon")
        .exists("the caption carries the loading spinner");
      assert.strictEqual(
        findAll(".d-select__skeleton").length,
        3,
        "the skeleton keeps its own rows below the caption"
      );

      resolveLoad([]);
      await typing;
      assert
        .dom(".d-select__loading-status")
        .doesNotExist("the caption leaves with the skeleton");
    });

    test("loadingLabel takes a skeleton row's place so the panel keeps its height", async function (assert) {
      const rows = [
        { id: 1, name: "One" },
        { id: 2, name: "Two" },
        { id: 3, name: "Three" },
        { id: 4, name: "Four" },
      ];
      let resolveLoad;
      const load = (filter) =>
        filter
          ? new Promise((resolve) => (resolveLoad = resolve))
          : Promise.resolve(rows);

      await render(
        <template>
          <DSelect @load={{load}} @loadingLabel="Generating suggestions" />
        </template>
      );
      await click("[role='combobox']");
      await waitFor("[role='option']");
      const before = find(".d-select__panel").offsetHeight;

      const typing = fillIn("[role='combobox']", "x");
      await waitFor(".d-select__skeleton");

      assert.strictEqual(
        findAll(".d-select__skeleton").length,
        3,
        "the caption stands in for one of the four rows"
      );
      const during = find(".d-select__panel").offsetHeight;
      assert.true(
        Math.abs(during - before) <= 1,
        `the panel keeps its height (${before}px before, ${during}px while loading)`
      );

      resolveLoad([]);
      await typing;
    });

    test("loadingLabel is absent unless asked for", async function (assert) {
      let resolveLoad;
      const load = () => new Promise((resolve) => (resolveLoad = resolve));

      await render(<template><DSelect @load={{load}} /></template>);
      const typing = fillIn("[role='combobox']", "x");
      await waitFor(".d-select__skeleton");

      assert.dom(".d-select__loading-status").doesNotExist();

      resolveLoad([]);
      await typing;
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (a page in flight)",
  function (hooks) {
    setupRenderingTest(hooks);

    class Args {
      @tracked kindContext = { step: 1 };
      @tracked placeholder = "First";
    }

    async function openWhilePending(assert, change) {
      const args = new Args();
      const releases = [];
      const load = () =>
        new Promise((resolve) =>
          releases.push(() => resolve([{ id: 1, name: "One" }]))
        );

      await render(
        <template>
          <DSelect
            @kind="probe"
            @kindContext={{@kindContext}}
            @load={{load}}
            @placeholder={{@placeholder}}
          />
        </template>
      );
      const opening = click("[role='combobox']");
      await waitUntil(() => releases.length > 0);
      change(args);
      await rerender();
      releases.forEach((release) => release());
      await opening;
      await waitFor("[role='option']");

      assert.strictEqual(releases.length, 1, "the page is asked for once");
      assert.dom("[role='option']").hasText("One");
    }

    test("a changed kind context keeps the page in flight", async function (assert) {
      await openWhilePending(assert, (args) => {
        args.kindContext = { step: 2 };
      });
    });

    test("a changed placeholder keeps the page in flight", async function (assert) {
      await openWhilePending(assert, (args) => {
        args.placeholder = "Second";
      });
    });

    test("a failed page offers retry after asking once", async function (assert) {
      const args = new Args();
      let calls = 0;
      const load = () => {
        calls++;
        return Promise.reject(new Error("boom"));
      };

      await render(
        <template>
          <DSelect @kind="probe" @kindContext={{@kindContext}} @load={{load}} />
        </template>
      );
      await click("[role='combobox']");
      await waitFor(".d-select__retry");
      args.kindContext = { step: 2 };
      await settled();

      assert.strictEqual(calls, 1, "the failed page is not asked for again");
      assert.dom(".d-select__retry").exists();
    });
  }
);
