import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import {
  click,
  fillIn,
  find,
  findAll,
  focus,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import {
  DefaultHost,
  ITEMS,
  optionWithText,
} from "discourse/tests/helpers/d-select-hosts";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

class MultiHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="test-multi"
      @items={{ITEMS}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder="Pick some"
      @value={{this.value}}
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

class MultiValueCoercionHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value, payload) {
    this.args.onChange?.(value, payload, this.value);
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="test-multi-value-coercion"
      @items={{ITEMS}}
      @kind="test-multi-value-coercion"
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder="Pick some"
      @value={{this.value}}
    />
  </template>
}

module(
  "Integration | ui-kit | select | DSelect (multi typeahead)",
  function (hooks) {
    setupRenderingTest(hooks);

    // Wrapping a form control in a `label` is ordinary markup, but a `label` forwards its clicks
    // to the first LABELABLE descendant — and in a multi-select that is the first chip's remove
    // button. So clicking the field's text, its padding or its caret silently deleted a
    // selection. The control has to defend itself: a consumer cannot be expected to know that
    // one of its internal buttons will absorb every click in the surrounding label.
    test("a surrounding label does not delete a chip", async function (assert) {
      await render(
        <template>
          <label class="field-label">
            <span class="field-text">Tags</span>
            <MultiHost @value={{array 1 2}} />
          </label>
        </template>
      );

      assert.dom(".d-select__chip").exists({ count: 2 }, "two chips to start");

      // The mechanism, asserted directly: the label resolves to the sink rather than to any
      // control inside the trigger. This is what makes the protection structural, so it is what
      // must fail if a labelable element is ever introduced ahead of the sink.
      assert.strictEqual(
        find(".field-label").control,
        find(".d-select__label-sink"),
        "the label's control is the sink, not a chip's remove button"
      );

      await click(".field-text");
      assert
        .dom(".d-select__chip")
        .exists({ count: 2 }, "clicking the label's text removes nothing");

      await click(".field-label");
      assert
        .dom(".d-select__chip")
        .exists({ count: 2 }, "nor does clicking the label itself");
    });

    // The guard above must not cost the chip its own keyboard removal, which produces a click
    // that looks identical to a forwarded one.
    test("Enter on a focused chip still removes it", async function (assert) {
      await render(<template><MultiHost @value={{array 1 2}} /></template>);

      const remove = findAll(".d-select__chip-remove")[0];
      await focus(remove);
      await triggerKeyEvent(remove, "keydown", "Enter");
      await click(remove);

      assert
        .dom(".d-select__chip")
        .exists({ count: 1 }, "the keyboard path still removes a chip");
    });

    test("shows the placeholder when empty", async function (assert) {
      await render(<template><MultiHost /></template>);
      assert.dom(".d-select__input").hasAttribute("placeholder", "Pick some");
      assert.dom(".d-select__chip").doesNotExist();
    });

    test("selecting adds a chip, keeps the menu open, and keeps the picked row flagged", async function (assert) {
      await render(<template><MultiHost /></template>);
      await click(".d-select__input");
      assert.dom("[role='option']").exists({ count: 3 });

      await click("[role='option']");
      assert.dom("[role='listbox']").exists("multi stays open after a pick");
      assert
        .dom("[role='listbox']")
        .hasAttribute(
          "aria-multiselectable",
          "true",
          "a multi listbox declares multi-select semantics"
        );
      assert.dom(".d-select__chip").exists({ count: 1 }, "a chip is added");
      assert
        .dom("[role='option']")
        .exists({ count: 3 }, "the picked item stays in the list");
      assert
        .dom("[role='option'][aria-selected='true']")
        .exists({ count: 1 }, "the picked row is flagged selected");
      assert
        .dom(
          "[role='option'][aria-selected='true'] .d-select__option-selected-icon"
        )
        .exists("the selected row carries a check");

      // Clicking the first option again would toggle the now-selected item back
      // off, so pick a still-unselected row to add a second chip.
      await click("[role='option'][aria-selected='false']");
      assert.dom(".d-select__chip").exists({ count: 2 });
    });

    test("removing a chip deselects it", async function (assert) {
      await render(<template><MultiHost @value={{array 1 2}} /></template>);
      assert.dom(".d-select__chip").exists({ count: 2 });

      // The chip is a span; removal is its inner button, not the chip itself.
      await click(".d-select__chip .d-select__chip-remove");
      assert.dom(".d-select__chip").exists({ count: 1 }, "one chip removed");
    });

    test("each chip is a list item with an inner remove button named for its label", async function (assert) {
      await render(<template><MultiHost @value={{array 1}} /></template>);

      // The chips are a native labelled <ul>/<li> list (real "Selected items, list, N items"
      // semantics) rather than a role=group of spans; removal is the chip's inner button.
      assert
        .dom("li.d-select__chip")
        .exists({ count: 1 }, "the chip is a list item, not a button");
      assert
        .dom("ul.d-select__chip-list")
        .hasAttribute("aria-label", /.+/, "the chips are a labelled list");

      const removeButton = find(".d-select__chip .d-select__chip-remove");
      assert
        .dom(removeButton)
        .hasTagName("button", "removal is a dedicated inner button");

      const ids = removeButton.getAttribute("aria-labelledby").split(" ");
      assert.strictEqual(
        ids.length,
        2,
        "the button is named by two referenced nodes"
      );
      assert
        .dom(`#${ids[0]}`)
        .hasText(
          "Apple",
          "the first referenced node is the chip label (item-first)"
        );
      assert
        .dom(`#${ids[1]}`)
        .hasText(
          "Press Backspace or Delete to remove",
          "the second is the removal hint, so the name reads 'Apple, Press Backspace or Delete to remove'"
        );
    });

    test("a chip whose value contains a space still names its remove button", async function (assert) {
      const spacedItems = [{ id: "bug fix", name: "Bug fix" }];
      await render(
        <template>
          <DefaultHost
            @items={{spacedItems}}
            @multiple={{true}}
            @value={{array "bug fix"}}
          />
        </template>
      );

      const labelledby = find(".d-select__chip-remove").getAttribute(
        "aria-labelledby"
      );
      assert.strictEqual(
        labelledby.split(" ").length,
        2,
        "ids are minted from the index, so a spaced value does not tokenize the IDREF list"
      );
      labelledby.split(" ").forEach((id) => {
        assert
          .dom(`#${CSS.escape(id)}`)
          .exists(`the referenced node #${id} resolves`);
      });
    });

    test("uses default labels when presentation blocks are omitted", async function (assert) {
      await render(
        <template>
          <DefaultHost @multiple={{true}} @value={{array 1 2}} />
        </template>
      );

      assert
        .dom(".d-select__chip")
        .exists({ count: 2 }, "one fallback chip renders for each selection");
      assert
        .dom(".d-select__chip:first-child")
        .includesText("Apple", "chips use the selection fallback");

      await click(".d-select__input");
      assert
        .dom("[role='option']")
        .exists({ count: 3 }, "selected items stay in the list");
      assert
        .dom("[role='option'][aria-selected='true']")
        .exists({ count: 2 }, "the two selected rows are flagged");
      assert
        .dom("[role='option'][aria-selected='false']")
        .hasText("Cherry pie", "the unselected row uses the item fallback");
    });

    test("the selected-option icon is customizable via @selectedIcon", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @multiple={{true}}
            @selectedIcon="star"
            @value={{array 1}}
          />
        </template>
      );
      await click(".d-select__input");

      assert
        .dom(
          "[role='option'][aria-selected='true'] .d-select__option-selected-icon.d-icon-star"
        )
        .exists("the selected row uses the custom icon, not the default check");
    });
  }
);

module(
  "Integration | ui-kit | DSelect (multi value coercion)",
  function (hooks) {
    setupRenderingTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

    test("coerces held string ids when adding a native-id item", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiValueCoercionHost @onChange={{onChange}} @value={{array "1"}} />
        </template>
      );

      await click(".d-select__input");
      await click(optionWithText("Banana"));

      assert.strictEqual(onChange.callCount, 1, "the selection emits once");
      const emittedValue = onChange.firstCall.args[0];
      assert.deepEqual(
        emittedValue,
        [1, 2],
        "the held string id and native picked id are emitted as native ids"
      );
      assert.deepEqual(
        emittedValue.map((id) => typeof id),
        ["number", "number"],
        "every emitted id has the source item's runtime type"
      );
      assert.true(
        emittedValue.every(Number.isInteger),
        "every emitted numeric id remains an integer"
      );
    });

    test("coerces the remaining ids when deselecting", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiValueCoercionHost
            @onChange={{onChange}}
            @value={{array "1" "2"}}
          />
        </template>
      );

      await click(".d-select__chip .d-select__chip-remove");

      assert.strictEqual(onChange.callCount, 1, "the deselection emits once");
      const emittedValue = onChange.firstCall.args[0];
      assert.deepEqual(
        emittedValue,
        [2],
        "deselecting emits the remaining resolved id in its native form"
      );
      assert.strictEqual(
        typeof emittedValue[0],
        "number",
        "the remaining id has the source item's runtime type"
      );
      assert.true(
        Number.isInteger(emittedValue[0]),
        "the remaining numeric id is an integer"
      );
    });

    test("preserves unresolved ids unchanged and in order", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiValueCoercionHost
            @onChange={{onChange}}
            @value={{array "999" "1"}}
          />
        </template>
      );

      await click(".d-select__input");
      await click(optionWithText("Banana"));

      assert.strictEqual(onChange.callCount, 1, "the selection emits once");
      const emittedValue = onChange.firstCall.args[0];
      assert.deepEqual(
        emittedValue,
        ["999", 1, 2],
        "the unresolved id stays first while resolved ids use native values"
      );
      assert.deepEqual(
        emittedValue.map((id) => typeof id),
        ["string", "number", "number"],
        "only ids resolved from source items are coerced"
      );
      assert.true(
        emittedValue.slice(1).every(Number.isInteger),
        "the resolved numeric ids remain integers"
      );
    });

    test("aligns payload items with the coerced value", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiValueCoercionHost @onChange={{onChange}} @value={{array "1"}} />
        </template>
      );

      await click(".d-select__input");
      await click(optionWithText("Banana"));

      assert.strictEqual(onChange.callCount, 1, "the selection emits once");
      const [emittedValue, payloadItems] = onChange.firstCall.args;
      assert.deepEqual(
        emittedValue,
        [1, 2],
        "the emitted value contains native source ids"
      );
      assert.deepEqual(
        payloadItems,
        [ITEMS[0], ITEMS[1]],
        "the payload contains the items resolved for the emitted value"
      );
      assert.deepEqual(
        payloadItems.map((item) => item.id),
        emittedValue,
        "payload item ids line up positionally with the coerced value"
      );
      assert.true(
        payloadItems.every((item) => Number.isInteger(item.id)),
        "payload ids retain their native numeric type"
      );
    });

    test("keeps value coercion scoped to multi-select", async function (assert) {
      const singleOnChange = sinon.spy();
      const multiOnChange = sinon.spy();
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @onChange={{singleOnChange}}
            @placeholder="Pick one"
            @value="1"
          />
          <MultiValueCoercionHost
            @onChange={{multiOnChange}}
            @value={{array "1"}}
          />
        </template>
      );

      const [singleController, multiController] = findAll("[role='combobox']");
      await click(singleController);
      await click(optionWithText("Banana"));

      assert.strictEqual(
        singleOnChange.callCount,
        1,
        "the single selection emits once"
      );
      const singleValue = singleOnChange.firstCall.args[0];
      assert.strictEqual(
        singleValue,
        2,
        "single-select continues to emit the picked item's native id"
      );
      assert.strictEqual(
        typeof singleValue,
        "number",
        "single-select emits a scalar with the native runtime type"
      );
      assert.true(
        Number.isInteger(singleValue),
        "the emitted single-select id remains an integer"
      );

      await click(multiController);
      await click(optionWithText("Banana"));

      assert.strictEqual(
        multiOnChange.callCount,
        1,
        "the multi selection emits once"
      );
      const multiValue = multiOnChange.firstCall.args[0];
      assert.deepEqual(
        multiValue,
        [1, 2],
        "multi-select applies native-id coercion to its emitted array"
      );
      assert.deepEqual(
        multiValue.map((id) => typeof id),
        ["number", "number"],
        "multi-select emits native runtime types without changing single-select shape"
      );
    });

    test("communicates a coerced change without mutating the bound value", async function (assert) {
      const boundValue = ["1"];
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiValueCoercionHost
            @onChange={{onChange}}
            @value={{boundValue}}
          />
        </template>
      );

      await click(".d-select__input");
      await click(optionWithText("Banana"));

      assert.strictEqual(onChange.callCount, 1, "the selection emits once");
      const [emittedValue, , valueAtOnChange] = onChange.firstCall.args;
      assert.deepEqual(
        emittedValue,
        [1, 2],
        "onChange communicates the coerced next value"
      );
      assert.deepEqual(
        valueAtOnChange,
        ["1"],
        "the host still owns the original bound value when onChange begins"
      );
      assert.deepEqual(
        boundValue,
        ["1"],
        "the engine never mutates the array supplied as @value"
      );
      assert.strictEqual(
        typeof boundValue[0],
        "string",
        "the original bound id retains its runtime type"
      );
      assert
        .dom(".d-select__chip")
        .exists(
          { count: 2 },
          "the host displays the next value only after accepting onChange"
        );
    });

    test("coerces values emitted through the modifySelectKit bridge", async function (assert) {
      let selectKit;
      const onChange = sinon.spy();
      withPluginApi((api) => {
        api.modifySelectKit("test-multi-value-coercion").prependContent(() => ({
          id: "capture",
          name: "Capture facade",
          onSelect: (facade) => (selectKit = facade),
        }));
      });

      await render(
        <template>
          <MultiValueCoercionHost @onChange={{onChange}} @value={{array "1"}} />
        </template>
      );
      await click(".d-select__input");
      await click(optionWithText("Capture facade"));

      assert.notStrictEqual(
        selectKit,
        undefined,
        "the legacy action row exposes the compat facade"
      );
      selectKit.select(2, ITEMS[1]);
      await settled();

      assert.strictEqual(
        onChange.callCount,
        1,
        "the bridge selection emits once"
      );
      const emittedValue = onChange.firstCall.args[0];
      assert.deepEqual(
        emittedValue,
        [1, 2],
        "the bridge emits held and picked ids in their native source types"
      );
      assert.deepEqual(
        emittedValue.map((id) => typeof id),
        ["number", "number"],
        "the bridge emission contains only native-typed resolved ids"
      );
      assert.true(
        emittedValue.every(Number.isInteger),
        "the bridge emission retains integer ids"
      );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (chip keys, control variants)",
  function (hooks) {
    setupRenderingTest(hooks);

    class ChipHost extends Component {
      @tracked value = [1, 2];

      @action
      onChange(value) {
        this.value = value;
      }

      <template>
        <DSelect
          @clearable={{true}}
          @identifier="test-select"
          @items={{ITEMS}}
          @multiple={{true}}
          @onChange={{this.onChange}}
          @value={{this.value}}
          @variant="static"
        />
      </template>
    }

    test("a static trigger's chips are display-only", async function (assert) {
      await render(<template><ChipHost /></template>);

      assert
        .dom(".d-select__chip")
        .exists({ count: 2 }, "the held values render as chips");
      assert
        .dom(".d-select__trigger button.d-select__chip-remove")
        .doesNotExist(
          "no remove buttons are nested in the select-only combobox"
        );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (multi checkbox indicator)",
  function (hooks) {
    setupRenderingTest(hooks);

    // A check that appears out of blank space read as an awkward gap and gave no hint the row
    // was toggleable. The pair carries its own unselected state; both glyphs stay aria-hidden
    // because `aria-selected` on the row is the state channel.
    test("multi rows draw an empty box unselected and a checked box selected", async function (assert) {
      await render(
        <template>
          <DefaultHost @multiple={{true}} @value={{array 1}} />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom("[role='option'][aria-selected='true'] .d-icon-far-square-check")
        .exists("the selected row draws a checked box");
      assert
        .dom("[role='option'][aria-selected='false'] .d-icon-far-square")
        .exists("an unselected row draws an empty box rather than a gap");
      assert
        .dom("svg.d-select__option-selected-icon")
        .hasAttribute(
          "aria-hidden",
          "true",
          "the glyphs stay hidden from assistive tech, leaving aria-selected as the state channel"
        );
    });

    test("a consumer @selectedIcon keeps its show-when-selected behaviour", async function (assert) {
      await render(
        <template>
          <DSelect
            @identifier="test-select"
            @items={{ITEMS}}
            @multiple={{true}}
            @selectedIcon="star"
            @value={{array 1}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom(".d-select__option-selected-icon.--checkbox")
        .doesNotExist("a supplied glyph is not replaced by the checkbox pair");
      assert
        .dom("[role='option'][aria-selected='true'] .d-icon-star")
        .exists("the supplied glyph still marks the selection");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect multi placeholder",
  function (hooks) {
    setupRenderingTest(hooks);

    const FRUITS = [
      { id: 1, name: "Apple" },
      { id: 2, name: "Banana" },
    ];
    const TRIGGER = ".d-select__trigger";

    test("an empty mobile multi shows its placeholder", async function (assert) {
      forceMobile();
      const empty = [];

      await render(
        <template>
          <DSelect
            @items={{FRUITS}}
            @multiple={{true}}
            @placeholder="Pick fruit"
            @value={{empty}}
          />
        </template>
      );

      assert
        .dom(`${TRIGGER} .d-select__placeholder`)
        .hasText("Pick fruit", "the trigger says what to do");
    });

    test("an empty mobile multi falls back to the default text", async function (assert) {
      forceMobile();
      const empty = [];

      await render(
        <template>
          <DSelect @items={{FRUITS}} @multiple={{true}} @value={{empty}} />
        </template>
      );

      assert
        .dom(`${TRIGGER} .d-select__placeholder`)
        .hasText(i18n("d_select.add_placeholder"));
    });

    for (const variant of ["button", "static"]) {
      test(`an empty desktop ${variant} multi shows its placeholder`, async function (assert) {
        const empty = [];

        await render(
          <template>
            <DSelect
              @items={{FRUITS}}
              @multiple={{true}}
              @placeholder="Pick fruit"
              @value={{empty}}
              @variant={{variant}}
            />
          </template>
        );

        assert.dom(`${TRIGGER} .d-select__placeholder`).hasText("Pick fruit");
      });
    }

    test("a held value replaces the placeholder", async function (assert) {
      forceMobile();
      const held = [1];

      await render(
        <template>
          <DSelect
            @items={{FRUITS}}
            @multiple={{true}}
            @placeholder="Pick fruit"
            @value={{held}}
          />
        </template>
      );

      assert.dom(".d-select__chip").exists("the chip shows");
      assert
        .dom(`${TRIGGER} .d-select__placeholder`)
        .doesNotExist("and no placeholder sits beside it");
    });

    test("a desktop typeahead keeps it on the input, once", async function (assert) {
      const empty = [];

      await render(
        <template>
          <DSelect
            @items={{FRUITS}}
            @multiple={{true}}
            @placeholder="Pick fruit"
            @value={{empty}}
          />
        </template>
      );

      assert
        .dom(`${TRIGGER} [role='combobox']`)
        .hasAttribute("placeholder", "Pick fruit", "the input carries it");
      assert
        .dom(`${TRIGGER} .d-select__placeholder`)
        .doesNotExist("with no second copy beside it");
    });
  }
);

/** A promise whose settlement the test controls. */
function deferred() {
  let resolve;
  const promise = new Promise((done) => (resolve = done));
  return { promise, resolve };
}

/** Dispatches a paste carrying `text` on the element. */
function paste(selector, text) {
  const data = new DataTransfer();
  data.setData("text", text);
  data.setData("text/plain", text);
  const event = new ClipboardEvent("paste", {
    clipboardData: data,
    bubbles: true,
    cancelable: true,
  });
  find(selector).dispatchEvent(event);
  return event;
}

const FRUIT = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry" },
  { id: 4, name: "Damson", disabled: true },
];

/** The option whose text includes `name`. */
function optionNamed(name) {
  return findAll("[role='option']").find((row) =>
    row.textContent.includes(name)
  );
}

/** An action row that hands `batch` to `control.selectMany`. */
function bulkRow(batch) {
  return () => [
    {
      id: "bulk",
      name: "Add several",
      onSelect(control) {
        control.selectMany?.(batch);
      },
    },
  ];
}

module(
  "Integration | ui-kit | select | DSelect (multi bulk add)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("selectMany adds a batch in one change", async function (assert) {
      const onChange = sinon.spy();
      const specialItems = bulkRow([FRUIT[0], FRUIT[1], FRUIT[2]]);

      await render(
        <template>
          <DSelect
            @items={{FRUIT}}
            @multiple={{true}}
            @onChange={{onChange}}
            @specialItems={{specialItems}}
            @value={{(array)}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();
      await dSelect().selectByName("Add several");

      assert.true(onChange.calledOnce, "one emit");
      assert.deepEqual(onChange.lastCall.args[0], [1, 2, 3]);
    });

    test("selectMany skips held, disabled and repeated items", async function (assert) {
      const onChange = sinon.spy();
      const specialItems = bulkRow([FRUIT[0], FRUIT[1], FRUIT[1], FRUIT[3]]);

      await render(
        <template>
          <DSelect
            @items={{FRUIT}}
            @multiple={{true}}
            @onChange={{onChange}}
            @specialItems={{specialItems}}
            @value={{array 1}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();
      await dSelect().selectByName("Add several");

      assert.true(onChange.calledOnce);
      assert.deepEqual(onChange.lastCall.args[0], [1, 2], "only Banana is new");
    });

    test("selectMany stops at the cap and says what was left out", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      const onChange = sinon.spy();
      const specialItems = bulkRow([FRUIT[1], FRUIT[2]]);

      await render(
        <template>
          <A11yLiveRegions />
          <DSelect
            @items={{FRUIT}}
            @maximum={{2}}
            @multiple={{true}}
            @onChange={{onChange}}
            @specialItems={{specialItems}}
            @value={{array 1}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();
      await dSelect().selectByName("Add several");

      assert.deepEqual(
        onChange.lastCall.args[0],
        [1, 2],
        "truncated to the cap"
      );
      const polite = find("#a11y-announcements-polite").textContent;
      assert.true(/1 added/.test(polite), `reports the addition: ${polite}`);
      assert.true(/1 not added/.test(polite), `reports the skip: ${polite}`);
    });

    test("a batch that adds nothing still cancels an older update", async function (assert) {
      const gate = deferred();
      const onChange = sinon.spy();
      const specialItems = () => [
        {
          id: "slow",
          name: "Slow add",
          onSelect(control) {
            control.update(async (scope) => {
              await gate.promise;
              scope.select(FRUIT[2]);
            });
          },
        },
        {
          id: "bulk",
          name: "Add held",
          onSelect(control) {
            control.selectMany?.([FRUIT[0]]);
          },
        },
      ];

      await render(
        <template>
          <DSelect
            @items={{FRUIT}}
            @multiple={{true}}
            @onChange={{onChange}}
            @specialItems={{specialItems}}
            @value={{array 1}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();
      try {
        optionNamed("Slow add").click();
        optionNamed("Add held").click();
      } finally {
        gate.resolve();
        await settled();
      }

      assert.true(onChange.notCalled, "the newer, empty intent wins");
    });

    test("a parsed paste adds every item and clears the query", async function (assert) {
      const onChange = sinon.spy();
      const parsePaste = (text) =>
        text.includes("|")
          ? text.split("|").map((name) => FRUIT.find((f) => f.name === name))
          : null;

      await render(
        <template>
          <DSelect
            @items={{FRUIT}}
            @multiple={{true}}
            @onChange={{onChange}}
            @parsePaste={{parsePaste}}
            @value={{(array)}}
          />
        </template>
      );
      await click("[role='combobox']");
      await fillIn("[role='combobox']", "x");
      const event = paste("[role='combobox']", "Apple|Cherry");
      await settled();

      assert.true(event.defaultPrevented, "the paste is consumed");
      assert.true(onChange.calledOnce);
      assert.deepEqual(onChange.lastCall.args[0], [1, 3]);
      assert.dom("[role='combobox']").hasValue("", "the query is cleared");
    });

    test("a paste the parser declines is left alone", async function (assert) {
      const onChange = sinon.spy();
      const parsePaste = () => null;

      await render(
        <template>
          <DSelect
            @items={{FRUIT}}
            @multiple={{true}}
            @onChange={{onChange}}
            @parsePaste={{parsePaste}}
            @value={{(array)}}
          />
        </template>
      );
      await click("[role='combobox']");
      const event = paste("[role='combobox']", "Apple");
      await settled();

      assert.false(event.defaultPrevented, "default paste proceeds");
      assert.true(onChange.notCalled);
    });

    test("an async parse is superseded by a hand pick", async function (assert) {
      const parsed = deferred();
      const onChange = sinon.spy();
      const parsePaste = () => parsed.promise;

      await render(
        <template>
          <DSelect
            @items={{FRUIT}}
            @multiple={{true}}
            @onChange={{onChange}}
            @parsePaste={{parsePaste}}
            @value={{(array)}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();
      try {
        paste(".d-select__filter", "Apple|Cherry");
        optionNamed("Banana").click();
      } finally {
        parsed.resolve([FRUIT[0], FRUIT[2]]);
        await settled();
      }

      assert.deepEqual(
        onChange.args.map(([value]) => value),
        [[2]],
        "only the hand pick lands"
      );
    });

    test("the button variant's filter takes a parsed paste", async function (assert) {
      const onChange = sinon.spy();
      const parsePaste = (text) =>
        text.split("|").map((name) => FRUIT.find((f) => f.name === name));

      await render(
        <template>
          <DSelect
            @items={{FRUIT}}
            @multiple={{true}}
            @onChange={{onChange}}
            @parsePaste={{parsePaste}}
            @value={{(array)}}
            @variant="button"
          />
        </template>
      );
      await dSelect().open();
      paste(".d-select__filter", "Apple|Banana");
      await settled();

      assert.deepEqual(onChange.lastCall?.args[0], [1, 2]);
    });
  }
);

/** A controlled multi host for the strip tests. */
class StripHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value) {
    this.args.onChange?.(value);
    this.value = value;
  }

  <template>
    <A11yLiveRegions />
    <DSelect
      @items={{ITEMS}}
      @label="Fruit"
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @value={{this.value}}
      @variant={{@variant}}
    />
  </template>
}

const MODAL = ".fk-d-menu-modal";

/** An element's accessible name from aria-labelledby, aria-label or its text. */
function accessibleName(element) {
  const ids = element?.getAttribute("aria-labelledby");
  if (ids) {
    return ids
      .split(/\s+/)
      .map((id) => document.getElementById(id)?.textContent.trim() ?? "")
      .join(" ")
      .trim();
  }
  return (
    element?.getAttribute("aria-label") ??
    element?.textContent ??
    ""
  ).trim();
}

/** Whether `first` precedes `second` in document order. */
function isBefore(first, second) {
  const ordered = [...document.querySelectorAll("*")];
  return ordered.indexOf(first) < ordered.indexOf(second);
}

/** The strip's remove buttons, in order. */
function stripButtons() {
  return findAll(`${MODAL} .d-select__strip button`);
}

module(
  "Integration | ui-kit | select | DSelect (selection strip)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      forceMobile();
    });

    test("the mobile modal lists held items below the input", async function (assert) {
      await render(
        <template>
          <StripHost @multiple={{true}} @value={{array 1 2}} />
        </template>
      );
      await click(".d-select__trigger");

      const strip = find(`${MODAL} .d-select__strip`);
      assert.dom(strip).exists("a multi-select shows its strip in the modal");
      assert
        .dom(strip.matches("ul") ? strip : strip.querySelector("ul"))
        .hasAttribute("aria-label", "Selected items");
      const names = stripButtons().map(accessibleName);
      assert.strictEqual(names.length, 2, "one remove button per held item");
      assert.true(
        names[0].startsWith("Apple"),
        `named for its item: ${names[0]}`
      );
      assert.true(names[1].startsWith("Banana"), `in held order: ${names[1]}`);

      const input = find(`${MODAL} [role='combobox']`);
      const listbox = find(`${MODAL} [role='listbox']`);
      assert.true(
        isBefore(input, strip),
        "the strip comes after the query input"
      );
      assert.true(isBefore(strip, listbox), "and before the list");
    });

    test("the strip is one tab stop roved with the arrow keys", async function (assert) {
      await render(
        <template>
          <StripHost @multiple={{true}} @value={{array 1 2 3}} />
        </template>
      );
      await click(".d-select__trigger");

      const buttons = stripButtons();
      assert.deepEqual(
        buttons.map((button) => button.tabIndex),
        [0, -1, -1],
        "only one chip is a tab stop"
      );
      buttons[0].focus();
      await triggerKeyEvent(buttons[0], "keydown", "ArrowRight");
      assert.strictEqual(
        document.activeElement,
        stripButtons()[1],
        "ArrowRight moves to the next chip"
      );
    });

    test("Delete removes a chip, announces it and keeps focus in the strip", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      const onChange = sinon.spy();
      await render(
        <template>
          <StripHost
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{array 1 2 3}}
          />
        </template>
      );
      await click(".d-select__trigger");

      stripButtons()[1].focus();
      await triggerKeyEvent(stripButtons()[1], "keydown", "Delete");

      assert.deepEqual(onChange.lastCall?.args[0], [1, 3], "Banana is removed");
      assert
        .dom("#a11y-announcements-polite")
        .includesText("Removed Banana", "the removal is announced");
      assert.true(
        accessibleName(document.activeElement).startsWith("Apple"),
        "focus moves to the previous chip"
      );
    });

    test("removing the first chip focuses the next one", async function (assert) {
      await render(
        <template>
          <StripHost @multiple={{true}} @value={{array 1 2}} />
        </template>
      );
      await click(".d-select__trigger");

      stripButtons()[0].focus();
      await triggerKeyEvent(stripButtons()[0], "keydown", "Backspace");

      assert.true(
        accessibleName(document.activeElement).startsWith("Banana"),
        "focus moves to the next chip"
      );
    });

    test("removing the last held item hands focus to the query input", async function (assert) {
      await render(
        <template><StripHost @multiple={{true}} @value={{array 1}} /></template>
      );
      await click(".d-select__trigger");

      stripButtons()[0].focus();
      await triggerKeyEvent(stripButtons()[0], "keydown", "Delete");

      assert
        .dom(`${MODAL} .d-select__strip`)
        .doesNotExist("an empty strip goes away");
      assert.strictEqual(
        document.activeElement,
        find(`${MODAL} [role='combobox']`),
        "focus lands on the query input, never the body"
      );
    });

    test("in the static modal, removing the last item focuses the list", async function (assert) {
      await render(
        <template>
          <StripHost @multiple={{true}} @value={{array 1}} @variant="static" />
        </template>
      );
      await click(".d-select__trigger");

      stripButtons()[0].focus();
      await triggerKeyEvent(stripButtons()[0], "keydown", "Delete");

      assert.notStrictEqual(
        document.activeElement,
        document.body,
        "never the body"
      );
      assert.true(
        Boolean(document.activeElement?.closest(`${MODAL} [role='listbox']`)),
        "focus lands in the list"
      );
    });

    test("a pointer removal works and the strip follows the value", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <StripHost
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );
      await click(".d-select__trigger");
      await click(stripButtons()[0]);

      assert.deepEqual(onChange.lastCall?.args[0], [2]);
      assert.strictEqual(stripButtons().length, 1);
    });

    test("a single select has no strip", async function (assert) {
      await render(<template><StripHost @value={{1}} /></template>);
      await click(".d-select__trigger");

      assert.dom(`${MODAL} .d-select__strip`).doesNotExist();
    });

    test("a multi-select holding nothing has no strip", async function (assert) {
      await render(<template><StripHost @multiple={{true}} /></template>);
      await click(".d-select__trigger");

      assert.dom(`${MODAL} .d-select__strip`).doesNotExist();
    });

    test("the mobile modal is named after the field", async function (assert) {
      await render(<template><StripHost @multiple={{true}} /></template>);
      await click(".d-select__trigger");

      assert
        .dom(MODAL)
        .hasAttribute("aria-label", "Fruit", "the dialog has a name");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (Escape focus)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("Escape from a panel control returns focus to the typeahead input", async function (assert) {
      await render(
        <template>
          <DSelect @items={{ITEMS}}>
            <:footer>
              <button class="test-footer-btn" type="button">Act</button>
            </:footer>
          </DSelect>
        </template>
      );
      await click("[role='combobox']");
      find(".test-footer-btn").focus();
      await triggerKeyEvent(".test-footer-btn", "keydown", "Escape");

      assert.dom("[role='listbox']").doesNotExist("the panel closes");
      assert.strictEqual(
        document.activeElement,
        find("[role='combobox']"),
        "focus returns to the input, not the body"
      );
    });
  }
);
