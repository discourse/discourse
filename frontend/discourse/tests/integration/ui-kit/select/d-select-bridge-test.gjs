import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { clearCallbacks } from "discourse/select-kit/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { Host, ITEMS } from "discourse/tests/helpers/d-select-hosts";
import { resetLegacyBridge } from "discourse/ui-kit/select/-internals/modify-select-kit-bridge";
import DSelect from "discourse/ui-kit/select/d-select";

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
        .dom("[role='combobox']")
        .hasValue("", "the action row did not become the selection");
      assert
        .dom("[role='listbox']")
        .exists("an action row keeps the menu open");
    });

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
            @items={{ITEMS}}
            @value={{state.value}}
            @multiple={{state.multiple}}
            @maximum={{state.maximum}}
            @identifier="test-select"
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
