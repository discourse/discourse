import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  find,
  render,
  settled,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { applyContentPluginApiCallbacks } from "discourse/select-kit/lib/plugin-api";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  EngineProbe,
  Host,
  ITEMS,
  MultiLimitsHost,
  optionWithText,
  probedEngine,
} from "discourse/tests/helpers/d-select-hosts";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

module(
  "Integration | ui-kit | select | DSelect (modifySelectKit bridge)",
  function (hooks) {
    setupRenderingTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

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
      let receivedSetter;
      withPluginApi((api) => {
        api.modifySelectKit("test-select").prependContent(() => ({
          id: "act",
          name: "Act now",
          onSelect: (selectKit) => {
            receivedValue = selectKit.value;
            receivedSetter = selectKit.set;
          },
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
      assert.strictEqual(
        typeof receivedSetter,
        "function",
        "it is the facade, which only the legacy surface has a setter on"
      );
      assert
        .dom("[role='combobox']")
        .hasValue("", "the action row did not become the selection");
      assert
        .dom("[role='listbox']")
        .exists("an action row keeps the menu open");
    });

    // Legacy callbacks walk up from `selectKit.element` (for example to find the composer it
    // sits in), so it must be the trigger, which stays where the select was rendered. The
    // panel is moved elsewhere in the page, and on mobile it is a modal.
    for (const mobile of [false, true]) {
      test(`legacy callbacks receive the trigger as the element${mobile ? " on mobile" : ""}`, async function (assert) {
        if (mobile) {
          forceMobile();
        }

        let element;
        withPluginApi((api) => {
          api.modifySelectKit("test-select").appendContent((selectKit) => {
            element = selectKit.element;
          });
        });

        await render(<template><Host /></template>);
        await click(".d-select__trigger");

        assert.dom("[role='listbox']").exists("the menu is open");
        assert.strictEqual(
          element,
          find(".d-select__trigger"),
          "the element is the trigger, not the panel"
        );
      });
    }

    test("reactive arg changes never recreate the engine behind the bridge", async function (assert) {
      const seen = new Set();
      withPluginApi((api) => {
        api.modifySelectKit("test-select").appendContent((component) => {
          seen.add(component);
          return { id: "legacy-row", name: "Legacy row" };
        });
      });

      class FlipState {
        @tracked maximum;
        @tracked multiple = false;
        @tracked value = null;
      }
      const state = new FlipState();

      await render(
        <template>
          <DSelect
            @identifier="test-select"
            @items={{ITEMS}}
            @kind="test-select"
            @maximum={{state.maximum}}
            @multiple={{state.multiple}}
            @value={{state.value}}
            @variant="button"
          />
        </template>
      );
      await click(".d-select__trigger");

      assert
        .dom("[role='listbox']")
        .includesText("Legacy row", "the bridge is active before the flip");

      state.multiple = true;
      state.value = [1];
      state.maximum = 5;
      await settled();

      assert
        .dom("[role='listbox']")
        .hasAria("multiselectable", "true", "the multiple flip took effect");
      assert.strictEqual(
        seen.size,
        1,
        "one facade for the life of the component — the engine was never recreated"
      );
    });
  }
);

class ContextState {
  @tracked instance = { label: "First" };
  @tracked label = "Tracked";
  @tracked show = true;
}

module(
  "Integration | ui-kit | select | DSelect extension contexts",
  function (hooks) {
    setupRenderingTest(hooks);

    test("content receives the names, the context data and the control", async function (assert) {
      let seen;
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items, context) => {
                seen = context;
                return items;
              })
            )
        );
      });
      const kind = { scope: "recipe" };
      const instance = { topicId: 7 };

      await render(
        <template>
          <DSelect
            @identifier="context-select"
            @instanceContext={{instance}}
            @items={{ITEMS}}
            @kind="context-kind"
            @kindContext={{kind}}
            @value={{2}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert.strictEqual(seen.kind, "context-kind", "the kind is its name");
      assert.strictEqual(
        seen.identifier,
        "context-select",
        "the identifier is the call site's name"
      );
      assert.strictEqual(
        seen.kindContext,
        kind,
        "the recipe context is passed as is"
      );
      assert.strictEqual(
        seen.instanceContext,
        instance,
        "the call-site context is passed as is"
      );
      assert.false("instance" in seen, "the old data key is gone");
      assert.strictEqual(seen.control.value, 2, "the control reads the value");
      assert.strictEqual(
        seen.control.filter,
        "",
        "the control reads the filter"
      );
    });

    test("names default to undefined and context data to frozen empty objects", async function (assert) {
      let seen;
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items, context) => {
                seen = context;
                return items;
              })
            )
        );
      });

      await render(<template><DSelect @items={{ITEMS}} /></template>);
      await click("[role='combobox']");

      assert.true("kind" in seen, "the kind key is present");
      assert.strictEqual(seen.kind, undefined, "without a kind");
      assert.true("identifier" in seen, "the identifier key is present");
      assert.strictEqual(seen.identifier, undefined, "without an identifier");
      assert.deepEqual(
        seen.kindContext,
        {},
        "kindContext is empty without a recipe context"
      );
      assert.true(Object.isFrozen(seen.kindContext), "and frozen");
      assert.deepEqual(
        seen.instanceContext,
        {},
        "instanceContext is empty without a call-site context"
      );
      assert.true(Object.isFrozen(seen.instanceContext), "and frozen");
    });

    test("a new @instanceContext re-runs content customizations", async function (assert) {
      const state = new ContextState();
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items, context) => [
                ...items,
                {
                  id: "from-instance",
                  name: `Row ${context.instanceContext.label}`,
                },
              ])
            )
        );
      });

      await render(
        <template>
          <DSelect @instanceContext={{state.instance}} @items={{ITEMS}} />
        </template>
      );
      await click("[role='combobox']");
      assert.dom("[role='listbox']").includesText("Row First");

      state.instance = { label: "Second" };
      await settled();

      assert
        .dom("[role='listbox']")
        .includesText("Row Second", "the row follows the call-site context");
    });

    test("a content customization that reads tracked state re-runs when it changes", async function (assert) {
      const state = new ContextState();
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items) => [
                ...items,
                { id: "tracked", name: `Row ${state.label}` },
              ])
            )
        );
      });

      await render(<template><DSelect @items={{ITEMS}} /></template>);
      await click("[role='combobox']");
      assert.dom("[role='listbox']").includesText("Row Tracked");

      state.label = "Changed";
      await settled();

      assert
        .dom("[role='listbox']")
        .includesText("Row Changed", "the list follows the state it read");
    });

    test("change receives the names and the context data", async function (assert) {
      let seen;
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.change((next, context) => {
                seen = context;
                next();
              })
            )
        );
      });
      const kind = { scope: "recipe" };
      const instance = { topicId: 7 };
      const onChange = () => {};

      await render(
        <template>
          <DSelect
            @identifier="change-select"
            @instanceContext={{instance}}
            @items={{ITEMS}}
            @kind="change-kind"
            @kindContext={{kind}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Banana"));

      assert.strictEqual(seen.kind, "change-kind", "the kind is passed");
      assert.strictEqual(
        seen.identifier,
        "change-select",
        "the identifier is passed"
      );
      assert.strictEqual(
        seen.kindContext,
        kind,
        "the recipe context is passed"
      );
      assert.strictEqual(
        seen.instanceContext,
        instance,
        "the call-site context is passed"
      );
      assert.strictEqual(seen.value, 2, "the next value is passed");
      assert.strictEqual(
        typeof seen.control?.reload,
        "function",
        "the change context carries the control"
      );
    });

    test("the control is one frozen object for the life of the select", async function (assert) {
      const controls = [];
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items, context) => {
                controls.push(context.control);
                return items;
              })
            )
        );
      });

      await render(
        <template><DSelect @items={{ITEMS}} @variant="button" /></template>
      );
      await click(".d-select__trigger");
      await fillIn(".d-select__filter", "an");

      assert.true(controls.length > 1, "the list was built more than once");
      assert.strictEqual(
        controls[0],
        controls.at(-1),
        "every build sees the same control, so it can key per-select state"
      );
      assert.true(Object.isFrozen(controls[0]), "the control is frozen");
    });

    test("an action row receives the control, not the engine", async function (assert) {
      const onChange = sinon.spy();
      let received;
      const items = [
        ...ITEMS,
        {
          id: "pick",
          name: "Pick banana",
          onSelect: (control) => {
            received = control;
            control.select(ITEMS[1]);
          },
        },
        {
          id: "dismiss",
          name: "Dismiss",
          onSelect: (control) => control.close(),
        },
      ];

      await render(
        <template><DSelect @items={{items}} @onChange={{onChange}} /></template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Pick banana"));

      assert.true(onChange.calledOnce, "the row selected through the control");
      assert.strictEqual(
        onChange.firstCall.args[0],
        2,
        "with the item it chose"
      );
      assert.strictEqual(
        typeof received.revealMore,
        "undefined",
        "engine internals are not exposed to rows"
      );

      await click("[role='combobox']");
      await click(optionWithText("Dismiss"));

      assert
        .dom("[role='listbox']")
        .doesNotExist("the control closed the menu");
    });

    test("the control does nothing once the select is destroyed", async function (assert) {
      const state = new ContextState();
      const onChange = sinon.spy();
      let stored;
      const items = [
        ...ITEMS,
        {
          id: "keep",
          name: "Keep control",
          onSelect: (control) => (stored = control),
        },
      ];

      await render(
        <template>
          {{#if state.show}}
            <DSelect @items={{items}} @onChange={{onChange}} />
          {{/if}}
        </template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Keep control"));

      state.show = false;
      await settled();
      stored.select(ITEMS[0]);
      stored.close();

      assert.true(onChange.notCalled, "a late select reaches no parent");
    });
  }
);

/** A promise with its resolve and reject exposed, so a test controls when work settles. */
function deferred() {
  let resolve, reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

/** An action row that (optionally) closes the select and starts an update running `work`. */
function updateRow(name, work, { close = true } = {}) {
  return {
    id: `row-${name}`,
    name,
    onSelect: (control) => {
      if (close) {
        control.close();
      }
      control.update(work).catch(() => {});
    },
  };
}

/**
 * Waits for the pending state, runs `whilePending`, then releases the work and the click. The
 * release runs even when an assertion throws, so a failure stays in its own test instead of
 * holding settledness until the suite times out.
 */
/**
 * The option with `text`, or a synchronous throw. An unawaited `click(undefined)` rejects outside
 * the test and aborts the whole run, so a click that is not awaited at once goes through here.
 */
function requireOption(text) {
  const option = optionWithText(text);
  if (!option) {
    throw new Error(`No option reads "${text}"`);
  }
  return option;
}

async function duringUpdate(gate, clicking, whilePending) {
  try {
    await waitFor(".d-select__pending-icon", { timeout: 2000 });
    await whilePending?.();
  } finally {
    gate.resolve();
    await clicking;
  }
}

function politeText() {
  return find("#a11y-announcements-polite")?.textContent ?? "";
}

class AsyncUpdateHost extends Component {
  @tracked value = this.args.value ?? (this.args.multiple ? [] : null);

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <A11yLiveRegions />
    <DSelect
      @icon={{@icon}}
      @iconOnly={{@iconOnly}}
      @items={{@items}}
      @label={{@label}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @placeholder="Pick one"
      @showCaret={{@showCaret}}
      @value={{this.value}}
      @variant={{@variant}}
    />
  </template>
}

class AsyncUpdateSelectionHost extends Component {
  @tracked value = this.args.value ?? null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @items={{@items}}
      @onChange={{this.onChange}}
      @placeholder="Pick one"
      @value={{this.value}}
    >
      <:selection as |item|>
        {{~item.name~}}
      </:selection>
    </DSelect>
  </template>
}

class AsyncUpdateVisibility {
  @tracked show = true;
}

module(
  "Integration | ui-kit | select | DSelect async update",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      disableClearA11yAnnouncementsInTests();
    });

    /** Items plus a row whose update waits on `gate`, then selects `pick`. */
    function suggestItems(gate, pick) {
      return [
        ...ITEMS,
        updateRow("Suggest", async (scope) => {
          await gate.promise;
          scope.select(pick);
        }),
      ];
    }

    test("a pending update shows the skeleton and a spinner in place of the caret, then the result", async function (assert) {
      const gate = deferred();
      const items = suggestItems(gate, ITEMS[1]);

      await render(
        <template><AsyncUpdateHost @items={{items}} @value={{1}} /></template>
      );
      await click("[role='combobox']");
      await duringUpdate(gate, click(optionWithText("Suggest")), () => {
        assert.true(
          find(".d-select__trigger").lastElementChild.classList.contains(
            "d-select__pending-icon"
          ),
          "the spinner takes the caret's place as the trigger's last child"
        );
        assert.dom(".d-select__caret").doesNotExist("the caret is replaced");
        assert
          .dom(".d-select__trigger .d-skeleton")
          .exists("the value slot shows the loading skeleton");
        assert
          .dom(".d-select__trigger")
          .hasAttribute("aria-busy", "true", "the trigger region is busy");
        assert
          .dom("input[role='combobox']")
          .hasAttribute("aria-busy", "true", "the focused combobox is busy");
        assert
          .dom("input[role='combobox']")
          .hasValue("", "the input shows no stale label while pending");
      });

      assert
        .dom("input[role='combobox']")
        .hasValue("Banana", "the new value shows once the update ends");
      assert.dom(".d-select__caret").exists("the caret is back");
      assert.dom(".d-select__pending-icon").doesNotExist("the spinner is gone");
      assert
        .dom(".d-select__trigger")
        .doesNotHaveAttribute("aria-busy", "the trigger is no longer busy");
      assert
        .dom("input[role='combobox']")
        .doesNotHaveAttribute("aria-busy", "the combobox is no longer busy");
    });

    test("an async update shows the skeleton in a :selection typeahead that keeps focus", async function (assert) {
      const gate = deferred();
      const items = suggestItems(gate, ITEMS[1]);

      await render(
        <template>
          <AsyncUpdateSelectionHost @items={{items}} @value={{1}} />
        </template>
      );
      await click("[role='combobox']");
      await duringUpdate(gate, click(optionWithText("Suggest")), () => {
        assert
          .dom("input[role='combobox']")
          .isFocused(
            "focus stays in the input after the row closes the select"
          );
        assert
          .dom(".d-select__presentation .d-skeleton")
          .exists("the skeleton renders even though the input has focus");
      });

      const input = find("input[role='combobox']");
      assert.strictEqual(
        input.value,
        "Banana",
        "the new label lands in the input"
      );
      assert.strictEqual(
        input.selectionStart,
        0,
        "the label is selected from its start"
      );
      assert.strictEqual(
        input.selectionEnd,
        input.value.length,
        "to its end, ready to overtype"
      );
    });

    test("an async update keeps a button trigger's accessible name on the held value", async function (assert) {
      const gate = deferred();
      const items = suggestItems(gate, ITEMS[1]);

      await render(
        <template>
          <AsyncUpdateHost @items={{items}} @value={{1}} @variant="button" />
        </template>
      );
      await click(".d-select__trigger");
      await duringUpdate(gate, click(optionWithText("Suggest")), () => {
        assert
          .dom(".d-select__trigger")
          .hasAttribute("aria-busy", "true", "the trigger is busy");
        assert.true(
          find(".d-select__trigger")
            .getAttribute("aria-label")
            .includes("Apple"),
          "the accessible name still carries the held value"
        );
        assert
          .dom(".d-select__trigger .d-skeleton")
          .exists("the value slot shows the skeleton");
      });

      assert
        .dom(".d-select__trigger")
        .includesText("Banana", "the new value shows once the update ends");
    });

    test("an async update spins an icon-only trigger even without a caret", async function (assert) {
      const gate = deferred();
      const items = suggestItems(gate, ITEMS[1]);

      await render(
        <template>
          <AsyncUpdateHost
            @icon="gear"
            @iconOnly={{true}}
            @items={{items}}
            @label="Fruit"
            @showCaret={{false}}
            @value={{1}}
            @variant="button"
          />
        </template>
      );
      assert.dom(".d-select__caret").doesNotExist("no caret to begin with");

      await click(".d-select__trigger");
      await duringUpdate(gate, click(optionWithText("Suggest")), () => {
        assert
          .dom(".d-select__pending-icon")
          .exists("the spinner shows although the caret is hidden");
      });

      assert.dom(".d-select__pending-icon").doesNotExist("the spinner is gone");
      assert.dom(".d-select__caret").doesNotExist("the caret stays hidden");
    });

    test("an async update turns a multi-select's chips into skeletons", async function (assert) {
      const gate = deferred();
      const value = [1, 2];
      const items = suggestItems(gate, ITEMS[2]);

      await render(
        <template>
          <AsyncUpdateHost
            @items={{items}}
            @multiple={{true}}
            @value={{value}}
          />
        </template>
      );
      await click("[role='combobox']");
      await duringUpdate(gate, click(optionWithText("Suggest")), () => {
        assert
          .dom(".d-select__chip .d-skeleton")
          .exists("the chips show the loading skeleton");
        assert
          .dom(".d-select__chip-list")
          .doesNotIncludeText(
            "Apple",
            "the held chips are replaced while pending"
          );
        assert
          .dom("input[role='combobox']")
          .hasAttribute("aria-busy", "true", "the combobox is busy");
      });

      assert
        .dom(".d-select__chip-list")
        .includesText(
          "Cherry pie",
          "the added chip shows once the update ends"
        );
      assert
        .dom(".d-select__chip-list")
        .includesText("Apple", "the held chips come back");
    });

    test("an async update on an empty select shows the loading state with no placeholder", async function (assert) {
      for (const multiple of [false, true]) {
        const gate = deferred();
        const items = suggestItems(gate, ITEMS[1]);
        const label = multiple ? "multi" : "single";

        await render(
          <template>
            <AsyncUpdateHost @items={{items}} @multiple={{multiple}} />
          </template>
        );
        await click("[role='combobox']");
        await duringUpdate(gate, click(optionWithText("Suggest")), () => {
          assert
            .dom(".d-select__trigger .d-skeleton")
            .exists(`the empty ${label} select shows the skeleton`);
          assert.strictEqual(
            find("input[role='combobox']").placeholder,
            "",
            `the empty ${label} select shows no placeholder beside it`
          );
        });
      }
    });

    test("an async update that clears, changes nothing, or fails restores the trigger", async function (assert) {
      const outcomes = [
        {
          name: "a clear",
          work: async (scope) => scope.clear(),
          value: "",
          placeholder: "Pick one",
        },
        {
          name: "no change",
          work: async () => {},
          value: "Apple",
          placeholder: "",
        },
        {
          name: "a failure",
          work: async () => {
            throw new Error("boom");
          },
          value: "Apple",
          placeholder: "",
        },
      ];

      for (const { name, work, value, placeholder } of outcomes) {
        const gate = deferred();
        const items = [
          ...ITEMS,
          updateRow("Suggest", async (scope) => {
            await gate.promise;
            await work(scope);
          }),
        ];

        await render(
          <template><AsyncUpdateHost @items={{items}} @value={{1}} /></template>
        );
        await click("[role='combobox']");
        await duringUpdate(gate, click(optionWithText("Suggest")));

        const input = find("input[role='combobox']");
        assert.strictEqual(
          input.value,
          value,
          `${name} leaves the right label`
        );
        assert.strictEqual(
          input.placeholder,
          placeholder,
          `${name} leaves the right placeholder`
        );
        assert
          .dom(".d-select__trigger [role='alert']")
          .doesNotExist(`${name} shows no inline error in the trigger`);
        assert
          .dom(".d-select__pending-icon")
          .doesNotExist(`${name} ends the pending state`);
      }
    });

    test("an async update yields to the user reopening the select or picking by hand", async function (assert) {
      const gate = deferred();
      const items = suggestItems(gate, ITEMS[1]);

      await render(
        <template><AsyncUpdateHost @items={{items}} @value={{1}} /></template>
      );
      await click("[role='combobox']");
      const pending = [];
      await duringUpdate(gate, click(optionWithText("Suggest")), async () => {
        await waitUntil(() => !find("[role='listbox']"));
        pending.push(click("[role='combobox']"));
        await waitFor("[role='listbox']");
        assert
          .dom(".d-select__pending-icon")
          .doesNotExist("reopening ends the pending state at once");
        pending.push(click(optionWithText("Cherry pie")));
      });
      await Promise.all(pending);

      assert
        .dom("input[role='combobox']")
        .hasValue("Cherry pie", "the hand pick wins over the late result");
    });

    test("an async update ends at once when the user removes a chip with Backspace", async function (assert) {
      const gate = deferred();
      const value = [1, 2];
      const items = suggestItems(gate, ITEMS[2]);

      await render(
        <template>
          <AsyncUpdateHost
            @items={{items}}
            @multiple={{true}}
            @value={{value}}
          />
        </template>
      );
      await click("[role='combobox']");
      let pressing;
      await duringUpdate(gate, click(optionWithText("Suggest")), async () => {
        await waitUntil(() => !find("[role='listbox']"));
        pressing = triggerKeyEvent(
          "input[role='combobox']",
          "keydown",
          "Backspace"
        );
        await waitUntil(() => !find(".d-select__pending-icon"));
        assert
          .dom(".d-select__chip .d-skeleton")
          .doesNotExist("the chips are back at once");
        assert
          .dom(".d-select__chip-list")
          .includesText("Apple", "the kept chip shows");
        assert
          .dom(".d-select__chip-list")
          .doesNotIncludeText("Banana", "only the removal applied");
      });
      await pressing;

      assert
        .dom(".d-select__chip-list")
        .doesNotIncludeText("Cherry pie", "the late add never lands");
    });

    test("an async update survives the close that resets a typed query", async function (assert) {
      const gate = deferred();
      const items = suggestItems(gate, ITEMS[1]);

      await render(
        <template><AsyncUpdateHost @items={{items}} @value={{1}} /></template>
      );
      await fillIn("input[role='combobox']", "Sugg");
      await duringUpdate(gate, click(optionWithText("Suggest")), async () => {
        await waitUntil(() => !find("[role='listbox']"));
      });

      assert
        .dom("input[role='combobox']")
        .hasValue("Banana", "the update applied after the query was reset");
    });

    test("an async update announces its start and its outcome", async function (assert) {
      const gate = deferred();
      const items = suggestItems(gate, ITEMS[1]);

      await render(
        <template><AsyncUpdateHost @items={{items}} @value={{1}} /></template>
      );
      await click("[role='combobox']");
      await duringUpdate(gate, click(optionWithText("Suggest")), async () => {
        await waitUntil(() => politeText().includes("Updating selection"), {
          timeout: 2000,
        });
        assert.true(
          politeText().includes("Updating selection…"),
          "the start is announced while the update is pending"
        );
      });

      assert.true(
        politeText().includes("Selected Banana"),
        "the outcome names the selected item"
      );
    });

    test("an async update announces a synchronous set and a re-pick, but no start", async function (assert) {
      const items = [
        ...ITEMS,
        updateRow("Set", (scope) => scope.select(ITEMS[1])),
        updateRow("Repick", (scope) => scope.select(ITEMS[1])),
      ];

      await render(
        <template><AsyncUpdateHost @items={{items}} @value={{1}} /></template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Set"));

      assert.true(
        politeText().includes("Selected Banana"),
        "a programmatic set is announced"
      );
      assert.false(
        politeText().includes("Updating selection"),
        "a synchronous update never announces a start"
      );

      await click("[role='combobox']");
      await click(optionWithText("Repick"));

      assert.true(
        politeText().includes("Selected Banana"),
        "a programmatic re-pick of the held value is announced"
      );
    });

    test("an async update leaves hand picks unannounced, even when deferred", async function (assert) {
      const queued = [];
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.change((next) => {
                queued.push(next);
              })
            )
        );
      });

      await render(
        <template><AsyncUpdateHost @items={{ITEMS}} @value={{1}} /></template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Banana"));
      queued.shift()();
      await settled();

      assert
        .dom("input[role='combobox']")
        .hasValue("Banana", "the deferred hand pick applied");
      assert.false(
        politeText().includes("Selected"),
        "a hand pick, deferred or not, is not announced"
      );
    });

    test("an async update announces a multi clear as one cleared selection", async function (assert) {
      const value = [1, 2];
      const items = [
        ...ITEMS,
        updateRow("Clear all", (scope) => scope.clear()),
      ];

      await render(
        <template>
          <AsyncUpdateHost
            @items={{items}}
            @multiple={{true}}
            @value={{value}}
          />
        </template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Clear all"));

      assert.true(
        politeText().includes("Selection cleared"),
        "the clear is announced once, not as a removal"
      );
      assert.false(
        politeText().includes("Removed"),
        "no single removal is announced"
      );
    });

    test("an async update that changes nothing announces no outcome", async function (assert) {
      const items = [...ITEMS, updateRow("Check", async () => {})];

      await render(
        <template><AsyncUpdateHost @items={{items}} @value={{1}} /></template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Check"));

      assert.false(politeText().includes("Selected"), "nothing was selected");
      assert.false(politeText().includes("cleared"), "nothing was cleared");
      assert.false(
        politeText().includes("Updating selection"),
        "an update that ends before the delay announces no start"
      );
    });

    test("an async update re-runs a content customization that reads pending", async function (assert) {
      const gate = deferred();
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items, context) => [
                ...items,
                updateRow(
                  context.control.pending ? "Loading suggestion" : "Suggest",
                  async () => {
                    await gate.promise;
                  },
                  { close: false }
                ),
              ])
            )
        );
      });

      await render(
        <template><AsyncUpdateHost @items={{ITEMS}} @value={{1}} /></template>
      );
      await click("[role='combobox']");
      await duringUpdate(gate, click(requireOption("Suggest")), async () => {
        await waitUntil(() => optionWithText("Loading suggestion"), {
          timeout: 2000,
        });
        assert.notStrictEqual(
          optionWithText("Loading suggestion"),
          undefined,
          "the row follows the pending state"
        );
      });

      assert.notStrictEqual(
        optionWithText("Suggest"),
        undefined,
        "the row returns once the update ends"
      );
    });

    test("an async update survives the select being unrendered mid-flight", async function (assert) {
      const gate = deferred();
      const visibility = new AsyncUpdateVisibility();
      const items = suggestItems(gate, ITEMS[1]);

      await render(
        <template>
          {{#if visibility.show}}
            <AsyncUpdateHost @items={{items}} @value={{1}} />
          {{/if}}
        </template>
      );
      await click("[role='combobox']");
      await duringUpdate(gate, click(optionWithText("Suggest")), async () => {
        visibility.show = false;
        await waitUntil(() => !find(".d-select__trigger"));
      });

      assert.dom(".d-select__trigger").doesNotExist("the select is gone");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect item classes",
  function (hooks) {
    setupRenderingTest(hooks);

    test("item classes are added to option rows without replacing core classes", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forIdentifier("test-select", (spec) =>
              spec.row((row, context) => {
                row.classes.push("x-extra", `x-item-${context.item.id}`);
              })
            )
        );
      });

      await render(<template><Host @value={{2}} /></template>);
      await click("[role='combobox']");

      assert
        .dom("[role='option'].x-extra")
        .exists({ count: 3 }, "every option row gets the class");
      assert
        .dom(optionWithText("Banana"))
        .hasClass("x-item-2", "a class can depend on the row's item")
        .hasClass("d-select__option", "the core class stays")
        .hasClass("--selected", "the core state modifier stays");
    });

    test("row customizations receive the item, the names and the context data, without the control", async function (assert) {
      const seen = [];
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.row((row, context) => {
                seen.push(context);
              })
            )
        );
      });
      const items = [
        { id: 1, name: "Apple" },
        { id: 2, name: "Banana" },
      ];
      const kind = { scope: "recipe" };
      const instance = { topicId: 7 };

      await render(
        <template>
          <DSelect
            @identifier="item-class-select"
            @instanceContext={{instance}}
            @items={{items}}
            @kind="item-class-kind"
            @kindContext={{kind}}
          />
        </template>
      );
      await click("[role='combobox']");

      const apple = seen.find((context) => context.item?.id === 1);
      assert.true(!!apple, "the customization runs for the Apple row");
      assert.strictEqual(apple.item, items[0], "item is the raw source item");
      assert.strictEqual(
        apple.identifier,
        "item-class-select",
        "identifier is @identifier"
      );
      assert.strictEqual(apple.kind, "item-class-kind", "kind is @kind");
      assert.strictEqual(
        apple.kindContext,
        kind,
        "kindContext is the recipe context"
      );
      assert.strictEqual(
        apple.instanceContext,
        instance,
        "instanceContext is the call-site context"
      );
      assert.false(
        "control" in apple,
        "the control's verbs are not offered at render time"
      );
      assert.false(apple.selected, "an unheld row is not selected");
      assert.false(apple.disabled, "an ordinary row is not disabled");
    });

    test("item classes follow the selection as it changes", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.row((row, context) => {
                if (context.selected) {
                  row.classes.push("is-held");
                }
              })
            )
        );
      });
      const empty = [];

      await render(<template><MultiLimitsHost @value={{empty}} /></template>);
      await click("[role='combobox']");

      assert.dom("[role='option'].is-held").doesNotExist("nothing is held yet");

      await click(optionWithText("Banana"));
      assert
        .dom(optionWithText("Banana"))
        .hasClass("is-held", "picking a row passes selected: true");
      assert
        .dom("[role='option'].is-held")
        .exists({ count: 1 }, "only the picked row");

      await click(optionWithText("Banana"));
      assert
        .dom(optionWithText("Banana"))
        .doesNotHaveClass("is-held", "removing it passes selected: false");
    });

    test("item classes see rows disabled by the selection cap", async function (assert) {
      const disabledById = {};
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.row((row, context) => {
                disabledById[context.item.id] = context.disabled;
                if (context.disabled) {
                  row.classes.push("is-capped");
                }
              })
            )
        );
      });
      const held = [1];

      await render(
        <template><MultiLimitsHost @maximum={{1}} @value={{held}} /></template>
      );
      await click("[role='combobox']");

      assert.deepEqual(
        disabledById,
        { 1: false, 2: true, 3: true },
        "unheld rows report disabled at the cap"
      );
      assert
        .dom("[role='option'].is-capped")
        .exists({ count: 2 }, "and can be styled from it");
    });

    test("item classes skip group headers and dividers", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.row((row) => row.classes.push("x-row"))
            )
        );
      });
      const sectioned = [
        { id: 1, name: "Apple", section: "fruit" },
        { id: 2, name: "Apricot", section: "fruit" },
        { id: 3, name: "Beet", section: "vegetable" },
        { id: 4, name: "Kale", section: "leafy" },
      ];
      const groupLabel = (key) => (key === "fruit" ? "Fruit" : null);

      await render(
        <template>
          <DSelect
            @groupBy="section"
            @groupLabel={{groupLabel}}
            @identifier="test-select"
            @items={{sectioned}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom(".d-select__group-header")
        .exists("a labeled group renders a header");
      assert
        .dom(".d-select__divider")
        .exists("an unlabeled boundary renders a divider");
      assert
        .dom(".d-select__group-header.x-row")
        .doesNotExist("headers are not items");
      assert
        .dom(".d-select__divider.x-row")
        .doesNotExist("dividers are not items");
      assert
        .dom("[role='option'].x-row")
        .exists({ count: 4 }, "every option still gets the class");
    });

    test("item classes apply to the none row and the create row", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.row((row) => row.classes.push("x-row"))
            )
        );
      });
      const createItem = (filter) => ({
        id: filter,
        name: filter,
        __create: true,
      });

      await render(
        <template>
          <DSelect
            @allowCreate={{true}}
            @createItem={{createItem}}
            @identifier="test-select"
            @items={{ITEMS}}
            @noneLabel="None"
          />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom("[role='option'].--none")
        .hasClass("x-row", "the none row is an item");

      await fillIn("[role='combobox']", "dragonfruit");
      assert
        .dom("[role='option'].--create")
        .hasClass("x-row", "the create row is an item");
    });

    test("item classes start from a fresh row for every row and render", async function (assert) {
      const inputs = [];
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.row((row, context) => {
                inputs.push({
                  row,
                  classes: row.classes,
                  length: row.classes.length,
                });
                row.classes.push(`x-item-${context.item.id}`);
              })
            )
        );
      });

      await render(<template><DSelect @items={{ITEMS}} /></template>);
      await click("[role='combobox']");
      await fillIn("[role='combobox']", "a");
      await fillIn("[role='combobox']", "");

      assert.true(
        inputs.length > ITEMS.length,
        "rows are transformed again after filtering"
      );
      assert.true(
        inputs.every(({ length }) => length === 0),
        "each input starts empty"
      );
      assert.strictEqual(
        new Set(inputs.map(({ row }) => row)).size,
        inputs.length,
        "every call gets its own row"
      );
      assert.strictEqual(
        new Set(inputs.map(({ classes }) => classes)).size,
        inputs.length,
        "and its own classes array"
      );
      for (const item of ITEMS) {
        assert
          .dom(`[role='option'].x-item-${item.id}`)
          .exists(
            { count: 1 },
            "a mutated input adds a class only to its own row"
          );
      }
    });

    test("item classes apply to action rows but not to chips or the trigger", async function (assert) {
      const items = [...ITEMS, { id: "action", name: "Action", onSelect() {} }];
      const held = [1];
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.row((row) => row.classes.push("x-row"))
            )
        );
      });

      await render(
        <template>
          <DSelect @items={{items}} @multiple={{true}} @value={{held}} />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom("[role='option'].x-row")
        .exists(
          { count: 4 },
          "the action row and ordinary options get the class"
        );
      assert.dom(".d-select__chip").exists("a held item renders a chip");
      assert
        .dom(".x-row")
        .exists({ count: 4 }, "chips and the trigger get no option classes");
    });

    test("item classes ignore empty and falsy entries", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.row((row, context) => {
                if (context.item.id === 3) {
                  row.classes.push(null, "", false);
                }
              })
            )
        );
      });

      await render(<template><Host /></template>);
      await click("[role='combobox']");

      assert.deepEqual(
        [...optionWithText("Cherry").classList],
        [...optionWithText("Banana").classList],
        "falsy entries add no classes"
      );
      assert.deepEqual(
        [...optionWithText("Banana").classList],
        ["d-select__option"],
        "an empty result leaves only the core class"
      );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect transformer safeguard",
  function (hooks) {
    setupRenderingTest(hooks);

    function numbered(count, offset = 0) {
      return Array.from({ length: count }, (_, i) => ({
        id: offset + i + 1,
        name: `Item ${offset + i + 1}`,
        section: (offset + i) % 2 ? "odd" : "even",
      }));
    }

    function spyAnnounce(context) {
      return sinon.spy(getOwner(context).lookup("service:a11y"), "announce");
    }

    function countAnnounced(announce, key, count) {
      return announce.withArgs(i18n(`d_select.${key}`, { count }), "polite")
        .callCount;
    }

    function setSizes() {
      return [
        ...document.querySelectorAll("ul[role='listbox'] > [role='option']"),
      ].map((option) => option.getAttribute("aria-setsize"));
    }

    test("a client list is sized by the rows a transformer keeps", async function (assert) {
      const announce = spyAnnounce(this);
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) => spec.content((items) => items.slice(0, 2)))
        );
      });
      const items = numbered(5);

      await render(
        <template><DSelect @items={{items}} @variant="button" /></template>
      );
      await click(".d-select__trigger");

      assert.deepEqual(setSizes(), ["2", "2"], "both kept rows say 2");
      assert.strictEqual(
        countAnnounced(announce, "results_count", 2),
        1,
        "the announced count matches the set size"
      );
      assert.strictEqual(
        countAnnounced(announce, "results_count", 5),
        0,
        "the source's own count is never announced"
      );
    });

    test("a grouped client list is counted from its options, not its headers", async function (assert) {
      const announce = spyAnnounce(this);
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) => spec.content((items) => items.slice(0, 2)))
        );
      });
      const items = numbered(5);
      const groupLabel = (key) => (key === "even" ? "Even" : "Odd");

      await render(
        <template>
          <DSelect
            @groupBy="section"
            @groupLabel={{groupLabel}}
            @items={{items}}
            @variant="button"
          />
        </template>
      );
      await click(".d-select__trigger");

      assert
        .dom("ul[role='listbox'] > .d-select__group-header")
        .exists("a header leads the list");
      assert.deepEqual(setSizes(), ["2", "2"], "both kept rows say 2");
      assert.strictEqual(
        countAnnounced(announce, "results_count", 2),
        1,
        "the count skips the header to find the set size"
      );
    });

    test("rows a transformer adds count toward the set and the announcement", async function (assert) {
      const announce = spyAnnounce(this);
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items) => [
                ...items,
                { id: "extra-1", name: "Extra 1" },
                { id: "extra-2", name: "Extra 2" },
              ])
            )
        );
      });
      const items = numbered(3);

      await render(
        <template><DSelect @items={{items}} @variant="button" /></template>
      );
      await click(".d-select__trigger");

      assert.deepEqual(
        setSizes(),
        ["5", "5", "5", "5", "5"],
        "every row says 5"
      );
      assert.strictEqual(
        countAnnounced(announce, "results_count", 5),
        1,
        "and so does the announcement"
      );
    });

    test("a paged set is the declared total plus the transformer's net change", async function (assert) {
      const announce = spyAnnounce(this);
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items) => items.filter((item) => item.id % 4 !== 0))
            )
        );
      });
      const load = (_filter, { offset = 0 }) => ({
        items: numbered(20, offset),
        total: 100,
      });

      await render(
        <template>
          <DSelect @debounce={{false}} @load={{load}} @variant="button" />
        </template>
      );
      await click(".d-select__trigger");

      assert.strictEqual(setSizes().length, 15, "fifteen of twenty rows show");
      assert.true(
        setSizes().every((size) => size === "95"),
        "the set is 100 less the 5 hidden so far"
      );
      assert.strictEqual(
        countAnnounced(announce, "results_count", 95),
        1,
        "the announcement says the same"
      );
    });

    test("a none row counts in the announcement as it does in the set size", async function (assert) {
      const announce = spyAnnounce(this);
      const items = numbered(3);

      await render(
        <template>
          <DSelect @items={{items}} @noneLabel="None" @variant="button" />
        </template>
      );
      await click(".d-select__trigger");

      assert.deepEqual(setSizes(), ["4", "4", "4", "4"], "four options");
      assert.strictEqual(
        countAnnounced(announce, "results_count", 4),
        1,
        "four results are announced"
      );
    });

    test("a client list that changes while open still announces its new count", async function (assert) {
      const announce = spyAnnounce(this);
      const state = new (class {
        @tracked items = numbered(3);
      })();

      await render(
        <template>
          <DSelect @items={{state.items}} @variant="button" />
        </template>
      );
      await click(".d-select__trigger");
      assert.strictEqual(
        countAnnounced(announce, "results_count", 3),
        1,
        "opening announces the count"
      );

      state.items = numbered(5);
      await settled();

      assert.deepEqual(
        setSizes(),
        ["5", "5", "5", "5", "5"],
        "the rows carry the new size"
      );
      assert.strictEqual(
        countAnnounced(announce, "results_count", 5),
        1,
        "nothing else reports the change, so the count is announced"
      );
    });

    test("paging does not re-announce an estimate that moved", async function (assert) {
      const announce = spyAnnounce(this);
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items) => items.filter((item) => item.id % 4 !== 0))
            )
        );
      });
      const load = (_filter, { offset = 0 }) => ({
        items: numbered(20, offset),
        total: 100,
      });

      await render(
        <template>
          <EngineProbe @debounce={{false}} @load={{load}} @variant="button" />
        </template>
      );
      await click(".d-select__trigger");
      assert.strictEqual(
        countAnnounced(announce, "results_count", 95),
        1,
        "opening announces the estimate"
      );

      probedEngine().revealMore();
      await settled();

      assert.true(
        setSizes().every((size) => size === "90"),
        "the rows carry the new estimate"
      );
      assert.strictEqual(
        countAnnounced(announce, "results_count", 90),
        0,
        "more rows for the same query do not announce a new count"
      );
    });

    test("a set holding only the create row announces its one option", async function (assert) {
      const announce = spyAnnounce(this);
      const items = [];
      const createItem = (filter) => ({ id: `new:${filter}`, name: filter });
      await render(
        <template>
          <EngineProbe
            @allowCreate={{true}}
            @createItem={{createItem}}
            @items={{items}}
            @variant="button"
          />
        </template>
      );
      probedEngine().setFilter("Pear");
      await click(".d-select__trigger");

      assert.deepEqual(setSizes(), ["1"], "the create row sizes its set");
      assert.strictEqual(
        countAnnounced(announce, "results_count", 1),
        1,
        "the announced count includes the create row"
      );
    });

    test("slow reveals that grow the list keep paging after the skeletons go", async function (assert) {
      const items = numbered(100);
      let release;
      const load = (_filter, { offset = 0 }) =>
        offset === 0
          ? { items: items.slice(0, 10), hasMore: true }
          : new Promise((resolve) => {
              release = () =>
                resolve({
                  items: items.slice(offset, offset + 10),
                  hasMore: true,
                });
            });
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((rows) => rows.filter((row) => row.id % 2 === 1))
            )
        );
      });
      await render(
        <template>
          <EngineProbe @debounce={{false}} @load={{load}} @variant="button" />
        </template>
      );
      await click(".d-select__trigger");
      const engine = probedEngine();

      const hasFrontier = () =>
        release && find("ul[role='listbox'] .d-select__skeleton");
      for (let i = 0; i < 3; i++) {
        release = undefined;
        assert.true(
          engine.revealMore(),
          "a growing list accepts another reveal"
        );
        try {
          await waitUntil(hasFrontier);
          assert.strictEqual(
            setSizes().length,
            (i + 1) * 5,
            "only settled options show during the request"
          );
        } finally {
          release?.();
        }
        await settled();
        assert.strictEqual(
          setSizes().length,
          (i + 2) * 5,
          "new visible options replace the skeletons"
        );
      }
      assert.true(
        engine.canRevealMore,
        "slow visible growth never trips the brake"
      );
    });
  }
);

const ORIGINAL_ROWS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Apricot" },
  { id: 3, name: "Beet" },
];
const SUGGESTED_ROWS = [
  { id: 10, name: "Suggested ten" },
  { id: 11, name: "Suggested eleven" },
];

/**
 * A suggester written as a source swap: an action row flips a mode kept in the setup closure (one
 * per select) and starts a new query, and the `load` customization answers that query from the
 * suggestion source.
 */
function registerSuggester({ suggest } = {}) {
  const calls = { original: [], suggest: [] };

  const original = (filter, { offset = 0 } = {}) => {
    calls.original.push({ filter, offset });
    const term = filter.toLowerCase();
    return {
      items: ORIGINAL_ROWS.filter((row) =>
        row.name.toLowerCase().includes(term)
      ),
      hasMore: false,
    };
  };
  const suggestLoad = (filter, { offset = 0 } = {}) => {
    calls.suggest.push({ filter, offset });
    return suggest ? suggest() : { items: SUGGESTED_ROWS, hasMore: false };
  };

  withPluginApi((api) => {
    api.registerValueTransformer(
      "select-customizations",
      ({ value: selects }) =>
        selects.forIdentifier("suggester", (spec) => {
          let suggesting = false;

          spec.content((items) => {
            const row = suggesting
              ? {
                  id: "back",
                  name: "Back to results",
                  onSelect: (control) => {
                    suggesting = false;
                    control.reload();
                  },
                }
              : {
                  id: "suggest",
                  name: "Suggest tags",
                  onSelect: (control) => {
                    suggesting = true;
                    control.reload();
                  },
                };
            return [row, ...items];
          });

          spec.load((load, context) => {
            if (!suggesting) {
              return load;
            }
            if (context.filter) {
              suggesting = false;
              return load;
            }
            return suggestLoad;
          });
        })
    );
  });

  return { original, calls };
}

class SuggesterHost extends Component {
  @tracked value = [];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @debounce={{false}}
      @identifier="suggester"
      @load={{@load}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @value={{this.value}}
    >
      <:selection as |item|>
        {{~item.name~}}
      </:selection>
    </DSelect>
  </template>
}

function numberedRows(count) {
  return Array.from({ length: count }, (_, i) => ({
    id: i + 1,
    name: `Row ${i + 1}`,
  }));
}

module(
  "Integration | ui-kit | select | DSelect load customizations",
  function (hooks) {
    setupRenderingTest(hooks);

    const QUERY = ".d-select__trigger [role='combobox']";

    function optionNames() {
      return [
        ...document.querySelectorAll("ul[role='listbox'] > [role='option']"),
      ].map((option) => option.textContent.trim());
    }

    test("a suggest row swaps the source for the next query", async function (assert) {
      const { original, calls } = registerSuggester();

      await render(<template><SuggesterHost @load={{original}} /></template>);
      await click(QUERY);
      assert.deepEqual(
        optionNames(),
        ["Suggest tags", "Apple", "Apricot", "Beet"],
        "the original source answers first"
      );

      await click(optionWithText("Suggest tags"));

      assert.deepEqual(
        optionNames(),
        ["Back to results", "Suggested ten", "Suggested eleven"],
        "the suggestions replace the original rows"
      );
      assert.deepEqual(
        calls.suggest,
        [{ filter: "", offset: 0 }],
        "the suggestion source was asked once, for its first page"
      );
    });

    test("going back restores the original source from its first page", async function (assert) {
      const { original, calls } = registerSuggester();

      await render(<template><SuggesterHost @load={{original}} /></template>);
      await click(QUERY);
      await click(optionWithText("Suggest tags"));

      await click(optionWithText("Suggested ten"));
      await click(optionWithText("Back to results"));

      assert.deepEqual(
        optionNames(),
        ["Suggest tags", "Apple", "Apricot", "Beet"],
        "the original rows come back on their own, not after the suggestions"
      );
      assert.deepEqual(
        calls.original.at(-1),
        { filter: "", offset: 0 },
        "the original source was asked for its first page again"
      );
      assert
        .dom(".d-select__chip")
        .includesText("Suggested ten", "the picked suggestion keeps its name");
    });

    test("typing leaves suggest mode", async function (assert) {
      const { original, calls } = registerSuggester();

      await render(<template><SuggesterHost @load={{original}} /></template>);
      await click(QUERY);
      await click(optionWithText("Suggest tags"));

      await fillIn(QUERY, "ap");
      assert.deepEqual(
        optionNames(),
        ["Suggest tags", "Apple", "Apricot"],
        "the typed query is answered by the original source"
      );
      assert.deepEqual(
        calls.original.at(-1),
        { filter: "ap", offset: 0 },
        "with the typed filter"
      );

      await fillIn(QUERY, "");
      assert.deepEqual(
        optionNames(),
        ["Suggest tags", "Apple", "Apricot", "Beet"],
        "clearing the filter shows the normal list"
      );
    });

    test("a reload that lands before any loading state is announced as a new query", async function (assert) {
      const announce = sinon.spy(
        getOwner(this).lookup("service:a11y"),
        "announce"
      );
      let size = 60;
      const load = (_filter, { offset = 0 }) => ({
        items: Array.from({ length: size }, (_, i) => ({
          id: offset + i + 1,
          name: `Row ${offset + i + 1}`,
        })),
        total: size,
        hasMore: false,
      });

      await render(
        <template>
          <EngineProbe @debounce={{false}} @load={{load}} @variant="button" />
        </template>
      );
      await click(".d-select__trigger");
      size = 40;
      probedEngine().control.reload();
      await settled();

      assert
        .dom("ul[role='listbox']")
        .exists("the rows never gave way to the loading skeleton");
      assert.strictEqual(
        announce.withArgs(
          i18n("d_select.results_count", { count: 40 }),
          "polite"
        ).callCount,
        1,
        "the reloaded count is announced"
      );
    });

    test("a slow swap shows the loading skeleton, not the reveal skeleton", async function (assert) {
      let release;
      const { original } = registerSuggester({
        suggest: () =>
          new Promise((resolve) => {
            release = () => resolve({ items: SUGGESTED_ROWS, hasMore: false });
          }),
      });

      await render(<template><SuggesterHost @load={{original}} /></template>);
      await click(QUERY);
      const picked = click(requireOption("Suggest tags"));
      await waitUntil(() => release);
      await waitFor(".d-select__listbox--loading .d-select__skeleton");

      assert
        .dom(
          "ul[role='listbox']:not(.d-select__listbox--loading) .d-select__skeleton"
        )
        .doesNotExist("a swap is not more rows for the same query");

      release();
      await picked;
      await settled();
      assert.deepEqual(
        optionNames(),
        ["Back to results", "Suggested ten", "Suggested eleven"],
        "the suggestions land"
      );
    });

    test("a fast reload clears the cursor even when the rows stay identical", async function (assert) {
      const load = () => numberedRows(3);
      await render(
        <template>
          <EngineProbe @debounce={{false}} @load={{load}} @variant="button" />
        </template>
      );
      await click(".d-select__trigger");
      const query = ".d-select__filter";
      await triggerKeyEvent(query, "keydown", "ArrowDown");
      assert
        .dom(query)
        .hasAttribute(
          "aria-activedescendant",
          /.+/,
          "the cursor is on a row before reload"
        );
      const list = find("ul[role='listbox']");
      probedEngine().control.reload();
      await settled();
      assert.strictEqual(
        find("ul[role='listbox']"),
        list,
        "the list stayed mounted through the fast reload"
      );
      assert
        .dom(query)
        .doesNotHaveAttribute(
          "aria-activedescendant",
          "a new query clears the cursor"
        );
    });

    test("a load customization may update tracked state, and an empty reload reports again", async function (assert) {
      const state = new (class {
        @tracked calls = 0;
      })();
      const announce = sinon.spy(
        getOwner(this).lookup("service:a11y"),
        "announce"
      );
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.load((load) => {
                state.calls++;
                return load;
              })
            )
        );
      });
      const load = () => [];
      await render(
        <template>
          <span class="loader-calls">{{state.calls}}</span><EngineProbe
            @debounce={{false}}
            @load={{load}}
            @variant="button"
          />
        </template>
      );
      await click(".d-select__trigger");
      assert
        .dom(".loader-calls")
        .hasText("1", "the transformer writes outside render");
      assert.strictEqual(
        announce.withArgs(i18n("d_select.no_results"), "polite").callCount,
        1,
        "the first empty result is announced"
      );
      probedEngine().control.reload();
      await settled();
      assert
        .dom(".loader-calls")
        .hasText("2", "reload resolves the transformer again");
      assert.strictEqual(
        announce.withArgs(i18n("d_select.no_results"), "polite").callCount,
        2,
        "the new empty query is announced again"
      );
    });

    module("windowed", function (windowedHooks) {
      windowedHooks.beforeEach(function () {
        enableVirtualization();
      });

      windowedHooks.afterEach(function () {
        disableVirtualization();
      });

      test("a fast reload resets the real window's scroll without replacing its viewport", async function (assert) {
        const load = () => numberedRows(60);
        await render(
          <template>
            {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
            <style>
              .d-virtual-list {
                height: 200px;
                overflow-y: auto;
              }
            </style>
            <EngineProbe @debounce={{false}} @load={{load}} @variant="button" />
          </template>
        );
        await click(".d-select__trigger");
        const viewport = find(".d-virtual-list");
        assert.true(
          document.querySelectorAll("ul[role='listbox'] > [role='option']")
            .length < 60,
          "only the real window is mounted"
        );
        viewport.scrollTop = viewport.scrollHeight;
        await settled();
        assert.true(viewport.scrollTop > 0, "the viewport was scrolled");
        probedEngine().control.reload();
        await settled();
        assert.strictEqual(
          find(".d-virtual-list"),
          viewport,
          "the fast reload kept the viewport mounted"
        );
        assert.strictEqual(
          viewport.scrollTop,
          0,
          "the real window returns to the top"
        );
        assert
          .dom(`${"ul[role='listbox'] > [role='option']"}[data-index='0']`)
          .exists("the first row is mounted again");
      });
    });
  }
);

/** A controlled select carrying the kind and identifier the contract fixtures target. */
class ContractHost extends Component {
  @tracked value = this.args.value ?? (this.args.multiple ? [] : null);

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <A11yLiveRegions />
    <DSelect
      @identifier="contract-select"
      @items={{ITEMS}}
      @kind="contract-select"
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @placeholder="Pick one"
      @value={{this.value}}
    />
  </template>
}

function rowNames() {
  return [...document.querySelectorAll("[role='option']")].map((option) =>
    option.textContent.trim()
  );
}

/**
 * Registers an extension whose action row reads the value, closes, flags `isLoading`,
 * waits on `gate`, then selects its best match.
 */
function registerChooser(gate, { best, checksValue = true } = {}) {
  const state = new WeakMap();
  withPluginApi((api) => {
    api.modifySelectKit("contract-select").prependContent((component) => {
      if (component.selectKit.filter || state.get(component)) {
        return;
      }
      return {
        id: "contract-choose",
        name: "Choose for me",
        onSelect: async (selectKit) => {
          const startValue = selectKit.value;
          state.set(component, true);
          selectKit.close();
          selectKit.set("isLoading", true);
          try {
            await gate.promise;
            if (component.isDestroying) {
              return;
            }
            if (checksValue && selectKit.value !== startValue) {
              return;
            }
            if (best) {
              selectKit.select(best.id, best);
            }
          } finally {
            state.set(component, false);
            if (!component.isDestroying) {
              selectKit.set("isLoading", false);
            }
          }
        },
      };
    });
  });
}

module(
  "Integration | ui-kit | select | DSelect (modifySelectKit contract)",
  function (hooks) {
    setupRenderingTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

    hooks.beforeEach(function () {
      disableClearA11yAnnouncementsInTests();
    });

    // An extension that keeps per-component mode in a WeakMap, swaps rows with prepend and
    // replace, and calls `triggerSearch` after every mode change to rebuild the list.
    test("contract: triggerSearch rebuilds the list from an extension's new state", async function (assert) {
      const gate = deferred();
      const modes = new WeakMap();
      const SUGGESTIONS = [
        { id: 2, name: "Banana" },
        { id: 3, name: "Cherry pie" },
      ];
      const modeOf = (component) => modes.get(component) ?? "idle";

      withPluginApi((api) => {
        api.modifySelectKit("contract-select").prependContent((component) => {
          if (component.selectKit.filter) {
            modes.set(component, "idle");
            return;
          }
          if (modeOf(component) === "idle") {
            return {
              id: "contract-suggest",
              name: "Suggest",
              onSelect: async (selectKit) => {
                modes.set(component, "loading");
                selectKit.triggerSearch?.();
                await gate.promise;
                if (component.isDestroying) {
                  return;
                }
                modes.set(component, "results");
                selectKit.triggerSearch?.();
              },
            };
          }
        });

        api.modifySelectKit("contract-select").replaceContent((component) => {
          if (component.selectKit.filter) {
            return;
          }
          const mode = modeOf(component);
          if (mode === "loading") {
            return [{ id: "contract-loading", name: "Loading", onSelect() {} }];
          }
          if (mode === "results") {
            const taken = component.selectKit.value ?? [];
            return [
              {
                id: "contract-exit",
                name: "Back",
                onSelect: (selectKit) => {
                  modes.set(component, "idle");
                  selectKit.triggerSearch?.();
                },
              },
              ...SUGGESTIONS.filter((s) => !taken.includes(s.id)),
            ];
          }
        });

        api.modifySelectKit("contract-select").onChange((component) => {
          if (modeOf(component) === "results") {
            component.selectKit.triggerSearch?.();
          }
        });
      });

      await render(<template><ContractHost @multiple={{true}} /></template>);
      await click("[role='combobox']");
      assert.deepEqual(
        rowNames(),
        ["Suggest", "Apple", "Banana", "Cherry pie"],
        "the action row leads the list"
      );

      const picking = click(optionWithText("Suggest"));
      await waitUntil(() => rowNames().includes("Loading"), {
        timeout: 2000,
      });
      assert.deepEqual(
        rowNames(),
        ["Loading"],
        "the first triggerSearch shows the loading row"
      );

      gate.resolve();
      await picking;
      await settled();
      assert.deepEqual(
        rowNames(),
        ["Back", "Banana", "Cherry pie"],
        "the second triggerSearch shows the suggestions"
      );

      await click(optionWithText("Banana"));
      assert.deepEqual(
        rowNames(),
        ["Back", "Cherry pie"],
        "triggerSearch from onChange drops the taken suggestion"
      );

      await click(optionWithText("Back"));
      assert.true(
        rowNames().includes("Suggest"),
        "leaving the suggestions brings the action row back"
      );

      await fillIn("input[role='combobox']", "App");
      assert.false(
        rowNames().includes("Suggest"),
        "typing a query hides the action row"
      );
    });

    test("contract: isLoading shows the pending state and the late select is announced", async function (assert) {
      const gate = deferred();
      registerChooser(gate, { best: { id: 2, name: "Banana" } });

      await render(<template><ContractHost @value={{1}} /></template>);
      await click("[role='combobox']");
      await duringUpdate(gate, click(optionWithText("Choose for me")), () => {
        assert
          .dom(".d-select__trigger .d-skeleton")
          .exists("the value slot shows the loading skeleton");
        assert
          .dom(".d-select__trigger")
          .hasAttribute("aria-busy", "true", "the trigger is busy");
      });
      await settled();

      assert
        .dom("input[role='combobox']")
        .hasValue("Banana", "the suggestion becomes the selection");
      assert
        .dom(".d-select__pending-icon")
        .doesNotExist("clearing isLoading ends the pending state");
      assert.true(
        politeText().includes("Selected Banana"),
        "the late selection is announced as the update's outcome"
      );
    });

    test("contract: a hand pick made while isLoading is set beats the late select", async function (assert) {
      const gate = deferred();
      registerChooser(gate, {
        best: { id: 2, name: "Banana" },
        checksValue: false,
      });

      await render(<template><ContractHost @value={{1}} /></template>);
      await click("[role='combobox']");
      const pending = [];
      await duringUpdate(
        gate,
        click(optionWithText("Choose for me")),
        async () => {
          await waitUntil(() => !find("[role='listbox']"));
          pending.push(click("[role='combobox']"));
          await waitFor("[role='listbox']");
          assert
            .dom(".d-select__pending-icon")
            .doesNotExist("reopening ends the pending state at once");
          pending.push(click(optionWithText("Cherry pie")));
        }
      );
      await Promise.all(pending);
      await settled();

      assert
        .dom("input[role='combobox']")
        .hasValue(
          "Cherry pie",
          "the late select is dropped even without its own value check"
        );
    });

    test("contract: clearing isLoading without a select restores the trigger", async function (assert) {
      const gate = deferred();
      registerChooser(gate);

      await render(<template><ContractHost @value={{1}} /></template>);
      await click("[role='combobox']");
      await duringUpdate(gate, click(optionWithText("Choose for me")));
      await settled();

      assert
        .dom(".d-select__pending-icon")
        .doesNotExist("the pending state ends");
      assert
        .dom("input[role='combobox']")
        .hasValue("Apple", "the held value shows again");
    });

    // Mirrors the content filter a theme or plugin applies with replaceContent.
    test("contract: content, value and filter are readable on the component", async function (assert) {
      const seen = [];
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forIdentifier("contract-select", (spec) =>
              spec.content((items) => [...items, { id: 9, name: "Extra" }])
            )
        );
        api.modifySelectKit("contract-select").replaceContent((component) => {
          // Read defensively so a missing member fails an assertion, not the render.
          const content = component.content ?? [];
          seen.push({
            content: content.map((item) => item.id),
            value: component.value,
            filter: component.selectKit.filter,
          });
          return content.filter((item) => item.id !== 2);
        });
      });

      await render(<template><ContractHost @value={{1}} /></template>);
      await click("[role='combobox']");

      assert.deepEqual(
        rowNames(),
        ["Apple", "Cherry pie", "Extra"],
        "the returned list replaces the rows"
      );
      assert.deepEqual(
        seen.at(-1),
        { content: [1, 2, 3, 9], value: 1, filter: "" },
        "content is the list after the content customizations, with the held value"
      );

      await click(optionWithText("Cherry pie"));
      await click("[role='combobox']");
      assert.strictEqual(seen.at(-1).value, 3, "value follows the selection");

      await fillIn("input[role='combobox']", "pie");
      assert.strictEqual(
        seen.at(-1).filter,
        "pie",
        "the filter is the typed query"
      );
      assert.false(rowNames().includes("Banana"), "the filtered row stays out");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (bridge opt-out)",
  function (hooks) {
    setupRenderingTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

    test("a callback registered with bridge false never reaches DSelect", async function (assert) {
      const changes = [];
      withPluginApi((api) => {
        api
          .modifySelectKit("test-select", { bridge: false })
          .prependContent(() => ({ id: 99, name: "Legacy only" }))
          .onChange(() => changes.push("legacy-only"));
      });

      await render(<template><Host /></template>);
      await click("[role='combobox']");

      assert
        .dom("[role='listbox']")
        .doesNotIncludeText("Legacy only", "opted-out content stays out");
      await click(optionWithText("Apple"));
      assert.deepEqual(changes, [], "opted-out onChange never runs");
    });

    test("a default registration still bridges", async function (assert) {
      withPluginApi((api) => {
        api
          .modifySelectKit("test-select")
          .prependContent(() => ({ id: 99, name: "Bridged" }));
        api
          .modifySelectKit("test-select", { bridge: false })
          .prependContent(() => ({ id: 98, name: "Legacy only" }));
      });

      await render(<template><Host /></template>);
      await click("[role='combobox']");

      assert.dom("[role='listbox']").includesText("Bridged");
      assert.dom("[role='listbox']").doesNotIncludeText("Legacy only");
    });

    test("an opted-out onChange is skipped beside a bridged one", async function (assert) {
      const changes = [];
      withPluginApi((api) => {
        api
          .modifySelectKit("test-select")
          .onChange(() => changes.push("bridged"));
        api
          .modifySelectKit("test-select", { bridge: false })
          .onChange(() => changes.push("legacy-only"));
      });

      await render(<template><Host /></template>);
      await click("[role='combobox']");
      await click(optionWithText("Apple"));

      assert.deepEqual(changes, ["bridged"]);
    });

    test("opted-out callbacks still run in select-kit", async function (assert) {
      withPluginApi((api) => {
        api
          .modifySelectKit("test-select", { bridge: false })
          .appendContent(() => ({ id: 99, name: "Legacy only" }));
      });

      const content = applyContentPluginApiCallbacks([], {
        pluginApiIdentifiers: ["test-select"],
      });
      assert.deepEqual(
        content.map((row) => row.name),
        ["Legacy only"],
        "the legacy component keeps applying it"
      );
    });
  }
);
