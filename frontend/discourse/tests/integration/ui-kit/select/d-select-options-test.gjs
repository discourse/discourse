import { tracked } from "@glimmer/tracking";
import { trackedArray } from "@ember/reactive/collections";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  resetOnerror,
  settled,
  setupOnerror,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";

/** Dispatches a real paste so parsing and selection use the same public input path. */
function paste(text) {
  const data = new DataTransfer();
  data.setData("text", text);
  data.setData("text/plain", text);
  const event = new ClipboardEvent("paste", {
    clipboardData: data,
    bubbles: true,
    cancelable: true,
  });
  find("[role='combobox']").dispatchEvent(event);
  return event;
}

module("Integration | ui-kit | select | DSelect options", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    resetOnerror();
  });

  test("in-place options mutations update disabled settings and remove entries", async function (assert) {
    const apple = { id: "apple", name: "Apple" };
    const pear = { id: "pear", name: "Pear" };
    const plum = { id: "plum", name: "Plum" };
    const options = trackedArray([apple, pear, plum]);
    const changes = [];
    const onChange = (...args) => changes.push(args);
    const pearRow = `[role='option'][data-value='${pear.id}']`;
    const plumRow = `[role='option'][data-value='${plum.id}']`;

    await render(
      <template>
        <DSelect @onChange={{onChange}} @options={{options}} />
      </template>
    );
    await dSelect().open();
    assert
      .dom("[role='option']")
      .exists({ count: 3 }, "all initial entries render");
    assert
      .dom(pearRow)
      .doesNotHaveAttribute("aria-disabled", "pear starts enabled");

    options.splice(1, 2, selectOption(pear, { disabled: true }));
    await settled();

    assert
      .dom(pearRow)
      .hasAttribute(
        "aria-disabled",
        "true",
        "in-place replacement renders pear disabled"
      );
    assert
      .dom(plumRow)
      .doesNotExist("in-place removal drops plum from the open list");
    await dSelect().select(pear.id);
    assert.deepEqual(changes, [], "in-place replacement prevents picking pear");

    await dSelect().close();
    await dSelect().open();
    assert
      .dom(pearRow)
      .hasAttribute(
        "aria-disabled",
        "true",
        "reopening retains the replacement settings"
      );
    assert
      .dom(plumRow)
      .doesNotExist("reopening does not restore the removed entry");
    await dSelect().select(pear.id);
    assert.deepEqual(changes, [], "pear remains unpickable after reopening");
    await dSelect().select(apple.id);
    assert.strictEqual(
      changes.at(-1)?.[1],
      apple,
      "the remaining enabled record is pickable"
    );
  });

  test("extra options keep the first equal value and drop source duplicates", async function (assert) {
    const extraPear = { id: "pear", name: "Extra pear" };
    const sourcePear = { id: extraPear.id, name: "Source pear" };
    const apple = { id: "apple", name: "Apple" };
    const options = [sourcePear, apple];
    const extraOptions = () => [selectOption(extraPear, { disabled: true })];
    const changes = [];
    const onChange = (...args) => changes.push(args);
    const pearRow = `[role='option'][data-value='${extraPear.id}']`;

    await render(
      <template>
        <DSelect
          @extraOptions={{extraOptions}}
          @onChange={{onChange}}
          @options={{options}}
        >
          <:option as |record|>{{record.name}}</:option>
        </DSelect>
      </template>
    );
    await dSelect().open();

    assert
      .dom(pearRow)
      .exists(
        { count: 1 },
        "equal extra and source values render exactly one option"
      );
    assert
      .dom(pearRow)
      .hasText(extraPear.name, "the first option, from extras, is retained");
    assert
      .dom(pearRow)
      .hasAttribute(
        "aria-disabled",
        "true",
        "the retained extra keeps its disabled setting"
      );
    assert
      .dom("[role='option']")
      .exists(
        { count: 2 },
        "the source duplicate is dropped and the distinct source remains"
      );
    for (const row of findAll(pearRow)) {
      await click(row);
    }
    assert.deepEqual(
      changes,
      [],
      "no option for the duplicate value can be picked"
    );
    await dSelect().select(apple.id);
    assert.strictEqual(
      changes.at(-1)?.[1],
      apple,
      "the distinct enabled source remains pickable"
    );
  });

  test("mixed options yield record config and the actual option", async function (assert) {
    const apple = { id: "apple", name: "Apple" };
    const pear = { id: "pear", name: "Pear" };
    const pearOption = selectOption(pear, {
      disabled: true,
      description: "Not ripe",
    });
    const options = [apple, pearOption];
    const seen = new Map();
    const describe = (record, config, option) => {
      seen.set(record.id, { record, config, option });
      return record.name;
    };

    await render(
      <template>
        <DSelect @options={{options}}>
          <:option as |record config option|>
            <span
              class="fixture__option"
              data-disabled={{if option.disabled "yes" "no"}}
            >
              {{describe record config option}}
            </span>
          </:option>
        </DSelect>
      </template>
    );
    await dSelect().open();

    assert
      .dom(".fixture__option")
      .exists(
        { count: options.length },
        "the renamed block draws every option"
      );
    assert.strictEqual(
      seen.get(apple.id)?.record,
      apple,
      "bare records are yielded unchanged"
    );
    assert.strictEqual(
      seen.get(pear.id)?.record,
      pear,
      "wrapped records are yielded unchanged"
    );
    assert.strictEqual(
      seen.get(pear.id)?.option,
      pearOption,
      "the third parameter is the option itself"
    );
    assert.strictEqual(
      seen.get(apple.id)?.option.record,
      apple,
      "bare input is wrapped for the third parameter"
    );
    assert.true(
      Object.isFrozen(seen.get(pear.id)?.config ?? {}),
      "the second parameter is frozen config"
    );
    assert
      .dom(".fixture__option[data-disabled='yes']")
      .hasText(pear.name, "option settings are readable in the block");
    assert
      .dom(".d-select__option-description")
      .hasText(pearOption.description, "the deliberate description is drawn");
  });

  test("options functions receive config and use configured record fields", async function (assert) {
    const fruits = [
      { code: "apple", label: "Apple" },
      { code: "pear", label: "Pear" },
    ];
    const configs = [];
    const options = (config) => {
      configs.push(config);
      return fruits;
    };
    const changes = [];
    const onChange = (...args) => changes.push(args);

    await render(
      <template>
        <DSelect
          @labelField="label"
          @onChange={{onChange}}
          @options={{options}}
          @valueField="code"
        />
      </template>
    );
    await dSelect().search(fruits[1].label);

    assert
      .dom("[role='option']")
      .exists({ count: 1 }, "filtering reads the record's configured label");
    assert.true(configs.length > 0, "the source function is called");
    assert.true(
      configs.every((config) => Object.isFrozen(config ?? {})),
      "each call receives frozen resolved config"
    );
    if (find(`[role='option'][data-value='${fruits[1].code}']`)) {
      await dSelect().select(fruits[1].code);
    }
    assert.strictEqual(
      changes[0]?.[0],
      fruits[1].code,
      "selection reads the configured value"
    );
    assert.strictEqual(
      changes[0]?.[1],
      fruits[1],
      "the callback gets the source record"
    );
  });

  test("config-shaped options assert instead of being treated as a list", async function (assert) {
    const options = { filterable: true };
    const errors = [];
    setupOnerror((error) => errors.push(error));

    await render(<template><DSelect @options={{options}} /></template>);
    if (find(".d-select")) {
      await dSelect().open();
    }

    assert.true(
      errors.some(
        (error) =>
          /Assertion Failed:/.test(error.message) &&
          /@options/.test(error.message)
      ),
      "the development assertion identifies the miswired list argument"
    );
  });

  test("single selection resolves wrapped options to the original record", async function (assert) {
    const fruit = { id: "pear", name: "Pear" };
    const options = [selectOption(fruit, { description: "Autumn harvest" })];
    const seen = [];
    const label = (record, config) => {
      seen.push([record, config]);
      return record.name;
    };

    await render(
      <template>
        <DSelect @options={{options}} @value={{fruit.id}} @variant="button">
          <:selection as |record config|><span
              class="fixture__single-selection"
            >{{label record config}}</span></:selection>
        </DSelect>
      </template>
    );

    assert
      .dom(".fixture__single-selection")
      .hasText(fruit.name, "a held value resolves from the option's record");
    assert.strictEqual(
      seen.at(-1)?.[0],
      fruit,
      "the single selection block gets the exact caller record"
    );
    assert.true(
      Object.isFrozen(seen.at(-1)?.[1] ?? {}),
      "the second argument is frozen config"
    );
  });

  test("selection blocks and chips receive records after wrapped picks", async function (assert) {
    const fruits = [
      { id: "apple", name: "Apple" },
      { id: "pear", name: "Pear" },
    ];
    const options = fruits.map((fruit) =>
      selectOption(fruit, { description: `${fruit.name} harvest` })
    );
    const held = tracked([]);
    const seen = new Map();
    const label = (record) => {
      seen.set(record.id, record);
      return record.name;
    };
    const changes = [];
    const onChange = (value, records) => {
      changes.push([value, records]);
      held.value = value;
    };

    await render(
      <template>
        <DSelect
          @multiple={{true}}
          @onChange={{onChange}}
          @options={{options}}
          @value={{held.value}}
        >
          <:selection as |record|><span class="fixture__selection">{{label
                record
              }}</span></:selection>
        </DSelect>
      </template>
    );
    for (const fruit of fruits) {
      await dSelect().select(fruit.id);
    }

    assert.deepEqual(
      changes.at(-1)[0],
      fruits.map((fruit) => fruit.id),
      "the values remain domain ids"
    );
    fruits.forEach((fruit, index) => {
      assert.strictEqual(
        changes.at(-1)[1][index],
        fruit,
        "onChange retains each record identity"
      );
      assert.strictEqual(
        seen.get(fruit.id),
        fruit,
        "selection receives each record identity"
      );
      assert
        .dom(`.d-select__chip[data-value='${fruit.id}'] .fixture__selection`)
        .hasText(fruit.name, "each chip uses the record block");
    });
    assert
      .dom(".d-select__chip .d-select__option-description")
      .doesNotExist("option descriptions do not leak into chips");
  });

  for (const field of [
    "disabled",
    "description",
    "sticky",
    "position",
    "onSelect",
    "__divider",
    "__header",
    "__none",
    "__unresolved",
    "__create",
  ]) {
    test(`bare ${field} data never drives option behaviour`, async function (assert) {
      const actions = [];
      const fields = {
        disabled: true,
        description: "Record metadata",
        sticky: true,
        position: "sticky",
        onSelect: () => actions.push(true),
        __divider: true,
        __header: true,
        __none: true,
        __unresolved: true,
        __create: true,
      };
      const apple = { id: "apple", name: "Apple" };
      const pear = { id: "pear", name: "Pear", [field]: fields[field] };
      const before = { ...pear };
      const options = [apple, pear];
      const held = tracked(null);
      const changes = [];
      const seen = new Map();
      const label = (record, config, option) => {
        seen.set(record.id, { record, option });
        return record.name;
      };
      const onChange = (value, record) => {
        changes.push([value, record]);
        held.value = value;
      };

      await render(
        <template>
          <DSelect
            @onChange={{onChange}}
            @options={{options}}
            @value={{held.value}}
            @variant="button"
          >
            <:option as |record config option|><span
                class="fixture__ordinary"
              >{{label record config option}}</span></:option>
            <:selection as |record|><span
                class="fixture__held"
              >{{record.name}}</span></:selection>
            <:unresolved><span class="fixture__unresolved"></span></:unresolved>
          </DSelect>
        </template>
      );
      await dSelect().open();

      assert.deepEqual(
        findAll("[role='option']").map((row) => row.dataset.value),
        options.map((fruit) => fruit.id),
        "record data cannot hoist or replace ordinary rows"
      );
      const selector = `[role='option'][data-value='${pear.id}']`;
      const row = find(selector);
      assert.dom(selector).exists("the colliding record is an ordinary option");
      assert
        .dom(selector)
        .doesNotHaveAttribute(
          "aria-disabled",
          "record data cannot disable a pick"
        );
      for (const modifier of [
        "--sticky",
        "--action",
        "--none",
        "--create",
        "--unresolved",
      ]) {
        assert
          .dom(selector)
          .doesNotHaveClass(modifier, `${modifier} is not inferred from data`);
      }
      assert
        .dom(".d-select__option-description")
        .doesNotExist("description data is not presentation");
      assert
        .dom(".d-select__divider, .d-select__group-header")
        .doesNotExist("record markers cannot make structural rows");
      const observed = seen.get(pear.id);
      assert.strictEqual(
        observed?.record,
        pear,
        "the block gets the original record"
      );
      for (const key of ["disabled", "action", "none", "create"]) {
        assert.false(
          observed?.option[key],
          `${key} stays false without settings`
        );
      }
      if (row) {
        await dSelect().select(pear.id);
      }

      assert.deepEqual(
        changes.map(([value]) => value),
        [pear.id],
        "the ordinary pick emits its value"
      );
      assert.strictEqual(
        changes[0]?.[1],
        pear,
        "the ordinary pick emits its record"
      );
      assert
        .dom(".fixture__held")
        .hasText(pear.name, "the selection is resolved ordinary data");
      assert
        .dom(".fixture__unresolved")
        .doesNotExist("record markers cannot choose the unresolved block");
      assert.deepEqual(actions, [], "a bare callback field never runs");
      assert.deepEqual(pear, before, "the engine never mutates the record");
    });
  }

  test("disabled settings reject pointer and keyboard while an enabled neighbour selects", async function (assert) {
    const apple = { id: "apple", name: "Apple" };
    const pear = { id: "pear", name: "Pear" };
    const options = [
      selectOption(apple),
      selectOption(pear, { disabled: true }),
    ];
    const changes = [];
    const onChange = (...args) => changes.push(args);

    await render(
      <template>
        <DSelect
          @onChange={{onChange}}
          @options={{options}}
          @variant="static"
        />
      </template>
    );
    await dSelect().open();
    assert
      .dom(`[role='option'][data-value='${pear.id}']`)
      .hasAttribute(
        "aria-disabled",
        "true",
        "the disabled setting reaches ARIA"
      );
    await dSelect().select(pear.id);
    assert.deepEqual(changes, [], "a disabled click emits nothing");
    await triggerKeyEvent("[role='combobox']", "keydown", "End");
    assert
      .dom("[role='option'].--active")
      .hasAttribute(
        "data-value",
        pear.id,
        "keyboard activation targets the disabled option"
      );
    await triggerKeyEvent("[role='combobox']", "keydown", "Enter");
    assert.deepEqual(changes, [], "disabled Enter emits nothing");
    await dSelect().select(apple.id);
    assert.strictEqual(
      changes[0][0],
      apple.id,
      "the enabled neighbour remains pickable"
    );
    assert.strictEqual(
      changes[0][1],
      apple,
      "enabled selection returns a record"
    );
  });

  test("extra action options run on click and Enter with control and original record", async function (assert) {
    const fruit = { id: "browse", name: "Browse fruit" };
    const calls = [];
    const original = selectOption(fruit, {
      onSelect: (control, record) => calls.push([control, record]),
    });
    const projected = { id: fruit.id, name: fruit.name.toUpperCase() };
    const action = selectOption(projected).with(original.settings);
    const apple = { id: "apple", name: "Apple" };
    const extras = [action, apple];
    const extraOptions = () => extras;
    const options = [];
    const changes = [];
    const onChange = (...args) => changes.push(args);

    await render(
      <template>
        <DSelect
          @extraOptions={{extraOptions}}
          @onChange={{onChange}}
          @options={{options}}
          @variant="static"
        >
          <:option as |record config option|><span
              data-action={{if option.action "yes" "no"}}
            >{{record.name}}</span></:option>
        </DSelect>
      </template>
    );
    await dSelect().open();
    assert
      .dom("[role='option']")
      .exists(
        { count: extras.length },
        "extra options mix wrapped options and bare records"
      );
    assert
      .dom("[data-action='yes']")
      .hasText(projected.name, "extra options expose the action flag");
    await dSelect().select(projected.id);
    assert.strictEqual(calls.length, 1, "click runs the action once");
    assert
      .dom("[role='listbox']")
      .exists("action activation keeps the list available");
    await triggerKeyEvent("[role='combobox']", "keydown", "Home");
    await triggerKeyEvent("[role='combobox']", "keydown", "Enter");
    assert.strictEqual(calls.length, 2, "Enter runs the action again");
    for (const [control, record] of calls) {
      assert.strictEqual(
        record,
        fruit,
        "carrying settings retains the callback's record"
      );
      assert.strictEqual(
        typeof control.select,
        "function",
        "the first argument is a control"
      );
      assert.strictEqual(
        control.value,
        null,
        "actions never become held values"
      );
    }
    assert.deepEqual(changes, [], "neither gesture emits onChange");
    await dSelect().select(apple.id);
    assert.strictEqual(
      changes[0][1],
      apple,
      "a bare extra option selects its original record"
    );
  });

  test("sticky settings pin an option ahead of ordinary source options", async function (assert) {
    const apple = { id: "apple", name: "Apple" };
    const pear = { id: "pear", name: "Pear" };
    const options = [
      apple,
      selectOption(pear, { position: "sticky", description: "Pinned fruit" }),
    ];

    await render(<template><DSelect @options={{options}} /></template>);
    await dSelect().open();

    assert.deepEqual(
      findAll("[role='option']").map((row) => row.dataset.value),
      [pear.id, apple.id],
      "the explicitly sticky option is hoisted"
    );
    assert
      .dom(`[role='option'][data-value='${pear.id}']`)
      .hasClass("--sticky", "the sticky option uses the pinned row contract");
    assert
      .dom(`[data-value='${pear.id}'] .d-select__option-description`)
      .hasText(
        options[1].description,
        "the setting's description is retained when hoisted"
      );
  });

  test("paste skips disabled and action options while returning eligible records", async function (assert) {
    const apple = { id: "apple", name: "Apple" };
    const pear = { id: "pear", name: "Pear" };
    const plum = { id: "plum", name: "Plum" };
    const cherry = { id: "cherry", name: "Cherry" };
    const actions = [];
    const options = [
      selectOption(apple),
      selectOption(pear, { disabled: true }),
      selectOption(plum, { onSelect: () => actions.push(true) }),
      cherry,
    ];
    const held = tracked([]);
    const changes = [];
    const onChange = (value, records) => {
      changes.push([value, records]);
      held.value = value;
    };

    await render(
      <template>
        <DSelect
          @multiple={{true}}
          @onChange={{onChange}}
          @options={{options}}
          @value={{held.value}}
        />
      </template>
    );
    await dSelect().open();
    const event = paste(
      [apple, pear, plum, cherry].map((fruit) => fruit.name).join("|")
    );
    await settled();

    const expected = [apple, cherry];
    assert.true(event.defaultPrevented, "the multi-name paste is consumed");
    assert.deepEqual(
      changes.map(([value]) => value),
      [expected.map((fruit) => fruit.id)],
      "only eligible names become values"
    );
    expected.forEach((fruit, index) =>
      assert.strictEqual(
        changes[0][1][index],
        fruit,
        "paste returns the original records"
      )
    );
    assert.deepEqual(actions, [], "matching an action label never runs it");
    assert
      .dom(".d-select__chip")
      .exists({ count: expected.length }, "only eligible records get chips");
  });

  test("noneOption and createOption expose engine flags through the option block", async function (assert) {
    const apple = { id: "apple", name: "Apple" };
    const options = [selectOption(apple)];
    const query = "Kiwi";
    const created = { id: "kiwi", name: query };
    const createOption = () => created;
    const held = tracked(null);
    const changes = [];
    const onChange = (value, record) => {
      changes.push([value, record]);
      held.value = value;
    };

    await render(
      <template>
        <DSelect
          @allowCreate={{true}}
          @createOption={{createOption}}
          @noneOption={{true}}
          @onChange={{onChange}}
          @options={{options}}
          @value={{held.value}}
        >
          <:option as |record config option|><span
              data-create={{if option.create "yes" "no"}}
              data-none={{if option.none "yes" "no"}}
            >{{record.name}}</span></:option>
        </DSelect>
      </template>
    );
    await dSelect().open();
    assert
      .dom("[role='option'].--none")
      .hasAttribute(
        "aria-selected",
        "true",
        "none reads as selected without a held value"
      );
    assert
      .dom("[role='option'].--none [data-none='yes']")
      .exists("the none option is visible to the block");
    await dSelect().select(apple.id);
    await dSelect().open();
    assert
      .dom("[role='option'].--none")
      .hasAttribute(
        "aria-selected",
        "false",
        "holding a record unselects none"
      );
    await click("[role='option'].--none");
    assert.strictEqual(
      changes.at(-1)[0],
      null,
      "picking none clears the value"
    );
    await dSelect().search(query);
    assert
      .dom("[role='option'].--create [data-create='yes']")
      .hasText(
        created.name,
        "the renamed create hook yields an engine create option"
      );
    await dSelect().select(created.id);
    assert.strictEqual(
      changes.at(-1)[0],
      created.id,
      "create selects the builder's value"
    );
    assert.strictEqual(
      changes.at(-1)[1],
      created,
      "create emits the builder's record"
    );
  });

  test("unresolved blocks receive fallback records rather than options", async function (assert) {
    const fruit = { id: "plum", name: "Unavailable plum" };
    const options = [selectOption({ id: "apple", name: "Apple" })];
    const resolveValue = () => undefined;
    const createUnresolvedRecord = () => fruit;
    const seen = [];
    const label = (record, config) => {
      seen.push([record, config]);
      return record.name;
    };

    await render(
      <template>
        <DSelect
          @createUnresolvedRecord={{createUnresolvedRecord}}
          @options={{options}}
          @resolveValue={{resolveValue}}
          @value={{fruit.id}}
          @variant="button"
        >
          <:unresolved as |record config|><span
              class="fixture__fallback"
            >{{label record config}}</span></:unresolved>
        </DSelect>
      </template>
    );

    assert
      .dom(".fixture__fallback")
      .hasText(fruit.name, "the fallback block draws its record label");
    assert.true(seen.length > 0, "the unresolved block is called");
    assert.strictEqual(
      seen.at(-1)[0].id,
      fruit.id,
      "the fallback denotes the held value"
    );
    assert.notStrictEqual(
      seen.at(-1)[0],
      fruit,
      "the engine owns the fallback copy"
    );
    assert.strictEqual(
      seen.at(-1)[0].record,
      undefined,
      "no option wrapper reaches the block"
    );
    assert.true(
      Object.isFrozen(seen.at(-1)[1] ?? {}),
      "the second argument is frozen config"
    );
  });

  test("loader options retain disabled and action settings on arrival", async function (assert) {
    const apple = { id: "apple", name: "Apple" };
    const pear = { id: "pear", name: "Pear" };
    const plum = { id: "plum", name: "Plum" };
    const actions = [];
    const options = [
      apple,
      selectOption(pear, { disabled: true, description: "Not ripe" }),
      selectOption(plum, {
        onSelect: (control, record) => actions.push(record),
      }),
    ];
    const load = async () => ({ options });
    const changes = [];
    const onChange = (...args) => changes.push(args);

    await render(
      <template><DSelect @load={{load}} @onChange={{onChange}} /></template>
    );
    await dSelect().open();

    assert
      .dom("[role='option']")
      .exists(
        { count: options.length },
        "the new loader envelope supplies its options"
      );
    assert
      .dom(`[role='option'][data-value='${pear.id}']`)
      .hasAttribute("aria-disabled", "true", "loading retains disabled");
    assert
      .dom(`[data-value='${pear.id}'] .d-select__option-description`)
      .hasText(options[1].description, "loading retains description");
    await dSelect().select(pear.id);
    assert.deepEqual(
      changes,
      [],
      "the loaded disabled option cannot be picked"
    );
    await dSelect().select(plum.id);
    assert.strictEqual(
      actions[0],
      plum,
      "the loaded action retains its callback record"
    );
    assert.deepEqual(changes, [], "the loaded action emits no value");
    await dSelect().select(apple.id);
    assert.strictEqual(
      changes[0][1],
      apple,
      "a bare loaded record still selects by identity"
    );
  });

  test("disabled retained options stay unpickable while a query resets paging", async function (assert) {
    const fruit = { id: "pear", name: "Pear" };
    const blocked = selectOption(fruit, { disabled: true });
    const options = [
      blocked,
      ...Array.from({ length: 40 }, (_, index) => ({
        id: `pear-${index}`,
        name: `${fruit.name} harvest ${index}`,
      })),
    ];
    const changes = [];
    const onChange = (...args) => changes.push(args);
    let resolveLoad;
    const pending = new Promise((resolve) => (resolveLoad = resolve));
    let retained;
    let requested = false;
    const load = (query) => {
      if (query) {
        retained = find(`[role='option'][data-value='${fruit.id}']`);
        retained?.click();
        requested = true;
        return pending;
      }
      return { options, hasMore: true };
    };

    await render(
      <template>
        <DSelect @debounce={{false}} @load={{load}} @onChange={{onChange}} />
      </template>
    );
    await dSelect().open();
    assert
      .dom(`[role='option'][data-value='${fruit.id}']`)
      .hasAttribute("aria-disabled", "true", "the initial row is disabled");
    const typing = fillIn("[role='combobox']", fruit.name);
    try {
      await waitUntil(() => requested);
      assert.true(
        Boolean(retained),
        "the old disabled row was still on screen during reset"
      );
      assert.strictEqual(
        retained?.getAttribute("aria-disabled"),
        "true",
        "the retained row keeps its disabled presentation"
      );
      assert.deepEqual(changes, [], "clicking the retained row emits nothing");
    } finally {
      resolveLoad({ options: [blocked], hasMore: false });
      await typing;
    }
    await dSelect().select(fruit.id);
    assert.deepEqual(changes, [], "the settled replacement is disabled too");
  });

  test("skeleton replaces each placeholder through the renamed block", async function (assert) {
    let resolveLoad;
    const pending = new Promise((resolve) => (resolveLoad = resolve));
    const load = () => pending;

    await render(
      <template>
        <DSelect @load={{load}}>
          <:skeleton><span class="fixture__skeleton"></span></:skeleton>
        </DSelect>
      </template>
    );
    const opening = dSelect().open();
    try {
      await waitFor(".d-select__skeleton");
      const placeholders = findAll(".d-select__skeleton");
      assert.true(
        placeholders.length > 0,
        "the pending load draws placeholders"
      );
      assert
        .dom(".d-select__skeleton .fixture__skeleton")
        .exists(
          { count: placeholders.length },
          "each placeholder uses the renamed block"
        );
      assert
        .dom(".d-select__skeleton .d-skeleton")
        .doesNotExist("the block replaces the default bars");
    } finally {
      resolveLoad([]);
      await opening;
    }
  });

  test("group builders receive options and may return text or an action option", async function (assert) {
    const apple = { id: "apple", name: "Apple", family: "fruit" };
    const pear = { id: "pear", name: "Pear", family: apple.family };
    const pearOption = selectOption(pear, { disabled: true });
    const options = [apple, pearOption];
    const footer = { id: "browse", name: "Browse fruit" };
    const before = { ...footer };
    const actions = [];
    const footerOption = selectOption(footer, {
      onSelect: (control, record) => actions.push([control, record]),
    });
    const headers = [];
    const footers = [];
    const drawnFooters = [];
    const footerLabel = (record, config, group) => {
      drawnFooters.push([record, config, group]);
      return record.name;
    };
    const groupHeader = (key, entries, config) => {
      headers.push([key, entries, config]);
      return key;
    };
    const groupFooter = (key, entries, config) => {
      footers.push([key, entries, config]);
      return footerOption;
    };
    const changes = [];
    const onChange = (...args) => changes.push(args);

    await render(
      <template>
        <DSelect
          @groupBy="family"
          @groupFooter={{groupFooter}}
          @groupHeader={{groupHeader}}
          @onChange={{onChange}}
          @options={{options}}
        >
          <:groupFooter as |record config group|><span
              class="fixture__footer"
            >{{footerLabel record config group}}</span></:groupFooter>
        </DSelect>
      </template>
    );
    await dSelect().open();

    assert
      .dom(".d-select__group-header")
      .hasText(apple.family, "a string builder return becomes a text boundary");
    assert
      .dom(".fixture__footer")
      .hasText(footer.name, "an option builder return uses the footer block");
    assert.strictEqual(
      drawnFooters.at(-1)?.[0],
      footer,
      "the boundary yields the builder's record without copying it"
    );
    assert.true(
      Object.isFrozen(drawnFooters.at(-1)?.[1] ?? {}),
      "the boundary yields frozen config"
    );
    assert.strictEqual(
      drawnFooters.at(-1)?.[2].key,
      apple.family,
      "group metadata is separate from the record"
    );
    assert.true(
      drawnFooters.at(-1)?.[2].action,
      "group metadata identifies an action boundary"
    );
    for (const calls of [headers, footers]) {
      assert.true(calls.length > 0, "the builder is called");
      const [key, entries, config] = calls.at(-1);
      assert.strictEqual(
        key,
        apple.family,
        "the builder gets the record's group key"
      );
      assert.strictEqual(
        entries.length,
        options.length,
        "the builder sees the group's options"
      );
      assert.strictEqual(
        entries[0].record,
        apple,
        "a bare entry arrives as an option"
      );
      assert.strictEqual(
        entries[1],
        pearOption,
        "the existing option keeps its identity"
      );
      assert.true(
        entries[1].disabled,
        "the builder can read deliberate settings"
      );
      assert.true(
        Object.isFrozen(config ?? {}),
        "the builder receives frozen config"
      );
    }
    await dSelect().select(footer.id);
    assert.strictEqual(actions.length, 1, "the footer's action runs");
    assert.strictEqual(
      actions[0][1],
      footer,
      "the footer callback receives its original record"
    );
    assert.strictEqual(
      typeof actions[0][0].selectMany,
      "function",
      "the footer callback receives a control"
    );
    assert.deepEqual(
      changes,
      [],
      "the footer is an action rather than a selected value"
    );
    assert.deepEqual(
      footer,
      before,
      "building a boundary never stamps group metadata on its record"
    );
  });
});
