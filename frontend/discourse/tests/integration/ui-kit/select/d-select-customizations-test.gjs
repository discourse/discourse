import { tracked } from "@glimmer/tracking";
import { trackedObject } from "@ember/reactive/collections";
import { click, fillIn, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { ITEMS, optionWithText } from "discourse/tests/helpers/d-select-hosts";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import DSelect from "discourse/ui-kit/select/d-select";

/** Registers one `select-customizations` callback that receives the registry. */
function customize(register) {
  withPluginApi((api) =>
    api.registerValueTransformer("select-customizations", ({ value }) => {
      register(value);
    })
  );
}

module(
  "Integration | ui-kit | select | DSelect select-customizations",
  function (hooks) {
    setupRenderingTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

    test("row classes compose general to specific", async function (assert) {
      customize((selects) => {
        selects.forIdentifier("composer-tags", (spec) =>
          spec.row((row) => row.classes.push("x-identifier"))
        );
        selects.forKind("tag-chooser", (spec) =>
          spec.row((row) => row.classes.push("x-kind"))
        );
        selects.forAll((spec) => spec.row((row) => row.classes.push("x-all")));
      });

      await render(
        <template>
          <DSelect
            @identifier="composer-tags"
            @items={{ITEMS}}
            @kind="tag-chooser"
          />
        </template>
      );
      await click("[role='combobox']");

      assert.deepEqual(
        [...optionWithText("Apple").classList].filter((name) =>
          name.startsWith("x-")
        ),
        ["x-all", "x-kind", "x-identifier"]
      );
    });

    test("setup state is per rendered select and drives re-renders", async function (assert) {
      customize((selects) =>
        selects.forKind("toggler", (spec) => {
          const state = trackedObject({ on: false });
          spec.content((items) => [
            {
              id: "toggle",
              name: state.on ? "Toggle is on" : "Toggle is off",
              onSelect() {
                state.on = !state.on;
              },
            },
            ...items,
          ]);
        })
      );

      await render(
        <template>
          <DSelect @identifier="first" @items={{ITEMS}} @kind="toggler" />
          <DSelect @identifier="second" @items={{ITEMS}} @kind="toggler" />
        </template>
      );

      const [first, second] = document.querySelectorAll("[role='combobox']");
      await click(first);
      await click(optionWithText("Toggle is off"));
      assert.notStrictEqual(
        optionWithText("Toggle is on"),
        undefined,
        "the row follows its select's tracked state"
      );

      await click(second);
      assert.notStrictEqual(
        optionWithText("Toggle is off"),
        undefined,
        "the other select kept its own state"
      );
    });

    test("names are fixed for the select's life", async function (assert) {
      const state = new (class {
        @tracked kind = "first-kind";
      })();
      let setups = 0;
      customize((selects) => {
        selects.forKind("first-kind", (spec) => {
          setups++;
          spec.row((row) => row.classes.push("x-first"));
        });
        selects.forKind("second-kind", (spec) => {
          setups++;
          spec.row((row) => row.classes.push("x-second"));
        });
      });

      await render(
        <template><DSelect @items={{ITEMS}} @kind={{state.kind}} /></template>
      );
      state.kind = "second-kind";
      await settled();
      await click("[role='combobox']");
      await fillIn("[role='combobox']", "a");

      assert.strictEqual(setups, 1, "only the first kind's setup ran, once");
      assert
        .dom(optionWithText("Apple"))
        .hasClass("x-first", "the first kind's customizations still apply")
        .doesNotHaveClass("x-second");
    });

    test("the legacy bridge matches @kind", async function (assert) {
      withPluginApi((api) =>
        api
          .modifySelectKit("bridge-kind")
          .prependContent(() => ({ id: "legacy", name: "Legacy row" }))
      );

      await render(
        <template><DSelect @items={{ITEMS}} @kind="bridge-kind" /></template>
      );
      await click("[role='combobox']");

      assert.notStrictEqual(
        optionWithText("Legacy row"),
        undefined,
        "a kind without an identifier reaches the bridge"
      );
    });

    test("the legacy bridge ignores @identifier", async function (assert) {
      withPluginApi((api) =>
        api
          .modifySelectKit("bridge-identifier")
          .prependContent(() => ({ id: "legacy", name: "Legacy row" }))
      );

      await render(
        <template>
          <DSelect @identifier="bridge-identifier" @items={{ITEMS}} />
        </template>
      );
      await click("[role='combobox']");

      assert.strictEqual(
        optionWithText("Legacy row"),
        undefined,
        "an identifier alone does not reach the bridge"
      );
    });

    test("@identifier still names the menu", async function (assert) {
      await render(
        <template>
          <DSelect
            @identifier="named-menu"
            @items={{ITEMS}}
            @kind="named-kind"
          />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom(".named-menu-trigger")
        .hasAttribute("data-identifier", "named-menu", "the trigger is named");
      assert
        .dom(".named-menu-content")
        .hasAttribute("data-identifier", "named-menu", "the content is named");
      assert
        .dom("[data-identifier='named-kind']")
        .doesNotExist("the kind does not name the menu");
    });
  }
);
