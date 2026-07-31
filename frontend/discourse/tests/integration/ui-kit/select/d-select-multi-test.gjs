import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import {
  click,
  find,
  findAll,
  focus,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { clearCallbacks } from "discourse/select-kit/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  DefaultHost,
  ITEMS,
  optionWithText,
} from "discourse/tests/helpers/d-select-hosts";
import { resetLegacyBridge } from "discourse/ui-kit/select/-internals/modify-select-kit-bridge";
import DSelect from "discourse/ui-kit/select/d-select";

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

class MultiValueCoercionHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value, payload) {
    this.args.onChange?.(value, payload, this.value);
    this.value = value;
  }

  <template>
    <DSelect
      @multiple={{true}}
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder="Pick some"
      @identifier="test-multi-value-coercion"
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

      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "two chips to start");

      // The mechanism, asserted directly: the label resolves to the sink rather than to any
      // control inside the trigger. This is what makes the protection structural, so it is what
      // must fail if a labelable element is ever introduced ahead of the sink.
      assert.strictEqual(
        find(".field-label").control,
        find(".d-combobox__label-sink"),
        "the label's control is the sink, not a chip's remove button"
      );

      await click(".field-text");
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "clicking the label's text removes nothing");

      await click(".field-label");
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "nor does clicking the label itself");
    });

    // The guard above must not cost the chip its own keyboard removal, which produces a click
    // that looks identical to a forwarded one.
    test("Enter on a focused chip still removes it", async function (assert) {
      await render(<template><MultiHost @value={{array 1 2}} /></template>);

      const remove = findAll(".d-combobox__chip-remove")[0];
      await focus(remove);
      await triggerKeyEvent(remove, "keydown", "Enter");
      await click(remove);

      assert
        .dom(".d-combobox__chip")
        .exists({ count: 1 }, "the keyboard path still removes a chip");
    });

    test("shows the placeholder when empty", async function (assert) {
      await render(<template><MultiHost /></template>);
      assert.dom(".d-combobox__input").hasAttribute("placeholder", "Pick some");
      assert.dom(".d-combobox__chip").doesNotExist();
    });

    test("selecting adds a chip, keeps the menu open, and keeps the picked row flagged", async function (assert) {
      await render(<template><MultiHost /></template>);
      await click(".d-combobox__input");
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
      assert.dom(".d-combobox__chip").exists({ count: 1 }, "a chip is added");
      assert
        .dom("[role='option']")
        .exists({ count: 3 }, "the picked item stays in the list");
      assert
        .dom("[role='option'][aria-selected='true']")
        .exists({ count: 1 }, "the picked row is flagged selected");
      assert
        .dom(
          "[role='option'][aria-selected='true'] .d-combobox__option-selected-icon"
        )
        .exists("the selected row carries a check");

      // Clicking the first option again would toggle the now-selected item back
      // off, so pick a still-unselected row to add a second chip.
      await click("[role='option'][aria-selected='false']");
      assert.dom(".d-combobox__chip").exists({ count: 2 });
    });

    test("removing a chip deselects it", async function (assert) {
      await render(<template><MultiHost @value={{array 1 2}} /></template>);
      assert.dom(".d-combobox__chip").exists({ count: 2 });

      // The chip is a span; removal is its inner button, not the chip itself.
      await click(".d-combobox__chip .d-combobox__chip-remove");
      assert.dom(".d-combobox__chip").exists({ count: 1 }, "one chip removed");
    });

    test("each chip is a list item with an inner remove button named for its label", async function (assert) {
      await render(<template><MultiHost @value={{array 1}} /></template>);

      // The chips are a native labelled <ul>/<li> list (real "Selected items, list, N items"
      // semantics) rather than a role=group of spans; removal is the chip's inner button.
      assert
        .dom("li.d-combobox__chip")
        .exists({ count: 1 }, "the chip is a list item, not a button");
      assert
        .dom("ul.d-combobox__chip-list")
        .hasAttribute("aria-label", /.+/, "the chips are a labelled list");

      const removeButton = find(".d-combobox__chip .d-combobox__chip-remove");
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
            @multiple={{true}}
            @items={{spacedItems}}
            @value={{array "bug fix"}}
          />
        </template>
      );

      const labelledby = find(".d-combobox__chip-remove").getAttribute(
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
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "one fallback chip renders for each selection");
      assert
        .dom(".d-combobox__chip:first-child")
        .includesText("Apple", "chips use the selection fallback");

      await click(".d-combobox__input");
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
            @value={{array 1}}
            @selectedIcon="star"
          />
        </template>
      );
      await click(".d-combobox__input");

      assert
        .dom(
          "[role='option'][aria-selected='true'] .d-combobox__option-selected-icon.d-icon-star"
        )
        .exists("the selected row uses the custom icon, not the default check");
    });
  }
);

module(
  "Integration | ui-kit | DSelect (multi value coercion)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      clearCallbacks();
      resetLegacyBridge();
    });

    test("coerces held string ids when adding a native-id item", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiValueCoercionHost @value={{array "1"}} @onChange={{onChange}} />
        </template>
      );

      await click(".d-combobox__input");
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
            @value={{array "1" "2"}}
            @onChange={{onChange}}
          />
        </template>
      );

      await click(".d-combobox__chip .d-combobox__chip-remove");

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
            @value={{array "999" "1"}}
            @onChange={{onChange}}
          />
        </template>
      );

      await click(".d-combobox__input");
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
          <MultiValueCoercionHost @value={{array "1"}} @onChange={{onChange}} />
        </template>
      );

      await click(".d-combobox__input");
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
            @value="1"
            @onChange={{singleOnChange}}
            @placeholder="Pick one"
          />
          <MultiValueCoercionHost
            @value={{array "1"}}
            @onChange={{multiOnChange}}
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
            @value={{boundValue}}
            @onChange={{onChange}}
          />
        </template>
      );

      await click(".d-combobox__input");
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
        .dom(".d-combobox__chip")
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
          <MultiValueCoercionHost @value={{array "1"}} @onChange={{onChange}} />
        </template>
      );
      await click(".d-combobox__input");
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
          @items={{ITEMS}}
          @value={{this.value}}
          @onChange={{this.onChange}}
          @variant="static"
          @multiple={{true}}
          @clearable={{true}}
          @identifier="test-select"
        />
      </template>
    }

    test("Enter on a chip's remove button does not open the menu", async function (assert) {
      await render(<template><ChipHost /></template>);

      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "the held values render as chips");

      const remove = findAll(".d-combobox__chip-remove")[0];
      await focus(remove);
      await triggerKeyEvent(remove, "keydown", "Enter");

      assert
        .dom("[role='listbox']")
        .doesNotExist(
          "activating a chip's remove button is not a trigger activation"
        );
    });

    test("Backspace on a chip's remove button does not clear the whole selection", async function (assert) {
      await render(<template><ChipHost /></template>);

      const remove = findAll(".d-combobox__chip-remove")[0];
      await focus(remove);
      await triggerKeyEvent(remove, "keydown", "Backspace");

      assert
        .dom(".d-combobox__chip")
        .exists(
          { count: 2 },
          "a key aimed at one chip never empties the selection"
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
        .dom("svg.d-combobox__option-selected-icon")
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
            @items={{ITEMS}}
            @multiple={{true}}
            @value={{array 1}}
            @selectedIcon="star"
            @identifier="test-select"
          />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom(".d-combobox__option-selected-icon.--checkbox")
        .doesNotExist("a supplied glyph is not replaced by the checkbox pair");
      assert
        .dom("[role='option'][aria-selected='true'] .d-icon-star")
        .exists("the supplied glyph still marks the selection");
    });
  }
);
