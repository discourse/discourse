import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SelectEngine from "discourse/ui-kit/select/select-engine";

// Builds a controlled engine whose value is owned by a local variable that `onChange`
// updates — simulating the parent's @value / @onChange loop. `engine.value` reads the
// live variable, so the engine reflects "the parent" the way it does in a template.
function controlled(opts = {}) {
  let value = opts.value ?? (opts.multiple ? [] : null);
  const changes = [];
  const engine = new SelectEngine({
    ...opts,
    getValue: () => value,
    onChange: (nextValue, selected) => {
      value = nextValue;
      changes.push([nextValue, selected]);
    },
  });
  return { engine, changes };
}

module("Unit | ui-kit | SelectEngine", function (hooks) {
  setupTest(hooks);

  module("single-select (controlled)", function () {
    test("selecting emits (value, item) and the engine reflects it", function (assert) {
      const { engine, changes } = controlled();
      const a = { id: 1, name: "A" };
      const b = { id: 2, name: "B" };

      engine.select(a);
      engine.select(b);

      assert.strictEqual(
        engine.value,
        2,
        "the engine reflects the parent value"
      );
      assert.deepEqual(
        changes.at(-1),
        [2, b],
        "onChange receives the id and the item (not an array)"
      );
    });

    test("closeOnSelect requests close by default", function (assert) {
      let closed = 0;
      const { engine } = controlled({ requestClose: () => closed++ });

      engine.select({ id: 1 });
      assert.strictEqual(closed, 1, "selecting closes a single-select");
    });

    test("value is null with no selection", function (assert) {
      assert.strictEqual(controlled().engine.value, null);
    });

    test("deselect/clear emit null", function (assert) {
      const { engine, changes } = controlled({ value: 5 });
      engine.clear();
      assert.deepEqual(
        changes.at(-1),
        [null, null],
        "clear emits a null value"
      );
    });
  });

  module("multi-select (controlled)", function () {
    test("select appends, toggle deselects; value is an id array", function (assert) {
      const { engine, changes } = controlled({ multiple: true });
      const a = { id: 1 };
      const b = { id: 2 };

      engine.select(a);
      engine.select(b);
      assert.deepEqual([...engine.value], [1, 2], "value is the id array");
      assert.deepEqual(
        changes.at(-1),
        [
          [1, 2],
          [a, b],
        ],
        "onChange receives the id array and the item array"
      );

      engine.toggle(a);
      assert.deepEqual(
        [...engine.value],
        [2],
        "toggling a selected item removes it"
      );
      assert.true(engine.isSelected(b));
      assert.false(engine.isSelected(a));
    });

    test("does not request close on select", function (assert) {
      let closed = 0;
      const { engine } = controlled({
        multiple: true,
        requestClose: () => closed++,
      });

      engine.select({ id: 1 });
      assert.strictEqual(closed, 0, "a multi-select stays open on select");
    });

    test("deselectLast drops the last value; a no-op when empty", function (assert) {
      const { engine, changes } = controlled({
        multiple: true,
        value: [1, 2, 3],
      });
      engine.deselectLast();
      assert.deepEqual(
        changes.at(-1)[0],
        [1, 2],
        "the last selected value is removed"
      );

      const empty = controlled({ multiple: true, value: [] });
      empty.engine.deselectLast();
      assert.strictEqual(
        empty.changes.length,
        0,
        "no change is emitted for an empty selection"
      );
    });
  });

  test("isSelected compares by valueField against the controlled value", function (assert) {
    const single = controlled({ valueField: "slug", value: "x" }).engine;
    assert.true(single.isSelected({ slug: "x", name: "X" }));
    assert.false(single.isSelected({ slug: "y" }));

    const multi = controlled({ multiple: true, value: [1, 2] }).engine;
    assert.true(multi.isSelected({ id: 2 }));
    assert.false(multi.isSelected({ id: 3 }));
  });

  test("activate runs an item's onSelect instead of selecting it", function (assert) {
    let ran = 0;
    const { engine, changes } = controlled();
    engine.activate({ id: "act", onSelect: () => ran++ });

    assert.strictEqual(ran, 1, "the action callback runs");
    assert.strictEqual(changes.length, 0, "an action item never emits a value");
  });

  module("buildItems", function () {
    test("keeps already-selected items in multi-select, flagged selected", function (assert) {
      const { engine } = controlled({ multiple: true, value: [1] });

      const items = engine.buildItems([{ id: 1 }, { id: 2 }]);
      assert.deepEqual(
        items.map((d) => d.value),
        [1, 2],
        "selected items stay in the list (kept, not filtered)"
      );
      assert.true(items[0].flags.selected, "the selected item is flagged");
      assert.false(
        items[1].flags.selected,
        "an unselected item is not flagged"
      );
    });

    test("describeItems normalizes items and reflects __unresolved", function (assert) {
      const engine = new SelectEngine();

      const [normal] = engine.describeItems([{ id: 5, name: "Five" }]);
      assert.strictEqual(normal.value, 5, "value comes from the id field");
      assert.strictEqual(normal.key, "5", "key is the normalized value");
      assert.strictEqual(
        normal.item.name,
        "Five",
        "the raw item passes through"
      );
      assert.false(
        normal.flags.__unresolved,
        "a normal item is not unresolved"
      );

      const [unresolved] = engine.describeItems([
        { id: 9, name: "Nine", __unresolved: true },
      ]);
      assert.true(
        unresolved.flags.__unresolved,
        "an unresolved item's flag is reflected, not hardcoded false"
      );
    });

    test("normalizes each row into a { key, value, item, flags } descriptor", function (assert) {
      const apple = { id: 1, name: "Apple", disabled: true };
      const { engine } = controlled({ value: 2 });

      const [first, second] = engine.buildItems([apple, { id: 2, name: "B" }]);
      assert.strictEqual(first.key, "1", "key is the normalized value");
      assert.strictEqual(first.value, 1, "value is the raw id");
      assert.strictEqual(
        first.item,
        apple,
        "item is the raw model (by identity)"
      );
      assert.false(
        first.flags.selected,
        "an unselected row is not flagged selected"
      );
      assert.true(first.flags.disabled, "disabled is lifted onto flags");
      assert.true(
        second.flags.selected,
        "the row matching @value is flagged selected"
      );
    });

    test("appends a create item when allowed and there is no exact match", function (assert) {
      const engine = new SelectEngine({
        allowCreate: true,
        createItem: (filter) => ({ id: filter, name: filter, __create: true }),
      });
      engine.setFilter("new-tag");

      const items = engine.buildItems([{ id: 1, name: "existing" }]);
      assert.true(
        items.at(-1).flags.__create,
        "the last item is the create item"
      );
      assert.strictEqual(items.at(-1).item.name, "new-tag");
    });

    test("does not offer create when an exact match already exists", function (assert) {
      const engine = new SelectEngine({
        allowCreate: true,
        createItem: (filter) => ({ id: filter, __create: true }),
      });
      engine.setFilter("apple");

      const items = engine.buildItems([{ id: 1, name: "apple" }]);
      assert.false(
        items.some((d) => d.flags.__create),
        "no create item when the term already matches an item"
      );
    });

    test("prepends special items", function (assert) {
      const none = { id: null, name: "None", __special: true };
      const engine = new SelectEngine({ specialItems: () => [none] });

      const items = engine.buildItems([{ id: 1 }]);
      assert.true(items[0].item.__special, "special items lead the list");
      assert.deepEqual(
        items.map((d) => d.value),
        [null, 1]
      );
    });
  });

  module("data source", function () {
    test("loadItems filters a client (items) source by label substring", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple" },
          { id: 2, name: "Banana" },
        ],
      });
      engine.setFilter("ban");

      assert.deepEqual(
        engine.loadItems(engine.loadContext).map((i) => i.id),
        [2],
        "only the matching item is returned, synchronously"
      );
      assert.false(engine.isAsync, "a client source is not async");
    });

    test("loadItems delegates to load for a server source, forwarding the signal", function (assert) {
      const calls = [];
      const engine = new SelectEngine({
        load: (filter, opts) => {
          calls.push([filter, opts]);
          return Promise.resolve([]);
        },
      });
      engine.setFilter("q");

      const controller = new AbortController();
      engine.loadItems(engine.loadContext, { signal: controller.signal });

      assert.strictEqual(calls[0][0], "q", "load receives the live filter");
      assert.strictEqual(
        calls[0][1].signal,
        controller.signal,
        "load receives the abort signal"
      );
      assert.true(engine.isAsync, "a load source is async");
    });

    test("reload changes loadContext identity so DAsyncContent re-fetches", function (assert) {
      const engine = new SelectEngine({ load: () => Promise.resolve([]) });

      const before = engine.loadContext;
      assert.strictEqual(before, engine.loadContext, "stable while unchanged");

      engine.reload();
      assert.notStrictEqual(
        before,
        engine.loadContext,
        "reload() invalidates the context"
      );
    });
  });

  module("selected-value resolution", function () {
    test("resolves synchronously from the `selected` escape hatch", function (assert) {
      const item = { id: 5, name: "Five" };
      const engine = new SelectEngine({ selected: item });

      assert.strictEqual(
        engine.resolveSelection(5),
        item,
        "a known item resolves synchronously (no promise, no skeleton)"
      );
    });

    test("resolves via resolveValue and caches the result", async function (assert) {
      let calls = 0;
      const engine = new SelectEngine({
        resolveValue: (value) => {
          calls++;
          return Promise.resolve({ id: value, name: `n${value}` });
        },
      });

      const pending = engine.resolveSelection(7);
      assert.strictEqual(
        typeof pending?.then,
        "function",
        "an unknown value returns a promise"
      );
      const item = await pending;
      assert.strictEqual(item.name, "n7");

      const again = engine.resolveSelection(7);
      assert.strictEqual(again, item, "a resolved value is cached (sync hit)");
      assert.strictEqual(calls, 1, "resolveValue is not called again");
    });

    test("yields an __unresolved fallback for a held value that cannot resolve", function (assert) {
      const item = new SelectEngine().resolveSelection(9);
      assert.true(
        item.__unresolved,
        "a held id with no resolver becomes a fallback, never undefined"
      );
      assert.strictEqual(
        item.id,
        9,
        "the fallback carries the value on the valueField"
      );
    });

    test("resolves a value from a client items source", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple" },
          { id: 2, name: "Banana" },
        ],
      });
      assert.strictEqual(
        engine.resolveSelection(2)?.name,
        "Banana",
        "a client source resolves a value's item without a fetch"
      );
    });

    test("resolves a value from rows a server source already loaded", async function (assert) {
      let fetches = 0;
      const engine = new SelectEngine({
        load: () =>
          Promise.resolve([
            { id: 1, name: "Apple" },
            { id: 2, name: "Banana" },
          ]),
        resolveValue: (value) => {
          fetches++;
          return Promise.resolve({ id: value, name: "fetched" });
        },
      });

      await engine.loadItems(engine.loadContext);

      assert.strictEqual(
        engine.resolveSelection(2)?.name,
        "Banana",
        "an accumulated row resolves the value without a fetch"
      );
      assert.strictEqual(
        fetches,
        0,
        "no resolveValue request for a row already loaded"
      );
    });

    test("picking an item caches it so the trigger resolves synchronously", function (assert) {
      const { engine } = controlled({ load: () => Promise.resolve([]) });
      const topic = { id: 42, name: "Saved topic" };

      engine.select(topic);
      assert.strictEqual(
        engine.resolveSelection(42),
        topic,
        "the just-picked item resolves from cache (no fetch)"
      );
    });
  });

  module("unresolved fallback & batch resolution", function () {
    test("a rejecting resolveValue yields a fallback, never rejects", async function (assert) {
      const engine = new SelectEngine({
        resolveValue: () => Promise.reject(new Error("403")),
      });

      const item = await engine.resolveSelection(7);
      assert.true(
        item.__unresolved,
        "a rejected resolve degrades to a fallback"
      );
      assert.strictEqual(item.id, 7, "the fallback carries the value");
    });

    test("multi resolves the uncached ids in a single batch call", async function (assert) {
      const calls = [];
      const engine = new SelectEngine({
        multiple: true,
        selected: [{ id: 1, name: "One" }], // resolves synchronously via the escape hatch
        resolveValues: (values) => {
          calls.push(values);
          return Promise.resolve([{ id: 2, name: "Two" }]); // id 3 omitted
        },
      });

      const items = await engine.resolveSelection([1, 2, 3]);
      assert.deepEqual(
        calls,
        [[2, 3]],
        "only the uncached ids are batched, in a single call"
      );
      assert.deepEqual(
        items.map((i) => i.id),
        [1, 2, 3],
        "items come back in the original value order"
      );
      assert.deepEqual(
        items.map((i) => !!i.__unresolved),
        [false, false, true],
        "the omitted id becomes a fallback; the rest resolve"
      );
    });

    test("a rejecting batch makes every uncached id a fallback", async function (assert) {
      const engine = new SelectEngine({
        multiple: true,
        resolveValues: () => Promise.reject(new Error("boom")),
      });

      const items = await engine.resolveSelection([4, 5]);
      assert.true(
        items.every((i) => i.__unresolved),
        "a batch rejection degrades to fallbacks, never rejects"
      );
    });

    test("a transient failure does not strand the value as unavailable", async function (assert) {
      let attempt = 0;
      const engine = new SelectEngine({
        resolveValue: (value) => {
          attempt++;
          return attempt === 1
            ? Promise.reject(new Error("offline"))
            : Promise.resolve({ id: value, name: "Recovered" });
        },
      });

      assert.true(
        (await engine.resolveSelection(7)).__unresolved,
        "the first, failing resolve degrades to a fallback"
      );

      engine.reload();

      assert.strictEqual(
        (await engine.resolveSelection(7)).name,
        "Recovered",
        "reload drops the failed attempt, so it retries instead of stranding"
      );
    });

    test("an item that lands later supersedes an earlier fallback", function (assert) {
      let items = [];
      const engine = new SelectEngine({ items: () => items });

      assert.true(
        engine.resolveSelection(3).__unresolved,
        "an id absent from the list starts as a fallback"
      );

      items = [{ id: 3, name: "Landed" }];
      assert.strictEqual(
        engine.resolveSelection(3)?.name,
        "Landed",
        "the client list is consulted again once it supplies the id"
      );
    });

    test("a synchronously throwing resolveValues yields fallbacks", function (assert) {
      const engine = new SelectEngine({
        multiple: true,
        resolveValues: () => {
          throw new Error("sync boom");
        },
      });

      assert.true(
        engine.resolveSelection([4, 5]).every((i) => i.__unresolved),
        "a synchronous throw degrades to fallbacks instead of escaping"
      );
    });

    test("a synchronously throwing resolveValue yields a fallback", function (assert) {
      const engine = new SelectEngine({
        resolveValue: () => {
          throw new Error("sync boom");
        },
      });

      assert.true(
        engine.resolveSelection(7).__unresolved,
        "a synchronous throw degrades to a fallback instead of escaping"
      );
    });

    test("a single select resolves through resolveValues alone", async function (assert) {
      const calls = [];
      const engine = new SelectEngine({
        resolveValues: (values) => {
          calls.push(values);
          return Promise.resolve([{ id: 7, name: "Seven" }]);
        },
      });

      const item = await engine.resolveSelection(7);
      assert.deepEqual(calls, [[7]], "single resolves as a batch of one");
      assert.strictEqual(
        item.name,
        "Seven",
        "the batch result narrows to the single item"
      );
      assert.false(Array.isArray(item), "single never yields an array");
    });

    test("createUnresolvedItem names the fallback", function (assert) {
      const engine = new SelectEngine({
        createUnresolvedItem: (value) => ({
          id: value,
          name: `Topic #${value}`,
        }),
      });

      const item = engine.resolveSelection(123);
      assert.strictEqual(
        item.name,
        "Topic #123",
        "the hook names the fallback"
      );
      assert.true(
        item.__unresolved,
        "the engine still marks it unresolved, whatever the hook returns"
      );
    });

    test("a custom unresolved fallback without an id is still removable", async function (assert) {
      const { engine, changes } = controlled({
        multiple: true,
        value: [999],
        // Names the fallback but returns NO id/value field of its own.
        createUnresolvedItem: (value) => ({ name: `Topic #${value}` }),
        resolveValues: () => Promise.reject(new Error("nope")),
      });

      const [chip] = await engine.resolveSelection([999]);
      assert.true(
        chip.__unresolved,
        "the held id becomes an unresolved fallback"
      );
      assert.strictEqual(
        chip.name,
        "Topic #999",
        "the builder's label is kept"
      );

      // The engine stamps the held value onto the fallback, so its descriptor keys on
      // the value (not a positional __row key) and deselect can find it.
      const [descriptor] = engine.describeItems([chip]);
      assert.strictEqual(
        descriptor.value,
        999,
        "the held value is stamped onto the fallback"
      );
      assert.strictEqual(
        descriptor.key,
        "999",
        "the descriptor keys on the value, not the row index"
      );

      engine.deselect(chip);
      assert.deepEqual(
        changes.at(-1)[0],
        [],
        "deselecting the unresolved chip removes its value"
      );
    });

    test("an empty multi value still yields undefined (placeholder)", function (assert) {
      assert.strictEqual(
        new SelectEngine({ multiple: true }).resolveSelection([]),
        undefined,
        "empty multi → undefined so the trigger shows its placeholder"
      );
    });
  });

  module("value equality (string vs number ids)", function () {
    test("matches a string value against a numeric id and vice-versa", function (assert) {
      const single = controlled({ value: "2" }).engine;
      assert.true(
        single.isSelected({ id: 2 }),
        "string '2' matches numeric id 2"
      );
      assert.false(
        single.isSelected({ id: 6 }),
        "a different id is not selected"
      );
      assert.false(
        controlled({ value: "5x" }).engine.isSelected({ id: 5 }),
        "a non-numeric string does not over-match"
      );

      const reverse = controlled({ value: 2 }).engine;
      assert.true(
        reverse.isSelected({ id: "2" }),
        "numeric 2 matches string id '2'"
      );
    });

    test("matches mixed-type ids in multi-select and deselects by value", function (assert) {
      const { engine, changes } = controlled({
        multiple: true,
        value: ["1", 2],
      });
      assert.true(
        engine.isSelected({ id: 1 }),
        "string '1' matches numeric id 1"
      );
      assert.true(
        engine.isSelected({ id: 2 }),
        "numeric 2 matches numeric id 2"
      );

      engine.deselect({ id: 1 });
      assert.deepEqual(
        changes.at(-1)[0],
        [2],
        "deselecting id 1 removes the '1' entry regardless of its type"
      );
    });

    test("dedupes repeated ids in the value and before resolving", function (assert) {
      const engine = controlled({ multiple: true, value: [1, 2, 2, 1] }).engine;
      assert.deepEqual(
        [...engine.value],
        [1, 2],
        "value collapses duplicate ids, keeping first-occurrence order"
      );

      const client = new SelectEngine({
        multiple: true,
        items: [
          { id: 1, name: "One" },
          { id: 2, name: "Two" },
        ],
      });
      const resolved = client.resolveSelection([1, 2, 2, 1]);
      assert.deepEqual(
        resolved.map((item) => item.id),
        [1, 2],
        "resolveSelection resolves one item per distinct id (no duplicate chips)"
      );
    });

    test("caches across string/number id forms without refetching", async function (assert) {
      let calls = 0;
      const engine = new SelectEngine({
        resolveValue: () => {
          calls++;
          return Promise.resolve({ id: 5, name: "Five" });
        },
      });

      const item = await engine.resolveSelection("5");
      assert.strictEqual(item.name, "Five");
      assert.strictEqual(
        engine.resolveSelection(5),
        item,
        "the numeric form hits the cache populated by the string form"
      );
      assert.strictEqual(calls, 1, "resolveValue is not called a second time");
    });

    test("resolves a string value against a numeric client id", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple" },
          { id: 2, name: "Banana" },
        ],
      });
      assert.strictEqual(
        engine.resolveSelection("2")?.name,
        "Banana",
        "a string value resolves the numeric-id item"
      );
    });
  });
});
