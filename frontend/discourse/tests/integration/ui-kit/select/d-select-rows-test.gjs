import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  settled,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import {
  ITEMS,
  MultiLimitsHost,
  optionWithText,
} from "discourse/tests/helpers/d-select-hosts";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

class NoneRowHost extends Component {
  @tracked value = this.args.value ?? null;

  @action
  onChange(value, payload) {
    this.args.onChange?.(value, payload);
    this.value = value;
  }

  <template>
    <DSelect
      @items={{ITEMS}}
      @noneRow={{true}}
      @onChange={{this.onChange}}
      @texts={{hash noneLabel="None" placeholder="Pick one"}}
      @value={{this.value}}
      @variant={{@variant}}
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
      @items={{ITEMS}}
      @multiple={{true}}
      @noneRow={{true}}
      @onChange={{this.onChange}}
      @texts={{hash noneLabel="None" placeholder="Pick some"}}
      @value={{this.value}}
    />
  </template>
}

/**
 * The first remove button whose hit area, `distance` CSS pixels out from its center in each
 * direction, lies inside the field's visible box, so clipping by the field's scroll cannot
 * decide the result.
 */
function probeableButton(field, distance) {
  const box = field.getBoundingClientRect();
  const scale = box.height / field.offsetHeight || 1;
  const reach = distance * scale;
  return [...field.querySelectorAll(".d-select__chip-remove")].find(
    (button) => {
      const rect = button.getBoundingClientRect();
      const x = rect.left + rect.width / 2;
      const y = rect.top + rect.height / 2;
      return (
        x - reach > box.left &&
        x + reach < box.right &&
        y - reach > box.top &&
        y + reach < box.bottom
      );
    }
  );
}

/** Whether points `distance` CSS pixels above, below, left and right of the center hit `target`. */
function hitsAround(target, distance) {
  const rect = target.getBoundingClientRect();
  const scale = rect.height / target.offsetHeight || 1;
  const x = rect.left + rect.width / 2;
  const y = rect.top + rect.height / 2;
  const reach = distance * scale;
  return [
    [0, -reach],
    [0, reach],
    [-reach, 0],
    [reach, 0],
  ].every(([dx, dy]) => {
    const hit = document.elementFromPoint(x + dx, y + dy);
    return hit === target || target.contains(hit);
  });
}

module("Integration | ui-kit | DSelect (none row)", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the none row first with its public DOM contract", async function (assert) {
    await render(<template><NoneRowHost /></template>);
    await click("[role='combobox']");

    assert
      .dom("li.d-select__option.--none[role='option']")
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
      <template><NoneRowHost @onChange={{onChange}} @value={{2}} /></template>
    );
    await click("[role='combobox']");

    await click("li.d-select__option.--none");

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
      .dom(".d-select__presentation")
      .doesNotExist("no selection presentation encodes the none label");
  });

  test("keyboard Enter on the none row emits null and closes", async function (assert) {
    const onChange = sinon.spy();
    await render(
      <template><NoneRowHost @onChange={{onChange}} @value={{1}} /></template>
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
      .dom("li.d-select__option.--none")
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
      .dom("li.d-select__option.--none")
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

    await click("li.d-select__option.--none");

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
      <template><NoneRowHost @value={{3}} @variant="static" /></template>
    );
    await click("[role='combobox']");

    await triggerKeyEvent("[role='combobox']", "keydown", "Home");

    const noneOption = find("li.d-select__option.--none");
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
      <template><NoneRowHost @onChange={{onChange}} @value={{2}} /></template>
    );
    await click("[role='combobox']");

    assert
      .dom("li.d-select__option.--none")
      .exists("none is available before a query is entered");

    await fillIn("[role='combobox']", "zzzz");

    assert
      .dom("li.d-select__option.--none")
      .doesNotExist("none is filtered out for a non-empty query");
    assert
      .dom("[role='option']")
      .doesNotExist("the unmatched query has no activatable option");
    assert
      .dom(".d-select__empty[role='status']")
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
      .dom("li.d-select__option.--none")
      .exists("noneLabel is active for the single-select control");
    await triggerKeyEvent(singleController, "keydown", "Escape");

    await click(multiController);

    assert
      .dom("li.d-select__option.--none")
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
          <MultiLimitsHost @onChange={{onChange}} @value={{array 1 2}} />
        </template>
      );

      await click(".d-select__input");
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
          <MultiLimitsHost @onChange={{onChange}} @value={{array 1 2 3}} />
        </template>
      );

      await click(".d-select__input");
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
            @onChange={{onChange}}
            @value={{array 1}}
          />
        </template>
      );

      await click(".d-select__input");
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

    test("@groupDividers false draws no splitter between groups", async function (assert) {
      await render(
        <template>
          <DSelect
            @groupBy="section"
            @groupDividers={{false}}
            @identifier="test-select"
            @items={{SECTIONED}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert.dom(".d-select__divider").doesNotExist();
      assert.dom("[role='option']").exists({ count: 3 });
    });

    test("an unlabeled group boundary draws a splitter that is never an option", async function (assert) {
      await render(
        <template>
          <DSelect
            @groupBy="section"
            @identifier="test-select"
            @items={{SECTIONED}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom(".d-select__divider")
        .exists({ count: 1 }, "one splitter separates the two sections");
      assert
        .dom("[role='option']")
        .exists({ count: 3 }, "a splitter is not an option");
      assert
        .dom(".d-select__divider")
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
            @groupBy="section"
            @identifier="test-select"
            @items={{SECTIONED}}
          />
        </template>
      );
      await fillIn("[role='combobox']", "e");

      assert
        .dom("[role='option']")
        .exists({ count: 2 }, "one option per section matches the query");
      assert
        .dom(".d-select__divider")
        .exists(
          { count: 1 },
          "the boundary is recomputed from the filtered rows, not dropped"
        );
    });

    test("a splitter disappears when the query leaves a single group", async function (assert) {
      await render(
        <template>
          <DSelect
            @groupBy="section"
            @identifier="test-select"
            @items={{SECTIONED}}
          />
        </template>
      );
      await fillIn("[role='combobox']", "ap");

      assert
        .dom("[role='option']")
        .exists({ count: 2 }, "only the fruit section matches");
      assert
        .dom(".d-select__divider")
        .doesNotExist("nothing is left for a rule to separate");
    });
  }
);

module("Integration | ui-kit | select | DSelect create row", function (hooks) {
  setupRenderingTest(hooks);

  test("create follows sticky and special rows before grouped source rows", async function (assert) {
    const items = [
      { id: 1, name: "Apple", group: "Fruit" },
      { id: 2, name: "Apricot", group: "Fruit" },
      { id: 3, name: "Maple", group: "Trees" },
    ];
    const specialItems = () => [
      { id: "action", name: "Browse all" },
      { id: "sticky", name: "Pinned", sticky: true },
    ];
    const createItem = (filter) => ({
      id: `new:${filter}`,
      name: filter,
      __create: true,
    });
    const groupHeader = (group) => group;

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createItem={{createItem}}
          @groupBy="group"
          @groupHeader={{groupHeader}}
          @items={{items}}
          @noneRow={{true}}
          @specialItems={{specialItems}}
          @texts={{hash noneLabel="None"}}
        />
      </template>
    );
    await fillIn("[role='combobox']", "ap");

    const options = findAll("[role='option']");
    assert.deepEqual(
      options.map((option) => option.dataset.name),
      ["Pinned", "Browse all", "ap", "Apple", "Apricot", "Maple"],
      "the create row leads both groups after the synthetic prefix"
    );
    assert
      .dom(options[2])
      .hasText(
        i18n("d_select.create_item", { label: "ap" }),
        "the engine names the create action"
      );
    assert
      .dom(options[2])
      .doesNotHaveAttribute("aria-describedby", "create belongs to no group");
    assert
      .dom(options[3])
      .hasAttribute(
        "aria-describedby",
        /-group-0$/,
        "the source keeps its group description"
      );
    options.forEach((option, index) => {
      assert
        .dom(option)
        .hasAttribute(
          "aria-posinset",
          String(index + 1),
          "headers consume no option position"
        );
      assert
        .dom(option)
        .hasAttribute("aria-setsize", "6", "the set includes every option");
    });
  });

  test("create and loaded rows keep prefix positions with an unloaded declared total", async function (assert) {
    const load = () => ({
      items: [
        { id: 1, name: "Apple" },
        { id: 2, name: "Apricot" },
      ],
      total: 20,
      hasMore: true,
    });
    const createItem = (filter) => ({
      id: `new:${filter}`,
      name: filter,
      __create: true,
    });

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createItem={{createItem}}
          @load={{load}}
        />
      </template>
    );
    await fillIn("[role='combobox']", "ap");

    const options = findAll("[role='option']");
    assert
      .dom(options[0])
      .hasClass("--create", "create is reachable before more pages");
    options.forEach((option, index) => {
      assert
        .dom(option)
        .hasAttribute(
          "aria-posinset",
          String(index + 1),
          "loaded rows remain a prefix of the full set"
        );
      assert
        .dom(option)
        .hasAttribute(
          "aria-setsize",
          "21",
          "the declared total includes create"
        );
    });
  });

  test("duplicate checks use the built item's configured key rather than the typed value", async function (assert) {
    const items = [{ code: 5, text: "Apple" }];
    const createItem = (filter) => ({
      code: "5",
      text: filter,
      __create: true,
    });

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createItem={{createItem}}
          @items={{items}}
          @labelField="text"
          @valueField="code"
        />
      </template>
    );
    await fillIn("[role='combobox']", "ap");

    assert
      .dom("[role='option'].--create")
      .doesNotExist(
        "a constructed string key collides with the loaded numeric key even when the filter does not"
      );
  });

  test("a source string value matching the query does not block a distinct create key", async function (assert) {
    const items = [{ id: "ap", name: "Apple" }];
    const createItem = (filter) => ({
      id: `new:${filter}`,
      name: filter,
      __create: true,
    });

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createItem={{createItem}}
          @items={{items}}
        />
      </template>
    );
    await fillIn("[role='combobox']", "ap");

    assert
      .dom("[role='option'].--create")
      .exists("a raw string value is not a duplicate of the built key");
  });

  test("an item block overrides create wording while data-name stays the item label", async function (assert) {
    const createItem = (filter) => ({
      code: `new:${filter}`,
      text: filter.toUpperCase(),
      __create: true,
    });

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createItem={{createItem}}
          @items={{ITEMS}}
          @labelField="text"
          @valueField="code"
        >
          <:item as |item|>
            {{~concat "Use " item.text~}}
          </:item>
        </DSelect>
      </template>
    );
    await fillIn("[role='combobox']", "kiwi");

    assert
      .dom("[role='option'].--create")
      .hasText("Use KIWI", "the consumer controls content")
      .hasAttribute(
        "data-name",
        "KIWI",
        "the hook uses the configured item label"
      );
  });

  test("the item block is told which row is the create row", async function (assert) {
    const createItem = (filter) => ({ id: `new:${filter}`, name: filter });

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createItem={{createItem}}
          @items={{ITEMS}}
        >
          <:item as |item options row|>
            {{~if row.create (concat "Create " item.name) item.name~}}
          </:item>
        </DSelect>
      </template>
    );
    await fillIn("[role='combobox']", "an");

    assert
      .dom("[role='option'].--create")
      .hasText("Create an", "the create row knows it is one");
    assert
      .dom("[role='option'][data-value='2']")
      .hasText("Banana", "a record row is not the create row");
  });

  test("the engine supplies create wording for an unmarked item with a configured label", async function (assert) {
    const createItem = (filter) => ({
      code: `new:${filter}`,
      text: filter.toUpperCase(),
    });
    const items = [];

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createItem={{createItem}}
          @items={{items}}
          @labelField="text"
          @valueField="code"
        />
      </template>
    );
    await fillIn("[role='combobox']", "kiwi");

    assert
      .dom("[role='option']")
      .hasText(
        i18n("d_select.create_item", { label: "KIWI" }),
        "the wording uses the built item's label"
      )
      .hasAttribute("data-name", "KIWI", "the hook remains the value label");
  });

  test("local debounce retains the displayed query for creation and duplicate checks", async function (assert) {
    const allowCreate = sinon.spy((filter) => filter === "ap");
    const createItem = sinon.spy((filter) => ({
      id: `new:${filter}`,
      name: filter,
      __create: true,
    }));

    await render(
      <template>
        <DSelect
          @allowCreate={{allowCreate}}
          @createItem={{createItem}}
          @debounce={{150}}
          @items={{ITEMS}}
        />
      </template>
    );
    await fillIn("[role='combobox']", "ap");
    assert
      .dom("[role='option'].--create")
      .hasAttribute("data-name", "ap", "the initial query offers creation");

    allowCreate.resetHistory();
    createItem.resetHistory();
    const typing = fillIn("[role='combobox']", "apple");
    try {
      await waitUntil(() => allowCreate.called);
      assert
        .dom("[role='option'].--create")
        .hasAttribute(
          "data-name",
          "ap",
          "the retained create row still offers ap"
        );
      assert.true(
        allowCreate.args.every(([filter]) => filter === "ap"),
        "allowCreate sees only the displayed filter"
      );
      assert.true(createItem.called, "the retained proposal is rebuilt");
      assert.true(
        createItem.args.every(([filter]) => filter === "ap"),
        "the factory sees only the displayed filter"
      );
    } finally {
      await typing;
    }
    assert
      .dom("[role='option'].--create")
      .doesNotExist("the settled exact label no longer offers creation");
  });
});

module(
  "Integration | ui-kit | select | DSelect disabled rows and descriptions",
  function (hooks) {
    setupRenderingTest(hooks);
    hooks.beforeEach(() => enableVirtualization());
    hooks.afterEach(() => disableVirtualization());

    test("an item description follows the mixed text direction setting", async function (assert) {
      const items = [{ id: 1, name: "Apple", description: "שלום world" }];

      this.siteSettings.support_mixed_text_direction = true;
      await render(
        <template><DSelect @items={{items}} @variant="static" /></template>
      );
      await click(".d-select__trigger");

      assert
        .dom(".d-select__option-description")
        .hasAttribute(
          "dir",
          "auto",
          "mixed-direction sites let each description pick its own direction"
        );
    });

    test("an item description has no direction override by default", async function (assert) {
      const items = [{ id: 1, name: "Apple", description: "Fruit" }];

      this.siteSettings.support_mixed_text_direction = false;
      await render(
        <template><DSelect @items={{items}} @variant="static" /></template>
      );
      await click(".d-select__trigger");

      assert
        .dom(".d-select__option-description")
        .doesNotHaveAttribute("dir", "the page direction applies");
    });

    test("group, item description and cap share the option description without changing its name", async function (assert) {
      const items = [
        { id: 1, name: "Apple", group: "Fruit" },
        {
          id: 2,
          name: "Banana",
          group: "Fruit",
          description: "Requires permission",
        },
        {
          id: 3,
          name: "Cherry",
          group: "Fruit",
          disabled: true,
          description: "Unavailable today",
        },
      ];
      const groupHeader = (group) => group;
      const onChange = sinon.spy();
      await render(
        <template>
          <DSelect
            @groupBy="group"
            @groupHeader={{groupHeader}}
            @items={{items}}
            @maximum={{1}}
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{array 1}}
            @variant="static"
          >
            <:item as |item|><strong>{{item.name}}</strong></:item>
          </DSelect>
        </template>
      );
      await click(".d-select__trigger");
      const banana = optionWithText("Banana");
      const description = banana.querySelector(".d-select__option-description");
      assert
        .dom(description)
        .isVisible("secondary text is visible with custom row markup")
        .hasText("Requires permission", "the item description is rendered");
      const ids = (banana.getAttribute("aria-describedby") ?? "").split(/\s+/);
      assert.deepEqual(
        ids.map((id) => document.getElementById(id)?.textContent.trim()),
        [
          "Fruit",
          "Requires permission",
          find(".d-select__limit").textContent.trim(),
        ],
        "all three descriptions resolve in order"
      );
      assert
        .dom(document.getElementById(banana.getAttribute("aria-labelledby")))
        .hasText("Banana", "the accessible name excludes secondary text");
      await triggerKeyEvent("[role='combobox']", "keydown", "End");
      assert
        .dom("[role='option'].--active")
        .includesText("Cherry", "End reaches a reason-disabled row at the cap");
      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");
      await click(optionWithText("Cherry"));
      assert.true(
        onChange.notCalled,
        "both activation paths reject a reason-disabled row"
      );
    });

    test("virtual jumps retain consecutive positions through disabled rows and group headers", async function (assert) {
      const items = Array.from({ length: 160 }, (_, index) => ({
        id: index,
        name: `Row ${index}`,
        group: Math.floor(index / 40),
        disabled: index % 2 === 1,
      }));
      const groupHeader = (group) => `Group ${group}`;
      const onChange = sinon.spy();
      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 200px;
              overflow-y: auto;
            }
          </style>
          <DSelect
            @groupBy="group"
            @groupHeader={{groupHeader}}
            @items={{items}}
            @maximum={{1}}
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{array 0}}
            @variant="static"
          />
        </template>
      );
      await click(".d-select__trigger");
      for (const [key, expected] of [
        ["End", "159"],
        ["Home", "0"],
        ["ArrowDown", "1"],
      ]) {
        await triggerKeyEvent("[role='combobox']", "keydown", key);
        await waitUntil(
          () => find("[role='option'].--active")?.dataset.value === expected,
          {
            timeoutMessage: `${key}: expected ${expected}, got ${find("[role='option'].--active")?.dataset.value}; mounted ${findAll(
              "[role='option']"
            )
              .map((row) => row.dataset.value)
              .join(",")}`,
          }
        );
        assert
          .dom("[role='option'].--active")
          .hasAttribute(
            "data-logical-index",
            expected,
            "logical positions include disabled options and exclude headers"
          )
          .hasAttribute(
            "aria-setsize",
            "160",
            "the whole option set is counted"
          );
      }
      const beforePage = findAll("[role='option']").length;
      assert.true(beforePage < items.length, "only a window is mounted");
      await triggerKeyEvent("[role='combobox']", "keydown", "PageDown");
      await waitUntil(
        () =>
          find("[role='option'].--active")?.dataset.value ===
          String(1 + beforePage),
        {
          timeoutMessage: `PageDown: expected ${1 + beforePage}, got ${find("[role='option'].--active")?.dataset.value}`,
        }
      );
      assert
        .dom("[role='option'].--active")
        .hasAttribute(
          "aria-disabled",
          "true",
          "paging counts cap-disabled mounted options"
        );
      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");
      assert.true(
        onChange.notCalled,
        "a virtual jump never enables activation"
      );
    });
  }
);

/** Controlled values and live presentation options for the strip's session behavior. */
class CompactStripHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @describedBy="u1f-help"
      @disabled={{@disabled}}
      @items={{@items}}
      @load={{@load}}
      @maximum={{@maximum}}
      @maxVisibleChips={{@cap.value}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @resolveValues={{@resolveValues}}
      @texts={{hash ariaLabel="Fruit"}}
      @value={{this.value}}
      @variant={{@variant}}
    />
    <span id="u1f-help">Pick fruit</span>
    <button class="u1f-outside" type="button">Outside</button>
  </template>
}

module(
  "Integration | ui-kit | select | DSelect (compact chips and strip details)",
  function (hooks) {
    setupRenderingTest(hooks);

    const load = () => ITEMS;
    const resolveValues = (values) =>
      ITEMS.filter((item) => values.includes(item.id));

    for (const variant of ["typeahead", "button", "static"]) {
      test(`${variant} describes every held label and exposes display-only text`, async function (assert) {
        const cap = tracked(1);
        await render(
          <template>
            <CompactStripHost
              @cap={{cap}}
              @items={{ITEMS}}
              @value={{array 1 2 3}}
              @variant={{variant}}
            />
          </template>
        );
        const controller = find(".d-select__input") ?? find(".d-select");
        const descriptions = controller
          .getAttribute("aria-describedby")
          .split(/\s+/)
          .map((id) => document.getElementById(id).textContent)
          .join(" ");
        for (const text of ["Apple", "Banana", "Cherry pie", "Pick fruit"]) {
          assert.true(
            descriptions.includes(text),
            `description includes ${text}`
          );
        }
        assert
          .dom(".d-select__chip-label")
          .doesNotHaveAttribute("aria-hidden", "visible label stays exposed");
        await click(".d-select__chips-more");
        assert
          .dom("[role='listbox']")
          .exists("badge click bubbles to the trigger");
        assert
          .dom(".d-select__trigger .d-select__chip-remove")
          .doesNotExist("display-only trigger has no remove buttons");
      });
    }

    test("disabled compact labels remain outside the named root", async function (assert) {
      const cap = tracked(0);
      await render(
        <template>
          <CompactStripHost
            @cap={{cap}}
            @disabled={{true}}
            @items={{ITEMS}}
            @value={{array 1 2}}
            @variant="button"
          />
        </template>
      );
      const root = find(".d-select");
      const labels = root
        .getAttribute("aria-describedby")
        .split(/\s+/)
        .map((id) => document.getElementById(id))
        .find((element) => element.textContent.includes("Apple"));
      assert.false(
        root.contains(labels),
        "disabled labels can be read outside the unfocusable root"
      );
      assert.dom(labels).hasClass("sr-only", "held labels are visually hidden");
    });

    test("desktop strip latches eligibility until close and unmounts at zero", async function (assert) {
      const cap = tracked(1);
      await render(
        <template>
          <CompactStripHost
            @cap={{cap}}
            @items={{ITEMS}}
            @value={{array 1 2}}
          />
        </template>
      );
      await click(".d-select__input");
      const strip = find(".d-select__strip");
      assert.dom(strip).exists("overflow enables the strip");
      cap.value = undefined;
      await settled();
      assert.strictEqual(
        find(".d-select__strip"),
        strip,
        "the session keeps its strip after eligibility changes"
      );
      await triggerKeyEvent(".d-select__input", "keydown", "Escape");
      await click(".d-select__input");
      assert
        .dom(".d-select__strip")
        .doesNotExist("a new interactive-chip session clears the latch");
      cap.value = 0;
      await settled();
      const buttons = findAll(".d-select__strip button");
      buttons[1].focus();
      await triggerKeyEvent(buttons[1], "keydown", "Delete");
      await triggerKeyEvent(".d-select__strip button", "keydown", "Delete");
      assert
        .dom(".d-select__strip")
        .doesNotExist("zero held items unmount after focus leaves");
      assert.strictEqual(
        document.activeElement,
        find(".d-select__input"),
        "the final removal returns focus to the input"
      );
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "aria-label",
          "Fruit, 0 selected",
          "the empty count stays in the name"
        );
      await click(optionWithText("Banana"));
      assert
        .dom(".d-select__strip button")
        .exists({ count: 1 }, "picking again restores the latched strip");
    });

    for (const key of ["ArrowUp", "ArrowDown", "Tab"]) {
      test(`${key} returns from the compact strip to the input`, async function (assert) {
        const cap = tracked(0);
        await render(
          <template>
            <CompactStripHost
              @cap={{cap}}
              @items={{ITEMS}}
              @value={{array 1 2}}
            />
          </template>
        );
        await click(".d-select__input");
        await triggerKeyEvent(".d-select__input", "keydown", "Tab");
        assert
          .dom(document.activeElement)
          .hasClass(
            "d-select__strip-remove",
            "inline Tab order reaches the strip"
          );
        await triggerKeyEvent(document.activeElement, "keydown", key, {
          shiftKey: key === "Tab",
        });
        assert.strictEqual(
          document.activeElement,
          find(".d-select__input"),
          "the query regains focus"
        );
        assert
          .dom("[role='listbox']")
          .exists("returning to the query keeps the panel open");
      });
    }

    test("strip focus suppresses the row indicator and outside focus closes", async function (assert) {
      const cap = tracked(0);
      await render(
        <template>
          <CompactStripHost @cap={{cap}} @items={{ITEMS}} @value={{array 1}} />
        </template>
      );
      await click(".d-select__input");
      const active = find(".d-select__option.--active");
      assert.dom(active).exists("an unheld option is active");
      await triggerKeyEvent(".d-select__input", "keydown", "ArrowLeft");
      assert.strictEqual(
        getComputedStyle(active).outlineStyle,
        "none",
        "only the strip shows a focus indicator"
      );
      find(".u1f-outside").focus();
      await settled();
      assert
        .dom(".d-select__panel")
        .doesNotExist("focus leaving the strip dismisses the panel");
      assert.strictEqual(
        document.activeElement,
        find(".u1f-outside"),
        "outside focus is preserved"
      );
    });

    test("static server strips and local exceptions are symmetric across desktop and mobile", async function (assert) {
      await render(
        <template>
          <CompactStripHost
            @load={{load}}
            @resolveValues={{resolveValues}}
            @value={{array 1 2}}
            @variant="static"
          />
        </template>
      );
      await click(".d-select__trigger");
      assert
        .dom(".d-select__panel > .d-select__strip:first-child")
        .exists("a server static strip leads its panel");
      await dSelect().remove(2);
      assert
        .dom(".d-select")
        .hasAttribute(
          "data-value",
          "1",
          "the helper removes through the strip"
        );
      forceMobile();
      await render(
        <template>
          <CompactStripHost
            @items={{ITEMS}}
            @value={{array 1 2}}
            @variant="static"
          />
        </template>
      );
      await dSelect().remove(1);
      assert
        .dom(".d-select__strip button")
        .exists({ count: 1 }, "mobile local sources keep a strip");
    });

    test("desktop limit, field and results share a height budget", async function (assert) {
      const items = Array.from({ length: 60 }, (_, id) => ({
        id,
        name: `Held fruit with a long label ${id}`,
      }));
      const value = items.slice(0, 40).map((item) => item.id);
      const server = () => items;
      const resolve = () => items.slice(0, 40);
      await render(
        <template>
          <CompactStripHost
            @load={{server}}
            @maximum={{40}}
            @resolveValues={{resolve}}
            @value={{value}}
            @variant="button"
          />
        </template>
      );
      await click(".d-select__trigger");
      const panel = find(".d-select__panel");
      assert.true(
        Boolean(panel.children[0].querySelector(".d-select__filter")),
        "filter comes first"
      );
      assert
        .dom(panel.children[1])
        .hasClass("d-select__limit", "then the limit");
      assert
        .dom(panel.children[0])
        .hasClass("d-select__chips", "the field holds the chips");
      const strip = find(".d-select__panel .d-select__chips");
      assert.true(
        strip.scrollHeight > strip.clientHeight,
        "long strips scroll internally"
      );
      assert.strictEqual(
        getComputedStyle(strip).overflowY,
        "auto",
        "strip owns its scroll"
      );
      const button = probeableButton(strip, 11);
      assert.true(Boolean(button), "a chip sits clear of the field's edges");
      assert.true(
        hitsAround(button, 11),
        "the remove target reaches 24px across without growing the chip"
      );
      const chip = button.closest(".d-select__chip");
      assert.strictEqual(
        chip.offsetHeight,
        chip.querySelector(".d-select__chip-label").offsetHeight,
        "the chip is only as tall as its label, like a trigger chip"
      );
      assert.true(
        panel.offsetHeight <= parseFloat(getComputedStyle(panel).maxHeight) + 1,
        "the whole panel stays within its budget"
      );
      const list = find(".d-select__panel .d-virtual-list");
      assert.true(list.clientHeight > 0, "results retain a viewport");
      assert.true(
        list.getBoundingClientRect().bottom <=
          panel.getBoundingClientRect().bottom + 1,
        "the results fit in the remaining space"
      );
    });
  }
);
