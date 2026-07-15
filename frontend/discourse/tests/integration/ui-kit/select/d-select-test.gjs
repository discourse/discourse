import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import {
  click,
  fillIn,
  focus,
  render,
  triggerEvent,
  triggerKeyEvent,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { clearCallbacks } from "discourse/select-kit/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { resetLegacyBridge } from "discourse/ui-kit/select/-internals/modify-select-kit-bridge";
import DSelect from "discourse/ui-kit/select/d-select";

const ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry pie" },
];

// A controlled host: it owns @value and updates it from @onChange, exactly as a
// consumer (or FormKit) does.
class Host extends Component {
  @tracked value = this.args.value ?? null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant={{@variant}}
      @placeholder="Pick one"
      @identifier="test-select"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

module("Integration | ui-kit | select | DSelect (typeahead)", function (hooks) {
  setupRenderingTest(hooks);

  test("the trigger is a combobox input, present before opening", async function (assert) {
    await render(<template><Host /></template>);

    assert
      .dom("[role='combobox']")
      .exists("the trigger itself is the combobox input")
      .hasAttribute("aria-autocomplete", "list")
      .hasAttribute("aria-expanded", "false", "closed until opened")
      .hasAttribute(
        "aria-label",
        "Options",
        "the input has an accessible name"
      );
    assert.dom(".d-combobox__placeholder").hasText("Pick one");
    assert.dom("[role='listbox']").doesNotExist("closed on render");
  });

  test("does not open on focus; opens on ArrowDown, on click, and on typing", async function (assert) {
    await render(<template><Host /></template>);

    await focus("[role='combobox']");
    assert.dom("[role='listbox']").doesNotExist("bare focus never opens");

    await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
    assert.dom("[role='listbox']").exists("ArrowDown opens");
    assert.dom("[role='combobox']").hasAttribute("aria-expanded", "true");

    await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
    assert.dom("[role='listbox']").doesNotExist("Escape closes");

    await click("[role='combobox']");
    assert.dom("[role='listbox']").exists("click opens");
  });

  test("typing filters, and the query drives the list", async function (assert) {
    await render(<template><Host /></template>);

    await fillIn("[role='combobox']", "ban");
    assert.dom("[role='listbox']").exists("typing opens the list");
    assert.dom("[role='option']").exists({ count: 1 });
    assert.dom("[role='option']").hasText("Banana");

    // A term with a space must filter (the space isn't swallowed by keyboard nav).
    await fillIn("[role='combobox']", "cherry p");
    assert.dom("[role='option']").hasText("Cherry pie");
  });

  test("auto-highlights the first match and re-seeds as the query changes", async function (assert) {
    await render(<template><Host /></template>);

    await fillIn("[role='combobox']", "a");
    const active = document.querySelector("[role='option'].--active");
    assert.dom(active).hasText("Apple", "the first match is highlighted");
    assert
      .dom("[role='combobox']")
      .hasAttribute(
        "aria-activedescendant",
        active.id,
        "aria-activedescendant points at the highlighted option"
      );

    await fillIn("[role='combobox']", "cherry");
    assert
      .dom("[role='option'].--active")
      .hasText("Cherry pie", "the highlight re-seeds to the new first match");
  });

  test("Enter selects the highlighted option without an ArrowDown, and closes", async function (assert) {
    await render(<template><Host /></template>);
    await fillIn("[role='combobox']", "app");

    await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

    assert.dom("[role='listbox']").doesNotExist("selecting closes the menu");
    assert.dom(".d-combobox__presentation").hasText("Apple");
  });

  test("focus stays in the input while navigating with the arrows", async function (assert) {
    await render(<template><Host /></template>);
    await fillIn("[role='combobox']", "");
    await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");

    assert.strictEqual(
      document.activeElement.getAttribute("role"),
      "combobox",
      "the input keeps focus during navigation (active mode)"
    );
  });

  test("Escape resets the query so the next open starts clean", async function (assert) {
    await render(<template><Host /></template>);
    await fillIn("[role='combobox']", "ban");
    assert.dom("[role='option']").exists({ count: 1 });

    await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
    await click("[role='combobox']");

    assert.dom("[role='combobox']").hasValue("", "the query was reset");
    assert.dom("[role='option']").exists({ count: 3 }, "the full list is back");
  });

  test("moving focus to another field (Tab-out) closes it", async function (assert) {
    await render(
      <template>
        <Host />
        <button type="button" class="outside">outside</button>
      </template>
    );
    await click("[role='combobox']");
    assert.dom("[role='listbox']").exists();

    // Focus moving to a focusable element outside the widget closes it. (A bare blur with
    // no outside focus target does not; a truly-outside pointer click is handled below.)
    await focus(".outside");
    assert.dom("[role='listbox']").doesNotExist("Tab-out closes");
  });

  test("clicking a non-focusable element outside closes it", async function (assert) {
    await render(
      <template>
        <Host />
        <div class="outside">outside</div>
      </template>
    );
    await click("[role='combobox']");
    assert.dom("[role='listbox']").exists();

    // close-on-click-outside listens for a document `pointerdown` (not `click`), matching
    // float-kit's own dismiss tests; our `untriggers=[]` config must not break it.
    await triggerEvent(".outside", "pointerdown");
    assert.dom("[role='listbox']").doesNotExist("click-outside closes");
  });

  test("pointer: clicking an option selects it and closes", async function (assert) {
    await render(<template><Host /></template>);
    await click("[role='combobox']");
    await click("[role='option'][aria-selected='false']");

    assert.dom("[role='listbox']").doesNotExist("selecting closes the menu");
    assert
      .dom(".d-combobox__presentation")
      .exists("the trigger shows the selection");
  });

  test("clicking anywhere on the trigger (caret/label) opens and focuses the input", async function (assert) {
    await render(<template><Host @value={{1}} /></template>);
    assert.dom(".d-combobox__presentation").hasText("Apple");

    // The whole trigger is the open target, not just the narrow input strip.
    await click(".d-combobox__caret");
    assert.dom("[role='listbox']").exists("clicking the caret opens the menu");
    assert.strictEqual(
      document.activeElement.getAttribute("role"),
      "combobox",
      "focus lands in the query input"
    );
  });

  test("clicking the trigger while open does not toggle it closed", async function (assert) {
    await render(<template><Host @value={{1}} /></template>);
    await click("[role='combobox']");
    assert.dom("[role='listbox']").exists();

    // Clicking a non-focusable trigger region (the caret) while open must not blur-close
    // or toggle it shut.
    await click(".d-combobox__caret");
    assert
      .dom("[role='listbox']")
      .exists("stays open after clicking the caret");
  });

  test("a preset value resolves to its label with no fetch (client source)", async function (assert) {
    await render(<template><Host @value={{2}} /></template>);
    assert
      .dom(".d-combobox__presentation")
      .hasText("Banana", "the saved id resolves from the client list");
  });

  test("marks the selected option with aria-selected", async function (assert) {
    await render(<template><Host @value={{1}} /></template>);
    await click("[role='combobox']");
    assert
      .dom("[role='option'][aria-selected='true']")
      .hasText("Apple", "the current value's option is aria-selected");
  });

  test("shows an empty status and never a role=alert for no matches", async function (assert) {
    await render(<template><Host /></template>);
    await fillIn("[role='combobox']", "zzzz");

    assert
      .dom(".d-combobox__empty[role='status']")
      .exists("polite empty status");
    assert
      .dom("[role='alert']")
      .doesNotExist("counts/empties are announced politely, never assertively");
  });

  test("mid-composition input does not open or filter (IME)", async function (assert) {
    await render(<template><Host /></template>);
    const input = document.querySelector("[role='combobox']");

    input.value = "ban";
    input.dispatchEvent(new InputEvent("input", { isComposing: true }));
    assert
      .dom("[role='listbox']")
      .doesNotExist("a half-composed query neither opens nor filters");

    input.dispatchEvent(new CompositionEvent("compositionend"));
    await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
    assert
      .dom("[role='option']")
      .exists({ count: 1 }, "committing the composition filters");
    assert.dom("[role='option']").hasText("Banana");
  });
});

module(
  "Integration | ui-kit | select | DSelect (typeahead, mobile)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      forceMobile();
    });

    test("tapping the trigger opens a modal that hosts the focused query input", async function (assert) {
      await render(<template><Host /></template>);

      // On mobile the trigger holds no input of its own; tapping the trigger opens the modal.
      assert
        .dom(".d-combobox__trigger [role='combobox']")
        .doesNotExist("no query input in the closed mobile trigger");

      await click(".d-combobox__trigger");

      assert
        .dom(".fk-d-menu-modal [role='combobox']")
        .exists("the query input renders inside the modal");
      assert.strictEqual(
        document.activeElement.getAttribute("role"),
        "combobox",
        "the modal input is focused on open"
      );

      await fillIn(".fk-d-menu-modal [role='combobox']", "ban");
      assert.dom("[role='option']").exists({ count: 1 });
      assert.dom("[role='option']").hasText("Banana");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (button variant)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("opens into a WAI-ARIA combobox + listbox with wired ids", async function (assert) {
      await render(<template><Host @variant="button" /></template>);
      await click(".d-combobox__trigger");

      assert.dom("[role='combobox']").exists("the panel filter is a combobox");
      assert
        .dom("[role='combobox']")
        .hasAttribute("aria-autocomplete", "list")
        .hasAttribute("aria-expanded", "true");
      assert.dom("[role='listbox']").exists("results are a listbox");
      assert.dom("[role='option']").exists({ count: 3 }, "one option per item");

      const listboxId = document
        .querySelector("[role='listbox']")
        .getAttribute("id");
      assert
        .dom("[role='combobox']")
        .hasAttribute(
          "aria-controls",
          listboxId,
          "aria-controls points at the listbox"
        );
    });

    test("filters as you type, and spaces reach the filter", async function (assert) {
      await render(<template><Host @variant="button" /></template>);
      await click(".d-combobox__trigger");

      await fillIn("[role='combobox']", "ban");
      assert.dom("[role='option']").exists({ count: 1 });
      assert.dom("[role='option']").hasText("Banana");

      await fillIn("[role='combobox']", "cherry p");
      assert.dom("[role='option']").hasText("Cherry pie");
    });

    test("keyboard: ArrowDown + Enter selects the highlighted option and closes", async function (assert) {
      await render(<template><Host @variant="button" /></template>);
      await click(".d-combobox__trigger");
      await fillIn("[role='combobox']", "app");

      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

      assert.dom("[role='listbox']").doesNotExist("selecting closes the menu");
      assert
        .dom(".d-combobox__value")
        .hasText("Apple", "the trigger shows the pick");
    });

    test("pointer: clicking an option selects it and closes", async function (assert) {
      await render(<template><Host @variant="button" /></template>);
      await click(".d-combobox__trigger");
      await click("[role='option'][aria-selected='false']");

      assert.dom("[role='listbox']").doesNotExist("selecting closes the menu");
      assert
        .dom(".d-combobox__value")
        .exists("the trigger shows the selection");
    });
  }
);

module("Integration | ui-kit | select | DSelect (static)", function (hooks) {
  setupRenderingTest(hooks);

  test("no filter, focus-mode list, pick selects and closes", async function (assert) {
    await render(<template><Host @variant="static" /></template>);
    await click(".d-combobox__trigger");

    assert
      .dom("[role='combobox']")
      .doesNotExist("no filter input in static mode");
    assert.dom("[role='listbox']").exists();
    assert.dom("[role='option']").exists({ count: 3 });

    await click("[role='option']");
    assert.dom("[role='listbox']").doesNotExist("selecting closes (single)");
    assert.dom(".d-combobox__value").hasText("Apple");
  });
});

class MultiHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @multiple={{true}}
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder="Pick some"
      @identifier="test-multi"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

module("Integration | ui-kit | select | DSelect (multi)", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the placeholder when empty", async function (assert) {
    await render(<template><MultiHost /></template>);
    assert.dom(".d-combobox__placeholder").hasText("Pick some");
    assert.dom(".d-combobox__chip").doesNotExist();
  });

  test("selecting adds a chip, keeps the menu open, and hides the picked item", async function (assert) {
    await render(<template><MultiHost /></template>);
    await click(".d-combobox__expand");
    assert.dom("[role='option']").exists({ count: 3 });

    await click("[role='option']");
    assert.dom("[role='listbox']").exists("multi stays open after a pick");
    assert.dom(".d-combobox__chip").exists({ count: 1 }, "a chip is added");
    assert
      .dom("[role='option']")
      .exists({ count: 2 }, "the picked item leaves the list");

    await click("[role='option']");
    assert.dom(".d-combobox__chip").exists({ count: 2 });
  });

  test("removing a chip deselects it", async function (assert) {
    await render(<template><MultiHost @value={{array 1 2}} /></template>);
    assert.dom(".d-combobox__chip").exists({ count: 2 });

    await click(".d-combobox__chip");
    assert.dom(".d-combobox__chip").exists({ count: 1 }, "one chip removed");
  });
});

module("Integration | ui-kit | select | DSelect (async)", function (hooks) {
  setupRenderingTest(hooks);

  test("an error can be retried without changing the query", async function (assert) {
    let requestCount = 0;
    let retryFilter;
    let resolveRetry;
    const load = (filter) => {
      requestCount++;

      if (requestCount === 1) {
        return Promise.reject(new Error("The first request failed"));
      }

      retryFilter = filter;
      return new Promise((resolve) => {
        resolveRetry = resolve;
      });
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
      .dom(".d-combobox__error [role='alert']")
      .exists("the first request displays the async error");
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
  "Integration | ui-kit | select | DSelect (modifySelectKit bridge)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      clearCallbacks();
      resetLegacyBridge();
    });

    test("legacy prependContent rows render in the listbox", async function (assert) {
      withPluginApi((api) => {
        api
          .modifySelectKit("test-select")
          .prependContent(() => ({ id: 99, name: "Injected" }));
      });

      await render(<template><Host /></template>);
      await click("[role='combobox']");

      assert
        .dom("[role='option']")
        .exists({ count: 4 }, "the injected row joins the three client items");
      assert
        .dom("[role='listbox']")
        .includesText("Injected", "the legacy row is rendered");
    });

    test("a legacy action row runs its onSelect with the selectKit facade, without selecting", async function (assert) {
      let receivedValue = "unset";
      withPluginApi((api) => {
        api.modifySelectKit("test-select").prependContent(() => ({
          id: "act",
          name: "Act now",
          onSelect: (selectKit) => (receivedValue = selectKit.value),
        }));
      });

      await render(<template><Host /></template>);
      await click("[role='combobox']");
      // The action row is prepended, so it is the first option.
      await click("[role='option']");

      assert.strictEqual(
        receivedValue,
        null,
        "onSelect received the selectKit facade (reading its value works)"
      );
      assert
        .dom(".d-combobox__placeholder")
        .exists("the action row did not become the selection");
      assert
        .dom("[role='listbox']")
        .exists("an action row keeps the menu open");
    });
  }
);
