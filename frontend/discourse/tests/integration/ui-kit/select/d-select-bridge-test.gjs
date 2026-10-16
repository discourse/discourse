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
        await click(".d-combobox__trigger");

        assert.dom("[role='listbox']").exists("the menu is open");
        assert.strictEqual(
          element,
          find(".d-combobox__trigger"),
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
            @maximum={{state.maximum}}
            @multiple={{state.multiple}}
            @value={{state.value}}
            @variant="button"
          />
        </template>
      );
      await click(".d-combobox__trigger");

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

    test("select-content receives the kind, instance and control contexts", async function (assert) {
      let seen;
      withPluginApi((api) => {
        api.registerValueTransformer("select-content", ({ value, context }) => {
          seen = context;
          return value;
        });
      });
      const kind = { scope: "recipe" };
      const instance = { topicId: 7 };

      await render(
        <template>
          <DSelect
            @identifier="context-select"
            @instanceContext={{instance}}
            @items={{ITEMS}}
            @kindContext={{kind}}
            @value={{2}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert.strictEqual(seen.kind, kind, "the recipe context is passed as is");
      assert.strictEqual(
        seen.instance,
        instance,
        "the call-site context is passed as is"
      );
      assert.strictEqual(seen.control.value, 2, "the control reads the value");
      assert.strictEqual(
        seen.control.filter,
        "",
        "the control reads the filter"
      );
    });

    test("kind and instance default to frozen empty objects", async function (assert) {
      let seen;
      withPluginApi((api) => {
        api.registerValueTransformer("select-content", ({ value, context }) => {
          seen = context;
          return value;
        });
      });

      await render(<template><DSelect @items={{ITEMS}} /></template>);
      await click("[role='combobox']");

      assert.deepEqual(seen.kind, {}, "kind is empty without a recipe context");
      assert.true(Object.isFrozen(seen.kind), "and frozen");
      assert.deepEqual(
        seen.instance,
        {},
        "instance is empty without a call-site context"
      );
      assert.true(Object.isFrozen(seen.instance), "and frozen");
    });

    test("a new @instanceContext re-runs select-content", async function (assert) {
      const state = new ContextState();
      withPluginApi((api) => {
        api.registerValueTransformer("select-content", ({ value, context }) => [
          ...value,
          { id: "from-instance", name: `Row ${context.instance.label}` },
        ]);
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

    test("a transformer that reads tracked state re-runs when it changes", async function (assert) {
      const state = new ContextState();
      withPluginApi((api) => {
        api.registerValueTransformer("select-content", ({ value }) => [
          ...value,
          { id: "tracked", name: `Row ${state.label}` },
        ]);
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

    test("select-on-change receives the kind and instance contexts", async function (assert) {
      let seen;
      withPluginApi((api) => {
        api.registerBehaviorTransformer(
          "select-on-change",
          ({ context, next }) => {
            seen = context;
            next();
          }
        );
      });
      const kind = { scope: "recipe" };
      const instance = { topicId: 7 };
      const onChange = () => {};

      await render(
        <template>
          <DSelect
            @instanceContext={{instance}}
            @items={{ITEMS}}
            @kindContext={{kind}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Banana"));

      assert.strictEqual(seen.kind, kind, "the recipe context is passed");
      assert.strictEqual(
        seen.instance,
        instance,
        "the call-site context is passed"
      );
      assert.strictEqual(seen.value, 2, "the next value is passed");
      assert.false("control" in seen, "the change context carries no control");
    });

    test("the control is one frozen object for the life of the select", async function (assert) {
      const controls = [];
      withPluginApi((api) => {
        api.registerValueTransformer("select-content", ({ value, context }) => {
          controls.push(context.control);
          return value;
        });
      });

      await render(
        <template><DSelect @items={{ITEMS}} @variant="button" /></template>
      );
      await click(".d-combobox__trigger");
      await fillIn(".d-combobox__filter", "an");

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
async function duringUpdate(gate, clicking, whilePending) {
  try {
    await waitFor(".d-combobox__pending-icon", { timeout: 2000 });
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
      <:selection as |item|>{{item.name}}</:selection>
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
          find(".d-combobox__trigger").lastElementChild.classList.contains(
            "d-combobox__pending-icon"
          ),
          "the spinner takes the caret's place as the trigger's last child"
        );
        assert.dom(".d-combobox__caret").doesNotExist("the caret is replaced");
        assert
          .dom(".d-combobox__trigger .d-skeleton")
          .exists("the value slot shows the loading skeleton");
        assert
          .dom(".d-combobox__trigger")
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
      assert.dom(".d-combobox__caret").exists("the caret is back");
      assert
        .dom(".d-combobox__pending-icon")
        .doesNotExist("the spinner is gone");
      assert
        .dom(".d-combobox__trigger")
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
          .dom(".d-combobox__presentation .d-skeleton")
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
      await click(".d-combobox__trigger");
      await duringUpdate(gate, click(optionWithText("Suggest")), () => {
        assert
          .dom(".d-combobox__trigger")
          .hasAttribute("aria-busy", "true", "the trigger is busy");
        assert.true(
          find(".d-combobox__trigger")
            .getAttribute("aria-label")
            .includes("Apple"),
          "the accessible name still carries the held value"
        );
        assert
          .dom(".d-combobox__trigger .d-skeleton")
          .exists("the value slot shows the skeleton");
      });

      assert
        .dom(".d-combobox__trigger")
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
      assert.dom(".d-combobox__caret").doesNotExist("no caret to begin with");

      await click(".d-combobox__trigger");
      await duringUpdate(gate, click(optionWithText("Suggest")), () => {
        assert
          .dom(".d-combobox__pending-icon")
          .exists("the spinner shows although the caret is hidden");
      });

      assert
        .dom(".d-combobox__pending-icon")
        .doesNotExist("the spinner is gone");
      assert.dom(".d-combobox__caret").doesNotExist("the caret stays hidden");
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
          .dom(".d-combobox__chip .d-skeleton")
          .exists("the chips show the loading skeleton");
        assert
          .dom(".d-combobox__chip-list")
          .doesNotIncludeText(
            "Apple",
            "the held chips are replaced while pending"
          );
        assert
          .dom("input[role='combobox']")
          .hasAttribute("aria-busy", "true", "the combobox is busy");
      });

      assert
        .dom(".d-combobox__chip-list")
        .includesText(
          "Cherry pie",
          "the added chip shows once the update ends"
        );
      assert
        .dom(".d-combobox__chip-list")
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
            .dom(".d-combobox__trigger .d-skeleton")
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
          .dom(".d-combobox__trigger [role='alert']")
          .doesNotExist(`${name} shows no inline error in the trigger`);
        assert
          .dom(".d-combobox__pending-icon")
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
          .dom(".d-combobox__pending-icon")
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
        await waitUntil(() => !find(".d-combobox__pending-icon"));
        assert
          .dom(".d-combobox__chip .d-skeleton")
          .doesNotExist("the chips are back at once");
        assert
          .dom(".d-combobox__chip-list")
          .includesText("Apple", "the kept chip shows");
        assert
          .dom(".d-combobox__chip-list")
          .doesNotIncludeText("Banana", "only the removal applied");
      });
      await pressing;

      assert
        .dom(".d-combobox__chip-list")
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
        api.registerBehaviorTransformer("select-on-change", ({ next }) => {
          queued.push(next);
        });
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

    test("an async update re-runs a select-content transformer that reads pending", async function (assert) {
      const gate = deferred();
      withPluginApi((api) => {
        api.registerValueTransformer("select-content", ({ value, context }) => [
          ...value,
          updateRow(
            context.control.pending ? "Loading suggestion" : "Suggest",
            async () => {
              await gate.promise;
            },
            { close: false }
          ),
        ]);
      });

      await render(
        <template><AsyncUpdateHost @items={{ITEMS}} @value={{1}} /></template>
      );
      await click("[role='combobox']");
      await duringUpdate(gate, click(optionWithText("Suggest")), async () => {
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
        await waitUntil(() => !find(".d-combobox__trigger"));
      });

      assert.dom(".d-combobox__trigger").doesNotExist("the select is gone");
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
          "select-item-class",
          ({ value, context }) =>
            context.identifiers.includes("test-select")
              ? [...value, "x-extra", `x-item-${context.item.id}`]
              : value
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
        .hasClass("d-combobox__option", "the core class stays")
        .hasClass("--selected", "the core state modifier stays");
    });

    test("item classes receive the row item and the extension data, without the control", async function (assert) {
      const seen = [];
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-item-class",
          ({ value, context }) => {
            seen.push(context);
            return value;
          }
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
            @kindContext={{kind}}
          />
        </template>
      );
      await click("[role='combobox']");

      const apple = seen.find((context) => context.item?.id === 1);
      assert.true(!!apple, "the transformer runs for the Apple row");
      assert.strictEqual(apple.item, items[0], "item is the raw source item");
      assert.true(
        apple.identifiers.includes("item-class-select"),
        "identifiers include @identifier"
      );
      assert.strictEqual(apple.kind, kind, "kind is the recipe context");
      assert.strictEqual(
        apple.instance,
        instance,
        "instance is the call-site context"
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
          "select-item-class",
          ({ value, context }) =>
            context.selected ? [...value, "is-held"] : value
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
          "select-item-class",
          ({ value, context }) => {
            disabledById[context.item.id] = context.disabled;
            return context.disabled ? [...value, "is-capped"] : value;
          }
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
        api.registerValueTransformer("select-item-class", ({ value }) => [
          ...value,
          "x-row",
        ]);
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
        .dom(".d-combobox__group-header")
        .exists("a labeled group renders a header");
      assert
        .dom(".d-combobox__divider")
        .exists("an unlabeled boundary renders a divider");
      assert
        .dom(".d-combobox__group-header.x-row")
        .doesNotExist("headers are not items");
      assert
        .dom(".d-combobox__divider.x-row")
        .doesNotExist("dividers are not items");
      assert
        .dom("[role='option'].x-row")
        .exists({ count: 4 }, "every option still gets the class");
    });

    test("item classes apply to the none row and the create row", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer("select-item-class", ({ value }) => [
          ...value,
          "x-row",
        ]);
      });
      const createItem = (filter) => ({
        id: filter,
        name: `Create ${filter}`,
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

    test("item classes start from a fresh array for every row and render", async function (assert) {
      const inputs = [];
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-item-class",
          ({ value, context }) => {
            inputs.push({ value, length: value.length });
            value.push(`x-item-${context.item.id}`);
            return value;
          }
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
        new Set(inputs.map(({ value }) => value)).size,
        inputs.length,
        "every call gets its own array"
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
        api.registerValueTransformer("select-item-class", ({ value }) => [
          ...value,
          "x-row",
        ]);
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
      assert.dom(".d-combobox__chip").exists("a held item renders a chip");
      assert
        .dom(".x-row")
        .exists({ count: 4 }, "chips and the trigger get no option classes");
    });

    test("item classes ignore empty and falsy entries", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-item-class",
          ({ value, context }) =>
            context.item.id === 3 ? [...value, null, "", false] : value
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
        ["d-combobox__option"],
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
        api.registerValueTransformer("select-content", ({ value }) =>
          value.slice(0, 2)
        );
      });
      const items = numbered(5);

      await render(
        <template><DSelect @items={{items}} @variant="button" /></template>
      );
      await click(".d-combobox__trigger");

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
        api.registerValueTransformer("select-content", ({ value }) =>
          value.slice(0, 2)
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
      await click(".d-combobox__trigger");

      assert
        .dom("ul[role='listbox'] > .d-combobox__group-header")
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
        api.registerValueTransformer("select-content", ({ value }) => [
          ...value,
          { id: "extra-1", name: "Extra 1" },
          { id: "extra-2", name: "Extra 2" },
        ]);
      });
      const items = numbered(3);

      await render(
        <template><DSelect @items={{items}} @variant="button" /></template>
      );
      await click(".d-combobox__trigger");

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
        api.registerValueTransformer("select-content", ({ value }) =>
          value.filter((item) => item.id % 4 !== 0)
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
      await click(".d-combobox__trigger");

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
      await click(".d-combobox__trigger");

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
      await click(".d-combobox__trigger");
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
        api.registerValueTransformer("select-content", ({ value }) =>
          value.filter((item) => item.id % 4 !== 0)
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
      await click(".d-combobox__trigger");
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
      await click(".d-combobox__trigger");

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
        api.registerValueTransformer("select-content", ({ value }) =>
          value.filter((item) => item.id % 2 === 1)
        );
      });
      await render(
        <template>
          <EngineProbe @debounce={{false}} @load={{load}} @variant="button" />
        </template>
      );
      await click(".d-combobox__trigger");
      const engine = probedEngine();

      const hasFrontier = () =>
        release && find("ul[role='listbox'] .d-combobox__skeleton");
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
