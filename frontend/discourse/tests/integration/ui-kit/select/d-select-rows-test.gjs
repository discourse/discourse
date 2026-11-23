import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { trackedObject as trackedState } from "@ember/reactive/collections";
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
import SelectLiveRegions from "discourse/components/a11y/live-regions";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi as withSelectPluginApi } from "discourse/lib/plugin-api";
import { disableClearA11yAnnouncementsInTests as retainA11yAnnouncements } from "discourse/services/a11y";
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
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { selectOption } from "discourse/ui-kit/select/select-engine";
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
      @noneOption={{true}}
      @onChange={{this.onChange}}
      @options={{ITEMS}}
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
      @multiple={{true}}
      @noneOption={{true}}
      @onChange={{this.onChange}}
      @options={{ITEMS}}
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

  test("pointer selection emits null, closes, and shows the none label as the value", async function (assert) {
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
      .hasValue(
        "None",
        "the trigger shows the none label in place of the old selection"
      )
      .doesNotHaveAttribute("placeholder", "none is a value, not a prompt");
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
          <DSelect @multiple={{true}} @options={{ITEMS}} @value={{(array)}} />
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
        <template><DSelect @options={{ITEMS}} @value={{1}} /></template>
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
        selectOption(
          { id: 1, name: "Manage notifications" },
          { onSelect: onManage }
        ),
        { id: 2, name: "Banana" },
        { id: 3, name: "Cherry pie" },
      ];

      await render(
        <template>
          <MultiLimitsHost
            @onChange={{onChange}}
            @options={{items}}
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
            @options={{SECTIONED}}
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
            @options={{SECTIONED}}
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
            @options={{SECTIONED}}
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
            @options={{SECTIONED}}
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
    const extraOptions = () => [
      { id: "action", name: "Browse all" },
      selectOption({ id: "sticky", name: "Pinned" }, { position: "sticky" }),
    ];
    const createOption = (filter) => ({
      id: `new:${filter}`,
      name: filter,
    });
    const groupHeader = (group) => group;

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createOption={{createOption}}
          @extraOptions={{extraOptions}}
          @groupBy="group"
          @groupHeader={{groupHeader}}
          @noneOption={{true}}
          @options={{items}}
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
      options: [
        { id: 1, name: "Apple" },
        { id: 2, name: "Apricot" },
      ],
      total: 20,
      hasMore: true,
    });
    const createOption = (filter) => ({
      id: `new:${filter}`,
      name: filter,
    });

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createOption={{createOption}}
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
    const createOption = (filter) => ({
      code: "5",
      text: filter,
    });

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createOption={{createOption}}
          @labelField="text"
          @options={{items}}
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
    const createOption = (filter) => ({
      id: `new:${filter}`,
      name: filter,
    });

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createOption={{createOption}}
          @options={{items}}
        />
      </template>
    );
    await fillIn("[role='combobox']", "ap");

    assert
      .dom("[role='option'].--create")
      .exists("a raw string value is not a duplicate of the built key");
  });

  test("an item block overrides create wording while data-name stays the item label", async function (assert) {
    const createOption = (filter) => ({
      code: `new:${filter}`,
      text: filter.toUpperCase(),
    });
    const options = [{ code: "apple", text: "Apple" }];

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createOption={{createOption}}
          @labelField="text"
          @options={{options}}
          @valueField="code"
        >
          <:option as |option|>
            {{~concat "Use " option.record.text~}}
          </:option>
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
    const createOption = (filter) => ({ id: `new:${filter}`, name: filter });

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createOption={{createOption}}
          @options={{ITEMS}}
        >
          <:option as |option|>
            {{~if
              option.create
              (concat "Create " option.record.name)
              option.record.name
            ~}}
          </:option>
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
    const createOption = (filter) => ({
      code: `new:${filter}`,
      text: filter.toUpperCase(),
    });
    const items = [];

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createOption={{createOption}}
          @labelField="text"
          @options={{items}}
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
    const createOption = sinon.spy((filter) => ({
      id: `new:${filter}`,
      name: filter,
    }));

    await render(
      <template>
        <DSelect
          @allowCreate={{allowCreate}}
          @createOption={{createOption}}
          @debounce={{150}}
          @options={{ITEMS}}
        />
      </template>
    );
    await fillIn("[role='combobox']", "ap");
    assert
      .dom("[role='option'].--create")
      .hasAttribute("data-name", "ap", "the initial query offers creation");

    allowCreate.resetHistory();
    createOption.resetHistory();
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
      assert.true(createOption.called, "the retained proposal is rebuilt");
      assert.true(
        createOption.args.every(([filter]) => filter === "ap"),
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
      const items = [
        selectOption({ id: 1, name: "Apple" }, { description: "שלום world" }),
      ];

      this.siteSettings.support_mixed_text_direction = true;
      await render(
        <template><DSelect @options={{items}} @variant="static" /></template>
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
      const items = [
        selectOption({ id: 1, name: "Apple" }, { description: "Fruit" }),
      ];

      this.siteSettings.support_mixed_text_direction = false;
      await render(
        <template><DSelect @options={{items}} @variant="static" /></template>
      );
      await click(".d-select__trigger");

      assert
        .dom(".d-select__option-description")
        .doesNotHaveAttribute("dir", "the page direction applies");
    });

    test("group, item description and cap share the option description without changing its name", async function (assert) {
      const items = [
        { id: 1, name: "Apple", group: "Fruit" },
        selectOption(
          { id: 2, name: "Banana", group: "Fruit" },
          { description: "Requires permission" }
        ),
        selectOption(
          { id: 3, name: "Cherry", group: "Fruit" },
          { disabled: true, description: "Unavailable today" }
        ),
      ];
      const groupHeader = (group) => group;
      const onChange = sinon.spy();
      await render(
        <template>
          <DSelect
            @groupBy="group"
            @groupHeader={{groupHeader}}
            @maximum={{1}}
            @multiple={{true}}
            @onChange={{onChange}}
            @options={{items}}
            @value={{array 1}}
            @variant="static"
          >
            <:option as |option|><strong
              >{{option.record.name}}</strong></:option>
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
            @maximum={{1}}
            @multiple={{true}}
            @onChange={{onChange}}
            @options={{items}}
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
      @load={{@load}}
      @maximum={{@maximum}}
      @maxVisibleChips={{@cap.value}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @options={{@options}}
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
              @options={{ITEMS}}
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
            @options={{ITEMS}}
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
            @options={{ITEMS}}
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
              @options={{ITEMS}}
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
          <CompactStripHost
            @cap={{cap}}
            @options={{ITEMS}}
            @value={{array 1}}
          />
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
            @options={{ITEMS}}
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

module("Integration | ui-kit | select | DSelect list view", function (hooks) {
  setupRenderingTest(hooks);

  let trackedObject;
  let withPluginApi;
  let EngineProbe;
  hooks.before(async function () {
    ({ trackedObject } = await import("@ember/reactive/collections"));
    ({ withPluginApi } = await import("discourse/lib/plugin-api"));
    ({ EngineProbe } = await import("discourse/tests/helpers/d-select-hosts"));
  });

  function customize(setup) {
    withPluginApi((api) =>
      api.registerValueTransformer("select-customizations", ({ value }) =>
        value.forAll(setup)
      )
    );
  }

  /** Action accessors need a standalone spy on their bound callback. */
  function spyOnHostCallback(host, name) {
    const spy = sinon.spy(host[name]);
    Object.defineProperty(host, name, { configurable: true, value: spy });
    return spy;
  }

  test("renders explicit, derived and empty resolved option presentation on value rows", async function (assert) {
    const records = [
      {
        id: "explicit",
        title: "Canonical explicit",
        detail: "Canonical detail",
      },
      { id: "derived", title: "Canonical derived", detail: "Derived detail" },
      { id: "empty", title: "Must not show", detail: "Must not describe" },
    ];
    const options = [
      selectOption(
        { ...records[0], title: "Local explicit" },
        { label: "Alias", description: "Explicit detail" }
      ),
      { ...records[1], title: "Local derived", detail: "Local detail" },
      selectOption(records[2], { label: "", description: "" }),
    ];
    await render(
      <template>
        <DSelect
          @descriptionField="detail"
          @labelField="title"
          @options={{options}}
          @valueRecords={{records}}
          @variant="static"
        />
      </template>
    );
    await dSelect().open();
    assert
      .dom('[role="option"][data-value="explicit"]')
      .hasAttribute("data-name", "Alias")
      .hasText("Alias Explicit detail", "explicit properties drive the row");
    assert
      .dom('[data-value="explicit"] .d-select__option-description')
      .hasText("Explicit detail", "the explicit description wins");
    assert
      .dom('[role="option"][data-value="derived"]')
      .hasAttribute("data-name", "Canonical derived")
      .hasText(
        "Canonical derived Derived detail",
        "fields come from the key's canonical record"
      );
    assert
      .dom('[data-value="derived"] .d-select__option-description')
      .hasText("Derived detail", "the configured description field is drawn");
    assert
      .dom('[role="option"][data-value="empty"]')
      .hasAttribute("data-name", "")
      .hasText("", "empty properties suppress both field fallbacks");
    assert
      .dom('[data-value="empty"] .d-select__option-description')
      .doesNotExist("an empty description adds no description element");
  });

  test("renders native copy presentation while clicking emits the canonical record", async function (assert) {
    const record = { id: "a", title: "Original", detail: "Original detail" };
    const options = [record];
    const onChange = sinon.spy();
    customize((spec) =>
      spec.content((inputs) =>
        inputs.map((input) => ({
          ...input.record,
          title: "Changed",
          detail: "Changed detail",
        }))
      )
    );
    await render(
      <template>
        <DSelect
          @descriptionField="detail"
          @labelField="title"
          @onChange={{onChange}}
          @options={{options}}
          @variant="static"
        />
      </template>
    );
    await dSelect().open();
    assert
      .dom('[role="option"][data-value="a"]')
      .hasAttribute("data-name", "Changed")
      .hasText(
        "Changed Changed detail",
        "copy presentation reaches the rendered resolved option"
      );
    await dSelect().select("a");
    assert.strictEqual(
      onChange.firstCall?.args[1],
      record,
      "the click emits the original record"
    );
  });

  test("local presentation changes update membership without rerunning list async data", async function (assert) {
    const state = trackedObject({ label: "Needle", detail: "Before" });
    const record = {
      id: "a",
      get name() {
        return state.label;
      },
      get detail() {
        return state.detail;
      },
    };
    const options = [record];
    let loadListContent;
    class Probe extends EngineProbe {
      constructor() {
        super(...arguments);
        loadListContent = spyOnHostCallback(this.host, "loadListContent");
      }
    }
    await render(
      <template>
        <Probe
          @debounce={{false}}
          @descriptionField="detail"
          @options={{options}}
        />
      </template>
    );
    await dSelect().search("needle");
    assert
      .dom('[role="option"][data-value="a"]')
      .exists("the initial label matches");
    const loads = loadListContent.callCount;
    assert.true(loads > 0, "the real list async-data boundary was exercised");
    state.label = "Haystack";
    await settled();
    assert
      .dom('[role="option"][data-value="a"]')
      .doesNotExist("the changed pre-content label removes the row");
    assert.strictEqual(
      loadListContent.callCount,
      loads,
      "the label is a display dependency, never an async-data dependency"
    );
    state.label = "Needle again";
    state.detail = "After";
    await settled();
    assert
      .dom('[role="option"][data-value="a"]')
      .hasAttribute("data-name", "Needle again");
    assert
      .dom('[data-value="a"] .d-select__option-description')
      .hasText("After", "the returning row uses current presentation");
    assert.strictEqual(
      loadListContent.callCount,
      loads,
      "neither presentation change reruns the list loader"
    );
  });

  test("held async data ignores presentation while the list and chips update", async function (assert) {
    const state = trackedObject({ label: "Before", detail: "Before detail" });
    const record = {
      id: "a",
      get name() {
        return state.label;
      },
      get detail() {
        return state.detail;
      },
    };
    const options = [record];
    const value = ["a"];
    let loadListContent;
    let resolveMulti;
    class Probe extends EngineProbe {
      constructor() {
        super(...arguments);
        resolveMulti = spyOnHostCallback(this.host, "resolveMulti");
        loadListContent = spyOnHostCallback(this.host, "loadListContent");
      }
    }
    await render(
      <template>
        <Probe
          @descriptionField="detail"
          @multiple={{true}}
          @options={{options}}
          @value={{value}}
        />
      </template>
    );
    await dSelect().open();
    const heldRuns = resolveMulti.callCount;
    const listRuns = loadListContent.callCount;
    assert.true(
      heldRuns > 0,
      "the real held async-data boundary was exercised"
    );
    assert.true(
      listRuns > 0,
      "the real list async-data boundary was exercised"
    );
    state.label = "After";
    state.detail = "After detail";
    await settled();
    assert
      .dom(".d-select__chip-label")
      .hasText("After", "held presentation updates outside async data");
    assert
      .dom('[role="option"][data-value="a"]')
      .hasAttribute("data-name", "After");
    assert
      .dom('[data-value="a"] .d-select__option-description')
      .hasText("After detail", "the list reads the same presentation");
    assert.strictEqual(
      resolveMulti.callCount,
      heldRuns,
      "held async data does not rerun"
    );
    assert.strictEqual(
      loadListContent.callCount,
      listRuns,
      "list async data does not rerun"
    );
  });

  test("presentation changes never restart or abort an in-flight loader", async function (assert) {
    const state = trackedObject({ label: "Before" });
    const record = {
      id: "a",
      get name() {
        return state.label;
      },
    };
    const records = [record];
    let release;
    const load = sinon.spy(
      (_filter, { signal }) =>
        new Promise((resolve) => {
          release = () => resolve(records);
          assert.false(signal.aborted, "the pending request starts live");
        })
    );
    await render(
      <template><DSelect @load={{load}} @valueRecords={{records}} /></template>
    );
    const opening = dSelect().open();
    try {
      await waitUntil(() => load.called);
      const signal = load.firstCall.args[1].signal;
      state.label = "After";
      await new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve))
      );
      assert.strictEqual(
        load.callCount,
        1,
        "presentation never starts another load"
      );
      assert.false(
        signal.aborted,
        "presentation never aborts the existing load"
      );
    } finally {
      release?.();
      await opening;
    }
    assert
      .dom('[role="option"][data-value="a"]')
      .hasAttribute(
        "data-name",
        "After",
        "the accepted page draws current presentation"
      );
  });

  test("loading skeleton labels follow explicit and canonical resolved option labels", async function (assert) {
    const records = [
      { id: "a", name: "Canonical A" },
      { id: "b", name: "Canonical B" },
    ];
    const rows = [
      selectOption({ id: "a", name: "Local A" }, { label: "Alias A" }),
      { id: "b", name: "Local B" },
    ];
    let release;
    const load = (filter) =>
      filter ? new Promise((resolve) => (release = () => resolve([]))) : rows;
    await render(
      <template>
        <DSelectList
          @debounce={{false}}
          @load={{load}}
          @texts={{hash ariaLabel="Results"}}
          @valueRecords={{records}}
          @virtualized={{false}}
        />
      </template>
    );
    const typing = fillIn(
      '.d-select.--list .d-select__chips input[type="search"]',
      "query"
    );
    try {
      await waitUntil(
        () => findAll(".d-select__placeholder-label").length === 2
      );
      assert.deepEqual(
        findAll(".d-select__placeholder-label").map((element) =>
          element.textContent.trim()
        ),
        ["Alias A", "Canonical B"],
        "replacement skeletons retain resolved option labels, rather than input record labels"
      );
    } finally {
      release?.();
      await typing;
    }
  });

  test("option attributes reuse equivalent resolved options and recompute for resolved option and placement changes", async function (assert) {
    const listed = { id: "a", name: "Local" };
    const record = { ...listed, name: "Canonical" };
    const other = { id: "b", name: "Other" };
    const state = trackedObject({
      options: [listed, other],
      records: [selectOption(record, { description: "Before" })],
    });
    const attributes = sinon.spy((attrs, context) => {
      attrs.title = context.record.name;
    });
    customize((spec) => spec.optionAttributes(attributes));
    await render(
      <template>
        <DSelect
          @options={{state.options}}
          @valueRecords={{state.records}}
          @variant="static"
        />
      </template>
    );
    await dSelect().open();
    const initial = attributes.callCount;
    assert.strictEqual(
      initial,
      2,
      "each rendered row invokes the customization once"
    );
    assert.strictEqual(
      attributes.firstCall.args[1].record,
      record,
      "the customization receives the canonical record"
    );
    assert
      .dom('[role="option"][data-value="a"]')
      .hasAttribute(
        "title",
        "Canonical",
        "the returned attributes use that canonical record"
      );
    state.options = [selectOption(listed), other];
    await settled();
    assert.strictEqual(
      attributes.callCount,
      initial,
      "equivalent rebuilt inputs reuse the resolved option's attributes"
    );
    await triggerKeyEvent('[role="combobox"]', "keydown", "Home");
    await triggerKeyEvent('[role="combobox"]', "keydown", "ArrowDown");
    assert
      .dom('[role="option"].--active')
      .hasAttribute(
        "data-value",
        "b",
        "navigation really moved to a different row"
      );
    assert.strictEqual(
      attributes.callCount,
      initial,
      "moving the active row does not change its resolved option or placement"
    );
    state.records = [selectOption(record, { description: "After" })];
    await settled();
    assert.strictEqual(
      attributes.callCount,
      initial + 1,
      "a merged resolved option property changes even though the input record and settings did not"
    );
    assert
      .dom('[data-value="a"] .d-select__option-description')
      .hasText("After", "the changed resolved option reaches the row");
    state.options = [selectOption(listed, { position: "sticky" }), other];
    await settled();
    assert.strictEqual(
      attributes.callCount,
      initial + 2,
      "placement invalidates attributes independently of resolved option properties"
    );
    assert
      .dom('[role="option"][data-value="a"]')
      .hasClass("--sticky", "the placement really changed");
    state.options = [selectOption(listed, { position: "sticky" }), other];
    await settled();
    assert.strictEqual(
      attributes.callCount,
      initial + 2,
      "equal placement and resolved option do not invalidate the cache"
    );
  });

  test("rows honor disabled behavior contributed by valueRecords", async function (assert) {
    const record = { id: "a", name: "Apple" };
    const options = [record];
    const records = [selectOption(record, { disabled: true })];
    const onChange = sinon.spy();
    await render(
      <template>
        <DSelect
          @onChange={{onChange}}
          @options={{options}}
          @valueRecords={{records}}
          @variant="static"
        />
      </template>
    );
    await dSelect().open();

    assert
      .dom('[role="option"][data-value="a"]')
      .hasAttribute(
        "aria-disabled",
        "true",
        "the row exposes the disabled behavior from valueRecords"
      );
    await dSelect().select("a");
    assert.true(onChange.notCalled, "clicking the disabled row emits no value");
    assert
      .dom('[role="listbox"]')
      .exists("the disabled click keeps the list open");
  });

  test("rows run actions contributed by valueRecords instead of selecting a value", async function (assert) {
    const record = { id: "a", name: "Apple" };
    const options = [record];
    const onSelect = sinon.spy();
    const records = [selectOption(record, { onSelect })];
    const onChange = sinon.spy();
    await render(
      <template>
        <DSelect
          @onChange={{onChange}}
          @options={{options}}
          @valueRecords={{records}}
          @variant="static"
        />
      </template>
    );
    await dSelect().select("a");

    assert.strictEqual(
      onSelect.callCount,
      1,
      "clicking the row runs the action from valueRecords"
    );
    assert.strictEqual(
      onSelect.firstCall?.args[1],
      record,
      "the action receives the canonical record"
    );
    assert.true(onChange.notCalled, "the action never emits a selected value");
    assert.dom('[role="listbox"]').exists("the action keeps the list open");
    assert
      .dom('[role="option"][data-value="a"]')
      .hasAttribute(
        "aria-selected",
        "false",
        "the action row remains unselected"
      );
  });

  for (const origin of ["extra", "content"]) {
    test(`${origin} copies retain presentation when their source row is filtered out`, async function (assert) {
      const record = { id: "a", name: "Apple" };
      const copy = { id: "a", name: "All fruit" };
      const options = [record];
      const extraOptions = () => (origin === "extra" ? [copy] : []);
      const onChange = sinon.spy();
      if (origin === "content") {
        customize((spec) => spec.content(() => [copy]));
      }
      await render(
        <template>
          <DSelect
            @debounce={{false}}
            @extraOptions={{extraOptions}}
            @onChange={{onChange}}
            @options={{options}}
          />
        </template>
      );
      await dSelect().open();
      assert
        .dom('[role="option"][data-value="a"]')
        .hasText("All fruit", "the copy has its own presentation at rest");

      await dSelect().search("no matching fruit");

      assert
        .dom('[role="option"][data-value="a"]')
        .hasText(
          "All fruit",
          `the ${origin} copy keeps its label after Apple is filtered out`
        );
      assert
        .dom('[role="option"]')
        .exists({ count: 1 }, "only the injected copy is shown");
      await dSelect().select("a");
      assert.strictEqual(
        onChange.firstCall?.args[0],
        "a",
        "clicking the copy emits its value"
      );
      assert.strictEqual(
        onChange.firstCall?.args[1],
        record,
        "the filtered-out source record remains canonical"
      );
    });
  }

  test("paste ignores a local option removed while the select is closed", async function (assert) {
    const record = { id: "a", name: "Apple" };
    const created = { id: "new:Kiwi", name: "Kiwi" };
    const state = trackedObject({ options: [record] });
    const onChange = sinon.spy();
    const allowCreate = sinon.spy((name) => name === "Kiwi");
    const createOption = sinon.spy(() => created);
    await render(
      <template>
        <DSelect
          @allowCreate={{allowCreate}}
          @createOption={{createOption}}
          @multiple={{true}}
          @onChange={{onChange}}
          @options={{state.options}}
          @value={{(array)}}
        />
      </template>
    );
    await dSelect().open();
    assert
      .dom('[role="option"][data-value="a"]')
      .hasText("Apple", "the list initially shows the option");
    await dSelect().close();
    state.options = [];
    await settled();
    assert
      .dom('[role="listbox"]')
      .doesNotExist("the source changes while closed");

    const data = new DataTransfer();
    data.setData("text/plain", "Apple | Kiwi");
    find('[role="combobox"]').dispatchEvent(
      new ClipboardEvent("paste", {
        clipboardData: data,
        bubbles: true,
        cancelable: true,
      })
    );
    await settled();

    assert.deepEqual(
      onChange.lastCall?.args[0],
      [created.id],
      "paste emits no removed source value"
    );
    assert.deepEqual(
      allowCreate.args.map(([name]) => name),
      ["Apple", "Kiwi"],
      "the removed label reaches creation instead of matching the old row"
    );
    assert.deepEqual(
      createOption.args.map(([name]) => name),
      ["Kiwi"],
      "only the allowed unknown name is created"
    );
    assert.strictEqual(
      onChange.lastCall?.args[1]?.[0],
      created,
      "paste emits the created record"
    );
  });

  test("option attributes follow own settings when merged resolved option presentation stays unchanged", async function (assert) {
    const record = { id: "a", name: "Apple" };
    const records = [selectOption(record, { description: "Detail" })];
    const state = trackedObject({ options: [record] });
    const attributes = sinon.spy((attrs, context) => {
      attrs.title = context.option.description ?? "No option description";
    });
    customize((spec) => spec.optionAttributes(attributes));
    await render(
      <template>
        <DSelect
          @options={{state.options}}
          @valueRecords={{records}}
          @variant="static"
        />
      </template>
    );
    await dSelect().open();
    assert.strictEqual(
      attributes.callCount,
      1,
      "the rendered row evaluates attributes once"
    );
    assert.strictEqual(
      attributes.firstCall.args[1].record,
      record,
      "attributes receive the canonical record"
    );
    assert.strictEqual(
      attributes.firstCall.args[1].option.description,
      undefined,
      "the source option has no own description"
    );
    assert
      .dom('[data-value="a"] .d-select__option-description')
      .hasText(
        "Detail",
        "valueRecords supplies the merged resolved option description"
      );
    assert
      .dom('[role="option"][data-value="a"]')
      .hasAttribute(
        "title",
        "No option description",
        "attributes read the option's own description"
      );

    state.options = [selectOption(record)];
    await settled();
    assert.strictEqual(
      attributes.callCount,
      1,
      "equal own settings reuse the attribute cache"
    );

    state.options = [selectOption(record, { description: "Detail" })];
    await settled();
    assert.strictEqual(
      attributes.callCount,
      2,
      "changed own option settings recompute attributes even when the merged resolved option is unchanged"
    );
    assert.strictEqual(
      attributes.lastCall.args[1].option.description,
      "Detail",
      "the callback receives the new own description"
    );
    assert
      .dom('[role="option"][data-value="a"]')
      .hasAttribute(
        "title",
        "Detail",
        "the rendered attributes follow the new own settings"
      );
    assert
      .dom('[data-value="a"] .d-select__option-description')
      .hasText(
        "Detail",
        "the merged resolved option description remains unchanged"
      );

    state.options = [selectOption(record, { description: "Detail" })];
    await settled();
    assert.strictEqual(
      attributes.callCount,
      2,
      "equivalent own settings still reuse attributes"
    );

    state.options = [record];
    await settled();
    assert.strictEqual(
      attributes.callCount,
      3,
      "removing an own setting recomputes attributes"
    );
    assert.strictEqual(
      attributes.lastCall.args[1].option.description,
      undefined,
      "the callback sees the removed own description"
    );
    assert
      .dom('[role="option"][data-value="a"]')
      .hasAttribute(
        "title",
        "No option description",
        "removing the own setting restores the initial attributes"
      );
    assert
      .dom('[data-value="a"] .d-select__option-description')
      .hasText(
        "Detail",
        "valueRecords continues supplying the resolved option description"
      );
  });
});

module(
  "Integration | ui-kit | select | DSelect local inputs",
  function (hooks) {
    setupRenderingTest(hooks);

    let trackedObject;
    let withPluginApi;
    let recordOf;
    hooks.before(async function () {
      ({ trackedObject } = await import("@ember/reactive/collections"));
      ({ withPluginApi } = await import("discourse/lib/plugin-api"));
      ({ recordOf } = await import("discourse/ui-kit/select/select-engine"));
    });

    [false, true].forEach((multiple) => {
      test(`share one record between ${multiple ? "chips" : "the trigger"} and list blocks and refresh together`, async function (assert) {
        const state = trackedObject({ label: "Before" });
        const options = () => [
          { id: "a", name: state.label },
          { id: "b", name: "Other" },
        ];
        const value = multiple ? ["a"] : "a";
        const variant = multiple ? "typeahead" : "button";
        const selections = new Map();
        const listed = new Map();
        const showSelection = (input) => {
          const record = recordOf(input);
          selections.set(record.id, record);
          return record.name;
        };
        const showOption = (input) => {
          const record = recordOf(input);
          listed.set(record.id, record);
          return record.name;
        };
        await render(
          <template>
            <DSelect
              @multiple={{multiple}}
              @options={{options}}
              @value={{value}}
              @variant={{variant}}
            >
              <:selection as |option|>
                <span class="local-inputs__selection">{{showSelection
                    option.record
                  }}</span>
              </:selection>
              <:option as |option|>
                <span class="local-inputs__option">{{showOption
                    option.record
                  }}</span>
              </:option>
            </DSelect>
          </template>
        );
        assert
          .dom(".local-inputs__selection")
          .hasText("Before", "the held surface renders before opening");
        const before = selections.get("a");
        await dSelect().open();
        assert
          .dom('[role="option"][data-value="a"]')
          .hasAttribute("data-name", "Before");
        assert.strictEqual(
          listed.get("a"),
          before,
          "the list block and the held block receive the same local record"
        );
        await dSelect().close();
        await dSelect().open();
        assert.strictEqual(
          listed.get("a"),
          before,
          "reopening retains the local record"
        );
        assert.strictEqual(
          selections.get("a"),
          before,
          "reopening retains the held record"
        );

        state.label = "After";
        await settled();
        const after = selections.get("a");
        assert
          .dom(".local-inputs__selection")
          .hasText(
            "After",
            "the held block refreshes from the tracked builder"
          );
        assert
          .dom('[role="option"][data-value="a"] .local-inputs__option')
          .hasText("After", "the open list block refreshes too");
        assert
          .dom('[role="option"][data-value="a"]')
          .hasAttribute(
            "data-name",
            "After",
            "the row's public label follows the new record"
          );
        assert
          .dom(".d-select")
          .hasAttribute(
            "data-name",
            "After",
            "the root's held label follows the new record"
          );
        assert
          .dom(multiple ? '.d-select__chip[data-value="a"]' : ".d-select")
          .hasAttribute(
            "data-name",
            "After",
            "the held surface's public label follows the new record"
          );
        assert.notStrictEqual(
          after,
          before,
          "the tracked change replaces the held record"
        );
        assert.strictEqual(
          listed.get("a"),
          after,
          "the refreshed list and held blocks share the new record"
        );
        await dSelect().close();
        await dSelect().open();
        assert.strictEqual(
          listed.get("a"),
          after,
          "later list reads retain the refreshed record"
        );
        assert.strictEqual(
          selections.get("a"),
          after,
          "later held reads retain the refreshed record"
        );
      });
    });

    test("reuse option attributes across filtering until a builder dependency changes", async function (assert) {
      const state = trackedObject({ prefix: "Alpha" });
      const options = () => [
        { id: "a", name: `${state.prefix} A` },
        { id: "b", name: `${state.prefix} B` },
      ];
      const attributes = sinon.spy((attrs, { record }) => {
        attrs.title = record.name;
      });
      withPluginApi((api) =>
        api.registerValueTransformer("select-customizations", ({ value }) =>
          value.forAll((spec) => spec.optionAttributes(attributes))
        )
      );
      await render(
        <template>
          <DSelect
            @debounce={{false}}
            @options={{options}}
            @variant="typeahead"
          />
        </template>
      );
      await dSelect().open();
      assert.strictEqual(
        attributes.callCount,
        2,
        "each initial row evaluates its attributes once"
      );
      assert
        .dom('[role="option"][data-value="a"]')
        .hasAttribute(
          "title",
          "Alpha A",
          "the customization draws the initial record"
        );
      const original = attributes.firstCall.args[1].record;

      await dSelect().search("alpha");
      assert
        .dom('[role="option"]')
        .exists({ count: 2 }, "the query keeps both keys displayed");
      assert.strictEqual(
        attributes.callCount,
        2,
        "filtering unchanged local inputs reuses cached option attributes"
      );
      await triggerKeyEvent('[role="combobox"]', "keydown", "Home");
      await triggerKeyEvent('[role="combobox"]', "keydown", "ArrowDown");
      await triggerKeyEvent('[role="combobox"]', "keydown", "ArrowDown");
      assert
        .dom('[role="option"].--active')
        .hasAttribute("data-value", "b", "navigation changes the active row");
      assert.strictEqual(
        attributes.callCount,
        2,
        "navigation also retains the cached attributes"
      );

      state.prefix = "Alpha refreshed";
      await settled();
      assert.strictEqual(
        attributes.callCount,
        4,
        "a tracked builder change recomputes each row's attributes once"
      );
      assert
        .dom('[role="option"][data-value="a"]')
        .hasAttribute(
          "title",
          "Alpha refreshed A",
          "the first row uses its refreshed record"
        );
      assert
        .dom('[role="option"][data-value="b"]')
        .hasAttribute(
          "title",
          "Alpha refreshed B",
          "the second row uses its refreshed record"
        );
      const refreshed = attributes
        .getCalls()
        .findLast((call) => call.args[1].record.id === "a").args[1].record;
      assert.notStrictEqual(
        refreshed,
        original,
        "attribute callbacks receive the new local record"
      );
      await dSelect().search("alpha refreshed");
      assert
        .dom('[role="option"]')
        .exists({ count: 2 }, "the next query still displays both keys");
      assert.strictEqual(
        attributes.callCount,
        4,
        "later filtering reuses the refreshed resolved options' attributes"
      );
    });
  }
);

module("Integration | ui-kit | select | DSelect held view", function (hooks) {
  setupRenderingTest(hooks);

  let trackedObject;
  let withPluginApi;
  let EngineProbe;
  let probedEngine;
  let A11yLiveRegions;
  let disableClearA11yAnnouncementsInTests;
  hooks.before(async function () {
    ({ trackedObject } = await import("@ember/reactive/collections"));
    ({ withPluginApi } = await import("discourse/lib/plugin-api"));
    ({ EngineProbe, probedEngine } =
      await import("discourse/tests/helpers/d-select-hosts"));
    ({ default: A11yLiveRegions } =
      await import("discourse/components/a11y/live-regions"));
    ({ disableClearA11yAnnouncementsInTests } =
      await import("discourse/services/a11y"));
  });

  function customize(setup) {
    withPluginApi((api) =>
      api.registerValueTransformer("select-customizations", ({ value }) =>
        value.forAll(setup)
      )
    );
  }

  /** Wrap the bound action callback; action accessors cannot be spied on as methods. */
  function spyOnHeldData(host, name) {
    const spy = sinon.spy(host[name]);
    Object.defineProperty(host, name, { configurable: true, value: spy });
    return spy;
  }

  function deferred() {
    let resolve;
    const promise = new Promise((res) => (resolve = res));
    return { promise, resolve };
  }

  ["typeahead", "button", "static"].forEach((variant) => {
    test(`${variant} single trigger updates resolved option presentation outside held async data`, async function (assert) {
      const record = { id: "a", name: "Record", detail: "Record detail" };
      const options = [selectOption(record, { label: "Source" })];
      const filterBy = () => true;
      const state = trackedObject({ label: "Before" });
      customize((spec) =>
        spec.content((inputs, { filter, control }) =>
          inputs.map((option) =>
            option.with({
              label: filter || state.label,
              icon: control.filter ? "xmark" : "star",
              description: `${state.label} detail`,
            })
          )
        )
      );
      let resolveSingle;
      class Probe extends EngineProbe {
        constructor() {
          super(...arguments);
          resolveSingle = spyOnHeldData(this.host, "resolveSingle");
        }
      }
      await render(
        <template>
          <Probe
            @debounce={{false}}
            @filterBy={{filterBy}}
            @options={{options}}
            @value="a"
            @variant={{variant}}
          />
        </template>
      );
      const label =
        variant === "typeahead" ? ".d-select__input" : ".d-select__value";
      if (variant === "typeahead") {
        assert
          .dom(label)
          .hasValue(
            "Before",
            "the resting input shows the held resolved option label"
          );
      } else {
        assert
          .dom(label)
          .hasText(
            "Before",
            "the closed trigger shows the held resolved option label"
          );
      }
      assert
        .dom("[role='listbox']")
        .doesNotExist("the held view runs while closed");
      assert
        .dom(".d-select")
        .hasAttribute(
          "data-name",
          "Before",
          "the trigger hook reads the held resolved option"
        );
      const engine = probedEngine();
      assert.strictEqual(
        engine.heldOption?.(record)?.icon,
        "star",
        "the closed trigger carries the content icon"
      );
      assert.strictEqual(
        engine.heldOption?.(record)?.description,
        "Before detail",
        "the held resolved option carries the content description"
      );
      const runs = resolveSingle.callCount;
      assert.true(
        runs > 0,
        "the actual single held async-data boundary was exercised"
      );
      state.label = "After";
      await settled();
      if (variant === "typeahead") {
        assert
          .dom(label)
          .hasValue(
            "After",
            "closed resolved option presentation updates the resting input"
          );
      } else {
        assert
          .dom(label)
          .hasText(
            "After",
            "closed resolved option presentation updates the trigger"
          );
      }
      assert
        .dom(".d-select")
        .hasAttribute("data-name", "After", "the held hook updates too");
      assert.strictEqual(
        engine.heldOption?.(record)?.record,
        record,
        "the held resolved option retains the canonical record"
      );
      assert.strictEqual(
        engine.heldOption?.(record)?.description,
        "After detail",
        "content re-derives the description"
      );
      assert.strictEqual(
        resolveSingle.callCount,
        runs,
        "presentation never re-runs single held async data"
      );
      const query = variant === "static" ? "" : "query";
      if (query) {
        await dSelect().search(query);
      } else {
        await dSelect().open();
      }
      const listedLabel = query || "After";
      assert
        .dom('[role="option"][data-value="a"]')
        .hasText(
          `${listedLabel} After detail`,
          "the list content sees its own filter"
        );
      assert
        .dom(".d-select")
        .hasAttribute(
          "data-name",
          "After",
          "list activity never changes the held name"
        );
      assert.strictEqual(
        engine.heldOption?.(record)?.icon,
        "star",
        "list activity never changes the held icon through control.filter"
      );
      assert.strictEqual(
        engine.heldOption?.(record)?.description,
        "After detail",
        "list activity never changes held detail"
      );
      await dSelect().close();
    });
  });

  test("chips update and keep at-rest properties while typing without rerunning held async data", async function (assert) {
    const records = [
      { id: "a", name: "Record A" },
      { id: "b", name: "Record B" },
    ];
    const state = trackedObject({ label: "Before" });
    const filterBy = () => true;
    customize((spec) =>
      spec.content((inputs, { filter, control }) =>
        inputs.map((option) =>
          option.with({
            label: `${filter || state.label} ${option.record.id}`,
            icon: control.filter ? "xmark" : "star",
          })
        )
      )
    );
    let resolveMulti;
    class Probe extends EngineProbe {
      constructor() {
        super(...arguments);
        resolveMulti = spyOnHeldData(this.host, "resolveMulti");
      }
    }
    await render(
      <template>
        <Probe
          @debounce={{false}}
          @filterBy={{filterBy}}
          @multiple={{true}}
          @options={{records}}
          @value={{array "a" "b"}}
        />
      </template>
    );
    assert
      .dom('.d-select__chip[data-value="a"] .d-select__chip-label')
      .hasText(
        "Before a",
        "chips read the held resolved option before opening"
      );
    assert
      .dom('.d-select__chip[data-value="b"]')
      .hasAttribute(
        "data-name",
        "Before b",
        "each chip has its resolved option name"
      );
    const runs = resolveMulti.callCount;
    assert.true(
      runs > 0,
      "the real multi held async-data boundary was exercised"
    );
    assert.strictEqual(
      probedEngine().heldOption?.(records[0])?.icon,
      "star",
      "chips carry the at-rest content icon"
    );
    state.label = "After";
    await settled();
    assert
      .dom('.d-select__chip[data-value="a"] .d-select__chip-label')
      .hasText("After a", "closed chips follow content dependencies");
    assert
      .dom('.d-select__chip[data-value="b"]')
      .hasAttribute("data-name", "After b", "chip names update outside data");
    await dSelect().search("query");
    assert
      .dom('[role="option"][data-value="a"]')
      .hasText("query a", "the list has live content properties");
    assert
      .dom('.d-select__chip[data-value="a"] .d-select__chip-label')
      .hasText("After a", "typing leaves held labels at rest");
    assert
      .dom(".d-select")
      .hasAttribute(
        "data-name",
        "After a,After b",
        "the trigger names every at-rest held resolved option"
      );
    assert.strictEqual(
      probedEngine().heldOption?.(records[0])?.icon,
      "star",
      "typing leaves the held icon at rest"
    );
    assert.strictEqual(
      resolveMulti.callCount,
      runs,
      "neither presentation nor typing re-runs held async data"
    );
  });

  test("compact chips strip and screen-reader list share current resolved option labels", async function (assert) {
    const records = [
      { id: "a", name: "Record A" },
      { id: "b", name: "Record B" },
    ];
    const state = trackedObject({ prefix: "Before" });
    const filterBy = () => true;
    customize((spec) =>
      spec.content((inputs, { filter }) =>
        inputs.map((option) =>
          option.with({
            label: `${filter || state.prefix} ${option.record.id}`,
          })
        )
      )
    );
    let resolveMulti;
    class Probe extends EngineProbe {
      constructor() {
        super(...arguments);
        resolveMulti = spyOnHeldData(this.host, "resolveMulti");
      }
    }
    await render(
      <template>
        <Probe
          @debounce={{false}}
          @filterBy={{filterBy}}
          @maxVisibleChips={{1}}
          @multiple={{true}}
          @options={{records}}
          @value={{array "a" "b"}}
          @variant="typeahead"
        />
      </template>
    );
    assert
      .dom('.d-select__chip[data-value="a"] .d-select__chip-label')
      .hasText(
        "Before a",
        "the visible compact chip reads its resolved option"
      );
    assert.deepEqual(
      findAll("ul.sr-only li").map((element) => element.textContent.trim()),
      ["Before a", "Before b"],
      "the held description includes the overflow resolved option's label too"
    );
    const descriptions = find(".d-select__input")
      .getAttribute("aria-describedby")
      .split(/\s+/);
    assert.true(
      descriptions.includes(find("ul.sr-only").id),
      "the combobox actually references the held list"
    );
    await dSelect().open();
    assert
      .dom('.d-select__strip-item[data-value="b"] .d-select__strip-label')
      .hasText(
        "Before b",
        "the compact typeahead renders a strip for the overflow resolved option"
      );
    const runs = resolveMulti.callCount;
    state.prefix = "After";
    await settled();
    assert
      .dom('.d-select__strip-item[data-value="a"]')
      .hasAttribute(
        "data-name",
        "After a",
        "strip names use the resolved option"
      );
    assert
      .dom('.d-select__strip-item[data-value="b"] .d-select__strip-label')
      .hasText("After b", "strip labels update outside held data");
    assert.deepEqual(
      findAll("ul.sr-only li").map((element) => element.textContent.trim()),
      ["After a", "After b"],
      "the screen-reader held list updates outside data"
    );
    await dSelect().search("query");
    assert
      .dom('.d-select__strip-item[data-value="b"] .d-select__strip-label')
      .hasText("After b", "typing cannot change strip presentation");
    assert.strictEqual(
      resolveMulti.callCount,
      runs,
      "the strip and screen-reader list do not rerun held async data"
    );
  });

  test("content dropping two held inputs leaves their chips and values intact", async function (assert) {
    const records = [
      { id: "a", name: "Record A" },
      { id: "b", name: "Record B" },
      { id: "c", name: "Record C" },
    ];
    const options = records.map((record) =>
      selectOption(record, { label: `Held ${record.id}` })
    );
    const state = trackedObject({ drop: false });
    customize((spec) =>
      spec.content((inputs) =>
        inputs
          .filter((option) => !state.drop || option.record.id === "c")
          .map((option) =>
            option.with({ label: `Content ${option.record.id}` })
          )
      )
    );
    const onChange = sinon.spy();
    await render(
      <template>
        <EngineProbe
          @multiple={{true}}
          @onChange={{onChange}}
          @options={{options}}
          @value={{array "a" "b"}}
        />
      </template>
    );
    assert
      .dom('.d-select__chip[data-value="a"] .d-select__chip-label')
      .hasText("Content a", "held content runs before opening");
    await dSelect().open();
    state.drop = true;
    await settled();
    assert
      .dom('[role="option"]')
      .exists(
        { count: 1 },
        "the step really drops both held rows from the list"
      );
    assert
      .dom(".d-select__chip")
      .exists({ count: 2 }, "neither held chip is dropped");
    for (const key of ["a", "b"]) {
      assert
        .dom(`.d-select__chip[data-value="${key}"] .d-select__chip-label`)
        .hasText(
          `Held ${key}`,
          "a dropped input falls back to its own properties"
        );
    }
    assert
      .dom(".d-select")
      .hasAttribute("data-value", "a,b", "content never removes held values");
    assert.true(
      onChange.notCalled,
      "a presentation change emits no selection change"
    );
  });

  test("control.pending re-derives the closed trigger resolved option without loading", async function (assert) {
    const record = { id: "a", name: "Record" };
    const records = [record];
    const load = sinon.spy(() => []);
    customize((spec) =>
      spec.content((inputs, { control }) =>
        inputs.map((option) =>
          option.with({
            label: "Held",
            icon: control.pending ? "spinner" : "star",
          })
        )
      )
    );
    await render(
      <template>
        <EngineProbe
          @load={{load}}
          @value="a"
          @valueRecords={{records}}
          @variant="button"
        />
      </template>
    );
    assert
      .dom(".d-select__value")
      .hasText("Held", "the trigger reads native content while closed");
    const engine = probedEngine();
    assert.strictEqual(
      engine.heldOption?.(record)?.icon,
      "star",
      "the closed resolved option starts idle"
    );
    const gate = deferred();
    const updating = engine.update(() => gate.promise);
    try {
      await waitUntil(() => engine.pending);
      assert.strictEqual(
        engine.heldOption?.(record)?.icon,
        "spinner",
        "pending invalidates content while closed"
      );
      assert.dom('[role="listbox"]').doesNotExist("the control stays closed");
      assert.true(load.notCalled, "the at-rest view starts no paged load");
    } finally {
      gate.resolve();
      await updating;
      await settled();
    }
    assert.strictEqual(
      engine.heldOption?.(record)?.icon,
      "star",
      "settling invalidates the view again"
    );
  });

  [false, true].forEach((multiple) => {
    test(`typing with a paged source never aborts a pending ${multiple ? "batch" : "single"} resolve`, async function (assert) {
      const record = { id: "a", name: "Answer" };
      const gate = deferred();
      const resolve = sinon.spy(() => gate.promise);
      const resolveValue = multiple ? undefined : resolve;
      const resolveValues = multiple ? resolve : undefined;
      const value = multiple ? ["a"] : "a";
      const load = sinon.spy((filter) => [
        { id: "page", name: filter || "Page" },
      ]);
      customize((spec) =>
        spec.content((inputs, { filter }) =>
          inputs.map((option) =>
            option.with({ label: filter || "Held answer" })
          )
        )
      );
      const rendering = render(
        <template>
          <EngineProbe
            @debounce={{false}}
            @load={{load}}
            @multiple={{multiple}}
            @resolveValue={{resolveValue}}
            @resolveValues={{resolveValues}}
            @value={{value}}
            @variant="typeahead"
          />
        </template>
      );
      let opening;
      let typing;
      try {
        await waitUntil(() => resolve.called && find(".d-select"));
        opening = dSelect().open();
        await waitUntil(() => find('[role="option"][data-value="page"]'));
        const signal = resolve.firstCall.args[1].signal;
        typing = dSelect().search("query");
        await waitUntil(
          () =>
            find('[role="option"][data-value="page"]')?.dataset.name === "query"
        );
        assert.false(
          signal.aborted,
          "typing and accepting a query page never abort held resolution"
        );
        assert.strictEqual(
          resolve.callCount,
          1,
          "typing never starts a second held request"
        );
        assert.true(
          load.args.some(([filter]) => filter === "query"),
          "a real paged query ran while the held value was pending"
        );
      } finally {
        gate.resolve(multiple ? [record] : record);
        await rendering;
        await opening;
        await typing;
        await settled();
      }
      if (multiple) {
        assert
          .dom('.d-select__chip[data-value="a"] .d-select__chip-label')
          .hasText(
            "Held answer",
            "the original resolve settles into the at-rest chip"
          );
      } else {
        await dSelect().close();
        assert
          .dom(".d-select__input")
          .hasValue(
            "Held answer",
            "the original resolve settles into the resting trigger"
          );
      }
      assert
        .dom(".d-select")
        .doesNotHaveAttribute(
          "data-unresolved",
          "the original answer is resolved"
        );
      assert.strictEqual(
        probedEngine().heldOption?.(record)?.record,
        record,
        "the original request supplies the key's record"
      );
    });

    test(`reload retries an unresolved ${multiple ? "chip" : "trigger"} and replaces its fallback`, async function (assert) {
      const record = { id: "a", name: "Recovered record" };
      const resolve = sinon
        .stub()
        .onFirstCall()
        .returns(multiple ? [] : undefined)
        .onSecondCall()
        .returns(
          multiple
            ? [selectOption(record, { label: "Recovered resolved option" })]
            : selectOption(record, { label: "Recovered resolved option" })
        );
      const resolveValue = multiple ? undefined : resolve;
      const resolveValues = multiple ? resolve : undefined;
      const value = multiple ? ["a"] : "a";
      const options = [];
      await render(
        <template>
          <EngineProbe
            @multiple={{multiple}}
            @options={{options}}
            @resolveValue={{resolveValue}}
            @resolveValues={{resolveValues}}
            @value={{value}}
            @variant="button"
          />
        </template>
      );
      assert
        .dom(".d-select")
        .hasAttribute(
          "data-unresolved",
          "true",
          "the first answer is an unresolved fallback"
        );
      probedEngine().reload();
      await settled();
      assert.strictEqual(
        resolve.callCount,
        2,
        "reload eviction retries the mounted held async data"
      );
      assert
        .dom(".d-select")
        .doesNotHaveAttribute(
          "data-unresolved",
          "the retried record clears unresolved state"
        );
      assert
        .dom(multiple ? ".d-select__chip-label" : ".d-select__value")
        .hasText(
          "Recovered resolved option",
          "the retried answer's explicit label reaches the held surface"
        );
      assert
        .dom(".d-select")
        .hasAttribute(
          "data-name",
          "Recovered resolved option",
          "the retried resolved option names the trigger"
        );
    });
  });

  [false, true].forEach((unresolved) => {
    test(`announcer speaks the at-rest ${unresolved ? "unresolved" : "resolved"} option when a chip is removed under a live filter`, async function (assert) {
      disableClearA11yAnnouncementsInTests();
      const record = { id: "a", name: "Record name" };
      const options = unresolved
        ? [{ id: "b", name: "Other" }]
        : [record, { id: "b", name: "Other" }];
      const resolveValues = () => [];
      const filterBy = () => true;
      const state = trackedObject({ value: ["a"], label: "Before" });
      const onChange = (value) => (state.value = value);
      customize((spec) =>
        spec.content((inputs, { filter }) =>
          inputs.map((option) => option.with({ label: filter || state.label }))
        )
      );
      await render(
        <template>
          <EngineProbe
            @debounce={{false}}
            @filterBy={{filterBy}}
            @multiple={{true}}
            @onChange={{onChange}}
            @options={{options}}
            @resolveValues={{resolveValues}}
            @value={{state.value}}
          /><A11yLiveRegions />
        </template>
      );
      state.label = "After";
      await settled();
      await dSelect().search("query");
      await dSelect().remove("a");
      assert
        .dom("#a11y-announcements-polite")
        .hasText(
          probedEngine().text("optionRemoved", { item: "After" }),
          "removal announces the current at-rest resolved option, not the record or the query's row"
        );
      assert
        .dom(".d-select__chip")
        .doesNotExist("the real chip removal occurred");
    });
  });

  ["trigger", "chips", "strip"].forEach((surface) => {
    test(`${surface} keeps the unresolved branch until a page supplies its record`, async function (assert) {
      const multiple = surface !== "trigger";
      const value = multiple ? ["missing", "other"] : "missing";
      const variant = multiple ? "typeahead" : "button";
      const records = [{ id: "other", name: "Other" }];
      let page = [];
      const load = () => page;
      const resolveValue = () => undefined;
      const resolveValues = () => [];
      customize((spec) =>
        spec.content((inputs) =>
          inputs.map((option) =>
            option.with({
              label:
                option.record.name === "Arrived"
                  ? "Available missing"
                  : `Unavailable ${option.record.id}`,
            })
          )
        )
      );
      let heldData;
      class Probe extends EngineProbe {
        constructor() {
          super(...arguments);
          heldData = spyOnHeldData(
            this.host,
            multiple ? "resolveMulti" : "resolveSingle"
          );
        }
      }
      await render(
        <template>
          <Probe
            @debounce={{false}}
            @load={{load}}
            @maxVisibleChips={{1}}
            @multiple={{multiple}}
            @resolveValue={{resolveValue}}
            @resolveValues={{resolveValues}}
            @value={{value}}
            @valueRecords={{records}}
            @variant={{variant}}
          />
        </template>
      );
      if (multiple) {
        await dSelect().open();
      }
      const selector =
        surface === "trigger"
          ? ".d-select__value"
          : surface === "chips"
            ? '.d-select__chip[data-value="missing"]'
            : '.d-select__strip-item[data-value="missing"]';
      assert
        .dom(`${selector} .d-select__unresolved`)
        .hasText(
          "Unavailable missing",
          "the explicit resolved option label stays inside unresolved markup"
        );
      assert
        .dom(surface === "trigger" ? ".d-select" : selector)
        .hasAttribute(
          "data-name",
          "Unavailable missing",
          "unresolved surface hooks use resolved option labels"
        );
      assert
        .dom(".d-select")
        .hasAttribute(
          "data-unresolved",
          "true",
          "an explicit resolved option label never resolves a fallback"
        );
      const fallback = probedEngine().resolveSingleSync("missing");
      assert.true(
        probedEngine().heldOption?.(fallback)?.unresolved,
        "the surface shows the resolved option's unresolved state"
      );
      const runs = heldData.callCount;
      const arrived = { id: "missing", name: "Arrived" };
      page = [arrived];
      await dSelect().search("query");
      assert
        .dom(`${selector} .d-select__unresolved`)
        .doesNotExist(
          "the current resolved option leaves the unresolved branch even though async data still holds the fallback"
        );
      assert
        .dom(selector)
        .includesText(
          "Available missing",
          "the held surface reads the newly canonical resolved option"
        );
      assert
        .dom(".d-select")
        .doesNotHaveAttribute(
          "data-unresolved",
          "the arriving page resolves the held resolved option"
        );
      assert.strictEqual(
        probedEngine().heldOption?.(fallback)?.record,
        arrived,
        "the old descriptor's floor never replaces the page record"
      );
      assert.strictEqual(
        heldData.callCount,
        runs,
        "page presentation refreshes outside held async data"
      );
    });
  });

  ["trigger", "chips", "strip"].forEach((surface) => {
    test(`${surface} custom blocks receive the current record after a fallback gains a page record`, async function (assert) {
      const multiple = surface !== "trigger";
      const value = multiple ? ["missing", "other"] : "missing";
      const variant = multiple ? "typeahead" : "button";
      const records = [{ id: "other", name: "Other" }];
      const arrived = { id: "missing", name: "Arrived" };
      const updated = { id: "missing", name: "Updated" };
      const yielded = new Map();
      const showRecord = (branch, record) => {
        yielded.set(`${branch}:${record.id}`, record);
        return record.name;
      };
      let page = [];
      const load = () => page;
      const resolveValue = () => undefined;
      const resolveValues = () => [];
      const createUnresolvedRecord = (id) => ({ id, name: "Fallback" });
      customize((spec) =>
        spec.content((inputs) =>
          inputs.map((option) =>
            option.with({ label: `Display ${option.record.name}` })
          )
        )
      );
      await render(
        <template>
          <DSelect
            @createUnresolvedRecord={{createUnresolvedRecord}}
            @debounce={{false}}
            @load={{load}}
            @maxVisibleChips={{1}}
            @multiple={{multiple}}
            @resolveValue={{resolveValue}}
            @resolveValues={{resolveValues}}
            @value={{value}}
            @valueRecords={{records}}
            @variant={{variant}}
          >
            <:selection as |option|>
              <span class="held-block__selection">{{showRecord
                  "selection"
                  option.record
                }}</span>
            </:selection>
            <:unresolved as |option|>
              <span class="held-block__unresolved">{{showRecord
                  "unresolved"
                  option.record
                }}</span>
            </:unresolved>
          </DSelect>
        </template>
      );
      if (surface === "strip") {
        await dSelect().open();
      }
      const selector =
        surface === "trigger"
          ? ".d-select__value"
          : surface === "chips"
            ? '.d-select .d-select__chip[data-value="missing"]'
            : '.d-select__strip-item[data-value="missing"]';
      const nameSelector = surface === "trigger" ? ".d-select" : selector;
      assert
        .dom(`${selector} .held-block__unresolved`)
        .hasText(
          "Fallback",
          "the unresolved block receives the fallback record"
        );
      assert.strictEqual(
        yielded.get("unresolved:missing")?.id,
        "missing",
        "the unresolved block receives the held key"
      );
      assert
        .dom(nameSelector)
        .hasAttribute(
          "data-name",
          "Display Fallback",
          "the surface name uses content presentation rather than the block's record name"
        );

      page = [arrived];
      await dSelect().search("first");
      assert
        .dom(`${selector} .held-block__unresolved`)
        .doesNotExist(
          "the page record takes the surface out of the unresolved branch"
        );
      assert
        .dom(`${selector} .held-block__selection`)
        .hasText(
          "Arrived",
          "the selection block renders the current page record's name"
        );
      assert.strictEqual(
        yielded.get("selection:missing"),
        arrived,
        "the selection block receives the actual page record rather than a fallback or a presentation copy"
      );
      assert
        .dom(nameSelector)
        .hasAttribute(
          "data-name",
          "Display Arrived",
          "the surface name and block follow the same key's record"
        );

      page = [updated];
      await dSelect().search("second");
      assert
        .dom(`${selector} .held-block__selection`)
        .hasText(
          "Updated",
          "the resolved block also follows a later replacement record"
        );
      assert.strictEqual(
        yielded.get("selection:missing"),
        updated,
        "the block keeps receiving the current record after the branch has already changed"
      );
    });
  });

  test("adding the first chip announces the native content label", async function (assert) {
    disableClearA11yAnnouncementsInTests();
    const record = { id: "a", name: "Raw" };
    const options = [record];
    const state = trackedObject({ value: [] });
    const onChange = (value) => (state.value = value);
    customize((spec) =>
      spec.content((inputs) =>
        inputs.map((option) => option.with({ label: "Pretty" }))
      )
    );
    await render(
      <template>
        <DSelect
          @multiple={{true}}
          @onChange={{onChange}}
          @options={{options}}
          @value={{state.value}}
        /><A11yLiveRegions />
      </template>
    );
    assert.dom(".d-select__chip").doesNotExist("the multi-select starts empty");
    await dSelect().open();
    assert
      .dom('[role="option"][data-value="a"]')
      .hasText("Pretty", "native content names the option before it is held");
    await dSelect().select("a");
    assert
      .dom('.d-select__chip[data-value="a"] .d-select__chip-label')
      .hasText("Pretty", "the newly held chip shows the content label");
    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        i18n("d_select.item_added", { item: "Pretty" }),
        "adding the first held value announces the same content label as its chip"
      );
  });
});

module(
  "Integration | ui-kit | select | DSelect disabled picks",
  function (hooks) {
    setupRenderingTest(hooks);

    for (const source of ["list", "valueRecords"]) {
      for (const gesture of ["click", "keyboard Enter"]) {
        test(`${gesture} refuses a row disabled by ${source}`, async function (assert) {
          const blocked = { id: "blocked", name: "Blocked" };
          const enabled = { id: "enabled", name: "Enabled" };
          const disabled = selectOption(blocked, { disabled: true });
          const options = [enabled, source === "list" ? disabled : blocked];
          const records = source === "valueRecords" ? [disabled] : [];
          const state = trackedState({ value: [] });
          const onChange = sinon.spy((value) => (state.value = value));
          retainA11yAnnouncements();
          await render(
            <template>
              <DSelect
                @multiple={{true}}
                @onChange={{onChange}}
                @options={{options}}
                @value={{state.value}}
                @valueRecords={{records}}
                @variant="typeahead"
              /><SelectLiveRegions />
            </template>
          );
          await dSelect().open();
          assert
            .dom('[role="option"][data-value="blocked"]')
            .hasAttribute(
              "aria-disabled",
              "true",
              "the merged resolved option disables the actual option"
            );
          if (gesture === "click") {
            await click('[role="option"][data-value="blocked"]');
          } else {
            assert
              .dom("input.d-select__input")
              .exists("the rendered typeahead supplies the keyboard target");
            await triggerKeyEvent(
              "input.d-select__input",
              "keydown",
              "ArrowDown"
            );
            assert
              .dom('[role="option"][data-value="blocked"]')
              .hasClass(
                "--active",
                "keyboard navigation reaches the disabled row"
              );
            await triggerKeyEvent("input.d-select__input", "keydown", "Enter");
          }
          assert.strictEqual(
            onChange.callCount,
            0,
            "activating the disabled row emits nothing"
          );
          assert.deepEqual(state.value, [], "the value stays unchanged");
          assert.dom(".d-select__chip").doesNotExist("no chip is added");
          assert.dom('[role="listbox"]').exists("refusal leaves the list open");
          assert
            .dom("#a11y-announcements-polite")
            .doesNotIncludeText(
              i18n("d_select.item_added", { item: blocked.name }),
              "refusal never announces an addition"
            );
        });
      }
    }

    test("a closed control.select leaves no chip or add announcement", async function (assert) {
      const blocked = { id: "blocked", name: "Blocked" };
      const options = [selectOption(blocked, { disabled: true })];
      const state = trackedState({ value: [] });
      const onChange = sinon.spy((value) => (state.value = value));
      let control;
      withSelectPluginApi((api) =>
        api.registerValueTransformer("select-customizations", ({ value }) =>
          value.forAll((spec) =>
            spec.config((_config, context) => {
              control = context.control;
            })
          )
        )
      );
      retainA11yAnnouncements();
      await render(
        <template>
          <DSelect
            @multiple={{true}}
            @onChange={{onChange}}
            @options={{options}}
            @value={{state.value}}
            @variant="typeahead"
          /><SelectLiveRegions />
        </template>
      );

      control.select({ ...blocked, name: "Programmatic copy" });
      await settled();

      assert.strictEqual(
        onChange.callCount,
        0,
        "a closed programmatic pick consults the listed resolved option"
      );
      assert.deepEqual(state.value, [], "the parent value stays unchanged");
      assert.dom(".d-select__chip").doesNotExist("no refused chip appears");
      assert
        .dom('[role="listbox"]')
        .doesNotExist("the pick never opens the list");
      assert
        .dom("#a11y-announcements-polite")
        .doesNotIncludeText(
          i18n("d_select.item_added", { item: blocked.name }),
          "the canonical resolved option is not announced as added"
        );
      assert
        .dom("#a11y-announcements-polite")
        .doesNotIncludeText(
          i18n("d_select.item_added", { item: "Programmatic copy" }),
          "the passed copy is not announced as added"
        );
    });

    for (const parser of ["default", "custom"]) {
      test(`${parser} multi paste drops refused inputs before the cap`, async function (assert) {
        const blocked = { id: "blocked", name: "Blocked" };
        const a = { id: "a", name: "A" };
        const b = { id: "b", name: "B" };
        const c = { id: "c", name: "C" };
        const options = [blocked, a, b, c];
        const records = [selectOption(blocked, { disabled: true })];
        const parsePaste =
          parser === "custom"
            ? () => [
                blocked,
                blocked,
                selectOption(a, { disabled: true }),
                a,
                a,
                b,
                c,
              ]
            : undefined;
        const state = trackedState({ value: [] });
        const onChange = sinon.spy((value) => (state.value = value));
        retainA11yAnnouncements();
        await render(
          <template>
            <DSelect
              @maximum={{2}}
              @multiple={{true}}
              @onChange={{onChange}}
              @options={{options}}
              @parsePaste={{parsePaste}}
              @value={{state.value}}
              @valueRecords={{records}}
              @variant="typeahead"
            /><SelectLiveRegions />
          </template>
        );
        assert
          .dom("input.d-select__input")
          .exists("the typeahead has a native paste target");
        const data = new DataTransfer();
        data.setData("text/plain", "Blocked | Blocked | A | A | B | C");
        const event = new ClipboardEvent("paste", {
          clipboardData: data,
          bubbles: true,
          cancelable: true,
        });
        find("input.d-select__input").dispatchEvent(event);
        await settled();

        assert.deepEqual(
          state.value,
          ["a", "b"],
          "refused inputs leave capacity for later eligible keys"
        );
        assert.true(
          event.defaultPrevented,
          "the real paste handler consumes the batch"
        );
        assert.strictEqual(
          onChange.callCount,
          1,
          "paste emits one combined change"
        );
        assert.deepEqual(
          onChange.firstCall?.args[1],
          [a, b],
          "the payload contains only accepted records"
        );
        assert.deepEqual(
          onChange.firstCall?.args[2]?.origin?.bulk,
          { added: 2, held: 1, limit: 1 },
          "refused inputs do not inflate held or cap counts"
        );
        assert
          .dom('.d-select__chip[data-value="blocked"]')
          .doesNotExist("the refused key has no chip");
        assert
          .dom(".d-select__chip")
          .exists({ count: 2 }, "both eligible values are held");
        assert
          .dom("#a11y-announcements-polite")
          .doesNotIncludeText(
            blocked.name,
            "the batch announcement never names the refused input"
          );
      });
    }

    test("an entirely refused custom paste emits and announces no addition", async function (assert) {
      const blocked = { id: "blocked", name: "Blocked" };
      const options = [selectOption(blocked, { disabled: true })];
      const parsePaste = () => [blocked, { ...blocked }];
      const state = trackedState({ value: [] });
      const onChange = sinon.spy((value) => (state.value = value));
      retainA11yAnnouncements();
      await render(
        <template>
          <DSelect
            @multiple={{true}}
            @onChange={{onChange}}
            @options={{options}}
            @parsePaste={{parsePaste}}
            @value={{state.value}}
            @variant="typeahead"
          /><SelectLiveRegions />
        </template>
      );
      assert
        .dom("input.d-select__input")
        .exists("the typeahead supplies the paste target");
      const data = new DataTransfer();
      data.setData("text/plain", "Blocked | Blocked");
      find("input.d-select__input").dispatchEvent(
        new ClipboardEvent("paste", {
          clipboardData: data,
          bubbles: true,
          cancelable: true,
        })
      );
      await settled();

      assert.strictEqual(
        onChange.callCount,
        0,
        "an all-refused batch emits nothing"
      );
      assert.deepEqual(state.value, [], "the value remains empty");
      assert
        .dom(".d-select__chip")
        .doesNotExist("no chip survives the refused paste");
      assert
        .dom("#a11y-announcements-polite")
        .hasNoText(
          "a fully refused paste announces neither an addition nor a held or capped input"
        );
    });

    test("a held disabled chip remains removable", async function (assert) {
      const record = { id: "held", name: "Held" };
      const options = [selectOption(record, { disabled: true })];
      const state = trackedState({ value: [record.id] });
      const onChange = sinon.spy((value) => (state.value = value));
      await render(
        <template>
          <DSelect
            @multiple={{true}}
            @onChange={{onChange}}
            @options={{options}}
            @value={{state.value}}
            @variant="typeahead"
          />
        </template>
      );
      assert
        .dom('.d-select__chip[data-value="held"] .d-select__chip-remove')
        .exists(
          "disabled describes additions, so the held chip still offers removal"
        );
      await click('.d-select__chip[data-value="held"] .d-select__chip-remove');
      assert.deepEqual(
        state.value,
        [],
        "removing the disabled held value succeeds"
      );
      assert.strictEqual(onChange.callCount, 1, "removal emits once");
      assert.dom(".d-select__chip").doesNotExist("the chip is removed");
    });

    for (const { gesture, disabled } of [
      { gesture: "click", disabled: false },
      { gesture: "control.select", disabled: false },
      { gesture: "control.select", disabled: true },
    ]) {
      test(`${gesture} ${disabled ? "refuses a query-disabled row and accepts" : "accepts a query-enabled row and refuses"} it after closing`, async function (assert) {
        const record = { id: "query", name: "Query row" };
        const options = [record];
        const state = trackedState({ value: [] });
        const onChange = sinon.spy((value) => (state.value = value));
        let control;
        withSelectPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) =>
            value.forAll((spec) => {
              spec.config((_config, context) => {
                control = context.control;
              });
              spec.content((inputs, { filter }) =>
                inputs.map((option) =>
                  option.with({
                    disabled: filter === "query" ? disabled : !disabled,
                  })
                )
              );
            })
          )
        );
        await render(
          <template>
            <DSelect
              @multiple={{true}}
              @onChange={{onChange}}
              @options={{options}}
              @value={{state.value}}
              @variant="typeahead"
            />
          </template>
        );
        await dSelect().search("query");
        if (disabled) {
          assert
            .dom('[role="option"][data-value="query"]')
            .hasAttribute(
              "aria-disabled",
              "true",
              "the query disables the row"
            );
        } else {
          assert
            .dom('[role="option"][data-value="query"]')
            .exists("the query lists the row")
            .doesNotHaveAttribute("aria-disabled", "the query enables the row");
        }

        if (gesture === "click") {
          await dSelect().select(record.id);
        } else {
          control.select(record);
          await settled();
        }

        assert.strictEqual(
          onChange.callCount,
          disabled ? 0 : 1,
          "picking follows the row's displayed disabled state"
        );
        assert.deepEqual(
          state.value,
          disabled ? [] : [record.id],
          "the caller holds exactly the pick permitted by the query"
        );
        if (disabled) {
          assert
            .dom(".d-select__chip")
            .doesNotExist("the refused pick adds no chip");
        } else {
          assert
            .dom('.d-select__chip[data-value="query"]')
            .exists("the accepted pick adds its chip");
        }

        control.deselect(record);
        await settled();
        await dSelect().close();
        onChange.resetHistory();
        assert.dom('[role="listbox"]').doesNotExist("the list is closed");
        assert
          .dom("input.d-select__input")
          .hasValue("", "closing resets the query");

        control.select(record);
        await settled();

        assert.strictEqual(
          onChange.callCount,
          disabled ? 1 : 0,
          "a closed pick follows the opposite at-rest disabled state"
        );
        assert.deepEqual(
          state.value,
          disabled ? [record.id] : [],
          "the old list cannot decide a pick after the query resets"
        );
        assert
          .dom('[role="listbox"]')
          .doesNotExist("the control pick stays closed");
      });
    }

    test("a closed control.select refuses a source option disabled after the empty-query list closes", async function (assert) {
      const record = { id: "changed", name: "Changed row" };
      const enabled = selectOption(record, { disabled: false });
      const state = trackedState({ value: [], options: [enabled] });
      const onChange = sinon.spy((value) => (state.value = value));
      let control;
      withSelectPluginApi((api) =>
        api.registerValueTransformer("select-customizations", ({ value }) =>
          value.forAll((spec) =>
            spec.config((_config, context) => {
              control = context.control;
            })
          )
        )
      );
      await render(
        <template>
          <DSelect
            @multiple={{true}}
            @onChange={{onChange}}
            @options={{state.options}}
            @value={{state.value}}
            @variant="typeahead"
          />
        </template>
      );
      await dSelect().open();
      assert
        .dom("input.d-select__input")
        .hasValue("", "the list is built for the empty query");
      assert
        .dom('[role="option"][data-value="changed"]')
        .exists("the empty query lists the source option")
        .doesNotHaveAttribute("aria-disabled", "the listed row is enabled");

      await dSelect().close();
      state.options = [enabled.with({ disabled: true })];
      await settled();
      assert.dom('[role="listbox"]').doesNotExist("the list stays closed");
      assert
        .dom("input.d-select__input")
        .hasValue("", "closing leaves the same empty query");

      control.select(record);
      await settled();

      assert.strictEqual(
        onChange.callCount,
        0,
        "the closed pick consults the newly disabled source option"
      );
      assert.deepEqual(state.value, [], "the parent value stays empty");
      assert
        .dom(".d-select__chip")
        .doesNotExist("the refused pick adds no chip");
      assert
        .dom('[role="listbox"]')
        .doesNotExist("the refused control pick keeps the list closed");
    });

    test("the displayed row follows the live query and accepts a click while its load is pending", async function (assert) {
      const record = { id: "query", name: "Query row" };
      const state = trackedState({ value: [] });
      const onChange = sinon.spy((value) => (state.value = value));
      let release;
      const pending = new Promise((resolve) => {
        release = () => resolve([record]);
      });
      let pendingStarted = false;
      const load = (filter) => {
        if (filter === "qu") {
          pendingStarted = true;
          return pending;
        }
        return Promise.resolve([record]);
      };
      withSelectPluginApi((api) =>
        api.registerValueTransformer("select-customizations", ({ value }) =>
          value.forAll((spec) => {
            spec.content((inputs, { filter }) =>
              inputs.map((option) =>
                option.with({
                  disabled: !filter,
                  label: filter ? `Results for ${filter}` : "At rest",
                })
              )
            );
          })
        )
      );
      await render(
        <template>
          <DSelect
            @load={{load}}
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{state.value}}
            @variant="typeahead"
          />
        </template>
      );
      await dSelect().open();
      assert
        .dom('[role="option"][data-value="query"]')
        .hasAttribute("aria-disabled", "true", "the at-rest row is disabled");
      await dSelect().search("q");
      assert
        .dom('[role="option"][data-value="query"]')
        .hasAttribute("data-name", "Results for q", "q's results are displayed")
        .doesNotHaveAttribute("aria-disabled", "the query enables the row");

      const typing = fillIn("input.d-select__input", "qu");
      try {
        await waitUntil(() => pendingStarted);
        assert
          .dom("input.d-select__input")
          .hasValue("qu", "the live input has advanced to qu");
        assert
          .dom('[role="option"][data-value="query"]')
          .hasAttribute(
            "data-name",
            "Results for qu",
            "the retained row reflects the live query while qu is pending"
          )
          .doesNotHaveAttribute(
            "aria-disabled",
            "the displayed row stays enabled"
          );

        // The test helper would wait for the pending load before clicking.
        find('[role="option"][data-value="query"]').click();

        assert.strictEqual(
          onChange.callCount,
          1,
          "clicking the displayed enabled row emits one selection"
        );
        assert.deepEqual(
          state.value,
          [record.id],
          "the parent holds the selected value while qu is pending"
        );
        assert.deepEqual(
          onChange.firstCall?.args[1],
          [record],
          "the accepted selection supplies the record to the parent"
        );
      } finally {
        release();
        await typing;
      }
      assert
        .dom('.d-select__chip[data-value="query"]')
        .exists("the accepted displayed row adds its chip");
    });

    test("control.select uses the at-rest view after minChars unmounts the list without closing", async function (assert) {
      const a = { id: "a", name: "Apple" };
      const options = [a];
      const state = trackedState({ value: [] });
      const onChange = sinon.spy((value) => (state.value = value));
      let control;
      withSelectPluginApi((api) =>
        api.registerValueTransformer("select-customizations", ({ value }) =>
          value.forAll((spec) => {
            spec.config((_config, context) => {
              control = context.control;
            });
            spec.content((inputs, { filter }) =>
              inputs.map((option) => option.with({ disabled: filter !== "ap" }))
            );
          })
        )
      );
      await render(
        <template>
          <DSelect
            @minChars={{2}}
            @multiple={{true}}
            @onChange={{onChange}}
            @options={{options}}
            @value={{state.value}}
            @variant="typeahead"
          />
        </template>
      );
      await dSelect().search("ap");
      assert
        .dom('[role="option"][data-value="a"]')
        .exists("the qualifying query lists A")
        .doesNotHaveAttribute("aria-disabled", "the query enables A");

      await fillIn("input.d-select__input", "");

      assert
        .dom("input.d-select__input")
        .hasValue("", "the query is cleared")
        .hasAttribute("aria-expanded", "true", "the menu remains open");
      assert.dom(".d-select__panel").exists("the panel remains mounted");
      assert
        .dom(".d-select__min-chars")
        .exists("the minimum query hint replaces the list");
      assert
        .dom('[role="listbox"]')
        .doesNotExist("clearing below minChars unmounts the listbox");

      control.select(a);
      await settled();

      assert.strictEqual(
        onChange.callCount,
        0,
        "the at-rest disabled state refuses A once its listbox unmounts"
      );
      assert.deepEqual(state.value, [], "the parent value remains empty");
      assert
        .dom(".d-select__chip")
        .doesNotExist("the refused pick adds no chip");
    });
  }
);

module("Integration | ui-kit | select | DSelect icons", function (hooks) {
  setupRenderingTest(hooks);

  const noop = () => {};
  const iconOf = (element) =>
    [...element.querySelectorAll(":scope > .d-icon, :scope > * > .d-icon")]
      .map((icon) => [...icon.classList].find((c) => c.startsWith("d-icon-")))
      .filter(Boolean);

  test("a row draws its resolved option's icon before its label", async function (assert) {
    const options = [
      selectOption({ id: 1, name: "Apple" }, { icon: "far-heart" }),
      { id: 2, name: "Banana" },
    ];

    await render(
      <template>
        <DSelect @onChange={{noop}} @options={{options}} @value={{null}} />
      </template>
    );
    await dSelect().open();

    const row = find("[role='option'][data-value='1']");
    assert.strictEqual(
      row.querySelector(".d-icon-far-heart")?.parentElement,
      row,
      "the icon is the row's own"
    );
    assert.dom(row).hasText("Apple");
    assert.true(
      row.innerHTML.indexOf("d-icon-far-heart") <
        row.innerHTML.indexOf("Apple"),
      "the icon precedes the label"
    );
    assert
      .dom(".d-icon", find("[role='option'][data-value='2']"))
      .doesNotExist("a row whose resolved option has no icon draws none");
  });

  test("an option block's content follows the resolved option's icon", async function (assert) {
    const options = [
      selectOption({ id: 1, name: "Apple" }, { icon: "far-heart" }),
    ];

    await render(
      <template>
        <DSelect @onChange={{noop}} @options={{options}} @value={{null}}>
          <:option as |option|>
            <span class="custom-row">{{option.record.name}}</span>
          </:option>
        </DSelect>
      </template>
    );
    await dSelect().open();

    const row = find("[role='option'][data-value='1']");
    assert.deepEqual(iconOf(row), ["d-icon-far-heart"], "drawn once");
    assert
      .dom(".custom-row", row)
      .hasText("Apple", "the block still draws the label");
    assert.true(
      row.innerHTML.indexOf("d-icon-far-heart") <
        row.innerHTML.indexOf("custom-row"),
      "the icon precedes the block's content"
    );
  });

  test("@iconField derives the icon and an explicit empty icon draws none", async function (assert) {
    const options = [
      { id: 1, name: "Apple", glyph: "far-heart" },
      selectOption({ id: 2, name: "Banana", glyph: "star" }, { icon: "" }),
      { id: 3, name: "Cherry" },
    ];

    await render(
      <template>
        <DSelect
          @iconField="glyph"
          @onChange={{noop}}
          @options={{options}}
          @value={{null}}
        />
      </template>
    );
    await dSelect().open();

    assert.deepEqual(
      iconOf(find("[role='option'][data-value='1']")),
      ["d-icon-far-heart"],
      "the field names the icon"
    );
    assert
      .dom(".d-icon", find("[role='option'][data-value='2']"))
      .doesNotExist("an empty explicit icon clears the derived one");
    assert
      .dom(".d-icon", find("[role='option'][data-value='3']"))
      .doesNotExist("a record without the field draws none");
  });

  test("a described row keeps its icon out of the label it is named by", async function (assert) {
    const options = [
      selectOption(
        { id: 1, name: "Apple" },
        { icon: "far-heart", description: "Crisp" }
      ),
    ];

    await render(
      <template>
        <DSelect @onChange={{noop}} @options={{options}} @value={{null}} />
      </template>
    );
    await dSelect().open();

    const row = find("[role='option'][data-value='1']");
    assert.strictEqual(
      row.querySelector(".d-icon-far-heart")?.parentElement,
      row,
      "the icon sits in the row, beside its content"
    );
    const label = document.getElementById(row.getAttribute("aria-labelledby"));
    assert.dom(label).hasText("Apple");
    assert.dom(".d-icon", label).doesNotExist("the label holds no icon");
  });

  test("chips draw each held resolved option's icon and never its description", async function (assert) {
    const options = [
      selectOption(
        { id: 1, name: "Apple" },
        { icon: "far-heart", description: "Crisp" }
      ),
      { id: 2, name: "Banana" },
    ];

    await render(
      <template>
        <DSelect
          @multiple={{true}}
          @onChange={{noop}}
          @options={{options}}
          @value={{array 1 2}}
        />
      </template>
    );

    const [apple, banana] = findAll(".d-select__chip");
    assert.dom(".d-icon-far-heart", apple).exists("the chip draws the icon");
    assert
      .dom(".d-select__chip-label", apple)
      .hasText("Apple", "and never the description");
    assert
      .dom(".d-icon", banana.querySelector(".d-select__chip-label"))
      .doesNotExist("a chip whose resolved option has no icon draws none");
  });

  test("a chip's selection block follows the held icon", async function (assert) {
    const options = [
      selectOption({ id: 1, name: "Apple" }, { icon: "far-heart" }),
    ];

    await render(
      <template>
        <DSelect
          @multiple={{true}}
          @onChange={{noop}}
          @options={{options}}
          @value={{array 1}}
        >
          <:selection as |option|>
            <span class="custom-chip">{{option.record.name}}</span>
          </:selection>
        </DSelect>
      </template>
    );

    const label = find(".d-select__chip-label");
    assert.deepEqual(iconOf(label), ["d-icon-far-heart"], "drawn once");
    assert.dom(".custom-chip", label).hasText("Apple");
  });

  test("an unresolved chip draws no icon", async function (assert) {
    const options = [];

    await render(
      <template>
        <DSelect
          @iconField="glyph"
          @multiple={{true}}
          @onChange={{noop}}
          @options={{options}}
          @value={{array 99}}
        />
      </template>
    );

    assert.dom(".d-select__chip-label").exists("the held value has a chip");
    assert
      .dom(".d-select__chip-label .d-icon")
      .doesNotExist("an unresolved option derives no icon");
  });

  test("a group action row draws its icon unless its group block draws the row", async function (assert) {
    const options = [{ id: 1, name: "Apple", section: "fruit" }];
    const groupFooter = (key) =>
      selectOption(
        { id: `more-${key}`, name: "More fruit" },
        { icon: "plus", onSelect() {} }
      );

    await render(
      <template>
        <div class="plain">
          <DSelect
            @groupBy="section"
            @groupFooter={{groupFooter}}
            @onChange={{noop}}
            @options={{options}}
            @value={{null}}
            @variant="static"
          />
        </div>
        <div class="drawn">
          <DSelect
            @groupBy="section"
            @groupFooter={{groupFooter}}
            @onChange={{noop}}
            @options={{options}}
            @value={{null}}
            @variant="static"
          >
            <:groupFooter>
              <span class="custom-footer">More</span>
            </:groupFooter>
          </DSelect>
        </div>
      </template>
    );

    await dSelect(".plain .d-select").open();
    assert
      .dom(".plain .d-select__option.--action-footer .d-icon-plus")
      .exists({ count: 1 }, "the engine draws the footer's icon");
    await dSelect(".plain .d-select").close();

    await dSelect(".drawn .d-select").open();
    assert.dom(".drawn .custom-footer").exists("the block draws the row");
    assert
      .dom(".drawn .d-select__option.--action-footer .d-icon")
      .doesNotExist("the block owns what the row shows");
  });

  test("the selection strip draws each held resolved option's icon", async function (assert) {
    const cap = tracked(1);
    const options = [
      selectOption({ id: 1, name: "Apple" }, { icon: "far-heart" }),
      selectOption({ id: 2, name: "Banana" }, { icon: "star" }),
    ];

    await render(
      <template>
        <CompactStripHost
          @cap={{cap}}
          @options={{options}}
          @value={{array 1 2}}
        />
      </template>
    );
    await click(".d-select__input");

    const strip = find(".d-select__strip");
    assert.dom(strip).exists("overflow shows the strip");
    assert.dom(".d-icon-far-heart", strip).exists();
    assert.dom(".d-icon-star", strip).exists();
  });
});

module(
  "Integration | ui-kit | select | DSelect block contract",
  function (hooks) {
    setupRenderingTest(hooks);

    const noop = () => {};

    test("an option block receives the row's resolved option and the config, and nothing else", async function (assert) {
      const options = [
        selectOption(
          { id: 1, name: "Apple" },
          { icon: "far-heart", label: "Shown apple" }
        ),
      ];

      await render(
        <template>
          <DSelect
            @icon="gear"
            @onChange={{noop}}
            @options={{options}}
            @value={{null}}
            @variant="static"
          >
            <:option as |option config extra|>
              <span class="x-label">{{option.label}}</span>
              <span class="x-key">{{option.key}}</span>
              <span class="x-icon">{{option.icon}}</span>
              <span class="x-name">{{option.record.name}}</span>
              <span class="x-config">{{config.icon}}</span>
              <span class="x-extra">{{if extra "extra" "none"}}</span>
            </:option>
          </DSelect>
        </template>
      );
      await dSelect().open();

      assert
        .dom(".x-label")
        .hasText("Shown apple", "the resolved option's label");
      assert.dom(".x-key").hasText("1");
      assert.dom(".x-icon").hasText("far-heart");
      assert.dom(".x-name").hasText("Apple", "the record stays as passed");
      assert.dom(".x-config").hasText("gear", "the resolved config");
      assert.dom(".x-extra").hasText("none", "no third parameter");
    });

    test("a selection block receives the held resolved option and the config", async function (assert) {
      const options = [
        selectOption({ id: 1, name: "Apple" }, { label: "Shown apple" }),
      ];

      await render(
        <template>
          <DSelect
            @onChange={{noop}}
            @options={{options}}
            @value={{1}}
            @variant="static"
          >
            <:selection as |option config|>
              <span class="x-label">{{option.label}}</span>
              <span class="x-name">{{option.record.name}}</span>
              <span class="x-config">{{if config "config" "none"}}</span>
            </:selection>
          </DSelect>
        </template>
      );

      assert.dom(".x-label").hasText("Shown apple");
      assert.dom(".x-name").hasText("Apple");
      assert.dom(".x-config").hasText("config");
    });

    test("a chip's selection block receives its held resolved option", async function (assert) {
      const options = [
        selectOption({ id: 1, name: "Apple" }, { label: "Shown apple" }),
      ];

      await render(
        <template>
          <DSelect
            @multiple={{true}}
            @onChange={{noop}}
            @options={{options}}
            @value={{array 1}}
          >
            <:selection as |option|>
              <span class="x-label">{{option.label}}</span>
            </:selection>
          </DSelect>
        </template>
      );

      assert.dom(".d-select__chip .x-label").hasText("Shown apple");
    });

    test("an unresolved block receives the unresolved held option", async function (assert) {
      const options = [];

      await render(
        <template>
          <DSelect
            @onChange={{noop}}
            @options={{options}}
            @value={{99}}
            @variant="static"
          >
            <:unresolved as |option config|>
              <span class="x-unresolved">{{if
                  option.unresolved
                  "yes"
                  "no"
                }}</span>
              <span class="x-value">{{option.value}}</span>
              <span class="x-config">{{if config "config" "none"}}</span>
            </:unresolved>
          </DSelect>
        </template>
      );

      assert.dom(".x-unresolved").hasText("yes");
      assert.dom(".x-value").hasText("99");
      assert.dom(".x-config").hasText("config");
    });

    test("group blocks receive the boundary's resolved option, the config and the group's key", async function (assert) {
      const options = [{ id: 1, name: "Apple", section: "fruit" }];
      const groupHeader = (key) => `Header ${key}`;
      const groupFooter = (key) =>
        selectOption(
          { id: `more-${key}`, name: "More fruit" },
          { onSelect() {} }
        );

      await render(
        <template>
          <DSelect
            @groupBy="section"
            @groupFooter={{groupFooter}}
            @groupHeader={{groupHeader}}
            @onChange={{noop}}
            @options={{options}}
            @value={{null}}
            @variant="static"
          >
            <:groupHeader as |option config group|>
              <span class="x-header">{{option.label}}</span>
              <span class="x-header-key">{{group.key}}</span>
              <span class="x-header-config">{{if config "config" "none"}}</span>
              <span class="x-header-action">{{if
                  group.action
                  "group-action"
                  "none"
                }}</span>
            </:groupHeader>
            <:groupFooter as |option config group|>
              <span class="x-footer">{{option.label}}</span>
              <span class="x-footer-key">{{group.key}}</span>
              <span class="x-footer-action">{{if
                  option.action
                  "option-action"
                  "none"
                }}</span>
            </:groupFooter>
          </DSelect>
        </template>
      );
      await dSelect().open();

      assert.dom(".x-header").hasText("Header fruit");
      assert.dom(".x-header-key").hasText("fruit");
      assert.dom(".x-header-config").hasText("config");
      assert
        .dom(".x-header-action")
        .hasText("none", "the group no longer says whether it is an action");
      assert.dom(".x-footer").hasText("More fruit");
      assert.dom(".x-footer-key").hasText("fruit");
      assert
        .dom(".x-footer-action")
        .hasText("option-action", "the resolved option says it is an action");
    });

    test("the create row reaches the option block as a create option", async function (assert) {
      const options = [{ id: 1, name: "Apple" }];
      const createOption = (term) => ({ id: term, name: term });

      await render(
        <template>
          <DSelect
            @allowCreate={{true}}
            @createOption={{createOption}}
            @onChange={{noop}}
            @options={{options}}
            @value={{null}}
          >
            <:option as |option|>
              <span class="x-row">{{if
                  option.create
                  "create"
                  "plain"
                }}:{{option.label}}</span>
            </:option>
          </DSelect>
        </template>
      );
      await dSelect().open();
      await dSelect().search("Kiwi");

      assert
        .dom(".d-select__option.--create .x-row")
        .hasText("create:Kiwi", "the create row says so");
    });

    test("a list's option block receives the row's resolved option", async function (assert) {
      const options = [
        selectOption({ id: 1, name: "Apple" }, { label: "Shown apple" }),
      ];

      await render(
        <template>
          <DSelectList @onChange={{noop}} @options={{options}} @value={{null}}>
            <:option as |option config extra|>
              <span class="x-label">{{option.label}}</span>
              <span class="x-extra">{{if extra "extra" "none"}}</span>
            </:option>
          </DSelectList>
        </template>
      );

      assert.dom(".x-label").hasText("Shown apple");
      assert.dom(".x-extra").hasText("none");
    });
  }
);
