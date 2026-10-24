import { destroy } from "@ember/destroyable";
import { run as runLoop } from "@ember/runloop";
import { isSettled, settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { INPUT_DELAY } from "discourse/lib/environment";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import LoadFeedbackTracker from "discourse/ui-kit/select/-internals/coordinators/load-feedback";
import SelectAnnouncer from "discourse/ui-kit/select/-internals/coordinators/select-announcer";
import {
  PagedSource,
  SelectState,
} from "discourse/ui-kit/select/-internals/engine/select-sources";
import SelectEngine from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

module(
  "Unit | ui-kit | modify-select-kit bridge | alias edge cases",
  function (hooks) {
    setupTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

    test("aliases work without a kind for content and changes", function (assert) {
      const onChange = sinon.spy();
      withPluginApi((api) => {
        api.modifySelectKit("old-select").appendContent((component) => {
          assert.deepEqual(
            component.pluginApiIdentifiers,
            ["old-select"],
            "the facade exposes aliases without a kind"
          );
          return { id: "legacy", name: "Legacy" };
        });
        api.modifySelectKit("old-select").onChange(onChange);
      });
      const engine = new SelectEngine({ legacyKinds: ["old-select"] });

      assert.deepEqual(
        engine.buildItems([]).map((item) => item.value),
        ["legacy"],
        "content reaches an alias-only select"
      );
      engine.select({ id: "legacy", name: "Legacy" });
      assert.true(
        onChange.calledOnce,
        "the alias-only change callback runs once"
      );
    });

    test("shared callbacks run once per bridge invocation across duplicate names", function (assert) {
      const callbacks = {
        prependContent: sinon.spy(() => ({ id: "pre", name: "Pre" })),
        appendContent: sinon.spy(() => ({ id: "app", name: "App" })),
        replaceContent: sinon.spy((component, items) => items),
        onChange: sinon.spy(),
      };
      withPluginApi((api) => {
        for (const name of ["new-select", "old-select", "older-select"]) {
          const registration = api.modifySelectKit(name);
          for (const [method, callback] of Object.entries(callbacks)) {
            registration[method](callback);
          }
        }
        api.modifySelectKit("older-select").appendContent(() => ({
          id: "older",
          name: "Older",
        }));
      });
      const engine = new SelectEngine({
        kind: "new-select",
        legacyKinds: ["new-select", "old-select", "old-select", "older-select"],
      });
      for (let run = 1; run <= 2; run++) {
        assert.deepEqual(
          engine
            .buildItems([{ id: "core", name: "Core" }])
            .map((item) => item.value),
          ["pre", "core", "app", "older"],
          "shared callbacks preserve the content stages"
        );
        engine.select({ id: run, name: String(run) });
        for (const [method, callback] of Object.entries(callbacks)) {
          assert.strictEqual(
            callback.callCount,
            run,
            `${method} runs once each time`
          );
        }
      }
    });
  }
);

module("Unit | ui-kit | SelectEngine | maximum diagnostics", function (hooks) {
  setupTest(hooks);

  let warnStub;

  hooks.beforeEach(function () {
    warnStub = sinon.stub(console, "warn");
  });

  hooks.afterEach(function () {
    warnStub.restore();
  });

  const capWarnings = () =>
    warnStub
      .getCalls()
      .filter((call) => String(call.args[0]).includes("@maximum={{false}}"));

  test("static caps warn only for invalid numbers, including NaN", function (assert) {
    for (const [maximum, normalized, warnings] of [
      [undefined, null, 0],
      [false, null, 0],
      [1, 1, 0],
      [2.9, 2, 0],
      [Infinity, Infinity, 0],
      [0, null, 1],
      [-1, null, 1],
      [NaN, null, 1],
      [-Infinity, null, 1],
      [0.5, null, 1],
    ]) {
      warnStub.resetHistory();
      const engine = new SelectEngine({ multiple: true, maximum });

      assert.strictEqual(engine.maximum, normalized, `${maximum} normalizes`);
      assert.strictEqual(
        engine.maximum,
        normalized,
        `${maximum} stays normalized`
      );
      assert.strictEqual(
        capWarnings().length,
        warnings,
        `${maximum} warns at most once on repeated reads`
      );
    }
  });

  test("live caps warn on the first invalid value and only once per engine", function (assert) {
    let maximum = 3.9;
    const engine = new SelectEngine({
      multiple: true,
      maximum: 2,
      getMaximum: () => maximum,
    });

    assert.strictEqual(
      engine.maximum,
      3,
      "the live cap overrides the static cap"
    );
    maximum = false;
    assert.strictEqual(engine.maximum, null, "false overrides a static cap");
    maximum = undefined;
    assert.strictEqual(
      engine.maximum,
      2,
      "undefined falls back to the static cap"
    );
    assert.strictEqual(
      capWarnings().length,
      0,
      "valid reads do not consume a warning"
    );

    for (maximum of [NaN, 0, -2, false]) {
      assert.strictEqual(engine.maximum, null, `${maximum} removes the cap`);
      assert.strictEqual(
        capWarnings().length,
        1,
        "later reads never warn again"
      );
    }

    maximum = 4;
    assert.strictEqual(
      engine.maximum,
      4,
      "a valid cap still applies after warning"
    );
    const other = new SelectEngine({ multiple: true, maximum: NaN });
    assert.strictEqual(
      other.maximum,
      null,
      "another engine normalizes independently"
    );
    assert.strictEqual(
      capWarnings().length,
      2,
      "another engine has its own warning"
    );
  });
});

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
      opts.afterChange?.(nextValue);
    },
  });
  // Stands in for the parent writing `@value` without going through the engine.
  const setValue = (next) => (value = next);
  return { engine, changes, setValue };
}

/** A promise with its resolve and reject exposed, so a test controls when work settles. */
function deferred() {
  let resolve, reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
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
    let received;
    const { engine, changes } = controlled();
    engine.activate({
      id: "act",
      onSelect: (control) => {
        ran++;
        received = control;
      },
    });

    assert.strictEqual(ran, 1, "the action callback runs");
    assert.strictEqual(changes.length, 0, "an action item never emits a value");
    assert.strictEqual(
      received,
      engine.control,
      "the callback gets the control handle"
    );
  });

  test("the control does nothing once the engine is destroyed", function (assert) {
    let closes = 0;
    const { engine, changes } = controlled({
      items: [{ id: 1, name: "One" }],
      requestClose: () => closes++,
    });
    const control = engine.control;

    destroy(engine);
    control.select({ id: 1, name: "One" });
    control.close();

    assert.strictEqual(changes.length, 0, "a late select emits nothing");
    assert.strictEqual(closes, 0, "a late close requests nothing");
  });

  // A consumer that turns `@multiple` off can leave an array in `@value`. Single mode reads it
  // without rewriting the parent's value: empty is no value, one id carries over, and more
  // than one is a consumer mistake that asserts in development.
  module("arity flip (multiple → single)", function () {
    const items = [
      { id: 1, name: "One" },
      { id: 2, name: "Two" },
    ];

    function flipped(value) {
      let multiple = true;
      const { engine } = controlled({
        items,
        value,
        getMultiple: () => multiple,
      });
      multiple = false;
      return engine;
    }

    test("an empty held array reads as no value", function (assert) {
      const engine = flipped([]);

      assert.strictEqual(engine.value, null, "the value is null");
      assert.false(engine.hasValue, "nothing counts as selected");
      assert.strictEqual(
        engine.resolveSelection([]),
        undefined,
        "the trigger resolves to its empty state"
      );
    });

    test("a single held value carries over", function (assert) {
      const engine = flipped([2]);

      assert.strictEqual(engine.value, 2, "the value is the held id");
      assert.strictEqual(
        engine.resolveSelection([2])?.name,
        "Two",
        "the trigger resolves the held id, not the array"
      );
    });

    test("several held values assert", function (assert) {
      const engine = flipped([1, 2]);

      assert.throws(
        () => engine.value,
        /single-select/,
        "reading the value asserts"
      );
      assert.throws(
        () => engine.resolveSelection([1, 2]),
        /single-select/,
        "resolving the trigger asserts"
      );
    });
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

    test("prepends a create item when allowed and there is no exact match", function (assert) {
      const engine = new SelectEngine({
        allowCreate: true,
        createItem: (filter) => ({ id: filter, name: filter, __create: true }),
      });
      engine.setFilter("new-tag");

      const items = engine.buildItems([{ id: 1, name: "existing" }]);
      assert.true(items[0].flags.__create, "the first item is the create item");
      assert.strictEqual(items[0].item.name, "new-tag");
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

    test("loadItems delegates to load for a server source, forwarding the signal", async function (assert) {
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
      await Promise.resolve();

      assert.strictEqual(calls[0][0], "q", "load receives the live filter");
      assert.strictEqual(
        calls[0][1].signal,
        controller.signal,
        "load receives the abort signal"
      );
      assert.true(engine.isAsync, "a load source is async");
    });

    // Closing the panel tears down `DAsyncContent`, which aborts the signal it handed to the
    // source. Reopening before that request settles used to hit the in-flight short-circuit and
    // hand back the accumulator — empty, on a first page — as if it were the answer. The consumer
    // resolves on it synchronously and nothing re-asks, so the query is stuck reading "no results"
    // for rows that exist. An abandoned request must not be observable as a settled empty one.
    test("reopening after an aborted in-flight load asks again instead of answering empty", async function (assert) {
      const releases = [];
      const engine = new SelectEngine({
        load: () => new Promise((resolve) => releases.push(resolve)),
      });
      engine.setFilter("q");

      const closing = new AbortController();
      const first = engine.loadItems(engine.loadContext, {
        signal: closing.signal,
      });
      await Promise.resolve();
      assert.strictEqual(
        releases.length,
        1,
        "opening issues the first request"
      );
      assert.strictEqual(
        typeof first?.then,
        "function",
        "the first open waits on that request"
      );

      // The panel closes mid-flight, then reopens before the abort has settled.
      closing.abort();
      const reopened = new AbortController();
      const second = engine.loadItems(engine.loadContext, {
        signal: reopened.signal,
      });
      await Promise.resolve();

      assert.strictEqual(
        releases.length,
        2,
        "reopening issues a fresh request rather than reusing the abandoned one"
      );
      assert.strictEqual(
        typeof second?.then,
        "function",
        "the reopened panel waits on a request instead of being handed an empty list"
      );

      // The abandoned request settling must not win over the live one.
      releases[0]([{ id: 1, name: "Stale" }]);
      releases[1]([{ id: 2, name: "Fresh" }]);

      assert.deepEqual(
        (await second).map((item) => item.id),
        [2],
        "the reopened panel receives the rows its own request returned"
      );
    });

    // The second route to the same dead end, and the one an abort listener cannot reach. `reset()`
    // empties the accumulator but deliberately keeps both keys, so coming BACK to a filter that
    // already settled makes the settled key match the live one again — over rows that were just
    // discarded. The reuse short-circuit then answers `[]` synchronously and nothing re-asks.
    // Reachable by the ordinary typeahead close, which restores the empty filter.
    test("returning to an already-settled filter fetches again instead of answering empty", async function (assert) {
      let calls = 0;
      const engine = new SelectEngine({
        load: () => {
          calls++;
          return Promise.resolve([{ id: 1, name: "One" }]);
        },
      });

      // The panel opens on the empty filter and its first page settles.
      await engine.loadItems(engine.loadContext);
      assert.strictEqual(calls, 1, "opening issues the first request");

      // The reader types, then closes — which restores the empty filter. Both transitions reset
      // the source, so the rows that answered the empty filter are gone.
      engine.setFilter("q");
      engine.setFilter("");

      const rows = await engine.loadItems(engine.loadContext);

      assert.strictEqual(
        calls,
        2,
        "reopening re-asks rather than reusing an accumulator that was emptied"
      );
      assert.deepEqual(
        rows.map((item) => item.id),
        [1],
        "the reopened panel shows rows rather than an empty result"
      );
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
    test("resolves synchronously from `valueItems`", function (assert) {
      const item = { id: 5, name: "Five" };
      const engine = new SelectEngine({ valueItems: item });

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
        valueItems: [{ id: 1, name: "One" }], // resolves synchronously via valueItems
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

  module("in-flight resolve sharing", function () {
    /** A batch resolver whose every call waits on its own deferred, recording ids and signal. */
    function gatedResolver(known) {
      const calls = [];
      const resolveValues = (values, { signal } = {}) => {
        const gate = deferred();
        calls.push({ values, signal, gate });
        signal?.addEventListener("abort", () => gate.reject(signal.reason));
        return gate.promise.then(() =>
          known.filter((item) => values.includes(item.id))
        );
      };
      return { calls, resolveValues };
    }

    const PEOPLE = [
      { id: 1, name: "One" },
      { id: 2, name: "Two" },
      { id: 3, name: "Three" },
    ];

    test("in-flight resolve: concurrent resolves of the same ids fetch once", async function (assert) {
      const { calls, resolveValues } = gatedResolver(PEOPLE);
      const engine = new SelectEngine({ multiple: true, resolveValues });

      const first = engine.resolveSelection([1, 2]);
      const second = engine.resolveSelection([1, 2]);
      calls.forEach((call) => call.gate.resolve());

      assert.deepEqual(
        calls.map((call) => call.values),
        [[1, 2]],
        "the second resolve joins the pending request"
      );
      assert.deepEqual(
        (await first).map((item) => item.name),
        ["One", "Two"]
      );
      assert.deepEqual(
        (await second).map((item) => item.name),
        ["One", "Two"],
        "both callers get the real items"
      );
    });

    test("in-flight resolve: overlapping ids fetch only what is not pending", async function (assert) {
      const { calls, resolveValues } = gatedResolver(PEOPLE);
      const engine = new SelectEngine({ multiple: true, resolveValues });

      const first = engine.resolveSelection([1, 2]);
      const second = engine.resolveSelection([2, 3]);
      calls.forEach((call) => call.gate.resolve());

      assert.deepEqual(
        calls.map((call) => call.values),
        [[1, 2], [3]],
        "id 2 joins the pending request; only id 3 is fetched"
      );
      assert.deepEqual(
        (await first).map((item) => item.name),
        ["One", "Two"]
      );
      assert.deepEqual(
        (await second).map((item) => item.name),
        ["Two", "Three"],
        "the joined and the new results assemble in value order"
      );
    });

    test("in-flight resolve: one caller aborting leaves the request for the other", async function (assert) {
      const { calls, resolveValues } = gatedResolver(PEOPLE);
      const engine = new SelectEngine({ multiple: true, resolveValues });
      const leaving = new AbortController();

      engine.resolveSelection([1, 2], { signal: leaving.signal });
      const staying = engine.resolveSelection([1, 2]);
      leaving.abort();

      assert.strictEqual(calls.length, 1, "one request for both callers");
      assert.false(
        calls[0].signal.aborted,
        "the shared request survives while a caller still waits"
      );

      calls[0].gate.resolve();
      assert.deepEqual(
        (await staying).map((item) => item.name),
        ["One", "Two"],
        "the remaining caller gets the real items"
      );
      await settled();
      assert.deepEqual(
        engine.resolveSelection([1, 2]).map((item) => item.name),
        ["One", "Two"],
        "the cache holds the real items, read synchronously"
      );
    });

    test("in-flight resolve: when every caller aborts, the request aborts and nothing is cached", async function (assert) {
      const { calls, resolveValues } = gatedResolver(PEOPLE);
      const engine = new SelectEngine({ multiple: true, resolveValues });
      const a = new AbortController();
      const b = new AbortController();

      const first = engine.resolveSelection([1, 2], { signal: a.signal });
      const second = engine.resolveSelection([1, 2], { signal: b.signal });
      a.abort();
      b.abort();
      await Promise.allSettled([first, second]);
      await settled();

      assert.true(
        calls[0].signal.aborted,
        "the shared request is aborted once nobody waits"
      );

      const retry = engine.resolveSelection([1, 2]);
      assert.true(
        retry instanceof Promise,
        "an aborted request recorded no fallback, so the ids resolve again"
      );
      assert.strictEqual(calls.length, 2, "the retry is a fresh request");
      calls[1].gate.resolve();
      assert.deepEqual(
        (await retry).map((item) => item.name),
        ["One", "Two"]
      );
    });

    test("in-flight resolve: a failure landing late never replaces a real item", async function (assert) {
      const gate = deferred();
      const engine = new SelectEngine({
        resolveValues: () => gate.promise,
      });
      const picked = { id: 1, name: "Picked" };

      const pending = engine.resolveSelection(1);
      engine.select(picked);
      gate.reject(new Error("offline"));
      await pending;
      await settled();

      assert.strictEqual(
        engine.resolveSelection(1),
        picked,
        "the item picked while the resolve was pending stays"
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

// aria-setsize describes the complete set, never the mounted window, and never the -1
// sentinel (no two engines interpret it alike, and its own AAM tells user agents to
// substitute 1). A source that declares a total is sized by it while its tail loads; a
// source with no total is sized by the rows loaded so far — the ones a reader can reach —
// and "more exists" is carried by the announcements able to say so.
module("Unit | ui-kit | SelectEngine | setSize", function (hooks) {
  setupTest(hooks);

  function rows(count) {
    return Array.from({ length: count }, (_, i) => ({
      id: i + 1,
      name: `Item ${i + 1}`,
    }));
  }

  test("a partially-loaded server source with a declared total is sized by it", async function (assert) {
    const load = () => ({ items: rows(10), total: 900 });
    const engine = new SelectEngine({ load });

    const loaded = await engine.loadItems(engine.loadContext);
    const [first] = engine.buildItems(loaded);

    assert.strictEqual(
      engine.total,
      900,
      "the declared total is still exposed for the result-count announcement"
    );
    assert.strictEqual(
      first.setSize,
      900,
      "the declared total sizes the set while its tail loads"
    );
    assert.strictEqual(
      first.posInSet,
      1,
      "each loaded row still carries its own known position"
    );
  });

  test("a complete server source reports its true setSize", async function (assert) {
    const load = () => ({ items: rows(10), hasMore: false });
    const engine = new SelectEngine({ load });

    const loaded = await engine.loadItems(engine.loadContext);
    const [first] = engine.buildItems(loaded);

    assert.strictEqual(
      first.setSize,
      10,
      "a source that declares it is complete sizes the set to what it holds"
    );
    assert.strictEqual(
      first.posInSet,
      1,
      "positions are stamped from the start"
    );
  });

  test("a client source reports its full, known setSize", async function (assert) {
    const engine = new SelectEngine({ items: rows(300) });

    const loaded = engine.loadItems(engine.loadContext);
    const [first] = engine.buildItems(loaded);

    assert.strictEqual(
      loaded.length,
      300,
      "the whole client list renders — no engine-side render window"
    );
    assert.strictEqual(
      first.setSize,
      300,
      "a client source reports its full, known size"
    );
  });
});

/**
 * A paged source that records the filters it was asked for, so a test can prove a query was
 * genuinely re-fetched rather than served from a stale buffer.
 */
function recordingLoad(rowsFor) {
  const filters = [];
  const load = (filter) => {
    filters.push(filter);
    return Promise.resolve({ items: rowsFor(filter), hasMore: false });
  };
  return { load, filters };
}

const rowsFor = (filter) =>
  filter ? [{ id: `${filter}-a`, name: `${filter} result` }] : [];

module("Unit | ui-kit | SelectEngine | refiltering", function (hooks) {
  setupTest(hooks);

  // Typing forward only ever produces filters the engine has not seen. Deleting walks back
  // through filters it HAS seen, which is what made this reachable: the load key is
  // [filter, nonce, reveal], and resetting for a new query empties the accumulator while
  // leaving the settled-key pointing at a query that key can equal again.
  test("re-fetches a filter that was already loaded once, after deleting back to it", async function (assert) {
    const { load, filters } = recordingLoad(rowsFor);
    const engine = new SelectEngine({ load });

    engine.setFilter("12");
    await engine.loadItems(engine.loadContext);

    engine.setFilter("123");
    await engine.loadItems(engine.loadContext);

    assert.deepEqual(
      filters,
      ["12", "123"],
      "typing forward fetches each new query"
    );

    // Backspace: back to a filter whose key was already settled.
    engine.setFilter("12");
    const items = await engine.loadItems(engine.loadContext);

    assert.deepEqual(
      filters,
      ["12", "123", "12"],
      "deleting back to a previously-loaded query fetches it again"
    );
    assert.deepEqual(
      items.map((item) => item.id),
      ["12-a"],
      "and returns that query's rows rather than the emptied accumulator"
    );
  });

  test("stays correct across several deletions in a row", async function (assert) {
    const { load, filters } = recordingLoad(rowsFor);
    const engine = new SelectEngine({ load });

    for (const filter of ["1", "12", "123"]) {
      engine.setFilter(filter);
      await engine.loadItems(engine.loadContext);
    }

    for (const filter of ["12", "1"]) {
      engine.setFilter(filter);
      const items = await engine.loadItems(engine.loadContext);

      assert.deepEqual(
        items.map((item) => item.id),
        [`${filter}-a`],
        `after deleting back to "${filter}" the rows match the query`
      );
    }

    assert.deepEqual(
      filters,
      ["1", "12", "123", "12", "1"],
      "every deletion re-fetched instead of reusing a settled key"
    );
  });
});

module("Unit | ui-kit | SelectEngine | deferred load start", function (hooks) {
  setupTest(hooks);

  function pagedSource(load) {
    const state = new SelectState();
    const source = new PagedSource({
      resolveLoad: () => load,
      state,
      keyOf: (item) => String(item.id),
    });
    return { source, state };
  }

  test("a new request calls the loader after the current task, not during it", async function (assert) {
    let calls = 0;
    const { source } = pagedSource(() => {
      calls++;
      return [{ id: 1, name: "One" }];
    });

    const rows = source.rows({ signal: new AbortController().signal });
    assert.strictEqual(calls, 0, "the loader is not called synchronously");

    await Promise.resolve();
    assert.strictEqual(calls, 1, "the loader runs once the task yields");
    assert.deepEqual(
      (await rows).map((item) => item.id),
      [1],
      "the deferred request still answers"
    );
  });

  test("a request aborted before it starts never calls the loader", async function (assert) {
    let calls = 0;
    const { source, state } = pagedSource(() => {
      calls++;
      return [{ id: 1, name: "One" }];
    });

    const controller = new AbortController();
    const rows = source.rows({ signal: controller.signal });
    controller.abort();
    await rows;

    assert.strictEqual(calls, 0, "an abandoned request is never sent");
    assert.notStrictEqual(
      state.serverCompletedKey,
      null,
      "the request still reads as over, so nothing stays busy"
    );
    assert.strictEqual(
      state.serverSettledKey,
      null,
      "an unsent request never authorizes reusing the empty accumulator"
    );
  });

  test("a request reset before it starts never calls the loader", async function (assert) {
    let calls = 0;
    const { source, state } = pagedSource(() => {
      calls++;
      return [{ id: 1, name: "One" }];
    });

    const rows = source.rows({ signal: new AbortController().signal });
    source.reset();
    await rows;

    assert.strictEqual(calls, 0, "a superseded request is never sent");
    assert.strictEqual(
      state.serverCompletedKey,
      null,
      "a superseded request stamps no completion"
    );
    assert.strictEqual(
      state.serverSettledKey,
      null,
      "a superseded request stamps no success"
    );
  });

  test("a loader that throws synchronously settles as a failed load", async function (assert) {
    let calls = 0;
    const engine = new SelectEngine({
      load: () => {
        calls++;
        throw new Error("boom");
      },
    });

    let result;
    let threw = false;
    try {
      result = engine.loadItems(engine.loadContext);
    } catch {
      threw = true;
    }

    assert.false(threw, "the throw becomes a rejection");
    await assert.rejects(result, /boom/, "the rejection carries the error");
    assert.false(engine.serverPending, "the failed load reads as finished");

    await engine.loadItems(engine.loadContext).catch(() => {});
    assert.strictEqual(
      calls,
      2,
      "the next load asks again instead of reusing the empty accumulator"
    );
  });

  test("serverQueryPending is true only while a new query is in flight", async function (assert) {
    const engine = new SelectEngine({
      load: (filter, { offset = 0 }) => ({
        items: [{ id: `${filter}-${offset}`, name: "Row" }],
        hasMore: true,
      }),
    });

    await engine.loadItems(engine.loadContext);
    assert.false(
      engine.serverQueryPending,
      "a settled list has no query in flight"
    );

    engine.setFilter("q");
    assert.true(engine.serverQueryPending, "a new filter is a query in flight");

    await engine.loadItems(engine.loadContext);
    assert.false(engine.serverQueryPending, "the query settled");

    engine.revealMore();
    assert.true(engine.serverPending, "the reveal is in flight");
    assert.false(engine.serverQueryPending, "a reveal is not a new query");

    await engine.loadItems(engine.loadContext);
    engine.reload();
    assert.true(engine.serverPending, "the reload is in flight");
    assert.false(engine.serverQueryPending, "a reload is not a new query");
  });

  test("load feedback waits out the filter debounce only for a new query", function (assert) {
    const engine = { serverQueryPending: false };
    const feedback = new LoadFeedbackTracker({
      engine,
      getFilterDebounceDelay: () => INPUT_DELAY,
      getSkeletonCountArg: () => undefined,
    });

    assert.strictEqual(
      feedback._loadFeedbackDelay,
      250,
      "a reveal or reload starts at once, so it is not charged the debounce"
    );

    engine.serverQueryPending = true;
    assert.strictEqual(
      feedback._loadFeedbackDelay,
      250 + INPUT_DELAY,
      "a new query is charged the debounce it waited for"
    );
  });

  test("an immediate reload flags its own query until the next query starts", async function (assert) {
    const engine = new SelectEngine({
      load: (filter) => [{ id: filter || "row", name: "Row" }],
    });
    await engine.loadItems(engine.loadContext);

    assert.false(engine.immediateLoadFeedback, "a settled list is not flagged");

    engine.control.reload({ immediate: true });
    assert.true(
      engine.immediateLoadFeedback,
      "an immediate reload flags its query"
    );

    engine.control.reload();
    assert.false(
      engine.immediateLoadFeedback,
      "a plain reload starts a query of its own, unflagged"
    );

    engine.control.reload({ immediate: true });
    engine.setFilter("q");
    assert.false(
      engine.immediateLoadFeedback,
      "typing starts a new query, which waits as usual"
    );
  });

  test("an immediate reload shows the skeleton without waiting for the delay", function (assert) {
    const engine = {
      immediateLoadFeedback: false,
      serverAwaitingFirstPage: false,
      serverPending: true,
      serverQueryPending: false,
      serverRevealPending: false,
    };
    const feedback = new LoadFeedbackTracker({
      engine,
      getFilterDebounceDelay: () => INPUT_DELAY,
      getSkeletonCountArg: () => undefined,
    });

    assert.false(
      feedback.showingSkeleton,
      "a plain reload keeps the rows until the delay passes"
    );

    engine.immediateLoadFeedback = true;
    assert.true(
      feedback.showingSkeleton,
      "an immediate reload shows it at once"
    );
    assert.false(feedback.retainRowsWhileReloading);

    engine.serverPending = false;
    assert.false(
      feedback.showingSkeleton,
      "the skeleton leaves when the load settles"
    );
  });
});

module("Unit | ui-kit | SelectEngine | async update", function (hooks) {
  setupTest(hooks);

  const A = { id: 1, name: "A" };
  const B = { id: 2, name: "B" };
  const C = { id: 3, name: "C" };

  test("an update is pending until its work settles, and a scope write emits once", async function (assert) {
    const { engine, changes } = controlled({ items: [A, B] });
    const gate = deferred();

    const done = engine.control.update(async (scope) => {
      await gate.promise;
      scope.select(B);
    });

    assert.true(engine.control.pending, "pending while the work runs");
    assert.strictEqual(
      changes.length,
      0,
      "nothing is emitted before the work writes"
    );

    gate.resolve();
    await done;

    assert.false(
      engine.control.pending,
      "no longer pending once the work settles"
    );
    assert.deepEqual(changes, [[2, B]], "the scope write emitted exactly once");
  });

  test("a synchronous work applies its writes without ever becoming pending", function (assert) {
    const { engine, changes } = controlled({ items: [A] });
    let pendingInside;

    engine.control.update((scope) => {
      pendingInside = engine.control.pending;
      scope.select(A);
    });

    assert.false(pendingInside, "never pending, even while the work runs");
    assert.false(engine.control.pending, "not pending afterwards");
    assert.deepEqual(changes, [[1, A]], "the synchronous write still applied");
  });

  test("an update can clear, do nothing, or apply several writes", async function (assert) {
    const single = controlled({ items: [A], value: 1 });
    await single.engine.control.update(async (scope) => scope.clear());
    assert.deepEqual(
      single.changes,
      [[null, null]],
      "a single clear emits null"
    );

    const multi = controlled({ items: [A, B, C], multiple: true, value: [1] });
    await multi.engine.control.update(async (scope) => scope.clear());
    assert.deepEqual(multi.changes.at(-1)[0], [], "a multi clear emits []");

    const idle = controlled({ items: [A], value: 1 });
    await idle.engine.control.update(async () => {});
    assert.strictEqual(idle.changes.length, 0, "an empty work emits nothing");

    const both = controlled({ items: [A, B, C], multiple: true, value: [1] });
    await both.engine.control.update(async (scope) => {
      scope.select(B);
      scope.deselect(A);
    });
    assert.deepEqual(
      both.changes.map(([value]) => value),
      [[1, 2], [2]],
      "two writes in one update apply in order"
    );
  });

  test("two writes still apply when a change customization defers or vetoes", async function (assert) {
    const queued = [];
    let mode = "defer";
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) =>
            spec.change((next) => {
              if (mode === "defer") {
                queued.push(next);
              }
            })
          )
      );
    });

    const deferring = controlled({ items: [A, B, C], multiple: true });
    let writes = 0;
    await deferring.engine.control.update(async (scope) => {
      scope.select(A);
      writes++;
      scope.select(B);
      writes++;
    });
    assert.strictEqual(writes, 2, "the work ran to the end");
    assert.strictEqual(queued.length, 2, "both writes reached the transformer");

    mode = "veto";
    let vetoedScope;
    const vetoing = controlled({ items: [A, B], value: null });
    await vetoing.engine.control.update(async (scope) => {
      vetoedScope = scope;
      scope.select(A);
      assert.true(
        scope.current,
        "a vetoed own write does not read as a parent change"
      );
      scope.select(B);
    });
    assert.strictEqual(vetoing.changes.length, 0, "vetoed writes emit nothing");
    assert.false(vetoedScope.current, "the scope ends with its update");
  });

  test("a rejecting or throwing work ends the update and rejects update() with its reason", async function (assert) {
    const { engine } = controlled({ items: [A], value: 1 });
    const failure = new Error("boom");
    const gate = deferred();

    const rejecting = engine.control.update(async () => {
      await gate.promise;
      throw failure;
    });
    const barrier = engine.resolveSelection(engine.value);
    gate.resolve();

    await assert.rejects(rejecting, /boom/, "update() rejects with the reason");
    assert.false(engine.control.pending, "a rejection ends the update");
    assert.strictEqual(
      await barrier,
      undefined,
      "the display barrier fulfils rather than rejecting"
    );

    await assert.rejects(
      engine.control.update(() => {
        throw failure;
      }),
      /boom/,
      "a synchronous throw rejects update() too"
    );
    assert.false(
      engine.control.pending,
      "a synchronous throw leaves nothing pending"
    );
  });

  test("a newer update supersedes the older one", async function (assert) {
    const { engine, changes } = controlled({ items: [A, B] });
    const first = deferred();
    const second = deferred();
    let firstScope;

    const firstDone = engine.control.update(async (scope) => {
      firstScope = scope;
      await first.promise;
      scope.select(A);
    });
    const secondDone = engine.control.update(async (scope) => {
      await second.promise;
      scope.select(B);
    });

    assert.false(firstScope.current, "the older scope is no longer current");

    first.resolve();
    await firstDone;
    assert.true(
      engine.control.pending,
      "the older work finishing leaves the newer update pending"
    );
    assert.strictEqual(
      changes.length,
      0,
      "the superseded write emitted nothing"
    );

    second.resolve();
    await secondDone;
    assert.deepEqual(changes, [[2, B]], "only the newer update wrote");
  });

  test("every selection intent made outside the update supersedes it at once", async function (assert) {
    const intents = {
      "a pick": (engine) => engine.select(B),
      "a re-pick of the held value": (engine) => engine.select(A),
      "a deselect": (engine) => engine.deselect(A),
      "a clear": (engine) => engine.clear(),
      "a control clear": (engine) => engine.control.clear(),
    };

    for (const [name, act] of Object.entries(intents)) {
      const { engine } = controlled({ items: [A, B], value: 1 });
      const gate = deferred();
      let seen;
      const done = engine.control.update(async (scope) => {
        seen = scope;
        await gate.promise;
      });

      act(engine);

      assert.false(seen.current, `${name} supersedes the update`);
      assert.false(engine.control.pending, `${name} ends the pending state`);
      gate.resolve();
      await done;
    }

    const multi = controlled({ items: [A, B], multiple: true, value: [1, 2] });
    const gate = deferred();
    let multiScope;
    const done = multi.engine.control.update(async (scope) => {
      multiScope = scope;
      await gate.promise;
    });
    multi.engine.deselectLast();
    assert.false(
      multiScope.current,
      "removing the last chip supersedes the update"
    );
    assert.false(
      multi.engine.control.pending,
      "removing the last chip ends the pending state at once"
    );
    gate.resolve();
    await done;

    const empty = controlled({ items: [A] });
    const emptyGate = deferred();
    let emptyScope;
    const emptyDone = empty.engine.control.update(async (scope) => {
      emptyScope = scope;
      await emptyGate.promise;
    });
    empty.engine.control.clear();
    assert.false(
      emptyScope.current,
      "a control clear of an empty select still supersedes"
    );
    assert.strictEqual(empty.changes.length, 0, "and still emits nothing");
    emptyGate.resolve();
    await emptyDone;
  });

  test("a control call made while the update's own change is applied supersedes it", async function (assert) {
    let reentered = false;
    let engineRef;
    const { engine, changes } = controlled({
      items: [A, B, C],
      afterChange: (value) => {
        if (value === 1 && !reentered) {
          reentered = true;
          engineRef.control.select(C);
        }
      },
    });
    engineRef = engine;
    let seen;

    await engine.control.update(async (scope) => {
      seen = scope;
      scope.select(A);
      scope.select(B);
    });

    assert.false(
      seen.current,
      "the reentrant control call superseded the update"
    );
    assert.deepEqual(
      changes.map(([value]) => value),
      [1, 3],
      "the update's later write was refused"
    );
  });

  test("a parent change makes the scope stale, even before any write", async function (assert) {
    const { engine, changes, setValue } = controlled({
      items: [A, B],
      value: 1,
    });
    const gate = deferred();
    let currentAfterParent;

    const done = engine.control.update(async (scope) => {
      await gate.promise;
      currentAfterParent = scope.current;
      scope.select(B);
    });
    setValue(2);
    gate.resolve();
    await done;

    assert.false(currentAfterParent, "the no-write branch can see it is stale");
    assert.strictEqual(changes.length, 0, "a stale scope write emits nothing");

    const multi = controlled({
      items: [A],
      multiple: true,
      value: ["a,b", "c"],
    });
    const multiGate = deferred();
    let multiScope;
    const multiDone = multi.engine.control.update(async (scope) => {
      multiScope = scope;
      await multiGate.promise;
    });
    multi.setValue(["a", "b,c"]);
    assert.false(
      multiScope.current,
      "ids are compared one by one, not as one joined string"
    );
    multiGate.resolve();
    await multiDone;
  });

  test("an update's own deferred change neither supersedes it nor survives a later supersession", async function (assert) {
    const queued = [];
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) =>
            spec.change((next) => {
              queued.push(next);
            })
          )
      );
    });

    const own = controlled({ items: [A, B] });
    const gate = deferred();
    let ownScope;
    const ownDone = own.engine.control.update(async (scope) => {
      ownScope = scope;
      scope.select(A);
      await gate.promise;
    });
    assert.true(ownScope.current, "its own write does not supersede it");
    gate.resolve();
    await ownDone;
    queued.shift()();
    assert.deepEqual(
      own.changes.map(([value]) => value),
      [1],
      "a deferred change commits after a normal end"
    );

    const stale = controlled({ items: [A, B] });
    const staleGate = deferred();
    const staleDone = stale.engine.control.update(async (scope) => {
      scope.select(A);
      await staleGate.promise;
    });
    stale.engine.select(B);
    const [ownNext, manualNext] = queued.splice(0);
    manualNext();
    ownNext();
    staleGate.resolve();
    await staleDone;
    assert.deepEqual(
      stale.changes.map(([value]) => value),
      [2],
      "a superseded update's queued change never overwrites the newer pick"
    );
  });

  test("in a multi-select a manual add drops the async add", async function (assert) {
    const { engine, changes } = controlled({
      items: [A, B, C],
      multiple: true,
      value: [1],
    });
    const gate = deferred();

    const done = engine.control.update(async (scope) => {
      await gate.promise;
      scope.select(C);
    });
    engine.select(B);
    gate.resolve();
    await done;

    assert.deepEqual(
      changes.map(([value]) => value),
      [[1, 2]],
      "only the manual add landed"
    );
  });

  test("destroying the engine releases the display barrier before the work settles", async function (assert) {
    const { engine, changes } = controlled({ items: [A], value: null });
    const gate = deferred();
    let seen;

    const done = engine.control.update(async (scope) => {
      seen = scope;
      await gate.promise;
      scope.select(A);
    });
    const barrier = engine.resolveSelection(engine.value);

    destroy(engine);
    assert.strictEqual(
      await barrier,
      undefined,
      "the barrier fulfils while the work is still blocked"
    );
    assert.false(seen.current, "the scope is dead");

    gate.resolve();
    await done;
    assert.strictEqual(
      changes.length,
      0,
      "a write after destroy emits nothing"
    );
  });

  test("an update keeps writing when the parent declines its change", async function (assert) {
    const emitted = [];
    const engine = new SelectEngine({
      items: [A, B],
      getValue: () => null,
      onChange: (nextValue) => emitted.push(nextValue),
    });

    await engine.control.update(async (scope) => {
      scope.select(A);
      scope.select(B);
    });

    assert.deepEqual(
      emitted,
      [1, 2],
      "a declined change is not mistaken for a parent change"
    );
  });

  test("a locked select ignores direct and control mutations", function (assert) {
    const { engine, changes } = controlled({
      items: [A, B, C],
      multiple: true,
      value: [1, 2],
      getLocked: () => true,
    });

    engine.select(C, { programmatic: true });
    engine.toggle(A);
    engine.deselect(A, { programmatic: true });
    engine.deselectLast();
    engine.clear();
    engine.control.select(C);
    engine.control.deselect(B);
    engine.control.clear();

    assert.strictEqual(changes.length, 0, "a locked select emits no change");
  });

  test("a locked single select ignores direct and control mutations", function (assert) {
    const { engine, changes } = controlled({
      items: [A, B],
      value: 1,
      getLocked: () => true,
    });

    engine.select(B, { programmatic: true });
    engine.control.deselect(A);
    engine.control.clear();

    assert.strictEqual(changes.length, 0, "a locked select emits no change");
  });

  test("a change deferred by a customization does not commit once the select is locked", function (assert) {
    const queued = [];
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) => spec.change((next) => queued.push(next)))
      );
    });

    let locked = false;
    const { engine, changes } = controlled({
      items: [A, B],
      multiple: true,
      getLocked: () => locked,
    });

    engine.select(A, { programmatic: true });
    assert.strictEqual(
      queued.length,
      1,
      "the customization deferred the change"
    );

    locked = true;
    queued[0]();

    assert.strictEqual(
      changes.length,
      0,
      "the deferred change is dropped because the select locked meanwhile"
    );
  });

  test("scope writes are refused while the select is locked", async function (assert) {
    let locked = false;
    const { engine, changes } = controlled({
      items: [A],
      getLocked: () => locked,
    });

    await engine.control.update(async (scope) => {
      locked = true;
      scope.select(A);
    });

    assert.strictEqual(
      changes.length,
      0,
      "a locked select takes no scope write"
    );
  });

  test("a control deselect of an item not held, or a clear of nothing, emits nothing", function (assert) {
    const single = controlled({ items: [A, B], value: 1 });
    single.engine.control.deselect(B);
    assert.strictEqual(
      single.changes.length,
      0,
      "deselecting another item is a no-op"
    );

    single.engine.control.deselect(A);
    assert.deepEqual(
      single.changes,
      [[null, null]],
      "deselecting the held item clears"
    );

    const empty = controlled({ items: [A] });
    empty.engine.control.clear();
    assert.strictEqual(
      empty.changes.length,
      0,
      "clearing nothing emits nothing"
    );
  });

  test("settled() waits for an update's work", async function (assert) {
    const { engine } = controlled({ items: [A] });
    const gate = deferred();

    engine.control.update(async (scope) => {
      await gate.promise;
      scope.select(A);
    });

    assert.false(isSettled(), "unsettled while the work is blocked");
    gate.resolve();
    await settled();
    assert.false(engine.control.pending, "settled once the work ended");
  });
});

module("Unit | ui-kit | SelectEngine | load customizations", function (hooks) {
  setupTest(hooks);

  function clientItems(count) {
    return Array.from({ length: count }, (_, i) => ({
      id: i + 1,
      name: `Item ${i + 1}`,
    }));
  }

  test("a load customization is never consulted for a client source", async function (assert) {
    const spy = sinon.spy((load) => load);
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) => selects.forAll((spec) => spec.load(spy))
      );
    });
    const engine = new SelectEngine({
      items: [
        { id: 1, name: "Apple" },
        { id: 2, name: "Banana" },
      ],
    });

    engine.buildItems(await engine.loadItems(engine.loadContext));
    engine.setFilter("a");
    engine.buildItems(await engine.loadItems(engine.loadContext));
    engine.reload();
    engine.buildItems(await engine.loadItems(engine.loadContext));

    assert.false(spy.called, "the customization never ran");
  });

  test("a load customization runs once per query, never for a reveal", async function (assert) {
    const contexts = [];
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) =>
            spec.load((load, context) => {
              contexts.push(context);
              return load;
            })
          )
      );
    });
    const kind = { scope: "recipe" };
    const instance = { topicId: 7 };
    const engine = new SelectEngine({
      identifier: "load-select",
      kind: "load-kind",
      getKindContext: () => kind,
      getInstanceContext: () => instance,
      load: (_filter, { offset = 0 }) => ({
        items: Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        })),
        hasMore: true,
      }),
    });

    await engine.loadItems(engine.loadContext);
    assert.strictEqual(contexts.length, 1, "the first query consults it");

    engine.revealMore();
    await engine.loadItems(engine.loadContext);
    engine.revealMore();
    await engine.loadItems(engine.loadContext);
    assert.strictEqual(contexts.length, 1, "reveals reuse the query's loader");

    engine.setFilter("Item 1");
    await engine.loadItems(engine.loadContext);
    assert.strictEqual(contexts.length, 2, "a new filter is a new query");
    assert.strictEqual(contexts[1].filter, "Item 1", "with that filter");

    engine.reload();
    await engine.loadItems(engine.loadContext);
    assert.strictEqual(contexts.length, 3, "a reload is a new query");

    const [first] = contexts;
    assert.strictEqual(first.filter, "", "the first query had no filter");
    assert.strictEqual(first.identifier, "load-select", "identifier is passed");
    assert.strictEqual(first.kind, "load-kind", "kind is passed");
    assert.strictEqual(first.kindContext, kind, "kindContext is passed");
    assert.strictEqual(
      first.instanceContext,
      instance,
      "instanceContext is passed"
    );
    assert.strictEqual(first.control, engine.control, "control is passed");
  });

  test("the loader is resolved and called only after the current task", async function (assert) {
    const calls = [];
    const source = new PagedSource({
      resolveLoad: (filter) => {
        calls.push(["resolve", filter]);
        return (query, { offset }) => {
          calls.push(["load", query, offset]);
          return clientItems(2);
        };
      },
      state: new SelectState(),
      keyOf: (item) => String(item.id),
    });
    const rows = source.rows({});
    assert.deepEqual(calls, [], "neither callback runs synchronously");
    await Promise.resolve();
    assert.deepEqual(
      calls,
      [
        ["resolve", ""],
        ["load", "", 0],
      ],
      "both run in order when the task yields"
    );
    assert.deepEqual(
      await rows,
      clientItems(2),
      "the deferred source answers normally"
    );
  });

  test("an abandoned first request does not resolve or claim a loader", async function (assert) {
    let resolutions = 0;
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) =>
            spec.load((load) => {
              resolutions++;
              return load;
            })
          )
      );
    });
    const engine = new SelectEngine({ load: () => clientItems(2) });
    const abort = new AbortController();
    const abandoned = engine.loadItems(engine.loadContext, {
      signal: abort.signal,
    });
    abort.abort();
    await abandoned;
    assert.strictEqual(
      resolutions,
      0,
      "abandoning before the microtask never resolves the loader"
    );
    assert.deepEqual(
      await engine.loadItems(engine.loadContext),
      clientItems(2),
      "the replacement request still loads"
    );
    assert.strictEqual(resolutions, 1, "only the replacement claims a loader");
  });

  test("an in-flight abort keeps the same loader through retry and reveals", async function (assert) {
    let resolutions = 0;
    let release;
    const offsets = [];
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) =>
            spec.load(() => {
              resolutions++;
              const prefix = resolutions;
              return (_filter, { offset }) => {
                offsets.push(offset);
                const page = {
                  items: [{ id: offset + 1, name: `Source ${prefix}` }],
                  hasMore: true,
                };
                return offsets.length === 1
                  ? new Promise((resolve) => {
                      release = () => resolve(page);
                    })
                  : page;
              };
            })
          )
      );
    });
    const engine = new SelectEngine({ load: () => [] });
    const abort = new AbortController();
    const abandoned = engine.loadItems(engine.loadContext, {
      signal: abort.signal,
    });
    await Promise.resolve();
    abort.abort();
    release();
    await abandoned;
    const retry = await engine.loadItems(engine.loadContext);
    assert.strictEqual(
      retry[0].name,
      "Source 1",
      "retry uses the original closure"
    );
    engine.revealMore();
    const revealed = await engine.loadItems(engine.loadContext);
    assert.deepEqual(
      offsets,
      [0, 0, 1],
      "retry starts at zero and reveal advances"
    );
    assert.true(
      revealed.every((item) => item.name === "Source 1"),
      "reveals keep the same source"
    );
    assert.strictEqual(
      resolutions,
      1,
      "an abort after start does not unpin the loader"
    );
    engine.control.reload();
    assert.strictEqual(
      (await engine.loadItems(engine.loadContext))[0].name,
      "Source 2",
      "reload resolves a new closure"
    );
  });

  test("control.reload keeps a pending update and does nothing once destroyed", async function (assert) {
    let release;
    let scope;
    const changes = [];
    const engine = new SelectEngine({
      items: clientItems(2),
      onChange: (value) => changes.push(value),
    });
    const done = engine.control.update(async (currentScope) => {
      scope = currentScope;
      await new Promise((resolve) => {
        release = resolve;
      });
      currentScope.select(clientItems(2)[1]);
    });
    const previous = engine.loadContext;
    engine.control.reload();
    assert.notStrictEqual(
      engine.loadContext,
      previous,
      "reload starts a new query"
    );
    assert.true(scope.current, "reload leaves update authority intact");
    assert.true(engine.control.pending, "the update is still pending");
    assert.false("reload" in scope, "reload is not a selection-scope verb");
    release();
    await done;
    assert.deepEqual(changes, [2], "the update can still select after reload");
    destroy(engine);
    const destroyedContext = engine.loadContext;
    engine.control.reload();
    assert.strictEqual(
      engine.loadContext,
      destroyedContext,
      "a destroyed control cannot start another query"
    );
  });

  test("a load customization must return a function", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) => selects.forAll((spec) => spec.load(() => null))
      );
    });
    const engine = new SelectEngine({ load: () => [] });
    await assert.rejects(
      engine.loadItems(engine.loadContext),
      /load customization must return a function/i,
      "invalid results have a development assertion"
    );
  });
});

module("Unit | ui-kit | SelectEngine | sticky rows", function (hooks) {
  setupTest(hooks);

  const ROWS = [
    { id: 1, name: "Apple", section: "fruit" },
    { id: 2, name: "Beet", section: "vegetable" },
    { id: 3, name: "Cherry", section: "fruit" },
  ];

  function names(descriptors) {
    return descriptors.map((row) => row.item.name ?? row.item.label);
  }

  test("sticky rows are hoisted ahead of the none row and the specials, in order", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) =>
            spec.content((items) => [
              ...items,
              { id: "late", name: "Late action", sticky: true, onSelect() {} },
              { id: "plain", name: "Plain action", onSelect() {} },
            ])
          )
      );
    });
    const engine = new SelectEngine({
      items: [
        ROWS[0],
        { id: "early", name: "Early action", sticky: true, onSelect() {} },
        ROWS[1],
      ],
      noneLabel: "None",
      specialItems: () => [
        { id: "special", name: "Special" },
        { id: "sticky-special", name: "Sticky special", sticky: true },
      ],
    });

    const rows = engine.buildItems(await engine.loadItems(engine.loadContext));

    assert.deepEqual(
      names(rows),
      [
        "Sticky special",
        "Early action",
        "Late action",
        "None",
        "Special",
        "Apple",
        "Beet",
        "Plain action",
      ],
      "sticky rows lead, keeping the order they had in the unhoisted list"
    );
    assert.deepEqual(
      rows.map((row) => row.flags.sticky),
      [true, true, true, false, false, false, false, false],
      "only the hoisted rows are flagged sticky"
    );
  });

  test("sticky rows are never grouped and a sticky header is ignored", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) =>
            spec.content((items) => [
              {
                id: "act",
                name: "Sticky action",
                section: "fruit",
                sticky: true,
              },
              { __header: true, label: "Stray header", sticky: true },
              ...items,
            ])
          )
      );
    });
    const engine = new SelectEngine({
      items: ROWS,
      groupBy: "section",
      groupLabel: (key) => (key === "fruit" ? "Fruit" : "Vegetables"),
    });

    const rows = engine.buildItems(await engine.loadItems(engine.loadContext));
    const sticky = rows.find((row) => row.item.id === "act");

    assert.strictEqual(rows[0], sticky, "the sticky row comes first");
    assert.strictEqual(
      sticky.groupOrdinal,
      undefined,
      "it belongs to no group"
    );
    assert.false(
      rows.some((row) => row.flags.sticky && row.flags.group),
      "a header is never sticky"
    );
  });

  test("sticky rows number from 1 and leave the set size unchanged", async function (assert) {
    let makeSticky = true;
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) =>
            spec.content((items) => [
              ...items,
              { id: "act", name: "Action", sticky: makeSticky, onSelect() {} },
            ])
          )
      );
    });
    const engine = new SelectEngine({ items: ROWS, noneLabel: "None" });

    const stickyRows = engine.buildItems(
      await engine.loadItems(engine.loadContext)
    );
    makeSticky = false;
    const plainRows = engine.buildItems(
      await engine.loadItems(engine.loadContext)
    );

    assert.deepEqual(
      stickyRows.map((row) => row.posInSet),
      [1, 2, 3, 4, 5],
      "positions run contiguously from the sticky row"
    );
    assert.strictEqual(
      stickyRows[0].setSize,
      plainRows[0].setSize,
      "pinning moves a row without changing the size of the set"
    );
  });
});

module("Unit | ui-kit | SelectEngine | selectMany", function (hooks) {
  setupTest(hooks);

  const A = { id: 1, name: "A" };
  const B = { id: 2, name: "B" };
  const C = { id: 3, name: "C" };

  test("batch filters structural and action rows, caches new items and runs middleware once", function (assert) {
    const middleware = sinon.spy((next) => next());
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) => spec.change(middleware))
      );
    });
    const action = sinon.spy();
    const { engine, changes } = controlled({
      multiple: true,
      value: ["1"],
      maximum: 3,
    });
    engine.control.selectMany([
      A,
      { ...B, disabled: true },
      { ...B, __header: true },
      { ...B, __divider: true },
      { ...B, onSelect: action },
      B,
      { ...B, id: "2" },
      C,
      { id: 4 },
    ]);
    assert.deepEqual(
      changes,
      [
        [
          ["1", 2, 3],
          [B, C],
        ],
      ],
      "one batch with only eligible items"
    );
    assert.strictEqual(middleware.callCount, 1, "one middleware invocation");
    assert.strictEqual(action.callCount, 0, "action rows are skipped");
    assert.strictEqual(engine.resolveSingleSync(2), B, "new items are cached");
    assert.strictEqual(
      engine.resolveSingleSync(3),
      C,
      "every new item is cached"
    );
  });

  test("single select chooses the first new eligible item", function (assert) {
    const { engine, changes } = controlled({ value: 1 });
    engine.selectMany([A, { ...B, disabled: true }, C, B]);
    assert.deepEqual(
      changes,
      [[3, C]],
      "single select emits its first new item only"
    );
  });

  test("locked batches and empty batches emit nothing", function (assert) {
    const { engine, changes } = controlled({
      multiple: true,
      getLocked: () => true,
    });
    engine.selectMany([A, B]);
    assert.strictEqual(changes.length, 0, "locked batches do not emit");
    const empty = controlled({ multiple: true });
    empty.engine.selectMany([]);
    assert.strictEqual(empty.changes.length, 0, "empty batches do not emit");
  });

  test("fully capped batches supersede pending work before truncation", async function (assert) {
    const { engine, changes } = controlled({
      multiple: true,
      value: [1],
      maximum: 1,
    });
    const gate = deferred();
    let scope;
    const done = engine.control.update(async (current) => {
      scope = current;
      await gate.promise;
      current.clear();
    });
    try {
      engine.control.selectMany([B, C]);
      assert.false(
        scope.current,
        "even a capped batch revokes the older scope"
      );
    } finally {
      gate.resolve();
      await done;
    }
    assert.strictEqual(changes.length, 0, "the old clear cannot land");
  });

  test("scoped batches retain authority and deferred commits are revoked by a newer batch", async function (assert) {
    const queued = [];
    withPluginApi((api) => {
      api.registerValueTransformer(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) => spec.change((next) => queued.push(next)))
      );
    });
    const own = controlled({ multiple: true });
    await own.engine.control.update((scope) => {
      scope.selectMany([A, B]);
      assert.true(
        scope.current,
        "the batch preserves its scope during middleware"
      );
    });
    queued.shift()();
    assert.deepEqual(
      own.changes.at(-1)[0],
      [1, 2],
      "a normal end preserves the deferred batch"
    );

    const stale = controlled({ multiple: true });
    const gate = deferred();
    const done = stale.engine.control.update(async (scope) => {
      scope.selectMany([A, B]);
      await gate.promise;
    });
    stale.engine.control.selectMany([C]);
    queued.shift()();
    queued.shift()();
    gate.resolve();
    await done;
    assert.deepEqual(
      stale.changes.map(([value]) => value),
      [[3]],
      "a newer batch blocks the old deferred emit"
    );
  });
});

module("Unit | ui-kit | SelectEngine | maxLoaded and cursor", function (hooks) {
  setupTest(hooks);

  const A = { id: 1, name: "One" };
  const B = { id: 2, name: "Two" };
  const C = { id: 3, name: "Three" };

  test("maxLoaded reads the live cap for each query", async function (assert) {
    let maxLoaded = 3;
    const engine = new SelectEngine({
      getMaxLoaded: () => maxLoaded,
      load: () => ({ items: [A, B, C, { id: 4, name: "Four" }] }),
    });

    assert.strictEqual(
      (await engine.loadItems(engine.loadContext)).length,
      3,
      "the live reader caps the first query"
    );
    assert.true(engine.atCapWithMore, "discarded rows produce the hint");

    maxLoaded = undefined;
    engine.reload();
    assert.strictEqual(
      (await engine.loadItems(engine.loadContext)).length,
      4,
      "removing the live cap restores every row on reload"
    );
    assert.false(engine.atCapWithMore, "the uncapped query has no hint");
  });

  test("an uncapped source remains revealable after each page settles", async function (assert) {
    const engine = new SelectEngine({
      load: (_query, { offset = 0 }) => ({
        items: Array.from({ length: 60 }, (_, index) => ({
          id: offset + index,
          name: `Item ${offset + index}`,
        })),
        hasMore: true,
      }),
    });
    for (let index = 0; index < 6; index++) {
      await engine.loadItems(engine.loadContext);
      assert.true(
        engine.canRevealMore,
        "the settled source still has more rows"
      );
      assert.true(engine.revealMore(), "the next page is requested");
      assert.true(engine.serverPending, "the next page is now pending");
      assert.false(engine.canRevealMore, "pending work gates another reveal");
    }
    assert.strictEqual(engine.loadedCount, 360, "all six pages remain loaded");
  });

  test("reset forgets held keys even when the next query returns the same ids", async function (assert) {
    const engine = new SelectEngine({
      load: (query) => [{ id: 1, name: query || "Initial" }],
    });
    await engine.loadItems(engine.loadContext);
    engine.setFilter("Changed");
    let rows = await engine.loadItems(engine.loadContext);
    assert.deepEqual(
      rows,
      [{ id: 1, name: "Changed" }],
      "a new query retains its own row"
    );
    engine.reload();
    rows = await engine.loadItems(engine.loadContext);
    assert.deepEqual(
      rows,
      [{ id: 1, name: "Changed" }],
      "reload also clears held keys"
    );
  });

  test("a superseded response cannot replace the current query's opaque cursor", async function (assert) {
    const gate = deferred();
    const cursor = { after: [1, "opaque"] };
    const cursors = [];
    const engine = new SelectEngine({
      load: (query, opts) => {
        cursors.push(opts.cursor);
        return query ? { items: [B], hasMore: true, cursor } : gate.promise;
      },
    });
    const stale = engine.loadItems(engine.loadContext);
    await Promise.resolve();
    engine.setFilter("current");
    await engine.loadItems(engine.loadContext);
    gate.resolve({ items: [A], hasMore: true, cursor: "stale" });
    await stale;
    engine.revealMore();
    await engine.loadItems(engine.loadContext);
    assert.strictEqual(
      cursors.at(-1),
      cursor,
      "the current cursor keeps its identity"
    );
  });
});

module(
  "Unit | ui-kit | SelectAnnouncer | delayed reveal reports",
  function (hooks) {
    setupTest(hooks);

    const A = { id: 1, name: "One" };
    const B = { id: 2, name: "Two" };

    test("closing after delayed feedback clears the completion debt", async function (assert) {
      const gate = deferred();
      let calls = 0;
      const engine = new SelectEngine({
        load: () =>
          ++calls === 1 ? { items: [A], hasMore: true } : gate.promise,
      });
      const announce = sinon.spy();
      const announcer = new SelectAnnouncer({
        a11y: { announce },
        engine,
        getActiveOptionKey: () => null,
        reannounceActive: () => false,
        getNoResultsLabel: () => undefined,
        getShouldSuppressEntryCount: () => false,
      });
      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      const pending = engine.loadItems(engine.loadContext);
      announcer.announceReveal();
      await settled();
      assert.true(
        announce.calledWith(i18n("d_select.loading_more")),
        "a reveal held beyond the delay announces its start"
      );
      announcer.releaseSession();
      gate.resolve({ items: [B], hasMore: false });
      await pending;
      announcer.announceReveal();
      assert.false(
        announce.calledWith(i18n("d_select.loading_complete")),
        "the interrupted announcement owes no completion"
      );
      destroy(announcer);
    });

    for (const cleanup of ["close", "teardown"]) {
      test(`${cleanup} cancels a delayed reveal report`, async function (assert) {
        const gate = deferred();
        let calls = 0;
        const engine = new SelectEngine({
          load: () =>
            ++calls === 1 ? { items: [A], hasMore: true } : gate.promise,
        });
        const announce = sinon.spy();
        const announcer = new SelectAnnouncer({
          a11y: { announce },
          engine,
          getActiveOptionKey: () => null,
          reannounceActive: () => false,
          getNoResultsLabel: () => undefined,
          getShouldSuppressEntryCount: () => false,
        });
        await engine.loadItems(engine.loadContext);
        engine.revealMore();
        const pending = engine.loadItems(engine.loadContext);
        announcer.announceReveal();
        runLoop(() => {
          if (cleanup === "close") {
            announcer.releaseSession();
          } else {
            destroy(announcer);
          }
        });
        assert.true(
          isSettled(),
          "cleanup cancels the timer rather than waiting it out"
        );
        await settled();
        assert.false(announce.called, "no delayed report survives cleanup");
        gate.resolve({ items: [B], hasMore: false });
        await pending;
        if (cleanup === "close") {
          announcer.announceReveal();
        }
        assert.false(
          announce.calledWith(i18n("d_select.loading_complete")),
          "the interrupted reveal owes no completion"
        );
        destroy(announcer);
      });
    }
  }
);
