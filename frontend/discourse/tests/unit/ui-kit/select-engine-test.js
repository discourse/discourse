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
    test("hides already-selected items in multi-select", function (assert) {
      const { engine } = controlled({ multiple: true, value: [1] });

      const items = engine.buildItems([{ id: 1 }, { id: 2 }]);
      assert.deepEqual(
        items.map((i) => i.id),
        [2],
        "a selected item is filtered out of the list"
      );
    });

    test("appends a create item when allowed and there is no exact match", function (assert) {
      const engine = new SelectEngine({
        allowCreate: true,
        createItem: (filter) => ({ id: filter, name: filter, __create: true }),
      });
      engine.setFilter("new-tag");

      const items = engine.buildItems([{ id: 1, name: "existing" }]);
      assert.true(items.at(-1).__create, "the last item is the create item");
      assert.strictEqual(items.at(-1).name, "new-tag");
    });

    test("does not offer create when an exact match already exists", function (assert) {
      const engine = new SelectEngine({
        allowCreate: true,
        createItem: (filter) => ({ id: filter, __create: true }),
      });
      engine.setFilter("apple");

      const items = engine.buildItems([{ id: 1, name: "apple" }]);
      assert.false(
        items.some((i) => i.__create),
        "no create item when the term already matches an item"
      );
    });

    test("prepends special items", function (assert) {
      const none = { id: null, name: "None", __special: true };
      const engine = new SelectEngine({ specialItems: () => [none] });

      const items = engine.buildItems([{ id: 1 }]);
      assert.true(items[0].__special, "special items lead the list");
      assert.deepEqual(
        items.map((i) => i.id),
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

    test("yields undefined for an unresolvable value", function (assert) {
      assert.strictEqual(
        new SelectEngine().resolveSelection(9),
        undefined,
        "no resolver + no cache → undefined (trigger shows its placeholder)"
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
});
