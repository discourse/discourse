import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  ITEMS,
  MultiLimitsHost,
  optionWithText,
} from "discourse/tests/helpers/d-select-hosts";
import DSelect from "discourse/ui-kit/select/d-select";

class NoneRowHost extends Component {
  @tracked value = this.args.value ?? null;

  @action
  onChange(value, payload) {
    this.args.onChange?.(value, payload);
    this.value = value;
  }

  <template>
    <DSelect
      @variant={{@variant}}
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @noneLabel="None"
      @placeholder="Pick one"
    />
  </template>
}

class NoneRowMultiHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value, payload) {
    this.args.onChange?.(value, payload);
    this.value = value;
  }

  <template>
    <DSelect
      @multiple={{true}}
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @noneLabel="None"
      @placeholder="Pick some"
    />
  </template>
}

module("Integration | ui-kit | DSelect (none row)", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the none row first with its public DOM contract", async function (assert) {
    await render(<template><NoneRowHost /></template>);
    await click("[role='combobox']");

    assert
      .dom("li.d-combobox__option.--none[role='option']")
      .exists({ count: 1 }, "the none row uses the option DOM contract")
      .hasText("None", "the none row renders the literal label");
    assert.deepEqual(
      findAll("[role='option']").map((option) => option.textContent.trim()),
      ["None", "Apple", "Banana", "Cherry pie"],
      "the none row precedes every source option"
    );
  });

  test("pointer selection emits null, closes, and restores the placeholder", async function (assert) {
    const onChange = sinon.spy();
    await render(
      <template><NoneRowHost @value={{2}} @onChange={{onChange}} /></template>
    );
    await click("[role='combobox']");

    await click("li.d-combobox__option.--none");

    assert.strictEqual(onChange.callCount, 1, "the pointer pick emits once");
    assert.strictEqual(
      onChange.firstCall.args[0],
      null,
      "the none row emits null"
    );
    assert.dom("[role='listbox']").doesNotExist("the pointer pick closes");
    assert
      .dom("[role='combobox']")
      .hasValue("", "the trigger no longer displays the old selection")
      .hasAttribute(
        "placeholder",
        "Pick one",
        "the empty trigger shows its placeholder"
      );
    assert
      .dom(".d-combobox__presentation")
      .doesNotExist("no selection presentation encodes the none label");
  });

  test("keyboard Enter on the none row emits null and closes", async function (assert) {
    const onChange = sinon.spy();
    await render(
      <template><NoneRowHost @value={{1}} @onChange={{onChange}} /></template>
    );
    await click("[role='combobox']");
    await triggerKeyEvent("[role='combobox']", "keydown", "ArrowUp");

    assert
      .dom("[role='option'].--active")
      .hasText("None", "keyboard navigation highlights the none row");

    await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

    assert.strictEqual(onChange.callCount, 1, "Enter emits once");
    assert.strictEqual(
      onChange.firstCall.args[0],
      null,
      "Enter on the none row emits null"
    );
    assert.dom("[role='listbox']").doesNotExist("Enter closes the overlay");
  });

  test("none and real options have mutually exclusive aria-selected state", async function (assert) {
    await render(<template><NoneRowHost /></template>);
    await click("[role='combobox']");

    assert
      .dom("li.d-combobox__option.--none")
      .hasAttribute(
        "aria-selected",
        "true",
        "none is selected for a null value"
      );
    assert
      .dom("[role='option'][aria-selected='true']")
      .exists({ count: 1 }, "only none is selected for a null value");

    await click(optionWithText("Banana"));
    await click("[role='combobox']");

    assert
      .dom("li.d-combobox__option.--none")
      .hasAttribute(
        "aria-selected",
        "false",
        "none is not selected for a real value"
      );
    assert
      .dom("[role='option'][aria-selected='true']")
      .exists({ count: 1 }, "exactly one option remains selected")
      .hasText("Banana", "the real value's row is selected");
  });

  test("re-picking none closes without a redundant change", async function (assert) {
    const onChange = sinon.spy();
    await render(<template><NoneRowHost @onChange={{onChange}} /></template>);
    await click("[role='combobox']");

    await click("li.d-combobox__option.--none");

    assert.strictEqual(
      onChange.callCount,
      0,
      "re-picking none emits no redundant change"
    );
    assert
      .dom("[role='listbox']")
      .doesNotExist("re-picking none still closes the overlay");
  });

  test("includes none in the ARIA option positions", async function (assert) {
    await render(<template><NoneRowHost /></template>);
    await click("[role='combobox']");

    const options = findAll("[role='option']");
    assert.deepEqual(
      options.map((option) => option.getAttribute("aria-setsize")),
      ["4", "4", "4", "4"],
      "none and all source rows report the combined set size"
    );
    assert.deepEqual(
      options.map((option) => option.getAttribute("aria-posinset")),
      ["1", "2", "3", "4"],
      "none occupies position one and source rows follow it"
    );
  });

  test("Home lands on none as logical option zero", async function (assert) {
    // A non-editable (static) controller is required: on an editable typeahead input Home/End
    // stay with the text caret rather than navigating the list (d-roving-focus keeps them for an
    // editable controller). The none row is still the first logical option in either variant.
    await render(
      <template><NoneRowHost @variant="static" @value={{3}} /></template>
    );
    await click("[role='combobox']");

    await triggerKeyEvent("[role='combobox']", "keydown", "Home");

    const noneOption = find("li.d-combobox__option.--none");
    assert
      .dom(noneOption)
      .hasClass("--active", "Home highlights the none row")
      .hasAttribute(
        "data-logical-index",
        "0",
        "none is the first logical option"
      );
    assert
      .dom("[role='combobox']")
      .hasAttribute(
        "aria-activedescendant",
        noneOption.id,
        "the controller points at none after Home"
      );
  });

  test("a non-empty unmatched query excludes none and cannot clear the value", async function (assert) {
    const onChange = sinon.spy();
    await render(
      <template><NoneRowHost @value={{2}} @onChange={{onChange}} /></template>
    );
    await click("[role='combobox']");

    assert
      .dom("li.d-combobox__option.--none")
      .exists("none is available before a query is entered");

    await fillIn("[role='combobox']", "zzzz");

    assert
      .dom("li.d-combobox__option.--none")
      .doesNotExist("none is filtered out for a non-empty query");
    assert
      .dom("[role='option']")
      .doesNotExist("the unmatched query has no activatable option");
    assert
      .dom(".d-combobox__empty[role='status']")
      .hasText(
        "No results found",
        "the ordinary no-results state remains visible"
      );

    await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

    assert.strictEqual(
      onChange.callCount,
      0,
      "Enter with no match does not clear or otherwise change the value"
    );
    // A desktop typeahead restores the selected label into the input on close (see the "closing
    // restores the selected label" test); the presentation node is not this variant's display
    // surface. Value preservation itself is pinned by the callCount assertion above.
    await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
    assert
      .dom("[role='combobox']")
      .hasValue("Banana", "the selected value survives an unmatched query");
  });

  test("noneLabel is inert for multi-select emissions", async function (assert) {
    const onChange = sinon.spy();
    await render(
      <template>
        <NoneRowHost />
        <NoneRowMultiHost @onChange={{onChange}} />
      </template>
    );

    const [singleController, multiController] = findAll("[role='combobox']");
    await click(singleController);
    assert
      .dom("li.d-combobox__option.--none")
      .exists("noneLabel is active for the single-select control");
    await triggerKeyEvent(singleController, "keydown", "Escape");

    await click(multiController);

    assert
      .dom("li.d-combobox__option.--none")
      .doesNotExist("multi-select renders no none row");
    assert
      .dom("[role='option']")
      .exists(
        { count: ITEMS.length },
        "multi-select renders only source options"
      );

    await click(optionWithText("Apple"));
    await click(optionWithText("Banana"));

    assert.strictEqual(onChange.callCount, 2, "both selections emit a change");
    assert.deepEqual(
      onChange.args.map(([value]) => value),
      [[1], [1, 2]],
      "multi-select emissions contain source ids and never inject null"
    );
  });
});

module(
  "Integration | ui-kit | select | DSelect (pointer and cursor)",
  function (hooks) {
    setupRenderingTest(hooks);

    // Clicking a row rebuilds the item list, which re-runs the cursor reconcile; with no cursor
    // established it fell through to "highlight the first row", so a pointer user saw an
    // unrelated row marked. `aria-activedescendant` pointed there too, so a screen reader was
    // told the cursor was somewhere the reader had never been.
    test("a pointer selection moves the cursor without showing it", async function (assert) {
      await render(
        <template>
          <DSelect @items={{ITEMS}} @multiple={{true}} @value={{array}} />
        </template>
      );
      await click("[role='combobox']");

      const rows = findAll("[role='option']");
      assert.true(rows.length > 2, "the list has rows to move between");
      await click(rows[1]);

      // Nothing is highlighted: the reader is looking at the row they just clicked, and a mark
      // appearing anywhere reads as a second kind of selection.
      assert
        .dom("[role='option'].--active")
        .doesNotExist("a pointer press leaves no visible cursor");

      // But it did move. The first arrow continues from the clicked row rather than restarting
      // at the top, which is what makes the invisible move worth doing.
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      assert
        .dom("[role='option'].--active")
        .hasText(
          findAll("[role='option']")[2].textContent.trim(),
          "the keyboard resumes from the row the pointer acted on"
        );
    });

    // Auto-highlighting the first row is right for "type, then Enter takes the top match". But in
    // a multi-select, activating a held row REMOVES it, so when the first row happened to be one
    // of the held ones a reflexive Enter dropped a value the reader never navigated to. The cursor
    // starts at the first row Enter cannot remove instead, which keeps the affordance pointing at
    // an add rather than trading it away for an inert list.
    //
    // Two rows are held deliberately: with only one, an implementation that stepped to `items[1]`
    // rather than scanning would pass and the bug would come back on the second held row.
    test("opening a multi scans past every held row", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost @value={{array 1 2}} @onChange={{onChange}} />
        </template>
      );

      await click(".d-combobox__input");
      const controller = find("[role='combobox']");

      const rows = findAll("[role='option']");
      assert
        .dom(rows[0])
        .hasAttribute("aria-selected", "true", "row 1 is held");
      assert
        .dom(rows[1])
        .hasAttribute("aria-selected", "true", "row 2 is held");
      assert
        .dom("[role='option'].--active")
        .hasText("Cherry pie", "the cursor lands past both of them");
      assert
        .dom("[role='option'].--active")
        .hasAttribute(
          "aria-selected",
          "false",
          "the highlighted row is one Enter cannot remove"
        );
      assert.strictEqual(
        controller.getAttribute("aria-activedescendant"),
        find("[role='option'].--active").id,
        "the highlight is what assistive tech is pointed at"
      );

      await triggerKeyEvent(controller, "keydown", "Enter");

      assert.strictEqual(onChange.callCount, 1, "Enter emits exactly once");
      assert.deepEqual(
        onChange.lastCall?.args[0],
        [1, 2, 3],
        "Enter adds the highlighted row rather than dropping a held one"
      );
    });

    // The degenerate end of the same rule: nothing is safe to seed, so the cursor stays empty
    // rather than falling back to a held row.
    test("opening a multi with every row held leaves the cursor empty", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost @value={{array 1 2 3}} @onChange={{onChange}} />
        </template>
      );

      await click(".d-combobox__input");
      const controller = find("[role='combobox']");

      assert
        .dom("[role='option'].--active")
        .doesNotExist("no row is safe to highlight");
      assert.false(
        Boolean(controller.getAttribute("aria-activedescendant")),
        "nothing is advertised as active"
      );

      await triggerKeyEvent(controller, "keydown", "Enter");
      assert.strictEqual(onChange.callCount, 0, "Enter drops nothing");
    });

    // The counterweight: skipping held rows is a MULTI rule, keyed on activation being
    // destructive — not on the cursor merely preferring the top match. A filtering single-select
    // also declines to restore the selection, but activating its held row just re-confirms it, so
    // the top match keeps the cursor even when the top match IS the held value. Deriving the skip
    // from that preference instead silently retargeted Enter onto the second-best match.
    test("filtering a single-select keeps the cursor on a held top match", async function (assert) {
      await render(
        <template><DSelect @items={{ITEMS}} @value={{1}} /></template>
      );

      await click("[role='combobox']");
      await fillIn("[role='combobox']", "a");

      assert
        .dom(findAll("[role='option']")[0])
        .hasAttribute("aria-selected", "true", "the top match is the held row");
      assert
        .dom("[role='option'].--active")
        .hasText("Apple", "it keeps the cursor rather than being skipped");
    });

    // An action row runs a callback; it never becomes a value. Marking it selected because its id
    // happens to match a held one is wrong on every surface it reaches — it draws the chosen-value
    // fill and check, announces itself as selected, and gets scrolled to on open as though it were
    // the selection. It also made the multi cursor step over a row that removes nothing.
    test("an action row is never flagged selected, even when its id matches a held value", async function (assert) {
      const onChange = sinon.spy();
      const onManage = sinon.spy();
      const items = [
        { id: 1, name: "Manage notifications", onSelect: onManage },
        { id: 2, name: "Banana" },
        { id: 3, name: "Cherry pie" },
      ];

      await render(
        <template>
          <MultiLimitsHost
            @items={{items}}
            @value={{array 1}}
            @onChange={{onChange}}
          />
        </template>
      );

      await click(".d-combobox__input");
      const controller = find("[role='combobox']");
      const actionRow = findAll("[role='option']")[0];

      assert
        .dom(actionRow)
        .hasAttribute(
          "aria-selected",
          "false",
          "the action row is not announced as a chosen value"
        )
        .doesNotHaveClass("--selected", "and carries no selected styling");

      // The cursor consequence: it is safe to start on, because activating it removes nothing.
      assert
        .dom("[role='option'].--active")
        .hasText(
          "Manage notifications",
          "so the cursor starts on it rather than stepping over it"
        );

      await triggerKeyEvent(controller, "keydown", "Enter");

      // Both halves: the callback runs, and no value moved. Asserting only the ARIA attribute
      // would pass an implementation that made the row inert.
      assert.strictEqual(onManage.callCount, 1, "Enter runs the action");
      assert.strictEqual(onChange.callCount, 0, "and changes no value");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (splitter rows)",
  function (hooks) {
    setupRenderingTest(hooks);

    const SECTIONED = [
      { id: 1, name: "Apple", section: "fruit" },
      { id: 2, name: "Apricot", section: "fruit" },
      { id: 3, name: "Beet", section: "vegetable" },
    ];

    test("an unlabeled group boundary draws a splitter that is never an option", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{SECTIONED}}
            @groupBy="section"
            @identifier="test-select"
          />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom(".d-combobox__divider")
        .exists({ count: 1 }, "one splitter separates the two sections");
      assert
        .dom("[role='option']")
        .exists({ count: 3 }, "a splitter is not an option");
      assert
        .dom(".d-combobox__divider")
        .hasAttribute(
          "aria-hidden",
          "true",
          "a rule carries no meaning for a reader"
        );
      assert.deepEqual(
        findAll("[role='option']").map((option) =>
          option.getAttribute("data-logical-index")
        ),
        ["0", "1", "2"],
        "navigation indices stay contiguous across the splitter"
      );
    });

    test("a splitter survives a query while both of its groups do", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{SECTIONED}}
            @groupBy="section"
            @identifier="test-select"
          />
        </template>
      );
      await fillIn("[role='combobox']", "e");

      assert
        .dom("[role='option']")
        .exists({ count: 2 }, "one option per section matches the query");
      assert
        .dom(".d-combobox__divider")
        .exists(
          { count: 1 },
          "the boundary is recomputed from the filtered rows, not dropped"
        );
    });

    test("a splitter disappears when the query leaves a single group", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{SECTIONED}}
            @groupBy="section"
            @identifier="test-select"
          />
        </template>
      );
      await fillIn("[role='combobox']", "ap");

      assert
        .dom("[role='option']")
        .exists({ count: 2 }, "only the fruit section matches");
      assert
        .dom(".d-combobox__divider")
        .doesNotExist("nothing is left for a rule to separate");
    });
  }
);
