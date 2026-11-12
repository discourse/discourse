import { tracked } from "@glimmer/tracking";
import { destroy } from "@ember/destroyable";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SelectEngine, {
  selectOption,
} from "discourse/ui-kit/select/select-engine";

module("Unit | ui-kit | selectOption", function (hooks) {
  setupTest(hooks);

  let engines;

  hooks.beforeEach(function () {
    engines = [];
  });

  hooks.afterEach(function () {
    engines.forEach((engine) => destroy(engine));
  });

  function createEngine(init = {}) {
    const held = tracked(init.value ?? (init.multiple ? [] : null));
    const changes = [];
    const engine = new SelectEngine({
      ...init,
      getValue: () => held.value,
      onChange: (value, records) => {
        changes.push([value, records]);
        held.value = value;
      },
    });
    engines.push(engine);
    return { engine, changes };
  }

  test("bare options are frozen and keep record identity with inert defaults", function (assert) {
    const fruit = { id: "apple", name: "Apple" };
    const before = { ...fruit };
    const option = selectOption(fruit);

    assert.strictEqual(option.record, fruit, "the record is never copied");
    assert.true(Object.isFrozen(option), "the option is frozen");
    assert.false(
      Object.isFrozen(fruit),
      "wrapping leaves the caller's record mutable"
    );
    for (const key of ["disabled", "action", "create", "none"]) {
      assert.false(option[key], `${key} defaults to false`);
    }
    for (const key of ["description", "position", "divider"]) {
      assert.strictEqual(option[key], undefined, `${key} is absent`);
    }
    assert.deepEqual(option.settings, {}, "no settings are inferred");
    assert.deepEqual(fruit, before, "wrapping does not mutate the record");
  });

  test("settings expose deliberate behaviour and both position and divider values", function (assert) {
    const fruit = { id: "pear", name: "Pear" };
    const settings = {
      disabled: true,
      description: "Ripe fruit",
      position: "sticky",
      divider: "before",
      onSelect() {},
    };
    const option = selectOption(fruit, settings);

    assert.true(option.disabled, "disabled comes from settings");
    assert.true(option.action, "a callback makes an action");
    assert.strictEqual(
      option.description,
      settings.description,
      "description survives"
    );
    assert.strictEqual(option.position, settings.position, "sticky survives");
    assert.strictEqual(option.divider, settings.divider, "before survives");
    for (const key of ["disabled", "description", "position", "divider"]) {
      assert.strictEqual(
        option.settings[key],
        settings[key],
        `${key} is exposed`
      );
    }
    assert.strictEqual(
      typeof option.settings.onSelect,
      "function",
      "the action is exposed"
    );
    const end = option.with({ position: "end", divider: "after" });
    assert.strictEqual(end.position, "end", "end is a supported getter value");
    assert.strictEqual(
      end.divider,
      "after",
      "after is a supported getter value"
    );
  });

  test("with merges settings while undefined preserves and null clears", function (assert) {
    const fruit = { id: "plum", name: "Plum" };
    const settings = {
      disabled: true,
      description: "Stone fruit",
      position: "sticky",
      divider: "before",
      onSelect() {},
    };
    const original = selectOption(fruit, settings);
    const retained = original.with({
      disabled: undefined,
      description: "Purple fruit",
      position: undefined,
      divider: undefined,
      onSelect: undefined,
    });

    assert.notStrictEqual(retained, original, "with returns a new option");
    assert.strictEqual(retained.record, fruit, "with keeps the same record");
    assert.true(Object.isFrozen(retained), "the new option is frozen too");
    assert.true(retained.disabled, "undefined retains disabled");
    assert.true(retained.action, "undefined retains the action");
    assert.strictEqual(
      retained.position,
      settings.position,
      "undefined retains position"
    );
    assert.strictEqual(
      retained.divider,
      settings.divider,
      "undefined retains divider"
    );
    assert.strictEqual(
      retained.description,
      "Purple fruit",
      "a defined setting replaces"
    );
    assert.strictEqual(
      original.description,
      settings.description,
      "the original is unchanged"
    );

    const cleared = retained.with({
      disabled: null,
      description: null,
      position: null,
      divider: null,
      onSelect: null,
    });
    assert.false(cleared.disabled, "null clears disabled");
    assert.false(cleared.action, "null clears the action");
    for (const key of ["description", "position", "divider"]) {
      assert.strictEqual(cleared[key], undefined, `null clears ${key}`);
    }
    assert.true(retained.disabled, "clearing does not enable its source");
    assert.true(
      retained.action,
      "clearing does not remove its source's action"
    );
    assert.strictEqual(
      retained.description,
      "Purple fruit",
      "the source description remains"
    );
    for (const key of ["disabled", "description", "position", "divider"]) {
      assert.strictEqual(
        original[key],
        settings[key],
        `merging never changes the original ${key}`
      );
    }
    assert.strictEqual(
      retained.position,
      settings.position,
      "clearing does not change the retained position"
    );
    assert.strictEqual(
      retained.divider,
      settings.divider,
      "clearing does not change the retained divider"
    );
  });

  test("the factory merges an existing option just like with", function (assert) {
    const fruit = { id: "cherry", name: "Cherry" };
    const original = selectOption(fruit, {
      disabled: true,
      description: "Red",
    });
    const settings = {
      disabled: null,
      description: undefined,
      position: "sticky",
    };
    const expected = original.with(settings);
    const actual = selectOption(original, settings);

    assert.strictEqual(
      actual.record,
      fruit,
      "the factory unwraps a real option"
    );
    assert.deepEqual(
      actual.settings,
      expected.settings,
      "both merge paths agree"
    );
    assert.strictEqual(
      actual.disabled,
      expected.disabled,
      "both clear disabled"
    );
    assert.strictEqual(
      actual.description,
      expected.description,
      "both retain description"
    );
    assert.strictEqual(actual.position, expected.position, "both add position");
    assert.true(original.disabled, "the input option remains unchanged");
  });

  test("lookalikes JSON and forged prototypes remain plain records", function (assert) {
    const fruit = { id: "apple", name: "Apple" };
    const original = selectOption(fruit, { disabled: true });
    const lookalike = { record: fruit, disabled: true };
    const json = JSON.parse(JSON.stringify(lookalike));
    const forged = Object.create(Object.getPrototypeOf(original));

    for (const record of [lookalike, json, forged]) {
      const option = selectOption(record);
      assert.strictEqual(
        option.record,
        record,
        "only branded instances unwrap"
      );
      assert.false(option.disabled, "lookalike fields never become settings");
      assert.false(option.action, "a forged prototype has no behaviour");
    }
  });

  test("carried action settings retain the callback's original record", function (assert) {
    const fruit = { id: "pear", name: "Pear" };
    const projected = { id: fruit.id, name: fruit.name.toUpperCase() };
    const calls = [];
    const { engine, changes } = createEngine();
    const original = selectOption(fruit, {
      onSelect: (control, record) => calls.push([control, record]),
    });
    const carried = selectOption(projected).with(original.settings);
    const carriedAgain = selectOption({ ...projected }).with(carried.settings);

    carriedAgain.settings.onSelect(engine.control, carriedAgain.record);

    assert.strictEqual(calls.length, 1, "the carried callback runs once");
    assert.strictEqual(
      calls[0][0],
      engine.control,
      "the control is passed through"
    );
    assert.strictEqual(
      calls[0][1],
      fruit,
      "repeated carrying cannot rebind the original record"
    );
    assert.deepEqual(changes, [], "calling the action does not select a value");
  });

  test("unknown settings keys assert", function (assert) {
    const fruit = { id: "apple", name: "Apple" };
    const option = selectOption(fruit);
    assert.throws(
      () => selectOption(fruit, { sticky: true }),
      /Assertion Failed:/,
      "the old sticky field is not a settings key"
    );
    assert.throws(
      () => option.with({ sticky: true }),
      /Assertion Failed:/,
      "merging validates settings too"
    );
  });

  test("unknown position and divider values assert", function (assert) {
    const fruit = { id: "apple", name: "Apple" };
    const option = selectOption(fruit);
    for (const settings of [{ position: "middle" }, { divider: "around" }]) {
      assert.throws(
        () => selectOption(fruit, settings),
        /Assertion Failed:/,
        `invalid ${Object.keys(settings)[0]} asserts`
      );
      assert.throws(
        () => option.with(settings),
        /Assertion Failed:/,
        `merging invalid ${Object.keys(settings)[0]} asserts`
      );
    }
  });

  test("primitive records assert", function (assert) {
    const fruit = selectOption({ id: "apple", name: "Apple" }).record;
    for (const record of [fruit.id, 7, null, undefined]) {
      assert.throws(
        () => selectOption(record),
        /Assertion Failed:/,
        `${String(record)} is not an object record`
      );
    }
  });

  test("entry wrapping deduplicates values and retains the first option", async function (assert) {
    const apple = { code: "apple", label: "Apple" };
    const duplicate = { code: apple.code, label: "Another apple" };
    const pear = { code: "pear", label: "Pear" };
    const first = selectOption(apple, {
      disabled: true,
      description: "First harvest",
    });
    const { engine } = createEngine({
      options: [first, duplicate, pear],
      valueField: "code",
      labelField: "label",
    });
    const rows = engine.buildRows(await engine.loadOptions());

    assert.deepEqual(
      rows.map((row) => row.record),
      [apple, pear],
      "one row per non-null value"
    );
    assert.strictEqual(
      rows[0].option,
      first,
      "the first option and its settings win"
    );
    assert.true(rows[0].option.disabled, "a later duplicate cannot enable it");
    assert.strictEqual(
      rows[1].option.record,
      pear,
      "a bare record is wrapped at entry"
    );
    assert.false(rows[1].option.disabled, "the bare record gets no settings");
    assert.strictEqual(
      await engine.resolveSelection(apple.code),
      apple,
      "resolution returns the first record rather than its option"
    );
    assert.strictEqual(
      await engine.resolveSelection(pear.code),
      pear,
      "resolution of a bare input returns its record too"
    );
  });

  test("entry validation accepts a value alone or a label alone", async function (assert) {
    const apple = { code: "apple" };
    const pear = { label: "Pear" };
    const options = [selectOption(apple), pear];
    const { engine } = createEngine({
      options,
      valueField: "code",
      labelField: "label",
    });
    const rows = engine.buildRows(await engine.loadOptions());

    assert.deepEqual(
      rows.map((row) => row.record),
      [apple, pear],
      "only the absence of both fields is invalid"
    );
    assert.strictEqual(
      rows[0].record,
      apple,
      "a value-only record stays intact"
    );
    assert.strictEqual(
      rows[1].record,
      pear,
      "a label-only record stays intact"
    );
  });

  test("listing the same record twice asserts even through different wrappers", function (assert) {
    const fruit = { id: "apple", name: "Apple" };
    const first = selectOption(fruit);
    const second = first.with({ disabled: true });
    for (const init of [
      { options: [fruit, fruit] },
      { options: [first, second] },
      { options: [fruit, second] },
      { options: [first], extraOptions: () => [second] },
    ]) {
      assert.throws(
        () => {
          const { engine } = createEngine(init);
          engine.buildRows(engine.loadOptions());
        },
        /Assertion Failed:/,
        "record identity is checked before value deduplication"
      );
    }
  });

  test("an entry missing both configured fields asserts including a spread option", function (assert) {
    const fruit = { code: "apple", label: "Apple" };
    const option = selectOption(fruit);
    for (const record of [{ unrelated: fruit.code }, { ...option }]) {
      assert.throws(
        () => {
          const { engine } = createEngine({
            options: [record],
            valueField: "code",
            labelField: "label",
          });
          engine.loadOptions();
        },
        /Assertion Failed:/,
        "an option must be unwrapped rather than spread into record data"
      );
    }
  });

  test("a loader returning the old items envelope asserts", async function (assert) {
    const option = selectOption({ id: "apple", name: "Apple" });
    const { engine } = createEngine({
      load: async () => ({ items: [option.record] }),
    });

    await assert.rejects(
      Promise.resolve().then(() => engine.loadOptions()),
      /Assertion Failed:/,
      "the old loader shape is rejected rather than silently emptied"
    );
  });

  test("control select unwraps options and bare records carry no settings", function (assert) {
    const fruit = { id: "apple", name: "Apple", disabled: true, onSelect() {} };
    const option = selectOption(fruit, { disabled: true });
    const { engine, changes } = createEngine({ options: [option] });

    engine.control.select(option);
    assert.deepEqual(
      changes,
      [],
      "passing the disabled option honours its settings"
    );
    engine.control.select(fruit);

    assert.deepEqual(
      changes.map(([value]) => value),
      [fruit.id],
      "explicitly passing a bare record selects it"
    );
    assert.strictEqual(
      changes[0][1],
      fruit,
      "onChange receives the original record"
    );
    const pear = { id: "pear", name: "Pear" };
    engine.control.select(selectOption(pear));
    assert.strictEqual(
      changes.at(-1)[0],
      pear.id,
      "a value option selects its record's value"
    );
    assert.strictEqual(
      changes.at(-1)[1],
      pear,
      "the option never leaks to onChange"
    );
  });

  test("control select rejects action options without running them", function (assert) {
    const calls = [];
    const action = selectOption(
      { id: "browse", name: "Browse fruit" },
      { onSelect: () => calls.push(true) }
    );
    const { engine, changes } = createEngine();

    assert.throws(
      () => engine.control.select(action),
      /Assertion Failed:/,
      "select is not action activation"
    );
    assert.deepEqual(calls, [], "select does not run the callback");
    assert.deepEqual(changes, [], "select does not emit the action's id");
    engine.control.select(action.with({ onSelect: null }));
    assert.strictEqual(
      changes[0][0],
      action.record.id,
      "clearing the action makes a value option"
    );
    assert.strictEqual(
      changes[0][1],
      action.record,
      "the cleared option still emits its record"
    );
    assert.deepEqual(
      calls,
      [],
      "a cleared action never calls its old callback"
    );
  });

  test("control selectMany skips settings but accepts colliding bare record fields", function (assert) {
    const apple = {
      id: "apple",
      name: "Apple",
      disabled: true,
      onSelect() {},
      __header: true,
    };
    const pear = { id: "pear", name: "Pear" };
    const plum = { id: "plum", name: "Plum" };
    const cherry = { id: "cherry", name: "Cherry" };
    const calls = [];
    const { engine, changes } = createEngine({ multiple: true });

    engine.control.selectMany([
      selectOption(pear, { disabled: true }),
      selectOption(plum, { onSelect: () => calls.push(true) }),
      apple,
      selectOption(cherry),
    ]);

    const expected = [apple, cherry];
    assert.deepEqual(
      changes.map(([value]) => value),
      [expected.map((fruit) => fruit.id)],
      "only ordinary options are added in order"
    );
    assert.strictEqual(
      changes[0][1][0],
      apple,
      "the bare colliding record is returned unchanged"
    );
    assert.strictEqual(
      changes[0][1][1],
      cherry,
      "wrapped selections return records too"
    );
    assert.deepEqual(calls, [], "a skipped action never runs");
  });

  test("none and create are engine option kinds rather than record markers", async function (assert) {
    const apple = { id: "apple", name: "Apple" };
    const option = selectOption(apple);
    const created = { id: "kiwi", name: "Kiwi" };
    const before = { ...created };
    const { engine } = createEngine({
      options: [option],
      noneOption: true,
      allowCreate: true,
      createOption: () => selectOption(created),
    });
    const rows = engine.buildRows(await engine.loadOptions());
    const none = rows.find((row) => row.option.none);

    assert.true(Boolean(none), "the engine builds a none option");
    assert.true(
      engine.isSelected(none.option),
      "none is selected when no value is held"
    );
    assert.true(
      Object.isFrozen(none.option),
      "the engine option is frozen too"
    );
    assert.strictEqual(
      engine
        .buildRows(await engine.loadOptions())
        .find((row) => row.option.none).option,
      none.option,
      "the engine reuses its none option"
    );
    engine.control.select(apple);
    assert.false(
      engine.isSelected(none.option),
      "none stops being selected for a held record"
    );
    engine.setFilter(created.name);
    const filtered = engine.buildRows(await engine.loadOptions());
    const create = filtered.find((row) => row.option.create);
    assert.true(Boolean(create), "the engine marks the create option");
    assert.strictEqual(
      create.record,
      created,
      "create preserves the builder's record"
    );
    assert.false(create.option.none, "create and none are distinct kinds");
    assert.deepEqual(created, before, "creation never stamps record fields");
  });

  test("unresolved identity belongs only to the fallback copy and can later resolve", async function (assert) {
    const fruit = { id: "plum", name: "Plum", __unresolved: true };
    const option = selectOption(fruit);
    let available = false;
    const { engine } = createEngine({
      value: fruit.id,
      resolveValue: () => (available ? option.record : undefined),
      createUnresolvedRecord: () => fruit,
    });
    const fallback = await engine.resolveSelection(fruit.id);

    assert.notStrictEqual(
      fallback,
      fruit,
      "only the engine's fallback copy is marked"
    );
    assert.true(
      engine.isUnresolvedRecord(fallback),
      "the failed resolution is unresolved"
    );
    assert.false(
      engine.isUnresolvedRecord(fruit),
      "a field on the source record cannot mark it"
    );
    assert.strictEqual(
      fallback.id,
      fruit.id,
      "the fallback still denotes the held value"
    );
    available = true;
    engine.reload();
    const resolved = await engine.resolveSelection(fruit.id);
    assert.strictEqual(
      resolved,
      fruit,
      "retry returns the resolver's actual record"
    );
    assert.false(
      engine.isUnresolvedRecord(resolved),
      "a real resolution with the same value is not unresolved"
    );
    assert.true(
      engine.isUnresolvedRecord(fallback),
      "the old fallback keeps its own identity"
    );
  });
});
