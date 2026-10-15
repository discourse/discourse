import { tracked } from "@glimmer/tracking";
import { click, fillIn, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  Host,
  ITEMS,
  optionWithText,
} from "discourse/tests/helpers/d-select-hosts";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import DSelect from "discourse/ui-kit/select/d-select";

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
