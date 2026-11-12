import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { trackedObject } from "@ember/reactive/collections";
import {
  click,
  fillIn,
  findAll,
  render,
  settled,
  setupOnerror,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  EngineProbe,
  ITEMS,
  optionWithText,
  probedEngine,
} from "discourse/tests/helpers/d-select-hosts";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import { isSelectOption } from "discourse/ui-kit/select/-internals/engine/select-option";
import DSelect from "discourse/ui-kit/select/d-select";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { selectOption } from "discourse/ui-kit/select/select-engine";

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

    test("a load customization that wraps the source keeps the paging cursor", async function (assert) {
      customize((selects) =>
        selects.forKind("paged-recipe", (spec) =>
          spec.load((load) => (query, opts) => load(query, opts))
        )
      );
      const cursors = [];
      const pages = [];
      const load = (_query, opts = {}) => {
        cursors.push(opts.cursor);
        pages.push(opts.page);
        return {
          options: [{ id: cursors.length, name: `Item ${cursors.length}` }],
          hasMore: true,
          cursor: `after-${cursors.length}`,
        };
      };

      await render(
        <template>
          <EngineProbe
            @debounce={{false}}
            @kind="paged-recipe"
            @load={{load}}
          />
        </template>
      );
      await click("[role='combobox']");
      probedEngine().revealMore();
      await settled();

      assert.deepEqual(
        cursors.slice(0, 2),
        [undefined, "after-1"],
        "the wrapped source receives the cursor its previous page returned"
      );
      assert.deepEqual(
        pages.slice(0, 2),
        [1, 2],
        "the wrapped source receives the page number"
      );
    });

    test("row classes compose general to specific", async function (assert) {
      customize((selects) => {
        selects.forIdentifier("composer-tags", (spec) =>
          spec.optionAttributes((attributes) =>
            attributes.classes.push("x-identifier")
          )
        );
        selects.forKind("tag-chooser", (spec) =>
          spec.optionAttributes((attributes) =>
            attributes.classes.push("x-kind")
          )
        );
        selects.forAll((spec) =>
          spec.optionAttributes((attributes) =>
            attributes.classes.push("x-all")
          )
        );
      });

      await render(
        <template>
          <DSelect
            @identifier="composer-tags"
            @kind="tag-chooser"
            @options={{ITEMS}}
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
          spec.content((options) => [
            selectOption(
              {
                id: "toggle",
                name: state.on ? "Toggle is on" : "Toggle is off",
              },
              {
                onSelect() {
                  state.on = !state.on;
                },
              }
            ),
            ...options,
          ]);
        })
      );

      await render(
        <template>
          <DSelect @identifier="first" @kind="toggler" @options={{ITEMS}} />
          <DSelect @identifier="second" @kind="toggler" @options={{ITEMS}} />
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
      const kind = tracked("first-kind");
      let setups = 0;
      customize((selects) => {
        selects.forKind("first-kind", (spec) => {
          setups++;
          spec.optionAttributes((attributes) =>
            attributes.classes.push("x-first")
          );
        });
        selects.forKind("second-kind", (spec) => {
          setups++;
          spec.optionAttributes((attributes) =>
            attributes.classes.push("x-second")
          );
        });
      });

      await render(
        <template><DSelect @kind={{kind.value}} @options={{ITEMS}} /></template>
      );
      kind.value = "second-kind";
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
        <template><DSelect @kind="bridge-kind" @options={{ITEMS}} /></template>
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
          <DSelect @identifier="bridge-identifier" @options={{ITEMS}} />
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
            @kind="named-kind"
            @options={{ITEMS}}
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

/** Registers one `spec.config` callback for every select. */
function overrideOptions(callback) {
  customize((selects) => selects.forAll((spec) => spec.config(callback)));
}

const MANY = Array.from({ length: 30 }, (_, i) => ({
  id: i + 1,
  name: `Row ${i + 1}`,
}));

module(
  "Integration | ui-kit | select | DSelect select-customizations | options and rows",
  function (hooks) {
    setupRenderingTest(hooks);

    test("caretIcon swaps the open and closed glyphs", async function (assert) {
      overrideOptions(() => ({
        caretIcon: { open: "chevron-up", closed: "chevron-right" },
      }));

      await render(
        <template>
          <DSelect @options={{ITEMS}} @value={{1}} @variant="static" />
        </template>
      );
      assert.dom(".d-select__caret").hasClass("d-icon-chevron-right");

      await click("[role='combobox']");
      assert.dom(".d-select__caret").hasClass("d-icon-chevron-up");
    });

    test("caretIcon overrides the call site's @caretIcon", async function (assert) {
      overrideOptions(() => ({ caretIcon: "caret-down" }));

      await render(
        <template>
          <DSelect
            @caretIcon="angles-down"
            @options={{ITEMS}}
            @value={{1}}
            @variant="static"
          />
        </template>
      );

      assert.dom(".d-select__caret").hasClass("d-icon-caret-down");
    });

    test("showCaret hides the caret", async function (assert) {
      overrideOptions(() => ({ showCaret: false }));

      await render(
        <template>
          <DSelect @options={{ITEMS}} @value={{1}} @variant="static" />
        </template>
      );

      assert.dom(".d-select__caret").doesNotExist();
    });

    test("icon renders a leading icon", async function (assert) {
      overrideOptions(() => ({ icon: "gear" }));

      await render(
        <template>
          <DSelect @options={{ITEMS}} @value={{1}} @variant="static" />
        </template>
      );

      assert.dom(".d-select__leading-icon").hasClass("d-icon-gear");
    });

    test("clearable offers the clear control", async function (assert) {
      overrideOptions(() => ({ clearable: true }));

      await render(
        <template>
          <DSelect @options={{ITEMS}} @value={{1}} @variant="static" />
        </template>
      );

      assert.dom(".d-select__clear").exists();
    });

    test("placeholder reaches the single trigger of every variant", async function (assert) {
      overrideOptions(() => ({ texts: { placeholder: "From extension" } }));

      await render(
        <template>
          <div class="static-host">
            <DSelect
              @options={{ITEMS}}
              @texts={{hash placeholder="From call site"}}
              @variant="static"
            />
          </div>
          <div class="typeahead-host">
            <DSelect
              @options={{ITEMS}}
              @texts={{hash placeholder="From call site"}}
            />
          </div>
        </template>
      );

      assert
        .dom(".static-host .d-select__placeholder")
        .hasText("From extension", "the static trigger shows it");
      assert
        .dom(".typeahead-host [role='combobox']")
        .hasAttribute(
          "placeholder",
          "From extension",
          "the typeahead input shows it"
        );
    });

    test("placeholder reaches the multi-select input", async function (assert) {
      overrideOptions(() => ({ texts: { placeholder: "From extension" } }));
      const none = [];

      await render(
        <template>
          <DSelect @multiple={{true}} @options={{ITEMS}} @value={{none}} />
        </template>
      );

      assert
        .dom(".d-select__input")
        .hasAttribute("placeholder", "From extension");
    });

    test("searchPlaceholder reaches the panel filter", async function (assert) {
      overrideOptions(() => ({ texts: { searchPlaceholder: "Find a fruit" } }));

      await render(
        <template><DSelect @options={{ITEMS}} @variant="button" /></template>
      );
      await click(".d-select__trigger");

      assert
        .dom(".d-select__filter")
        .hasAttribute("placeholder", "Find a fruit");
    });

    test("searchIcon reaches the panel search field", async function (assert) {
      overrideOptions(() => ({ searchIcon: "magnifying-glass" }));

      await render(
        <template><DSelect @options={{ITEMS}} @variant="button" /></template>
      );
      await click(".d-select__trigger");

      assert.dom(".d-select__panel .d-icon-magnifying-glass").exists();
    });

    test("loadingStatus and loadingLabel reach the loading state", async function (assert) {
      overrideOptions(() => ({
        loadingStatus: true,
        texts: { loadingLabel: "From extension" },
      }));
      let resolveLoad;
      const load = () => new Promise((resolve) => (resolveLoad = resolve));

      await render(<template><DSelect @load={{load}} /></template>);
      const typing = fillIn("[role='combobox']", "x");
      await waitFor(".d-select__skeleton");

      assert.dom(".d-select__loading-status").hasText("From extension");

      resolveLoad([]);
      await typing;
    });

    test("ariaLabel names the combobox and the listbox", async function (assert) {
      overrideOptions(() => ({ texts: { ariaLabel: "Fruit picker" } }));

      await render(
        <template>
          <DSelect @options={{ITEMS}} @texts={{hash ariaLabel="Call site"}} />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom("[role='combobox']")
        .hasAttribute("aria-label", "Fruit picker", "the combobox is named");
      assert
        .dom("[role='listbox']")
        .hasAttribute("aria-label", "Fruit picker", "the listbox is named");
    });

    test("noneLabel renames the call site's none row", async function (assert) {
      overrideOptions(() => ({ texts: { noneLabel: "Nothing" } }));

      await render(
        <template>
          <DSelect
            @noneOption={{true}}
            @options={{ITEMS}}
            @texts={{hash noneLabel="None"}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert.dom("[role='option'].--none").hasText("Nothing");
    });

    test("noneOption adds a none row where the call site has none", async function (assert) {
      overrideOptions(() => ({
        noneOption: true,
        texts: { noneLabel: "Nothing" },
      }));

      await render(<template><DSelect @options={{ITEMS}} /></template>);
      await click("[role='combobox']");

      assert.dom("[role='option'].--none").hasText("Nothing");
    });

    test("disabled locks the control", async function (assert) {
      overrideOptions(() => ({ disabled: true }));

      await render(
        <template>
          <div class="static-host">
            <DSelect
              @clearable={{true}}
              @options={{ITEMS}}
              @value={{1}}
              @variant="static"
            />
          </div>
          <div class="typeahead-host">
            <DSelect @options={{ITEMS}} @value={{1}} />
          </div>
        </template>
      );

      assert
        .dom(".static-host [role='combobox']")
        .hasAria("disabled", "true", "the static control is aria-disabled");
      assert
        .dom(".static-host .d-select__clear")
        .doesNotExist("a disabled control offers no clear");
      assert
        .dom(".typeahead-host [role='combobox']")
        .isDisabled("the typeahead input is natively disabled");

      await click(".static-host [role='combobox']");
      assert.dom("[role='listbox']").doesNotExist("it does not open");
    });

    test("disabled can only add a lock, never lift the call site's", async function (assert) {
      overrideOptions(() => ({ disabled: false }));

      await render(
        <template>
          <DSelect
            @disabled={{true}}
            @options={{ITEMS}}
            @value={{1}}
            @variant="static"
          />
        </template>
      );

      assert.dom("[role='combobox']").hasAria("disabled", "true");
    });

    test("a disabled override that reads the value and control renders without a cycle", async function (assert) {
      overrideOptions((current, context) => ({
        disabled: context.value === 1 && !context.control.pending,
      }));

      await render(
        <template>
          <DSelect @options={{ITEMS}} @value={{1}} @variant="static" />
        </template>
      );

      assert.dom("[role='combobox']").hasAria("disabled", "true");
    });

    test("iconOnly suppresses the label when a label resolves", async function (assert) {
      overrideOptions(() => ({ iconOnly: true, icon: "gear" }));

      await render(
        <template>
          <DSelect
            @options={{ITEMS}}
            @texts={{hash ariaLabel="Settings"}}
            @value={{2}}
            @variant="static"
          />
        </template>
      );

      assert.dom(".d-select__trigger.--icon-only").exists();
      assert.dom(".d-select__value").doesNotExist("the value text is hidden");
    });

    test("iconOnly is ignored with a warning when no label resolves", async function (assert) {
      const warn = sinon.stub(console, "warn");
      overrideOptions(() => ({ iconOnly: true, icon: "gear" }));

      try {
        await render(
          <template>
            <DSelect @options={{ITEMS}} @value={{2}} @variant="static" />
          </template>
        );

        assert
          .dom(".d-select__trigger.--icon-only")
          .doesNotExist("the trigger keeps its text layout");
        assert.dom(".d-select__value").hasText("Banana", "the value shows");
        assert.true(
          warn.calledWithMatch("iconOnly"),
          "a warning names the ignored option"
        );
      } finally {
        warn.restore();
      }
    });

    test("tiers resolve last-wins from the call site's values", async function (assert) {
      const seen = [];
      customize((selects) => {
        selects.forIdentifier("fruit", (spec) =>
          spec.config((current) => {
            seen.push(["identifier", current.texts.ariaLabel]);
            return { texts: { ariaLabel: "From identifier" } };
          })
        );
        selects.forKind("picker", (spec) =>
          spec.config((current) => {
            seen.push(["kind", current.texts.ariaLabel]);
            return { texts: { ariaLabel: "From kind" } };
          })
        );
        selects.forAll((spec) =>
          spec.config((current) => {
            seen.push(["all", current.texts.ariaLabel]);
            return { texts: { ariaLabel: "From all", placeholder: "Kept" } };
          })
        );
      });

      await render(
        <template>
          <DSelect
            @identifier="fruit"
            @kind="picker"
            @options={{ITEMS}}
            @texts={{hash ariaLabel="Call site"}}
          />
        </template>
      );

      assert.deepEqual(
        seen.slice(0, 3),
        [
          ["all", "Call site"],
          ["kind", "From all"],
          ["identifier", "From kind"],
        ],
        "each tier sees the value so far"
      );
      assert
        .dom("[role='combobox']")
        .hasAttribute("aria-label", "From identifier", "the most specific wins")
        .hasAttribute("placeholder", "Kept", "keys a later tier omits stay");
    });

    test("options follow tracked setup state", async function (assert) {
      customize((selects) =>
        selects.forAll((spec) => {
          const state = trackedObject({ suggesting: false });
          spec.config(() => (state.suggesting ? { caretIcon: "spinner" } : {}));
          spec.content((options) => [
            selectOption(
              { id: "toggle", name: "Toggle" },
              {
                onSelect() {
                  state.suggesting = !state.suggesting;
                },
              }
            ),
            ...options,
          ]);
        })
      );

      await render(
        <template>
          <DSelect
            @caretIcon="caret-down"
            @options={{ITEMS}}
            @value={{1}}
            @variant="static"
          />
        </template>
      );
      await click("[role='combobox']");
      assert.dom(".d-select__caret").hasClass("d-icon-caret-down");

      await click(optionWithText("Toggle"));
      assert
        .dom(".d-select__caret")
        .hasClass("d-icon-spinner", "the caret follows the state");
    });

    test("config callbacks run per change, not per row", async function (assert) {
      const label = tracked("First");
      let calls = 0;
      overrideOptions(() => {
        calls++;
        return { texts: { ariaLabel: label.value } };
      });

      await render(<template><DSelect @options={{MANY}} /></template>);
      await click("[role='combobox']");
      assert.true(calls >= 1, "the options were resolved");
      assert.true(
        calls <= 2,
        `rendering thirty rows resolved the config ${calls} times`
      );

      const before = calls;
      label.value = "Second";
      await settled();
      assert
        .dom("[role='combobox']")
        .hasAttribute("aria-label", "Second", "the change applied");
      assert.true(calls > before, "the change re-resolved the config");
      assert.true(
        calls - before <= 2,
        `one change resolved the config ${calls - before} times`
      );
    });

    test("config callbacks receive the names, data, value and control, but no config", async function (assert) {
      let seen;
      const kindContext = { scope: "recipe" };
      const instanceContext = { topicId: 7 };
      customize((selects) =>
        selects.forKind("picker", (spec) =>
          spec.config((current, context) => {
            seen = context;
            return {};
          })
        )
      );

      await render(
        <template>
          <DSelect
            @identifier="fruit"
            @instanceContext={{instanceContext}}
            @kind="picker"
            @kindContext={{kindContext}}
            @options={{ITEMS}}
            @value={{2}}
          />
        </template>
      );

      assert.strictEqual(seen.kind, "picker");
      assert.strictEqual(seen.identifier, "fruit");
      assert.strictEqual(seen.kindContext, kindContext);
      assert.strictEqual(seen.instanceContext, instanceContext);
      assert.strictEqual(seen.value, 2, "the normalized value");
      assert.strictEqual(seen.control.value, 2, "a control to read from");
      assert.false("config" in seen, "no resolved config, which would cycle");
    });

    test("a non-object result is skipped and an unknown key warns", async function (assert) {
      const warn = sinon.stub(console, "warn");
      customize((selects) => {
        selects.forAll((spec) => spec.config(() => undefined));
        selects.forAll((spec) => spec.config(() => "label"));
        selects.forAll((spec) =>
          spec.config(() => ({ texts: { ariaLabel: "Kept" }, lable: "Typo" }))
        );
      });

      try {
        await render(<template><DSelect @options={{ITEMS}} /></template>);

        assert
          .dom("[role='combobox']")
          .hasAttribute("aria-label", "Kept", "valid results still apply");
        assert.true(
          warn.calledWithMatch("lable"),
          "the unknown key is named in a warning"
        );
      } finally {
        warn.restore();
      }
    });

    test("a row title renders only when a customization sets one", async function (assert) {
      const items = [
        { id: 1, name: "Apple", title: "A raw title field" },
        { id: 2, name: "Banana" },
      ];
      customize((selects) =>
        selects.forKind("titled", (spec) =>
          spec.optionAttributes((attributes, context) => {
            if (context.record.id === 2) {
              attributes.title = "Ripe";
            }
          })
        )
      );

      await render(
        <template>
          <div class="plain"><DSelect @options={{items}} /></div>
          <div class="titled"><DSelect
              @kind="titled"
              @options={{items}}
            /></div>
        </template>
      );
      const [plain, titled] = document.querySelectorAll("[role='combobox']");

      await click(plain);
      assert
        .dom(optionWithText("Apple"))
        .doesNotHaveAttribute("title", "an item's own title is not a tooltip");

      await click(titled);
      const options = [...document.querySelectorAll("[role='option']")];
      const banana = options.filter(
        (option) => option.textContent.trim() === "Banana"
      );
      assert.true(
        banana.some((option) => option.getAttribute("title") === "Ripe"),
        "the customized row carries the title"
      );
      assert.true(
        options
          .filter((option) => option.textContent.trim() === "Apple")
          .every((option) => !option.hasAttribute("title")),
        "rows it left alone carry none"
      );
    });

    test("a row customization runs once per rendered row", async function (assert) {
      const runs = new Map();
      customize((selects) =>
        selects.forAll((spec) =>
          spec.optionAttributes((attributes, context) => {
            runs.set(context.record.id, (runs.get(context.record.id) ?? 0) + 1);
            attributes.title = `Row ${context.record.id}`;
            attributes.classes.push("x-row");
          })
        )
      );

      await render(<template><DSelect @options={{ITEMS}} /></template>);
      await click("[role='combobox']");

      assert.dom("[role='option'][title].x-row").exists({ count: 3 });
      assert.deepEqual(
        [...runs.values()],
        [1, 1, 1],
        "classes and title come from one run per row"
      );
    });
  }
);

/** Every tier appends to the recipe's `prefix`, so a delivered value proves it was resolved. */
function customizeRecipe() {
  customize((selects) =>
    selects.forKind("recipe", (spec) =>
      spec.config((current) => ({ prefix: `${current.prefix}+kind` }))
    )
  );
}

module(
  "Integration | ui-kit | select | DSelect select-customizations | recipe config",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a recipe key resolves from the call site through every tier", async function (assert) {
      const seen = [];
      customize((selects) => {
        selects.forIdentifier("crumb", (spec) =>
          spec.config((current) => {
            seen.push(current.prefix);
            return { prefix: `${current.prefix}+identifier` };
          })
        );
        selects.forKind("recipe", (spec) =>
          spec.config((current) => {
            seen.push(current.prefix);
            return { prefix: `${current.prefix}+kind` };
          })
        );
        selects.forAll((spec) =>
          spec.config((current) => {
            seen.push(current.prefix);
            return { prefix: `${current.prefix}+all` };
          })
        );
      });

      await render(
        <template>
          <DSelect
            @identifier="crumb"
            @kind="recipe"
            @kindConfig={{hash prefix="base"}}
            @options={{ITEMS}}
          >
            <:option as |item options|>
              {{~concat options.prefix " " item.name~}}
            </:option>
          </DSelect>
        </template>
      );
      await click("[role='combobox']");

      assert.deepEqual(
        seen.slice(0, 3),
        ["base", "base+all", "base+all+kind"],
        "each tier sees the call site's value, then the tiers before it"
      );
      assert
        .dom(optionWithText("base+all+kind+identifier Apple"))
        .exists("the recipe renders the most specific value");
    });

    test("the resolved config reaches the items function", async function (assert) {
      customizeRecipe();
      const itemsFor = (options) => [{ id: 1, name: `${options?.prefix} one` }];

      await render(
        <template>
          <DSelect
            @kind="recipe"
            @kindConfig={{hash prefix="base"}}
            @options={{itemsFor}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert.dom("[role='option']").hasText("base+kind one");
    });

    test("a zero-argument items function still works", async function (assert) {
      const itemsFor = () => ITEMS;

      await render(<template><DSelect @options={{itemsFor}} /></template>);
      await click("[role='combobox']");

      assert.dom("[role='option']").exists({ count: 3 });
    });

    test("the resolved config reaches @load, @resolveValue and @resolveValues", async function (assert) {
      customizeRecipe();
      const seen = {};
      const load = (filter, opts) => {
        seen.load = opts.config?.prefix;
        return [{ id: 1, name: "One" }];
      };
      const resolveValue = (value, opts) => {
        seen.resolveValue = opts.config?.prefix;
        return { id: value, name: `Item ${value}` };
      };
      const resolveValues = (values, opts) => {
        seen.resolveValues = opts.config?.prefix;
        return values.map((id) => ({ id, name: `Item ${id}` }));
      };
      const held = [8];

      await render(
        <template>
          <div class="single">
            <DSelect
              @debounce={{false}}
              @kind="recipe"
              @kindConfig={{hash prefix="base"}}
              @load={{load}}
              @resolveValue={{resolveValue}}
              @value={{7}}
              @variant="static"
            />
          </div>
          <div class="multi">
            <DSelect
              @kind="recipe"
              @kindConfig={{hash prefix="base"}}
              @load={{load}}
              @multiple={{true}}
              @resolveValues={{resolveValues}}
              @value={{held}}
            />
          </div>
        </template>
      );

      await click(".single [role='combobox']");

      assert.deepEqual(seen, {
        load: "base+kind",
        resolveValue: "base+kind",
        resolveValues: "base+kind",
      });
    });

    test("the resolved config reaches onChange as part of its third argument", async function (assert) {
      customizeRecipe();
      const onChange = sinon.spy();

      await render(
        <template>
          <DSelect
            @kind="recipe"
            @kindConfig={{hash prefix="base"}}
            @onChange={{onChange}}
            @options={{ITEMS}}
          />
        </template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Banana"));

      assert.true(onChange.calledOnce);
      const [value, item, change] = onChange.firstCall.args;
      assert.strictEqual(value, 2, "the value keeps its position");
      assert.strictEqual(item.name, "Banana", "so does the item");
      assert.strictEqual(change.config?.prefix, "base+kind");
    });

    test("the resolved config reaches every recipe callback as the last argument", async function (assert) {
      customizeRecipe();
      const seen = {};
      const record = (name, options) => (seen[name] = options?.prefix);
      const items = [
        { id: 1, name: "Apple", section: "fruit" },
        { id: 2, name: "Beet", section: "root" },
      ];
      let snapshot;
      const allowCreate = (filter, list, options) => {
        record("allowCreate", options);
        return true;
      };
      const createOption = (filter, options) => {
        record("createOption", options);
        return { id: filter, name: filter };
      };
      const createUnresolvedRecord = (value, options) => {
        record("createUnresolvedRecord", options);
        return { id: value, name: `Missing ${value}` };
      };
      const extraOptions = (state, options) => {
        snapshot = state;
        record("extraOptions", options);
        return [];
      };
      const filterBy = (item, term, options) => {
        record("filterBy", options);
        return item.name.toLowerCase().includes(term.toLowerCase());
      };
      const groupBy = (item, options) => {
        record("groupBy", options);
        return item.section;
      };
      const groupHeader = (key, rows, options) => {
        record("groupHeader", options);
        return key;
      };
      const groupFooter = (key, rows, options) => {
        record("groupFooter", options);
        return key;
      };

      await render(
        <template>
          <DSelect
            @allowCreate={{allowCreate}}
            @createOption={{createOption}}
            @createUnresolvedRecord={{createUnresolvedRecord}}
            @extraOptions={{extraOptions}}
            @filterBy={{filterBy}}
            @groupBy={{groupBy}}
            @groupFooter={{groupFooter}}
            @groupHeader={{groupHeader}}
            @kind="recipe"
            @kindConfig={{hash prefix="base"}}
            @options={{items}}
            @value={{99}}
          />
        </template>
      );
      await click("[role='combobox']");
      await fillIn("[role='combobox']", "a");

      assert.deepEqual(seen, {
        allowCreate: "base+kind",
        createOption: "base+kind",
        createUnresolvedRecord: "base+kind",
        filterBy: "base+kind",
        groupBy: "base+kind",
        groupFooter: "base+kind",
        groupHeader: "base+kind",
        extraOptions: "base+kind",
      });
      assert.deepEqual(
        Object.keys(snapshot).sort(),
        ["filter", "hasValue", "value"],
        "the snapshot argument is unchanged"
      );
    });

    test("the resolved config reaches the blocks as the last parameter", async function (assert) {
      customizeRecipe();
      const items = [{ id: 1, name: "Apple", section: "fruit" }];
      const groupHeader = (key) => key;
      const groupFooter = (key) => `${key} end`;

      await render(
        <template>
          <div class="held">
            <DSelect
              @groupBy="section"
              @groupFooter={{groupFooter}}
              @groupHeader={{groupHeader}}
              @kind="recipe"
              @kindConfig={{hash prefix="base"}}
              @options={{items}}
              @value={{1}}
              @variant="static"
            >
              <:option as |item options|>
                <span class="x-item">{{options.prefix}}</span>
              </:option>
              <:selection as |item options|>
                <span class="x-selection">{{options.prefix}}</span>
              </:selection>
              <:groupHeader as |header options|>
                <span class="x-header">{{options.prefix}}</span>
              </:groupHeader>
              <:groupFooter as |footer options|>
                <span class="x-group-footer">{{options.prefix}}</span>
              </:groupFooter>
              <:footer as |state options|>
                <span class="x-footer">{{options.prefix}}</span>
              </:footer>
            </DSelect>
          </div>
          <div class="missing">
            <DSelect
              @kind="recipe"
              @kindConfig={{hash prefix="base"}}
              @options={{items}}
              @value={{99}}
              @variant="static"
            >
              <:unresolved as |item options|>
                <span class="x-unresolved">{{options.prefix}}</span>
              </:unresolved>
            </DSelect>
          </div>
        </template>
      );

      assert.dom(".x-selection").hasText("base+kind");
      assert.dom(".x-unresolved").hasText("base+kind");

      await click(".held [role='combobox']");
      assert.dom(".x-item").hasText("base+kind");
      assert.dom(".x-header").hasText("base+kind");
      assert.dom(".x-group-footer").hasText("base+kind");
      assert.dom(".x-footer").hasText("base+kind");
    });

    test("delivered options carry the resolved core keys too", async function (assert) {
      const itemsFor = (options) => [
        { id: 1, name: options?.texts?.ariaLabel },
      ];
      customize((selects) =>
        selects.forKind("recipe", (spec) =>
          spec.config(() => ({ texts: { ariaLabel: "From extension" } }))
        )
      );

      await render(
        <template>
          <DSelect
            @kind="recipe"
            @kindConfig={{hash prefix="base"}}
            @options={{itemsFor}}
            @texts={{hash ariaLabel="Call site"}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert.dom("[role='option']").hasText("From extension");
    });

    test("recipe values stay live", async function (assert) {
      customizeRecipe();
      const prefix = tracked("first");

      await render(
        <template>
          <DSelect
            @kind="recipe"
            @kindConfig={{hash prefix=prefix.value}}
            @options={{ITEMS}}
          >
            <:option as |item options|>
              {{~concat options.prefix " " item.name~}}
            </:option>
          </DSelect>
        </template>
      );
      await click("[role='combobox']");
      assert.dom(optionWithText("first+kind Apple")).exists();

      prefix.value = "second";
      await settled();
      assert.dom(optionWithText("second+kind Apple")).exists();
    });

    test("null in the hash counts as absent, but the key stays declared", async function (assert) {
      const warn = sinon.stub(console, "warn");
      let seen;
      customize((selects) =>
        selects.forKind("recipe", (spec) =>
          spec.config((current) => {
            seen = current;
            return { prefix: "set" };
          })
        )
      );

      try {
        await render(
          <template>
            <DSelect
              @kind="recipe"
              @kindConfig={{hash prefix=null}}
              @options={{ITEMS}}
            >
              <:option as |item options|>
                {{~concat options.prefix " " item.name~}}
              </:option>
            </DSelect>
          </template>
        );
        await click("[role='combobox']");

        assert.true("prefix" in seen, "the key is declared");
        assert.strictEqual(seen.prefix, undefined, "with no base value");
        assert.dom(optionWithText("set Apple")).exists("the override applies");
        assert.false(warn.calledWithMatch("prefix"), "and it does not warn");
      } finally {
        warn.restore();
      }
    });

    test("only keys that are neither core nor declared warn", async function (assert) {
      const warn = sinon.stub(console, "warn");
      customize((selects) =>
        selects.forKind("recipe", (spec) =>
          spec.config(() => ({
            prefix: "ok",
            texts: { ariaLabel: "ok" },
            sufix: "typo",
          }))
        )
      );

      try {
        await render(
          <template>
            <DSelect
              @kind="recipe"
              @kindConfig={{hash prefix="base"}}
              @options={{ITEMS}}
            />
          </template>
        );

        assert.true(warn.calledWithMatch("sufix"), "the typo warns");
        assert.false(warn.calledWithMatch('"prefix"'), "a recipe key does not");
        assert.false(warn.calledWithMatch('"texts"'), "a core key does not");
        assert.false(warn.calledWithMatch("ariaLabel"), "nor a core text");
      } finally {
        warn.restore();
      }
    });

    test("@kindConfig without @kind asserts", async function (assert) {
      let message;
      setupOnerror((error) => (message ??= error.message));

      await render(
        <template>
          <DSelect @kindConfig={{hash prefix="base"}} @options={{ITEMS}} />
        </template>
      );

      assert.true(
        !!message?.includes("@kindConfig"),
        `the assertion names @kindConfig: ${message}`
      );
      assert.true(
        /@kind(?!Options)/.test(message ?? ""),
        `and the missing @kind: ${message}`
      );
    });

    test("a recipe key named like a core key asserts", async function (assert) {
      let message;
      setupOnerror((error) => (message ??= error.message));

      await render(
        <template>
          <DSelect
            @kind="recipe"
            @kindConfig={{hash ariaLabel="Mine"}}
            @options={{ITEMS}}
          />
        </template>
      );

      assert.true(
        message?.includes("ariaLabel"),
        `the assertion names the colliding key: ${message}`
      );
    });

    test("every point's context carries the resolved config", async function (assert) {
      customizeRecipe();
      const seen = {};
      customize((selects) =>
        selects.forKind("recipe", (spec) => {
          spec.content((items, context) => {
            seen.content = context.config;
            return items;
          });
          spec.optionAttributes((attributes, context) => {
            seen.row = context.config;
          });
          spec.load((load, context) => {
            seen.load = context.config;
            return load;
          });
          spec.change((next, context) => {
            seen.change = context.config;
            next();
          });
        })
      );
      const load = () => ITEMS;

      await render(
        <template>
          <DSelect
            @debounce={{false}}
            @kind="recipe"
            @kindConfig={{hash prefix="base"}}
            @load={{load}}
          />
        </template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Banana"));

      for (const point of ["content", "row", "load", "change"]) {
        assert.strictEqual(
          seen[point]?.prefix,
          "base+kind",
          `${point} sees the resolved value`
        );
        assert.true(Object.isFrozen(seen[point]), `${point} gets a snapshot`);
      }
    });

    test("a change middleware and the emit it lets through share one snapshot", async function (assert) {
      customizeRecipe();
      let middlewareConfig;
      customize((selects) =>
        selects.forKind("recipe", (spec) =>
          spec.change((next, context) => {
            middlewareConfig = context.config;
            next();
          })
        )
      );
      const onChange = sinon.spy();

      await render(
        <template>
          <DSelect
            @kind="recipe"
            @kindConfig={{hash prefix="base"}}
            @onChange={{onChange}}
            @options={{ITEMS}}
          />
        </template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Banana"));

      assert.strictEqual(onChange.firstCall.args[2].config, middlewareConfig);
    });

    test("the change context carries the control", async function (assert) {
      let contentControl;
      let changeControl;
      let reloadedAfterEmit = false;
      customize((selects) =>
        selects.forAll((spec) => {
          spec.content((items, context) => {
            contentControl = context.control;
            return items;
          });
          spec.change(async (next, context) => {
            changeControl = context.control;
            await next();
            // Guarded so a missing control fails the assertions below, not the whole run.
            if (context.control) {
              context.control.reload();
              reloadedAfterEmit = true;
            }
          });
        })
      );

      await render(<template><DSelect @options={{ITEMS}} /></template>);
      await click("[role='combobox']");
      await click(optionWithText("Banana"));

      assert.strictEqual(changeControl, contentControl, "the same control");
      assert.true(reloadedAfterEmit, "it can reload after the emit");
    });

    test("one options callback drives a core and a recipe key from tracked setup state", async function (assert) {
      customize((selects) =>
        selects.forKind("recipe", (spec) => {
          const state = trackedObject({ suggesting: false });
          spec.config(() =>
            state.suggesting
              ? { texts: { placeholder: "Suggesting" }, prefix: "suggest" }
              : { texts: { placeholder: "Browsing" }, prefix: "browse" }
          );
          spec.content((options) => [
            selectOption(
              { id: "toggle", name: "Toggle" },
              {
                onSelect() {
                  state.suggesting = !state.suggesting;
                },
              }
            ),
            ...options,
          ]);
        })
      );

      await render(
        <template>
          <DSelect
            @kind="recipe"
            @kindConfig={{hash prefix="base"}}
            @options={{ITEMS}}
          >
            <:option as |item options|>
              {{~concat options.prefix " " item.name~}}
            </:option>
          </DSelect>
        </template>
      );
      await click("[role='combobox']");
      assert.dom("[role='combobox']").hasAttribute("placeholder", "Browsing");
      assert.dom(optionWithText("browse Apple")).exists();

      await click(optionWithText("browse Toggle"));
      assert.dom("[role='combobox']").hasAttribute("placeholder", "Suggesting");
      assert.dom(optionWithText("suggest Apple")).exists();
    });

    test("an async select's items function sees the resolved config during construction", async function (assert) {
      customizeRecipe();
      const calls = [];
      const itemsFor = (options) => {
        calls.push(options?.prefix);
        return [];
      };
      const load = () => ITEMS;

      await render(
        <template>
          <DSelect
            @kind="recipe"
            @kindConfig={{hash prefix="base"}}
            @load={{load}}
            @options={{itemsFor}}
          />
        </template>
      );

      assert.true(calls.length > 0, "construction read the items function");
      assert.strictEqual(calls[0], "base+kind", "with the resolved config");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect select-customizations load context",
  function (hooks) {
    setupRenderingTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

    test("spec.load sees the load context", async function (assert) {
      const seen = [];
      customize((selects) =>
        selects.forKind("recipe", (spec) =>
          spec.load((load, context) => {
            seen.push(context.loadContext);
            return load;
          })
        )
      );
      const load = () => ITEMS;

      await render(
        <template>
          <DSelect
            @kind="recipe"
            @load={{load}}
            @loadContext={{hash categoryId=7}}
            @variant="button"
          />
        </template>
      );
      await click(".d-select__trigger");

      assert.strictEqual(
        seen.at(-1)?.categoryId,
        7,
        "the load customization context carries loadContext"
      );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (legacy kind)",
  function (hooks) {
    setupRenderingTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

    const MINI_AND_INTERSECTION = [
      "tags-intersection-chooser",
      "mini-tag-chooser",
    ];
    const noop = () => {};

    test("the root carries each legacy name as a class", async function (assert) {
      await render(
        <template>
          <div class="one">
            <DSelect
              @kind="select-tag"
              @legacyKind="mini-tag-chooser"
              @options={{ITEMS}}
            />
          </div>
          <div class="many">
            <DSelect
              @kind="select-tag-filter"
              @legacyKind={{MINI_AND_INTERSECTION}}
              @options={{ITEMS}}
            />
          </div>
          <div class="list">
            <DSelectList
              @kind="select-tag"
              @legacyKind="tag-chooser"
              @onChange={{noop}}
              @options={{ITEMS}}
            />
          </div>
        </template>
      );

      assert.dom(".one .d-select").hasClass("mini-tag-chooser");
      assert.dom(".many .d-select").hasClass("tags-intersection-chooser");
      assert.dom(".many .d-select").hasClass("mini-tag-chooser");
      assert.dom(".list .d-select").hasClass("tag-chooser");
    });

    test("forKind customizations match only the new kind", async function (assert) {
      customize((selects) => {
        selects.forKind("select-tag", (spec) =>
          spec.optionAttributes((attributes) =>
            attributes.classes.push("x-new-kind")
          )
        );
        selects.forKind("mini-tag-chooser", (spec) =>
          spec.optionAttributes((attributes) =>
            attributes.classes.push("x-legacy-kind")
          )
        );
      });

      await render(
        <template>
          <DSelect
            @kind="select-tag"
            @legacyKind="mini-tag-chooser"
            @options={{ITEMS}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert.true(optionWithText("Apple").classList.contains("x-new-kind"));
      assert.false(
        optionWithText("Apple").classList.contains("x-legacy-kind"),
        "a legacy name is for the deprecated bridge only"
      );
    });

    test("DSelectList applies content callbacks on its legacy name", async function (assert) {
      withPluginApi((api) =>
        api
          .modifySelectKit("mini-tag-chooser")
          .appendContent(() => ({ id: "legacy-row", name: "Legacy row" }))
      );

      await render(
        <template>
          <DSelectList
            @kind="select-tag"
            @legacyKind="mini-tag-chooser"
            @onChange={{noop}}
            @options={{ITEMS}}
            @virtualized={{false}}
          />
        </template>
      );

      assert.true(
        Boolean(optionWithText("Legacy row")),
        "the legacy callback's row is listed"
      );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect select-customizations | options and records",
  function (hooks) {
    setupRenderingTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

    test("option attributes get the option and its record", async function (assert) {
      const selected = { id: 1, name: "Selected" };
      const disabled = { id: 2, name: "Disabled" };
      const options = [
        selectOption(selected, { description: "Chosen" }),
        selectOption(disabled, { disabled: true }),
      ];
      const contexts = [];
      customize((selects) => {
        selects.forAll((spec) => {
          spec.optionAttributes((attributes, context) => {
            contexts.push(context);
            attributes.classes.push("opt-all");
            attributes.title =
              context.option?.description ?? context.record?.name;
          });
        });
        selects.forKind("opt-attributes", (spec) =>
          spec.optionAttributes((attributes) =>
            attributes.classes.push("opt-kind")
          )
        );
        selects.forIdentifier("opt-instance", (spec) =>
          spec.optionAttributes((attributes) =>
            attributes.classes.push("opt-instance")
          )
        );
      });

      await render(
        <template>
          <DSelect
            @identifier="opt-instance"
            @kind="opt-attributes"
            @options={{options}}
            @value={{1}}
            @virtualized={{false}}
          />
        </template>
      );
      await click("[role='combobox']");

      const selectedContext = contexts.find(
        (context) => context.record === selected
      );
      const disabledContext = contexts.find(
        (context) => context.record === disabled
      );
      assert.strictEqual(
        selectedContext?.option?.record,
        selected,
        "context option holds the exact caller record"
      );
      assert.strictEqual(
        selectedContext?.option?.description,
        "Chosen",
        "context option carries settings"
      );
      assert.true(selectedContext?.selected, "the context reports selection");
      assert.false(
        selectedContext?.disabled,
        "the selected option remains enabled"
      );
      assert.true(disabledContext?.disabled, "the context reports disabled");
      assert.false(
        disabledContext?.selected,
        "the other option is not selected"
      );
      assert.true(
        contexts.length >= 2,
        "the attributes step ran for both records"
      );
      assert
        .dom("[role='option'][data-value='1']")
        .hasAttribute("title", "Chosen", "the attributes step sets the title");
      assert.deepEqual(
        [
          ...(findAll("[role='option'][data-value='1']")[0]?.classList ?? []),
        ].filter((name) => name.startsWith("opt-")),
        ["opt-all", "opt-kind", "opt-instance"],
        "attribute classes compose in tier order"
      );
      assert
        .dom("[role='option'][data-value='2']")
        .hasAttribute(
          "aria-disabled",
          "true",
          "the disabled setting reaches the DOM"
        );
    });

    test("the attributes cache reuses equal settings across new options", async function (assert) {
      const record = { id: 1, name: "Stable" };
      const settings = {
        description: "Same",
        position: "sticky",
        divider: "after",
        onSelect() {},
      };
      const original = selectOption(record, settings);
      const options = tracked([original]);
      let calls = 0;
      customize((selects) =>
        selects.forAll((spec) =>
          spec.optionAttributes((attributes) => {
            calls++;
            attributes.title = `Evaluation ${calls}`;
          })
        )
      );

      await render(
        <template>
          <DSelect @options={{options.value}} @virtualized={{false}} />
        </template>
      );
      await click("[role='combobox']");
      const initialCalls = calls;
      assert.true(initialCalls > 0, "the first option was presented");
      const initialTitle = findAll("[role='option']")[0]?.getAttribute("title");
      const rebuilt = original.with({ description: "Same" });
      assert.notStrictEqual(
        rebuilt.settings,
        original.settings,
        "the fixture rebuilds the settings object"
      );
      options.value = [rebuilt];
      await settled();

      assert.strictEqual(
        calls,
        initialCalls,
        "equal settings by value do not run the attributes step again"
      );
      assert
        .dom("[role='option']")
        .hasAttribute(
          "title",
          initialTitle,
          "the cached attributes remain visible"
        );
    });

    for (const setting of ["description", "position"]) {
      test(`the attributes cache invalidates changed ${setting} with the same record`, async function (assert) {
        const record = { id: 1, name: "Changing" };
        const original = selectOption(record, { description: "Before" });
        const options = tracked([original]);
        let calls = 0;
        customize((selects) =>
          selects.forAll((spec) =>
            spec.optionAttributes((attributes, context) => {
              calls++;
              attributes.title = `${context.option?.description}/${context.option?.position ?? "normal"}`;
            })
          )
        );

        await render(
          <template>
            <DSelect @options={{options.value}} @virtualized={{false}} />
          </template>
        );
        await click("[role='combobox']");
        assert
          .dom("[role='option']")
          .hasAttribute(
            "title",
            "Before/normal",
            "the attributes step reads the initial settings"
          );
        const initialCalls = calls;
        const replacement = original.with(
          setting === "description"
            ? { description: "After" }
            : { position: "end" }
        );
        assert.strictEqual(
          replacement.record,
          record,
          "the invalidation does not depend on changing records"
        );
        options.value = [replacement];
        await settled();

        assert.true(
          calls > initialCalls,
          "the changed setting runs the attributes step again"
        );
        assert
          .dom("[role='option']")
          .hasAttribute(
            "title",
            setting === "description" ? "After/normal" : "Before/end",
            "the new attributes reach the open list"
          );
        assert
          .dom(".d-select__option-description")
          .hasText(
            setting === "description" ? "After" : "Before",
            "the description follows the same option"
          );
      });
    }

    test("tracked content changes while open without a render error", async function (assert) {
      const first = Object.freeze({ id: 1, name: "First" });
      const second = Object.freeze({ id: 2, name: "Second" });
      const source = [first, second];
      const phase = tracked(1);
      const errors = [];
      const seen = [];
      setupOnerror((error) => errors.push(error.message));
      customize((selects) =>
        selects.forAll((spec) =>
          spec.content((options) => {
            seen.push(options);
            return options
              .map((entry) => selectOption(entry))
              .filter((option) => option.record.id === phase.value)
              .map((option) =>
                option.with({ description: `Phase ${phase.value}` })
              );
          })
        )
      );
      const changes = [];
      const onChange = (value, record) => changes.push([value, record]);

      await render(
        <template>
          <DSelect
            @onChange={{onChange}}
            @options={{source}}
            @virtualized={{false}}
          />
        </template>
      );
      await click("[role='combobox']");
      assert
        .dom("[data-value='1']")
        .includesText("Phase 1", "the first tracked state is shown");
      phase.value = 2;
      await settled();

      assert
        .dom("[role='listbox']")
        .exists("the list stays open during the change");
      assert
        .dom("[data-value='1']")
        .doesNotExist("the previous content is removed");
      assert
        .dom("[data-value='2']")
        .includesText("Phase 2", "the new tracked content is shown");
      assert.true(seen.length > 1, "tracked state rebuilds content");
      assert.true(
        seen.every((options) => options.every(isSelectOption)),
        "every host content evaluation receives options"
      );
      assert.deepEqual(errors, [], "there is no backtracking or render error");
      await click("[data-value='2']");
      assert.deepEqual(
        changes,
        [[2, second]],
        "the rebuilt option emits the original record"
      );
    });

    test("native content keeps explicit actions and treats bare fields as data", async function (assert) {
      const calls = [];
      const bare = Object.freeze({
        id: 1,
        name: "Bare data",
        disabled: true,
        sticky: true,
        description: "Hidden data",
        onSelect() {
          calls.push("bare");
        },
      });
      const actionRecord = Object.freeze({ id: 2, name: "Deliberate action" });
      const action = selectOption(actionRecord, {
        description: "Explicit description",
        onSelect: (control, record) => calls.push(record),
      });
      customize((selects) =>
        selects.forAll((spec) => spec.content(() => [bare, action]))
      );
      const onChange = (value, record) => calls.push([value, record]);

      await render(
        <template>
          <DSelect
            @onChange={{onChange}}
            @options={{null}}
            @virtualized={{false}}
          />
        </template>
      );
      await click("[role='combobox']");
      assert
        .dom("[data-value='1']")
        .doesNotHaveAttribute(
          "aria-disabled",
          "a bare disabled field is inert"
        );
      assert
        .dom("[data-value='1']")
        .doesNotHaveClass("--sticky", "a bare sticky field is inert");
      assert
        .dom("[data-value='1'] .d-select__option-description")
        .doesNotExist("a bare description is not displayed");
      assert
        .dom("[data-value='2'] .d-select__option-description")
        .hasText(
          "Explicit description",
          "an option keeps its explicit description"
        );
      await click("[data-value='2']");
      assert.deepEqual(
        calls,
        [actionRecord],
        "only the explicit action runs with its original record"
      );
      assert.dom("[role='listbox']").exists("the action leaves the list open");
      await click("[data-value='1']");
      assert.deepEqual(
        calls,
        [actionRecord, [1, bare]],
        "the bare result selects a value instead of running its method"
      );
    });

    test("legacy copies keep native settings and injected actions retain their receiver", async function (assert) {
      const native = Object.freeze({ id: 1, name: "Native" });
      const options = [
        selectOption(native, { description: "Native setting", disabled: true }),
      ];
      const calls = [];
      const errors = [];
      setupOnerror((error) => errors.push(error.message));
      const action = Object.freeze({
        id: 2,
        name: "Legacy action",
        sticky: true,
        description: "Legacy setting",
        onSelect(selectKit, record) {
          calls.push({ receiver: this, record, setter: selectKit.set });
        },
      });
      withPluginApi((api) =>
        api.modifySelectKit("opt-bridge").replaceContent((facade, content) => {
          assert.strictEqual(
            content[0],
            native,
            "legacy callbacks receive records"
          );
          assert.strictEqual(
            facade.content[0],
            native,
            "the facade holds records too"
          );
          return [{ ...content[0] }, action];
        })
      );
      const changes = [];
      const onChange = (...args) => changes.push(args);

      await render(
        <template>
          <DSelect
            @kind="opt-bridge"
            @onChange={{onChange}}
            @options={{options}}
            @virtualized={{false}}
          />
        </template>
      );
      await click("[role='combobox']");
      assert
        .dom("[data-value='1'] .d-select__option-description")
        .hasText(
          "Native setting",
          "a unique-key copy keeps the native description"
        );
      assert
        .dom("[data-value='1']")
        .hasAttribute(
          "aria-disabled",
          "true",
          "a unique-key copy keeps native disabled"
        );
      assert
        .dom("[data-value='2']")
        .hasClass("--sticky", "legacy sticky is translated");
      assert
        .dom("[data-value='2'] .d-select__option-description")
        .hasText("Legacy setting", "legacy description is translated");
      await click("[data-value='2']");
      assert.strictEqual(calls.length, 1, "the legacy action ran once");
      assert.strictEqual(
        calls[0]?.receiver,
        action,
        "the row is the legacy action receiver"
      );
      assert.strictEqual(
        calls[0]?.record,
        action,
        "the action argument is the original row"
      );
      assert.strictEqual(
        typeof calls[0]?.setter,
        "function",
        "the first action argument is the legacy facade"
      );
      assert.deepEqual(changes, [], "the action does not emit a selection");
      assert.deepEqual(
        errors,
        [],
        "legacy callbacks and actions do not raise render errors"
      );
    });
  }
);
