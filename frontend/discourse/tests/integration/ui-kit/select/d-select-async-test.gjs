import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import {
  click,
  fillIn,
  find,
  render,
  resetOnerror,
  setupOnerror,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { ITEMS } from "discourse/tests/helpers/d-select-hosts";
import DSelect from "discourse/ui-kit/select/d-select";

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
          @value={{123}}
          @resolveValue={{resolveValue}}
        />
        <DSelect
          class="sync-resolve-values"
          @items={{array}}
          @value={{456}}
          @resolveValues={{resolveValues}}
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
            @value={{this.value}}
            @resolveValue={{this.resolveValue}}
            @minChars={{3}}
          />
        {{/if}}
        <button type="button" class="toggle" {{on "click" this.toggle}}>
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
          @value={{this.value}}
          @resolveValue={{resolveValue}}
        />
        <button
          type="button"
          class="bump"
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
        <DSelect @items={{array}} @value={{7}} @resolveValue={{resolveValue}} />
      </template>
    );

    assert
      .dom("[role='combobox']")
      .hasValue(
        "7 (unavailable)",
        "the held value is shown as unavailable rather than blanking"
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
          @value={{2}}
          @resolveValue={{resolveValue}}
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
          @value={{array 1 2}}
          @resolveValues={{resolveValues}}
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
        "2 Unavailable",
        "the unavailable chip shows the failed id, keeping ids distinct, and carries the state in text for screen readers"
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
          @value={{array 1 2}}
          @valueItems={{valueItems}}
          @resolveValues={{resolveValues}}
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
          @items={{array}}
          @value={{123}}
          @resolveValue={{resolveValue}}
          @createUnresolvedItem={{createUnresolvedItem}}
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
          @items={{array}}
          @value={{123}}
          @resolveValue={{resolveValue}}
          @createUnresolvedItem={{createUnresolvedItem}}
        />
      </template>
    );

    assert
      .dom("[role='combobox']")
      .hasValue(
        "123 (unavailable)",
        "the default fallback keeps the unavailable suffix when the builder throws"
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
        <DSelect @items={{array}} @value={{2}} @resolveValue={{resolveValue}} />
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
                type="button"
                class="custom-retry"
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
