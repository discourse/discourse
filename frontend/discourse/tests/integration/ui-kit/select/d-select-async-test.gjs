import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  resetOnerror,
  setupOnerror,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { forceMobile } from "discourse/lib/mobile";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { ITEMS } from "discourse/tests/helpers/d-select-hosts";
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
      .dom(".d-combobox__trigger [role='alert']")
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

  test("a :loadingItem block replaces each placeholder row of the first load", async function (assert) {
    let resolveLoad;
    const load = () => new Promise((resolve) => (resolveLoad = resolve));

    await render(
      <template>
        <DSelect @load={{load}}>
          <:loadingItem><span class="custom-loading-row"></span></:loadingItem>
        </DSelect>
      </template>
    );
    const typing = fillIn("[role='combobox']", "x");
    await waitFor(".d-combobox__skeleton");

    const rows = findAll(".d-combobox__skeleton");
    assert.true(rows.length > 0, "the first load shows placeholder rows");
    assert.strictEqual(
      findAll(".d-combobox__skeleton .custom-loading-row").length,
      rows.length,
      "every placeholder row renders the block"
    );
    assert
      .dom(".d-combobox__skeleton .d-skeleton")
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

    assert
      .dom(".d-combobox__chip")
      .exists({ count: 2 }, "one chip per held id");
    assert
      .dom(".d-combobox__unresolved")
      .exists(
        { count: 1 },
        "the id that cannot resolve renders as unavailable"
      );
    assert
      .dom(".d-combobox__unresolved")
      .hasText(
        "Unknown item (2)",
        "the chip says what it is in visible text, keeping ids distinct"
      );
    assert
      .dom(".d-combobox__unresolved .d-icon")
      .doesNotExist("no icon stands in for the text");
    assert
      .dom(".d-combobox__unresolved")
      .doesNotHaveAttribute("title", "no tooltip repeats it");
    assert
      .dom(".d-combobox__unresolved .sr-only")
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
      .dom(".d-combobox__unresolved")
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
    await click(".d-combobox__chip-remove");

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
      .dom(".d-combobox__trigger .d-combobox__unresolved")
      .hasText("Unknown item (7)", "the visible text");
    assert.true(
      find(".d-combobox__trigger")
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
      .dom(".d-combobox__chip")
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
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </template>
    );
    await fillIn("[role='combobox']", "ban");

    assert
      .dom(".d-combobox__error .d-icon-triangle-exclamation")
      .exists("the first request displays the muted async error state");
    assert
      .dom(".d-combobox__retry")
      .hasText("Retry", "the error offers a recovery action");

    const retryClick = click(".d-combobox__retry");
    await waitFor(".d-combobox__skeleton");
    assert
      .dom(".d-combobox__skeleton")
      .exists("retry transitions back through the loading state");
    resolveRetry(ITEMS.filter((item) => item.name === "Banana"));
    await retryClick;

    assert.dom(".d-combobox__error").doesNotExist("the error is cleared");
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

      assert.dom(".d-combobox__error").exists();
      assert
        .dom(".d-combobox__error .d-icon-triangle-exclamation")
        .exists("the error shows a muted icon");
      assert
        .dom(".d-combobox__error [role='alert']")
        .doesNotExist("the heavy alert box is gone");
      assert
        .dom(".d-combobox__retry.btn-flat")
        .exists("the retry is a low-emphasis button");
    });

    test("@retryable={{false}} hides the retry button", async function (assert) {
      const load = () => Promise.reject(new Error("boom"));
      await render(
        <template><DSelect @load={{load}} @retryable={{false}} /></template>
      );
      await fillIn("[role='combobox']", "x");

      assert.dom(".d-combobox__error").exists("the error still renders");
      assert
        .dom(".d-combobox__retry")
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
            <:item as |item|>{{item.name}}</:item>
          </DSelect>
        </template>
      );
      await fillIn("[role='combobox']", "x");

      assert
        .dom(".custom-error")
        .hasText("boom", "the :error block renders with the error");
      assert
        .dom(".d-combobox__error .d-icon-triangle-exclamation")
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
        .dom(".d-combobox__error[role='alert']")
        .exists("the component keeps the alert container around the block");
      assert
        .dom(".d-combobox__error .custom-error")
        .hasText("Could not load", "the block supplies the contents");
      assert
        .dom(".d-combobox__error .d-combobox__error-message")
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
            <:selection as |item|>{{item.name}}</:selection>
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
            .dom(".d-combobox__trigger .d-skeleton")
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
            <:selection as |item|><span
                class="custom-selection"
              >{{item.name}}</span></:selection>
          </DSelect>
        </template>,
        Custom: <template>
          <DSelect
            @items={{array}}
            @multiple={{true}}
            @resolveValues={{resolveNone}}
            @value={{array 2}}
          >
            <:selection as |item|><span
                class="custom-selection"
              >{{item.name}}</span></:selection>
            <:unresolved as |item|><span class="custom-unresolved">Missing
                {{item.id}}</span></:unresolved>
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
            <:selection as |item|><span
                class="custom-selection"
              >{{item.name}}</span></:selection>
          </DSelect>
        </template>,
        Custom: <template>
          <DSelect
            @items={{array}}
            @resolveValues={{resolveNone}}
            @value={{2}}
            @variant="button"
          >
            <:selection as |item|><span
                class="custom-selection"
              >{{item.name}}</span></:selection>
            <:unresolved as |item|><span class="custom-unresolved">Missing
                {{item.id}}</span></:unresolved>
          </DSelect>
        </template>,
      },
      {
        name: "the desktop typeahead",
        Plain: <template>
          <DSelect @items={{array}} @resolveValues={{resolveNone}} @value={{2}}>
            <:selection as |item|><span
                class="custom-selection"
              >{{item.name}}</span></:selection>
          </DSelect>
        </template>,
        Custom: <template>
          <DSelect @items={{array}} @resolveValues={{resolveNone}} @value={{2}}>
            <:selection as |item|><span
                class="custom-selection"
              >{{item.name}}</span></:selection>
            <:unresolved as |item|><span class="custom-unresolved">Missing
                {{item.id}}</span></:unresolved>
          </DSelect>
        </template>,
      },
      {
        name: "the mobile typeahead",
        mobile: true,
        Plain: <template>
          <DSelect @items={{array}} @resolveValues={{resolveNone}} @value={{2}}>
            <:selection as |item|><span
                class="custom-selection"
              >{{item.name}}</span></:selection>
          </DSelect>
        </template>,
        Custom: <template>
          <DSelect @items={{array}} @resolveValues={{resolveNone}} @value={{2}}>
            <:selection as |item|><span
                class="custom-selection"
              >{{item.name}}</span></:selection>
            <:unresolved as |item|><span class="custom-unresolved">Missing
                {{item.id}}</span></:unresolved>
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
          .dom(".d-combobox__unresolved")
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
