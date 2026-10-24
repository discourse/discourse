import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { trackedObject } from "@ember/reactive/collections";
import {
  click,
  fillIn,
  render,
  settled,
  setupOnerror,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { ITEMS, optionWithText } from "discourse/tests/helpers/d-select-hosts";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import DSelect from "discourse/ui-kit/select/d-select";
import DSelectList from "discourse/ui-kit/select/d-select-list";

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

/** Registers one `spec.options` callback for every select. */
function overrideOptions(callback) {
  customize((selects) => selects.forAll((spec) => spec.options(callback)));
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
          <DSelect @items={{ITEMS}} @value={{1}} @variant="static" />
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
            @items={{ITEMS}}
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
          <DSelect @items={{ITEMS}} @value={{1}} @variant="static" />
        </template>
      );

      assert.dom(".d-select__caret").doesNotExist();
    });

    test("icon renders a leading icon", async function (assert) {
      overrideOptions(() => ({ icon: "gear" }));

      await render(
        <template>
          <DSelect @items={{ITEMS}} @value={{1}} @variant="static" />
        </template>
      );

      assert.dom(".d-select__leading-icon").hasClass("d-icon-gear");
    });

    test("clearable offers the clear control", async function (assert) {
      overrideOptions(() => ({ clearable: true }));

      await render(
        <template>
          <DSelect @items={{ITEMS}} @value={{1}} @variant="static" />
        </template>
      );

      assert.dom(".d-select__clear").exists();
    });

    test("placeholder reaches the single trigger of every variant", async function (assert) {
      overrideOptions(() => ({ placeholder: "From extension" }));

      await render(
        <template>
          <div class="static-host">
            <DSelect
              @items={{ITEMS}}
              @placeholder="From call site"
              @variant="static"
            />
          </div>
          <div class="typeahead-host">
            <DSelect @items={{ITEMS}} @placeholder="From call site" />
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
      overrideOptions(() => ({ placeholder: "From extension" }));
      const none = [];

      await render(
        <template>
          <DSelect @items={{ITEMS}} @multiple={{true}} @value={{none}} />
        </template>
      );

      assert
        .dom(".d-select__input")
        .hasAttribute("placeholder", "From extension");
    });

    test("searchPlaceholder reaches the panel filter", async function (assert) {
      overrideOptions(() => ({ searchPlaceholder: "Find a fruit" }));

      await render(
        <template><DSelect @items={{ITEMS}} @variant="button" /></template>
      );
      await click(".d-select__trigger");

      assert
        .dom(".d-select__filter")
        .hasAttribute("placeholder", "Find a fruit");
    });

    test("searchIcon reaches the panel search field", async function (assert) {
      overrideOptions(() => ({ searchIcon: "magnifying-glass" }));

      await render(
        <template><DSelect @items={{ITEMS}} @variant="button" /></template>
      );
      await click(".d-select__trigger");

      assert.dom(".d-select__panel .d-icon-magnifying-glass").exists();
    });

    test("label names the combobox and the listbox", async function (assert) {
      overrideOptions(() => ({ label: "Fruit picker" }));

      await render(
        <template><DSelect @items={{ITEMS}} @label="Call site" /></template>
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
      overrideOptions(() => ({ noneLabel: "Nothing" }));

      await render(
        <template><DSelect @items={{ITEMS}} @noneLabel="None" /></template>
      );
      await click("[role='combobox']");

      assert.dom("[role='option'].--none").hasText("Nothing");
    });

    test("noneLabel adds a none row where the call site has none", async function (assert) {
      overrideOptions(() => ({ noneLabel: "Nothing" }));

      await render(<template><DSelect @items={{ITEMS}} /></template>);
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
              @items={{ITEMS}}
              @value={{1}}
              @variant="static"
            />
          </div>
          <div class="typeahead-host">
            <DSelect @items={{ITEMS}} @value={{1}} />
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
            @items={{ITEMS}}
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
          <DSelect @items={{ITEMS}} @value={{1}} @variant="static" />
        </template>
      );

      assert.dom("[role='combobox']").hasAria("disabled", "true");
    });

    test("iconOnly suppresses the label when a label resolves", async function (assert) {
      overrideOptions(() => ({ iconOnly: true, icon: "gear" }));

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @label="Settings"
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
            <DSelect @items={{ITEMS}} @value={{2}} @variant="static" />
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
          spec.options((current) => {
            seen.push(["identifier", current.label]);
            return { label: "From identifier" };
          })
        );
        selects.forKind("picker", (spec) =>
          spec.options((current) => {
            seen.push(["kind", current.label]);
            return { label: "From kind" };
          })
        );
        selects.forAll((spec) =>
          spec.options((current) => {
            seen.push(["all", current.label]);
            return { label: "From all", placeholder: "Kept" };
          })
        );
      });

      await render(
        <template>
          <DSelect
            @identifier="fruit"
            @items={{ITEMS}}
            @kind="picker"
            @label="Call site"
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
          spec.options(() =>
            state.suggesting ? { caretIcon: "spinner" } : {}
          );
          spec.content((items) => [
            {
              id: "toggle",
              name: "Toggle",
              onSelect() {
                state.suggesting = !state.suggesting;
              },
            },
            ...items,
          ]);
        })
      );

      await render(
        <template>
          <DSelect
            @caretIcon="caret-down"
            @items={{ITEMS}}
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

    test("options callbacks run per change, not per row", async function (assert) {
      const state = new (class {
        @tracked label = "First";
      })();
      let calls = 0;
      overrideOptions(() => {
        calls++;
        return { label: state.label };
      });

      await render(<template><DSelect @items={{MANY}} /></template>);
      await click("[role='combobox']");
      assert.true(calls >= 1, "the options were resolved");
      assert.true(
        calls <= 2,
        `rendering thirty rows resolved the options ${calls} times`
      );

      const before = calls;
      state.label = "Second";
      await settled();
      assert
        .dom("[role='combobox']")
        .hasAttribute("aria-label", "Second", "the change applied");
      assert.true(calls > before, "the change re-resolved the options");
      assert.true(
        calls - before <= 2,
        `one change resolved the options ${calls - before} times`
      );
    });

    test("options callbacks receive the names, data, value and control, but no options", async function (assert) {
      let seen;
      const kindContext = { scope: "recipe" };
      const instanceContext = { topicId: 7 };
      customize((selects) =>
        selects.forKind("picker", (spec) =>
          spec.options((current, context) => {
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
            @items={{ITEMS}}
            @kind="picker"
            @kindContext={{kindContext}}
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
      assert.false("options" in seen, "no resolved options, which would cycle");
    });

    test("a non-object result is skipped and an unknown key warns", async function (assert) {
      const warn = sinon.stub(console, "warn");
      customize((selects) => {
        selects.forAll((spec) => spec.options(() => undefined));
        selects.forAll((spec) => spec.options(() => "label"));
        selects.forAll((spec) =>
          spec.options(() => ({ label: "Kept", lable: "Typo" }))
        );
      });

      try {
        await render(<template><DSelect @items={{ITEMS}} /></template>);

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
          spec.row((row, context) => {
            if (context.item.id === 2) {
              row.title = "Ripe";
            }
          })
        )
      );

      await render(
        <template>
          <div class="plain"><DSelect @items={{items}} /></div>
          <div class="titled"><DSelect @items={{items}} @kind="titled" /></div>
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
          spec.row((row, context) => {
            runs.set(context.item.id, (runs.get(context.item.id) ?? 0) + 1);
            row.title = `Row ${context.item.id}`;
            row.classes.push("x-row");
          })
        )
      );

      await render(<template><DSelect @items={{ITEMS}} /></template>);
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
      spec.options((current) => ({ prefix: `${current.prefix}+kind` }))
    )
  );
}

module(
  "Integration | ui-kit | select | DSelect select-customizations | recipe options",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a recipe key resolves from the call site through every tier", async function (assert) {
      const seen = [];
      customize((selects) => {
        selects.forIdentifier("crumb", (spec) =>
          spec.options((current) => {
            seen.push(current.prefix);
            return { prefix: `${current.prefix}+identifier` };
          })
        );
        selects.forKind("recipe", (spec) =>
          spec.options((current) => {
            seen.push(current.prefix);
            return { prefix: `${current.prefix}+kind` };
          })
        );
        selects.forAll((spec) =>
          spec.options((current) => {
            seen.push(current.prefix);
            return { prefix: `${current.prefix}+all` };
          })
        );
      });

      await render(
        <template>
          <DSelect
            @identifier="crumb"
            @items={{ITEMS}}
            @kind="recipe"
            @kindOptions={{hash prefix="base"}}
          >
            <:item as |item options|>
              {{~concat options.prefix " " item.name~}}
            </:item>
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

    test("resolved options reach the items function", async function (assert) {
      customizeRecipe();
      const itemsFor = (options) => [{ id: 1, name: `${options?.prefix} one` }];

      await render(
        <template>
          <DSelect
            @items={{itemsFor}}
            @kind="recipe"
            @kindOptions={{hash prefix="base"}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert.dom("[role='option']").hasText("base+kind one");
    });

    test("a zero-argument items function still works", async function (assert) {
      const itemsFor = () => ITEMS;

      await render(<template><DSelect @items={{itemsFor}} /></template>);
      await click("[role='combobox']");

      assert.dom("[role='option']").exists({ count: 3 });
    });

    test("resolved options reach @load, @resolveValue and @resolveValues", async function (assert) {
      customizeRecipe();
      const seen = {};
      const load = (filter, opts) => {
        seen.load = opts.options?.prefix;
        return [{ id: 1, name: "One" }];
      };
      const resolveValue = (value, opts) => {
        seen.resolveValue = opts.options?.prefix;
        return { id: value, name: `Item ${value}` };
      };
      const resolveValues = (values, opts) => {
        seen.resolveValues = opts.options?.prefix;
        return values.map((id) => ({ id, name: `Item ${id}` }));
      };
      const held = [8];

      await render(
        <template>
          <div class="single">
            <DSelect
              @debounce={{false}}
              @kind="recipe"
              @kindOptions={{hash prefix="base"}}
              @load={{load}}
              @resolveValue={{resolveValue}}
              @value={{7}}
              @variant="static"
            />
          </div>
          <div class="multi">
            <DSelect
              @kind="recipe"
              @kindOptions={{hash prefix="base"}}
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

    test("resolved options reach onChange as part of its third argument", async function (assert) {
      customizeRecipe();
      const onChange = sinon.spy();

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @kind="recipe"
            @kindOptions={{hash prefix="base"}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Banana"));

      assert.true(onChange.calledOnce);
      const [value, item, change] = onChange.firstCall.args;
      assert.strictEqual(value, 2, "the value keeps its position");
      assert.strictEqual(item.name, "Banana", "so does the item");
      assert.strictEqual(change.options?.prefix, "base+kind");
    });

    test("resolved options reach every recipe callback as the last argument", async function (assert) {
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
      const createItem = (filter, options) => {
        record("createItem", options);
        return { id: filter, name: filter, __create: true };
      };
      const createUnresolvedItem = (value, options) => {
        record("createUnresolvedItem", options);
        return { id: value, name: `Missing ${value}` };
      };
      const specialItems = (state, options) => {
        snapshot = state;
        record("specialItems", options);
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
      const groupLabel = (key, options) => {
        record("groupLabel", options);
        return key;
      };

      await render(
        <template>
          <DSelect
            @allowCreate={{allowCreate}}
            @createItem={{createItem}}
            @createUnresolvedItem={{createUnresolvedItem}}
            @filterBy={{filterBy}}
            @groupBy={{groupBy}}
            @groupLabel={{groupLabel}}
            @items={{items}}
            @kind="recipe"
            @kindOptions={{hash prefix="base"}}
            @specialItems={{specialItems}}
            @value={{99}}
          />
        </template>
      );
      await click("[role='combobox']");
      await fillIn("[role='combobox']", "a");

      assert.deepEqual(seen, {
        allowCreate: "base+kind",
        createItem: "base+kind",
        createUnresolvedItem: "base+kind",
        filterBy: "base+kind",
        groupBy: "base+kind",
        groupLabel: "base+kind",
        specialItems: "base+kind",
      });
      assert.deepEqual(
        Object.keys(snapshot).sort(),
        ["filter", "hasValue", "value"],
        "the snapshot argument is unchanged"
      );
    });

    test("resolved options reach the blocks as the last parameter", async function (assert) {
      customizeRecipe();
      const items = [{ id: 1, name: "Apple", section: "fruit" }];
      const groupLabel = (key) => key;

      await render(
        <template>
          <div class="held">
            <DSelect
              @groupBy="section"
              @groupLabel={{groupLabel}}
              @items={{items}}
              @kind="recipe"
              @kindOptions={{hash prefix="base"}}
              @value={{1}}
              @variant="static"
            >
              <:item as |item options|>
                <span class="x-item">{{options.prefix}}</span>
              </:item>
              <:selection as |item options|>
                <span class="x-selection">{{options.prefix}}</span>
              </:selection>
              <:groupHeader as |header options|>
                <span class="x-header">{{options.prefix}}</span>
              </:groupHeader>
              <:footer as |state options|>
                <span class="x-footer">{{options.prefix}}</span>
              </:footer>
            </DSelect>
          </div>
          <div class="missing">
            <DSelect
              @items={{items}}
              @kind="recipe"
              @kindOptions={{hash prefix="base"}}
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
      assert.dom(".x-footer").hasText("base+kind");
    });

    test("delivered options carry the resolved core keys too", async function (assert) {
      const itemsFor = (options) => [{ id: 1, name: options?.label }];
      customize((selects) =>
        selects.forKind("recipe", (spec) =>
          spec.options(() => ({ label: "From extension" }))
        )
      );

      await render(
        <template>
          <DSelect
            @items={{itemsFor}}
            @kind="recipe"
            @kindOptions={{hash prefix="base"}}
            @label="Call site"
          />
        </template>
      );
      await click("[role='combobox']");

      assert.dom("[role='option']").hasText("From extension");
    });

    test("recipe values stay live", async function (assert) {
      customizeRecipe();
      const state = new (class {
        @tracked prefix = "first";
      })();

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @kind="recipe"
            @kindOptions={{hash prefix=state.prefix}}
          >
            <:item as |item options|>
              {{~concat options.prefix " " item.name~}}
            </:item>
          </DSelect>
        </template>
      );
      await click("[role='combobox']");
      assert.dom(optionWithText("first+kind Apple")).exists();

      state.prefix = "second";
      await settled();
      assert.dom(optionWithText("second+kind Apple")).exists();
    });

    test("null in the hash counts as absent, but the key stays declared", async function (assert) {
      const warn = sinon.stub(console, "warn");
      let seen;
      customize((selects) =>
        selects.forKind("recipe", (spec) =>
          spec.options((current) => {
            seen = current;
            return { prefix: "set" };
          })
        )
      );

      try {
        await render(
          <template>
            <DSelect
              @items={{ITEMS}}
              @kind="recipe"
              @kindOptions={{hash prefix=null}}
            >
              <:item as |item options|>
                {{~concat options.prefix " " item.name~}}
              </:item>
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
          spec.options(() => ({ prefix: "ok", label: "ok", sufix: "typo" }))
        )
      );

      try {
        await render(
          <template>
            <DSelect
              @items={{ITEMS}}
              @kind="recipe"
              @kindOptions={{hash prefix="base"}}
            />
          </template>
        );

        assert.true(warn.calledWithMatch("sufix"), "the typo warns");
        assert.false(warn.calledWithMatch('"prefix"'), "a recipe key does not");
        assert.false(warn.calledWithMatch('"label"'), "a core key does not");
      } finally {
        warn.restore();
      }
    });

    test("@kindOptions without @kind asserts", async function (assert) {
      let message;
      setupOnerror((error) => (message ??= error.message));

      await render(
        <template>
          <DSelect @items={{ITEMS}} @kindOptions={{hash prefix="base"}} />
        </template>
      );

      assert.true(
        !!message?.includes("@kindOptions"),
        `the assertion names @kindOptions: ${message}`
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
            @items={{ITEMS}}
            @kind="recipe"
            @kindOptions={{hash label="Mine"}}
          />
        </template>
      );

      assert.true(
        message?.includes("label"),
        `the assertion names the colliding key: ${message}`
      );
    });

    test("every point's context carries the resolved options", async function (assert) {
      customizeRecipe();
      const seen = {};
      customize((selects) =>
        selects.forKind("recipe", (spec) => {
          spec.content((items, context) => {
            seen.content = context.options;
            return items;
          });
          spec.row((row, context) => {
            seen.row = context.options;
          });
          spec.load((load, context) => {
            seen.load = context.options;
            return load;
          });
          spec.change((next, context) => {
            seen.change = context.options;
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
            @kindOptions={{hash prefix="base"}}
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
      let middlewareOptions;
      customize((selects) =>
        selects.forKind("recipe", (spec) =>
          spec.change((next, context) => {
            middlewareOptions = context.options;
            next();
          })
        )
      );
      const onChange = sinon.spy();

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @kind="recipe"
            @kindOptions={{hash prefix="base"}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click("[role='combobox']");
      await click(optionWithText("Banana"));

      assert.strictEqual(onChange.firstCall.args[2].options, middlewareOptions);
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

      await render(<template><DSelect @items={{ITEMS}} /></template>);
      await click("[role='combobox']");
      await click(optionWithText("Banana"));

      assert.strictEqual(changeControl, contentControl, "the same control");
      assert.true(reloadedAfterEmit, "it can reload after the emit");
    });

    test("one options callback drives a core and a recipe key from tracked setup state", async function (assert) {
      customize((selects) =>
        selects.forKind("recipe", (spec) => {
          const state = trackedObject({ suggesting: false });
          spec.options(() =>
            state.suggesting
              ? { placeholder: "Suggesting", prefix: "suggest" }
              : { placeholder: "Browsing", prefix: "browse" }
          );
          spec.content((items) => [
            {
              id: "toggle",
              name: "Toggle",
              onSelect() {
                state.suggesting = !state.suggesting;
              },
            },
            ...items,
          ]);
        })
      );

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @kind="recipe"
            @kindOptions={{hash prefix="base"}}
          >
            <:item as |item options|>
              {{~concat options.prefix " " item.name~}}
            </:item>
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

    test("an async select's items function sees resolved options during construction", async function (assert) {
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
            @items={{itemsFor}}
            @kind="recipe"
            @kindOptions={{hash prefix="base"}}
            @load={{load}}
          />
        </template>
      );

      assert.true(calls.length > 0, "construction read the items function");
      assert.strictEqual(calls[0], "base+kind", "with resolved options");
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
              @items={{ITEMS}}
              @kind="select-tag"
              @legacyKind="mini-tag-chooser"
            />
          </div>
          <div class="many">
            <DSelect
              @items={{ITEMS}}
              @kind="select-tag-filter"
              @legacyKind={{MINI_AND_INTERSECTION}}
            />
          </div>
          <div class="list">
            <DSelectList
              @items={{ITEMS}}
              @kind="select-tag"
              @legacyKind="tag-chooser"
              @onChange={{noop}}
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
          spec.row((row) => row.classes.push("x-new-kind"))
        );
        selects.forKind("mini-tag-chooser", (spec) =>
          spec.row((row) => row.classes.push("x-legacy-kind"))
        );
      });

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @kind="select-tag"
            @legacyKind="mini-tag-chooser"
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
            @items={{ITEMS}}
            @kind="select-tag"
            @legacyKind="mini-tag-chooser"
            @onChange={{noop}}
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
