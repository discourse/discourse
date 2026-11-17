import { createCache, getValue } from "@glimmer/tracking/primitives/cache";
import { trackedObject } from "@ember/reactive/collections";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  isSelectItem,
  ItemDirectory,
  SelectItem,
} from "discourse/ui-kit/select/-internals/engine/select-item";
import {
  entryRecord,
  recordOf,
  selectOption,
} from "discourse/ui-kit/select/-internals/engine/select-option";

function createDirectory(record, contributions = {}) {
  const state = {
    record,
    contributions,
    unresolved: false,
    fields: { labelField: "name" },
  };
  const directory = new ItemDirectory({
    fields: () => state.fields,
    valueOf: (entry) => entry.id,
    recordFor: () => ({
      record: state.record,
      unresolved: state.unresolved,
    }),
    contributions: () => state.contributions,
  });
  return { directory, state };
}

module("Unit | ui-kit | select-item", function (hooks) {
  setupTest(hooks);

  test("item identity and branding come from injected sources", function (assert) {
    const record = { id: 0, name: "Authoritative pear", disabled: true };
    const input = selectOption({ id: "copy", name: "View pear" });
    const key = `fruit:${record.id}`;
    const view = { kind: "list", input };
    const calls = [];
    const sources = {
      fields: () => ({ labelField: "name" }),
      valueOf: (entry) => {
        calls.push(["valueOf", entry]);
        return `value:${entry.id}`;
      },
      recordFor: (requestedKey, requestedView) => {
        calls.push(["recordFor", requestedKey, requestedView]);
        return { record, unresolved: false };
      },
      contributions: (requestedKey, requestedView) => {
        calls.push(["contributions", requestedKey, requestedView]);
        return { view: input };
      },
    };
    const item = new ItemDirectory(sources).itemFor(key, view);

    assert.true(
      item instanceof SelectItem,
      "the directory builds a SelectItem"
    );
    assert.strictEqual(item.key, key, "the supplied key is retained");
    assert.strictEqual(
      item.record,
      record,
      "recordFor supplies the shared record"
    );
    assert.strictEqual(
      item.value,
      `value:${record.id}`,
      "valueOf supplies the value"
    );
    assert.false(item.unresolved, "the source's resolved state is retained");
    assert.deepEqual(item.properties, {}, "record fields are not settings");
    assert.false(
      item.disabled,
      "disabled defaults to false even on this record"
    );
    assert.strictEqual(item.action, undefined, "an absent action is undefined");
    assert.true(Object.isFrozen(item), "the item is frozen");
    assert.true(
      Object.isFrozen(item.properties),
      "explicit properties are frozen"
    );
    assert.false(Object.isFrozen(record), "the source record remains mutable");
    assert.true(
      calls.some(([method, entry]) => method === "valueOf" && entry === record),
      "valueOf reads the authoritative record"
    );
    for (const method of ["recordFor", "contributions"]) {
      assert.true(
        calls.some(
          ([name, requestedKey, requestedView]) =>
            name === method && requestedKey === key && requestedView === view
        ),
        `${method} receives the requesting key and view`
      );
    }
    assert.true(isSelectItem(item), "the directory's item carries the brand");
    const lookalike = {
      key: item.key,
      value: item.value,
      record: item.record,
      unresolved: item.unresolved,
      properties: item.properties,
      label: record.name,
      icon: undefined,
      description: undefined,
      disabled: item.disabled,
      action: item.action,
    };
    for (const candidate of [
      record,
      input,
      lookalike,
      Object.create(SelectItem.prototype),
      null,
      undefined,
      key,
    ]) {
      assert.false(isSelectItem(candidate), "only a built item has the brand");
    }
  });

  test("explicit precedence is view then valueRecords then pick then answer", function (assert) {
    const record = { id: "pear", name: "Pear" };
    const tiers = ["view", "valueRecords", "pick", "answer"];
    const contributions = Object.fromEntries(
      tiers.map((tier, index) => [
        tier,
        selectOption(
          { id: record.id, name: tier },
          {
            description: `${tier} description`,
            disabled: index % 2 === 0,
            position: index % 2 === 0 ? "sticky" : "end",
            divider: index % 2 === 0 ? "before" : "after",
            onSelect() {},
          }
        ),
      ])
    );
    const { directory } = createDirectory(record, contributions);
    const view = { kind: "list", input: record };

    for (const tier of tiers) {
      const expected = contributions[tier].settings;
      const item = directory.itemFor(record.id, view);
      assert.deepEqual(
        item.properties,
        expected,
        `${tier} wins every conflict`
      );
      assert.strictEqual(
        item.description,
        expected.description,
        `${tier} describes`
      );
      assert.strictEqual(
        item.disabled,
        expected.disabled,
        `${tier} controls disabled`
      );
      assert.strictEqual(
        item.action,
        expected.onSelect,
        `${tier} supplies the action`
      );
      assert.strictEqual(
        item.record,
        record,
        `${tier} never supplies the shared record`
      );
      delete contributions[tier];
    }

    assert.deepEqual(
      directory.itemFor(record.id, view).properties,
      {},
      "removed contributions leave no accumulated properties"
    );
  });

  test("absent settings never erase lower contributions", function (assert) {
    const record = { id: "plum", name: "Plum" };
    const answer = selectOption(record, { description: "Answer description" });
    const pick = selectOption(record, { disabled: true });
    const valueRecords = selectOption(record, { position: "end" });
    const viewInput = selectOption(record, { divider: "after" });
    const contributions = { view: viewInput, valueRecords, pick, answer };
    const { directory } = createDirectory(record, contributions);
    const view = { kind: "list", input: viewInput };
    const item = directory.itemFor(record.id, view);

    assert.deepEqual(
      item.properties,
      {
        ...answer.settings,
        ...pick.settings,
        ...valueRecords.settings,
        ...viewInput.settings,
      },
      "each tier contributes only its explicit settings"
    );
    contributions.view = record;
    contributions.valueRecords = selectOption(record);
    const bareHigher = directory.itemFor(record.id, view);
    assert.deepEqual(
      bareHigher.properties,
      { ...answer.settings, ...pick.settings },
      "bare records and empty options do not erase lower properties"
    );
    assert.true(
      bareHigher.disabled,
      "an empty option's disabled default is not explicit"
    );
  });

  test("with null clears only its own explicit settings", function (assert) {
    const record = { id: "apple", name: "Apple" };
    const lower = selectOption(record, {
      description: "Lower description",
      disabled: true,
      position: "sticky",
      divider: "before",
      onSelect() {},
    });
    const higher = selectOption(
      { ...record },
      {
        description: "Higher description",
        disabled: false,
        position: "end",
        divider: "after",
        onSelect() {},
      }
    );
    const { directory, state } = createDirectory(record, {
      view: higher,
      answer: lower,
    });
    const view = { kind: "list", input: higher };
    const before = directory.itemFor(record.id, view);
    state.contributions.view = higher.with(
      Object.fromEntries(Object.keys(higher.settings).map((key) => [key, null]))
    );
    const after = directory.itemFor(record.id, view);

    assert.deepEqual(
      before.properties,
      higher.settings,
      "higher initially wins"
    );
    assert.deepEqual(
      after.properties,
      lower.settings,
      "every cleared setting falls through"
    );
    assert.strictEqual(
      after.action,
      lower.settings.onSelect,
      "the lower action survives"
    );
    assert.deepEqual(
      before.properties,
      higher.settings,
      "the old item keeps its snapshot"
    );
    assert.notStrictEqual(
      after,
      before,
      "clearing effective properties creates an item"
    );
  });

  test("presentation derives through live field configuration", function (assert) {
    const record = {
      id: "fig",
      name: "Fig",
      count: 42,
      icon: "seedling",
      details: "Fresh fruit",
      alternateIcon: "leaf",
      alternateDetails: "Dried fruit",
    };
    const { directory, state } = createDirectory(record);
    state.fields = {
      labelField: "name",
      iconField: "icon",
      descriptionField: "details",
    };
    const item = directory.itemFor(record.id, { kind: "held" });

    assert.strictEqual(
      item.label,
      String(record.name),
      "label uses the configured field"
    );
    assert.strictEqual(
      item.icon,
      record.icon,
      "icon uses the configured field"
    );
    assert.strictEqual(
      item.description,
      record.details,
      "description uses the configured field"
    );
    assert.deepEqual(
      item.properties,
      {},
      "derivation does not become explicit properties"
    );
    state.fields = {
      labelField: "count",
      iconField: "alternateIcon",
      descriptionField: "alternateDetails",
    };
    assert.strictEqual(
      item.label,
      String(record.count),
      "the same item reads a new label field as a string"
    );
    assert.strictEqual(
      item.icon,
      record.alternateIcon,
      "the same item reads a new icon field"
    );
    assert.strictEqual(
      item.description,
      record.alternateDetails,
      "the same item reads a new description field"
    );
    state.fields = { labelField: "name" };
    assert.strictEqual(
      item.icon,
      undefined,
      "no icon field means no derived icon"
    );
    assert.strictEqual(
      item.description,
      undefined,
      "no description field means no derived description"
    );
  });

  test("explicit descriptions override derivation and empty means none", function (assert) {
    const record = { id: "date", name: "Date", details: "Record description" };
    const answer = selectOption(record, { description: "Answer description" });
    const empty = selectOption(record, { description: "" });
    const { directory, state } = createDirectory(record, { answer });
    state.fields.descriptionField = "details";
    const view = { kind: "held" };

    assert.strictEqual(
      directory.itemFor(record.id, view).description,
      answer.settings.description,
      "an explicit answer beats the record"
    );
    state.contributions.view = empty;
    const suppressed = directory.itemFor(record.id, view);
    assert.strictEqual(
      suppressed.description,
      undefined,
      "empty suppresses lower and derived descriptions"
    );
    assert.strictEqual(
      suppressed.properties.description,
      empty.settings.description,
      "empty remains an explicit property"
    );
    state.contributions.view = empty.with({ description: null });
    assert.strictEqual(
      directory.itemFor(record.id, view).description,
      answer.settings.description,
      "null reveals the lower explicit description"
    );
    delete state.contributions.answer;
    assert.strictEqual(
      directory.itemFor(record.id, view).description,
      record.details,
      "removing all explicit descriptions reveals derivation"
    );
  });

  test("explicit labels and icons override derivation and empty means none", function (assert) {
    const record = { id: "date", name: "Date", glyph: "calendar" };
    const answer = selectOption(record, {
      label: "Answer label",
      icon: "clock",
    });
    const { directory, state } = createDirectory(record, { answer });
    state.fields.iconField = "glyph";
    const view = { kind: "held" };

    const explicit = directory.itemFor(record.id, view);
    assert.strictEqual(
      explicit.label,
      "Answer label",
      "an explicit label wins"
    );
    assert.strictEqual(explicit.icon, "clock", "an explicit icon wins");

    state.contributions.view = selectOption(record, { label: "", icon: "" });
    const empty = directory.itemFor(record.id, view);
    assert.strictEqual(empty.label, "", "an empty label is shown as empty");
    assert.strictEqual(empty.icon, undefined, "an empty icon means none");

    delete state.contributions.view;
    delete state.contributions.answer;
    const derived = directory.itemFor(record.id, view);
    assert.strictEqual(derived.label, record.name, "the label field derives");
    assert.strictEqual(derived.icon, record.glyph, "the icon field derives");
  });

  test("unresolved items keep fallback labels and suppress derived details", function (assert) {
    const record = { id: "missing", fallbackName: "Missing fruit" };
    const reads = { icon: 0, details: 0 };
    for (const field of Object.keys(reads)) {
      Object.defineProperty(record, field, {
        get() {
          reads[field]++;
          return `fallback ${field}`;
        },
      });
    }
    const { directory, state } = createDirectory(record);
    state.unresolved = true;
    state.fields = {
      labelField: "fallbackName",
      iconField: "icon",
      descriptionField: "details",
    };
    const view = { kind: "held" };
    const item = directory.itemFor(record.id, view);

    assert.true(item.unresolved, "the unresolved source state is exposed");
    assert.strictEqual(
      item.label,
      record.fallbackName,
      "the fallback's configured label is visible"
    );
    assert.strictEqual(item.icon, undefined, "unresolved has no derived icon");
    assert.strictEqual(
      item.description,
      undefined,
      "unresolved has no derived description"
    );
    assert.deepEqual(
      reads,
      { icon: 0, details: 0 },
      "suppressed fields are never read"
    );
    const answer = selectOption(record, { description: "Still resolving" });
    state.contributions.answer = answer;
    const explicit = directory.itemFor(record.id, view);
    assert.true(
      explicit.unresolved,
      "an explicit description does not resolve the item"
    );
    assert.strictEqual(
      explicit.description,
      answer.settings.description,
      "an unresolved item still shows an explicit description"
    );
  });

  test("explicit false enables a lower disabled item", function (assert) {
    const record = { id: "lime", name: "Lime" };
    const lower = selectOption(record, { disabled: true });
    const higher = selectOption(record, { disabled: false });
    const { directory, state } = createDirectory(record, {
      answer: lower,
      view: higher,
    });
    const view = { kind: "held" };
    const enabled = directory.itemFor(record.id, view);

    assert.strictEqual(
      enabled.disabled,
      higher.settings.disabled,
      "false wins by precedence"
    );
    assert.true(
      Object.hasOwn(enabled.properties, "disabled"),
      "false stays explicit"
    );
    state.contributions.view = higher.with({ disabled: null });
    assert.strictEqual(
      directory.itemFor(record.id, view).disabled,
      lower.settings.disabled,
      "clearing false reveals true"
    );
    state.contributions = {};
    assert.false(
      directory.itemFor(record.id, view).disabled,
      "no explicit disabled means false"
    );
  });

  test("the winning action keeps its input record binding", function (assert) {
    const record = { id: "orange", name: "Shared orange" };
    const tiers = ["view", "valueRecords", "pick", "answer"];
    const calls = [];
    const contributions = Object.fromEntries(
      tiers.map((tier) => [
        tier,
        selectOption(
          { id: record.id, name: `${tier} orange` },
          {
            onSelect: (control, inputRecord) =>
              calls.push([tier, control, inputRecord]),
          }
        ),
      ])
    );
    const { directory } = createDirectory(record, contributions);
    const control = { filter: "citrus" };
    const view = { kind: "held" };

    for (const tier of tiers) {
      const input = contributions[tier];
      const item = directory.itemFor(record.id, view);
      assert.strictEqual(
        item.action,
        input.settings.onSelect,
        `${tier} wins without rebinding`
      );
      item.action(control);
      const [calledTier, calledControl, calledRecord] = calls.at(-1);
      assert.strictEqual(calledTier, tier, "only the winning callback runs");
      assert.strictEqual(
        calledControl,
        control,
        "the control is forwarded by identity"
      );
      assert.strictEqual(
        calledRecord,
        input.record,
        "the callback receives its own input's record"
      );
      assert.strictEqual(
        item.record,
        record,
        "the callback's record does not replace the item record"
      );
      delete contributions[tier];
    }
    assert.strictEqual(
      calls.length,
      tiers.length,
      "one action runs per invocation"
    );
    assert.strictEqual(
      directory.itemFor(record.id, view).action,
      undefined,
      "removing every callback removes the action"
    );
  });

  test("equal settings reuse items and changed records replace them in each view", function (assert) {
    const record = { id: "cherry", name: "Cherry" };
    for (const kind of ["list", "held"]) {
      const option = selectOption(record, {
        description: "Stone fruit",
        disabled: false,
      });
      const { directory, state } = createDirectory(record, { view: option });
      const view = { kind, input: option };
      const original = directory.itemFor(record.id, view);
      assert.strictEqual(
        directory.itemFor(record.id, { ...view }),
        original,
        `${kind} reuses an unchanged item`
      );
      const equal = selectOption(record, { ...option.settings });
      state.contributions.view = equal;
      assert.notStrictEqual(
        equal,
        option,
        "the equal-settings option really is new"
      );
      assert.strictEqual(
        directory.itemFor(record.id, { kind, input: equal }),
        original,
        `${kind} compares merged properties rather than option identity`
      );
      state.record = { ...record };
      const replacement = directory.itemFor(record.id, view);
      assert.notStrictEqual(
        replacement,
        original,
        `${kind} notices a new record with equal fields`
      );
      assert.strictEqual(
        replacement.record,
        state.record,
        `${kind} exposes the replacement record`
      );
      assert.strictEqual(
        directory.itemFor(record.id, view),
        replacement,
        `${kind} memoises the replacement`
      );
    }
  });

  test("every contribution is reread before a memo hit", function (assert) {
    const record = { id: "peach", name: "Peach" };
    const tiers = ["view", "valueRecords", "pick", "answer"];
    for (const kind of ["list", "held"]) {
      for (const tier of tiers) {
        const option = selectOption(record, {
          description: `${tier} original`,
        });
        const { directory, state } = createDirectory(record, {
          [tier]: option,
        });
        const view = { kind, input: record };
        const original = directory.itemFor(record.id, view);
        state.contributions[tier] = option.with({
          description: `${tier} changed`,
        });
        const changed = directory.itemFor(record.id, view);
        assert.notStrictEqual(
          changed,
          original,
          `${kind} notices changed ${tier} properties`
        );
        assert.strictEqual(
          changed.description,
          state.contributions[tier].settings.description,
          `${kind} exposes the changed ${tier} property`
        );
        assert.strictEqual(
          original.description,
          option.settings.description,
          "an earlier item's explicit properties remain unchanged"
        );
        delete state.contributions[tier];
        const removed = directory.itemFor(record.id, view);
        assert.notStrictEqual(
          removed,
          changed,
          `${kind} notices removal of ${tier} properties`
        );
        assert.deepEqual(
          removed.properties,
          {},
          "removed settings are not accumulated"
        );
      }
    }
  });

  test("shadowed contribution changes preserve memo identity", function (assert) {
    const record = { id: "apricot", name: "Apricot" };
    const winner = selectOption(record, { description: "View description" });
    const answer = selectOption(record, { description: "Answer description" });
    const { directory, state } = createDirectory(record, {
      view: winner,
      answer,
    });
    const view = { kind: "list", input: winner };
    const original = directory.itemFor(record.id, view);
    state.contributions.answer = answer.with({ description: "Changed answer" });

    assert.strictEqual(
      directory.itemFor(record.id, view),
      original,
      "unchanged merged properties reuse the item despite a changed input"
    );
    delete state.contributions.view;
    const revealed = directory.itemFor(record.id, view);
    assert.notStrictEqual(
      revealed,
      original,
      "removing the winner changes merged properties"
    );
    assert.strictEqual(
      revealed.description,
      state.contributions.answer.settings.description,
      "the newest lower contribution is revealed"
    );
  });

  test("every changed merged setting replaces the memoised item", function (assert) {
    const record = { id: "mango", name: "Mango" };
    const settings = {
      description: "Original description",
      disabled: false,
      position: "sticky",
      divider: "before",
      onSelect() {},
    };
    const changes = {
      description: `${settings.description} changed`,
      disabled: !settings.disabled,
      position: "end",
      divider: "after",
      onSelect() {},
    };
    for (const kind of ["list", "held"]) {
      for (const [setting, value] of Object.entries(changes)) {
        const option = selectOption(record, settings);
        const { directory, state } = createDirectory(record, { view: option });
        const view = { kind, input: option };
        const original = directory.itemFor(record.id, view);
        const changedInput = option.with({ [setting]: value });
        state.contributions.view = changedInput;
        const changed = directory.itemFor(record.id, view);
        assert.notStrictEqual(
          changed,
          original,
          `${kind} notices a change to ${setting} alone`
        );
        assert.strictEqual(
          changed.properties[setting],
          changedInput.settings[setting],
          `${kind} keeps the new ${setting}`
        );
        state.contributions.view = selectOption(record, {
          ...changedInput.settings,
        });
        assert.strictEqual(
          directory.itemFor(record.id, view),
          changed,
          `${kind} reuses equal ${setting} settings on a new option`
        );
      }
    }
  });

  test("list and held have separate memos for the same key", function (assert) {
    const record = { id: "grape", name: "Grape" };
    const { directory } = createDirectory(record);
    const listView = { kind: "list", input: record };
    const heldView = { kind: "held" };
    const list = directory.itemFor(record.id, listView);
    const held = directory.itemFor(record.id, heldView);

    assert.notStrictEqual(list, held, "views never share item identity");
    assert.strictEqual(
      list.record,
      held.record,
      "views still share the key-scope record"
    );
    assert.strictEqual(
      directory.itemFor(record.id, listView),
      list,
      "held lookup does not overwrite the list memo"
    );
    assert.strictEqual(
      directory.itemFor(record.id, heldView),
      held,
      "list lookup does not overwrite the held memo"
    );
  });

  test("pruneList drops only list keys outside keep", function (assert) {
    const records = [
      { id: "kept", name: "Kept fruit" },
      { id: "dropped", name: "Dropped fruit" },
    ];
    const directory = new ItemDirectory({
      fields: () => ({ labelField: "name" }),
      valueOf: (record) => record.id,
      recordFor: (key) => ({
        record: records.find((record) => record.id === key),
        unresolved: false,
      }),
      contributions: () => ({}),
    });
    const before = records.map((record) => ({
      record,
      list: directory.itemFor(record.id, { kind: "list", input: record }),
      held: directory.itemFor(record.id, { kind: "held" }),
    }));
    const keep = new Set([records[0].id]);
    directory.pruneList(keep);

    for (const { record, list, held } of before) {
      const after = directory.itemFor(record.id, {
        kind: "list",
        input: record,
      });
      assert.strictEqual(
        after === list,
        keep.has(record.id),
        "list identity survives exactly for keys in keep"
      );
      assert.strictEqual(
        directory.itemFor(record.id, { kind: "held" }),
        held,
        "held items survive even when their list key is dropped"
      );
    }
    directory.pruneList(new Set());
    assert.notStrictEqual(
      directory.itemFor(records[0].id, { kind: "list", input: records[0] }),
      before[0].list,
      "an empty keep set also drops a formerly kept key"
    );
    assert.deepEqual(
      [...keep],
      [records[0].id],
      "pruning does not mutate the supplied keep set"
    );
  });

  test("building and memoising items never reads presentation fields", function (assert) {
    const values = { name: "Nectarine", icon: "leaf", details: "Smooth skin" };
    const reads = Object.fromEntries(
      Object.keys(values).map((field) => [field, 0])
    );
    const record = { id: "nectarine" };
    const rowRecord = {};
    for (const input of [record, rowRecord]) {
      for (const [field, value] of Object.entries(values)) {
        Object.defineProperty(input, field, {
          get() {
            reads[field]++;
            return value;
          },
        });
      }
    }
    const { directory, state } = createDirectory(record);
    state.fields = {
      labelField: "name",
      iconField: "icon",
      descriptionField: "details",
    };
    const listView = { kind: "list", input: record };
    const list = directory.itemFor(record.id, listView);
    const held = directory.itemFor(record.id, { kind: "held" });
    const row = directory.rowItem(rowRecord);
    assert.strictEqual(
      directory.itemFor(record.id, listView),
      list,
      "a memo lookup also stays lazy"
    );
    const noReads = Object.fromEntries(
      Object.keys(values).map((field) => [field, 0])
    );
    assert.deepEqual(
      reads,
      noReads,
      "building list, held and row items reads no presentation"
    );
    assert.strictEqual(list.label, values.name, "label derives when requested");
    assert.true(reads.name > noReads.name, "reading label reads its field");
    assert.strictEqual(reads.icon, noReads.icon, "label does not read icon");
    assert.strictEqual(
      reads.details,
      noReads.details,
      "label does not read description"
    );
    assert.strictEqual(
      held.icon,
      values.icon,
      "held icon derives when requested"
    );
    assert.true(reads.icon > noReads.icon, "reading icon reads its field");
    assert.strictEqual(
      row.description,
      values.details,
      "row description derives when requested"
    );
    assert.true(
      reads.details > noReads.details,
      "reading description reads its field"
    );
  });

  test("keyless row items use only their own input and memoise it", function (assert) {
    const shared = { id: "unrelated", name: "Shared fruit" };
    const record = {
      name: "Browse fruit",
      icon: "basket-shopping",
      details: "Open catalogue",
    };
    const input = selectOption(record, {
      description: "Own description",
      disabled: false,
      position: "end",
      divider: "before",
      onSelect() {},
    });
    const { directory, state } = createDirectory(shared, {
      view: selectOption(shared, {
        disabled: true,
        description: "Unrelated description",
      }),
    });
    state.unresolved = true;
    state.fields = {
      labelField: "name",
      iconField: "icon",
      descriptionField: "details",
    };
    const item = directory.rowItem(input);

    assert.true(isSelectItem(item), "row items have the item brand");
    assert.strictEqual(item.key, null, "a row input has no key");
    assert.strictEqual(item.record, record, "a row keeps its own input record");
    assert.false(
      item.unresolved,
      "a row is resolved independently of the keyed lookup"
    );
    assert.deepEqual(
      item.properties,
      input.settings,
      "only the row's own settings contribute"
    );
    assert.true(Object.isFrozen(item.properties), "row properties are frozen");
    assert.strictEqual(
      item.description,
      input.settings.description,
      "the row's explicit description wins"
    );
    assert.strictEqual(
      item.disabled,
      input.settings.disabled,
      "keyed disabled settings do not leak into the row"
    );
    assert.strictEqual(
      item.action,
      input.settings.onSelect,
      "the row keeps its own action"
    );
    assert.strictEqual(item.label, record.name, "the row derives its label");
    assert.strictEqual(item.icon, record.icon, "the row derives its icon");
    assert.strictEqual(
      directory.rowItem(input),
      item,
      "the same input reuses its row item"
    );
    const bare = directory.rowItem(record);
    assert.strictEqual(
      bare.record,
      record,
      "bare keyless records are also accepted"
    );
    assert.deepEqual(
      bare.properties,
      {},
      "bare rows have no explicit settings"
    );
    assert.false(bare.unresolved, "bare rows are resolved too");
    assert.strictEqual(bare.key, null, "bare rows are keyless too");
    assert.notStrictEqual(
      bare,
      item,
      "two inputs over one record do not share the row memo"
    );
    assert.strictEqual(
      directory.rowItem(record),
      bare,
      "bare row inputs are memoised too"
    );
  });

  test("a label cache tracks record field changes", function (assert) {
    const record = trackedObject({ id: "lemon", name: "Lemon" });
    const { directory } = createDirectory(record);
    const item = directory.itemFor(record.id, { kind: "held" });
    const computations = [];
    const label = createCache(() => {
      const value = item.label;
      computations.push(value);
      return value;
    });
    const initial = record.name;

    assert.strictEqual(
      getValue(label),
      initial,
      "the cache reads the original label"
    );
    assert.strictEqual(
      getValue(label),
      initial,
      "the unchanged label stays cached"
    );
    assert.deepEqual(
      computations,
      [initial],
      "an unchanged record does not recompute"
    );
    record.name = `${initial} zest`;
    assert.strictEqual(
      getValue(label),
      record.name,
      "changing the tracked field invalidates the label cache"
    );
    assert.deepEqual(
      computations,
      [initial, record.name],
      "the cache actually recomputed after the field change"
    );
    assert.strictEqual(
      directory.itemFor(record.id, { kind: "held" }),
      item,
      "a tracked label change needs no replacement item"
    );
  });

  module("unresolved naming, pruning and unwrapping", function () {
    function directoryOver(state) {
      return new ItemDirectory({
        fields: () => ({ labelField: "name" }),
        valueOf: (record) => record.id,
        recordFor: () => ({
          record: state.record,
          unresolved: state.unresolved,
        }),
        contributions: () => ({}),
        unresolvedLabel: state.unresolvedLabel,
      });
    }

    test("an unresolved item's label follows the engine's fallback naming", function (assert) {
      const state = {
        record: { id: 404, name: "404" },
        unresolved: true,
        unresolvedLabel: (record) => `Unknown item (${record.id})`,
      };
      const item = directoryOver(state).itemFor("404", { kind: "held" });
      assert.strictEqual(
        item.label,
        state.unresolvedLabel(state.record),
        "the default fallback is named by the engine's rule"
      );

      state.unresolvedLabel = () => undefined;
      assert.strictEqual(
        directoryOver(state).itemFor("404", { kind: "held" }).label,
        state.record.name,
        "a fallback the rule does not name keeps its own label"
      );
    });

    test("pruneHeld drops held items outside keep", function (assert) {
      const state = { record: { id: 1, name: "One" }, unresolved: false };
      const directory = directoryOver(state);
      const held = directory.itemFor("1", { kind: "held" });
      const list = directory.itemFor("1", {
        kind: "list",
        input: state.record,
      });

      directory.pruneHeld(new Set(["1"]));
      assert.strictEqual(
        directory.itemFor("1", { kind: "held" }),
        held,
        "a kept key keeps its held item"
      );

      directory.pruneHeld(new Set());
      assert.notStrictEqual(
        directory.itemFor("1", { kind: "held" }),
        held,
        "a dropped key builds a new held item"
      );
      assert.strictEqual(
        directory.itemFor("1", { kind: "list", input: state.record }),
        list,
        "the list memo is left alone"
      );
    });

    test("an item's value follows its record's raw value", function (assert) {
      const state = { record: { id: 7, name: "Seven" }, unresolved: false };
      const directory = directoryOver(state);
      const item = directory.itemFor("7", { kind: "held" });
      state.record.id = "7";

      assert.strictEqual(
        directory.itemFor("7", { kind: "held" }).value,
        "7",
        "a raw value change that keeps the key shows on the item"
      );
      assert.strictEqual(item.value, "7", "the value is read when asked for");
    });

    test("an item stands for its record wherever an entry is accepted", function (assert) {
      const state = { record: { id: 3, name: "Three" }, unresolved: false };
      const item = directoryOver(state).itemFor("3", { kind: "held" });

      assert.strictEqual(
        recordOf(item),
        state.record,
        "recordOf unwraps an item"
      );
      assert.strictEqual(
        entryRecord(item),
        state.record,
        "entryRecord unwraps an item"
      );
      const option = selectOption(item, { description: "Fresh" });
      assert.strictEqual(
        option.record,
        state.record,
        "wrapping an item lists its record"
      );
      assert.deepEqual(
        option.settings,
        { description: "Fresh" },
        "wrapping an item carries only the settings given"
      );
    });
  });
});
