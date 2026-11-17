import { createCache, getValue } from "@glimmer/tracking/primitives/cache";
import { trackedArray, trackedObject } from "@ember/reactive/collections";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import SelectEngine, {
  selectOption,
} from "discourse/ui-kit/select/select-engine";

function sourceArgs(source, readRows) {
  return source === "client" ? { options: readRows } : { load: readRows };
}

function countedRecords(count) {
  let reads = 0;
  const records = Array.from({ length: count }, (_, value) => {
    const record = { name: `Record ${value}` };
    Object.defineProperty(record, "value", {
      enumerable: true,
      get() {
        reads++;
        return value;
      },
    });
    return record;
  });

  return {
    records,
    get reads() {
      return reads;
    },
    reset() {
      reads = 0;
    },
  };
}

function assertNoRescans(assert, engine, counted, source) {
  const recordCount = counted.records.length;
  const lookupCount = recordCount / 4;
  const readBudget = recordCount * 2 + lookupCount * 4;

  assert.strictEqual(
    engine.resolveSingleSync(0),
    counted.records[0],
    "a warm-up lookup resolves the first record"
  );
  counted.reset();

  for (let value = recordCount - lookupCount; value < recordCount; value++) {
    assert.strictEqual(
      engine.resolveSingleSync(value),
      counted.records[value],
      `held value ${value} resolves its own record`
    );
  }

  assert.true(
    counted.reads < readBudget,
    `${source} keeps value-field reads below N*2 + K*4`
  );
}

module("Unit | ui-kit | SelectEngine | known records", function (hooks) {
  setupTest(hooks);

  for (const source of ["client", "paged"]) {
    for (const outcome of ["synchronous", "asynchronous"]) {
      test(`lets later listed records replace ${outcome} resolver outcomes for ${source} sources`, async function (assert) {
        const recorded = { id: "recorded", name: "Resolver record" };
        const listedRecorded = { id: recorded.id, name: "Listed duplicate" };
        const late = { id: "late", name: "Late listed record" };
        const provided = { id: recorded.id, name: "Provided record" };
        const providedLate = { id: late.id, name: "Provided late record" };
        const state = trackedObject({ rows: [], valueRecords: [] });
        const resolveValue = sinon.spy((value) => {
          const result = value === recorded.id ? recorded : undefined;
          return outcome === "asynchronous" ? Promise.resolve(result) : result;
        });
        const engine = new SelectEngine({
          ...sourceArgs(source, () => state.rows),
          getValueRecords: () => state.valueRecords,
          resolveValue,
        });

        assert.strictEqual(
          await engine.resolveSelection(recorded.id),
          recorded,
          "the resolver supplies a real recorded outcome"
        );
        const fallback = await engine.resolveSelection(late.id);
        assert.deepEqual(
          fallback,
          { id: late.id, name: late.id },
          "a missing value produces the default fallback"
        );
        const cachedFallback = engine.resolveSingleSync(late.id);
        assert.deepEqual(
          cachedFallback,
          { id: late.id, name: late.id },
          "a cached fallback is still an answer"
        );
        assert.strictEqual(
          engine.resolveSingleSync(late.id),
          cachedFallback,
          "synchronous reads retain the cached fallback"
        );
        assert.strictEqual(
          await engine.resolveSelection(late.id),
          cachedFallback,
          "repeated resolution retains the cached fallback"
        );
        assert.strictEqual(
          resolveValue.callCount,
          2,
          "each missing key was requested once"
        );

        state.rows = [listedRecorded, late];
        await engine.loadOptions(engine.loadContext);

        assert.strictEqual(
          engine.resolveSingleSync(recorded.id),
          listedRecorded,
          "the later listed record replaces the resolver outcome"
        );
        assert.strictEqual(
          engine.resolveSingleSync(late.id),
          late,
          "a later-listed real record supersedes the cached fallback"
        );
        assert.strictEqual(
          await engine.resolveSelection(late.id),
          late,
          "selection resolution also uses the later-listed record"
        );

        state.valueRecords = [provided, providedLate];
        assert.strictEqual(
          engine.resolveSingleSync(recorded.id),
          provided,
          "valueRecords beats a real recorded outcome"
        );
        assert.strictEqual(
          engine.resolveSingleSync(late.id),
          providedLate,
          "valueRecords beats a listed record and its cached fallback"
        );
        state.valueRecords = [];
        assert.strictEqual(
          engine.resolveSingleSync(recorded.id),
          listedRecorded,
          "removing valueRecords exposes the later listed record again"
        );
        assert.strictEqual(
          resolveValue.callCount,
          2,
          "known answers never call the resolver again"
        );
      });
    }

    test(`keeps ${source === "client" ? "local records above picks" : "newer picks above paged sightings"} for ${source} sources`, async function (assert) {
      const listed = { id: 1, name: "Listed" };
      const selected = { id: listed.id, name: "Selected" };
      const provided = { id: listed.id, name: "Provided" };
      const state = trackedObject({ value: null, valueRecords: [] });
      const engine = new SelectEngine({
        ...sourceArgs(source, () => [listed]),
        getValue: () => state.value,
        getValueRecords: () => state.valueRecords,
        onChange: (value) => (state.value = value),
      });
      await engine.loadOptions(engine.loadContext);
      assert.strictEqual(
        engine.resolveSingleSync(listed.id),
        listed,
        "the list initially answers"
      );

      engine.select(selected);

      assert.strictEqual(
        state.value,
        selected.id,
        "selection updates the held value"
      );
      assert.strictEqual(
        engine.resolveSingleSync(state.value),
        source === "client" ? listed : selected,
        source === "client"
          ? "the local record beats the pick with the same key"
          : "the newer pick beats the earlier page sighting"
      );
      state.valueRecords = provided;
      assert.strictEqual(
        engine.resolveSingleSync(state.value),
        provided,
        "a single valueRecords record beats the selected outcome"
      );
    });

    test(`normalizes string, number, and custom keys for ${source} sources`, async function (assert) {
      const numeric = { key: 1, name: "Numeric" };
      const staff = { key: "Staff", name: "Staff" };
      const provided = { key: "1", name: "Provided numeric" };
      const duplicateProvided = { key: 1, name: "Later numeric duplicate" };
      const providedStaff = { key: "STAFF", name: "Provided staff" };
      const duplicateStaff = { key: "staff", name: "Later staff duplicate" };
      const state = trackedObject({ valueRecords: [] });
      const resolveValue = sinon.spy();
      const engine = new SelectEngine({
        ...sourceArgs(source, () => [numeric, staff]),
        valueField: "key",
        normalizeKey: (key) => key.toLowerCase(),
        getValueRecords: () => state.valueRecords,
        resolveValue,
      });
      await engine.loadOptions(engine.loadContext);

      for (const value of [1, "1"]) {
        assert.strictEqual(
          engine.resolveSingleSync(value),
          numeric,
          `${typeof value} 1 resolves the numeric listed record`
        );
        assert.strictEqual(
          await engine.resolveSelection(value),
          numeric,
          "selection resolution uses the same normalized key"
        );
      }
      for (const value of ["staff", "STAFF"]) {
        assert.strictEqual(
          engine.resolveSingleSync(value),
          staff,
          "custom normalization applies to listed and requested keys"
        );
      }

      state.valueRecords = [
        provided,
        duplicateProvided,
        providedStaff,
        duplicateStaff,
      ];
      for (const value of [1, "1"]) {
        assert.strictEqual(
          engine.resolveSingleSync(value),
          provided,
          "the first valueRecords record wins across string and number keys"
        );
      }
      assert.strictEqual(
        engine.resolveSingleSync("staff"),
        providedStaff,
        "the first valueRecords record wins across custom normalized keys"
      );
      assert.false(
        resolveValue.called,
        "normalized listed values do not invoke the resolver"
      );
    });

    for (const form of ["getter", "builder"]) {
      test(`refreshes late valueRecords from a ${form} for ${source} sources`, async function (assert) {
        const first = { id: 7, name: "First arrival" };
        const replacement = { id: first.id, name: "Replacement arrival" };
        const state = trackedObject({ records: [] });
        const resolveValue = sinon.spy();
        const engine = new SelectEngine({
          ...sourceArgs(source, () => []),
          ...(form === "getter"
            ? { getValueRecords: () => state.records }
            : { valueRecords: () => state.records }),
          resolveValue,
        });
        await engine.resolveSelection(first.id);
        const fallback = engine.resolveSingleSync(first.id);
        assert.deepEqual(
          fallback,
          { id: first.id, name: String(first.id) },
          "the initially missing value is cached"
        );
        assert.strictEqual(
          engine.resolveSingleSync(first.id),
          fallback,
          "synchronous reads retain the cached fallback"
        );

        state.records = first;
        assert.strictEqual(
          engine.resolveSingleSync(first.id),
          first,
          "a late single record supersedes the fallback"
        );
        assert.strictEqual(
          await engine.resolveSelection(first.id),
          first,
          "selection resolution reads the late record"
        );

        state.records = [replacement];
        assert.strictEqual(
          engine.resolveSingleSync(first.id),
          replacement,
          "a later array supplies the current record for the same key"
        );

        state.records = [];
        assert.strictEqual(
          engine.resolveSingleSync(first.id),
          fallback,
          "removing valueRecords exposes the original cached fallback"
        );
        assert.strictEqual(
          resolveValue.callCount,
          1,
          "late arrivals do not require another resolver attempt"
        );
      });
    }

    test(`does not rescan array valueRecords for ${source} sources`, async function (assert) {
      const counted = countedRecords(64);
      const engine = new SelectEngine({
        ...sourceArgs(source, () => []),
        valueField: "value",
        valueRecords: counted.records,
      });
      await engine.loadOptions(engine.loadContext);

      assertNoRescans(assert, engine, counted, `${source} valueRecords`);
    });
  }

  test("keeps the first client option for a repeated key", async function (assert) {
    const first = { id: 1, name: "First" };
    const later = { id: "1", name: "Later" };
    const unrelated = { id: 2, name: "Unrelated" };
    const engine = new SelectEngine({
      options: [selectOption(first), unrelated, later],
    });
    await engine.loadOptions(engine.loadContext);

    for (const value of [1, "1"]) {
      assert.strictEqual(
        engine.resolveSingleSync(value),
        first,
        "the first listed option owns the normalized key"
      );
      assert.strictEqual(
        await engine.resolveSelection(value),
        first,
        "selection resolution keeps the first record too"
      );
    }
    engine.setFilter("Later");
    await engine.loadOptions(engine.loadContext);
    assert.strictEqual(
      engine.resolveSingleSync(1),
      first,
      "filtering does not change which full-list record owns the key"
    );
  });

  test("keeps the first paged record across overlapping pages", async function (assert) {
    const first = { id: 1, name: "First page" };
    const later = { id: "1", name: "Second page duplicate" };
    const last = { id: 2, name: "Second page unique" };
    const resolveValue = sinon.spy();
    const engine = new SelectEngine({
      load: (_filter, { page }) => ({
        options: page === 1 ? [selectOption(first)] : [later, last],
        hasMore: page === 1,
      }),
      resolveValue,
    });
    await engine.loadOptions(engine.loadContext);
    assert.strictEqual(
      engine.resolveSingleSync("1"),
      first,
      "the first page initially answers"
    );
    assert.true(engine.revealMore(), "the second page can be requested");
    await engine.loadOptions(engine.loadContext);

    for (const value of [1, "1"]) {
      assert.strictEqual(
        engine.resolveSingleSync(value),
        first,
        "the first page still owns the repeated normalized key"
      );
      assert.strictEqual(
        await engine.resolveSelection(value),
        first,
        "selection resolution also retains the first page's record"
      );
    }
    assert.strictEqual(
      engine.resolveSingleSync(last.id),
      last,
      "the unique second-page record is known too"
    );
    assert.false(
      resolveValue.called,
      "accepted pages answer without resolver calls"
    );
  });

  test("drops paged rows on filter changes and reload", async function (assert) {
    const old = { id: 1, name: "Old query record" };
    const other = { id: 2, name: "New query first page" };
    const fresh = { id: old.id, name: "New query later page" };
    const resolveValue = sinon.spy();
    const engine = new SelectEngine({
      load: (filter, { page }) => ({
        options: !filter ? [old] : page === 1 ? [other] : [fresh],
        hasMore: !!filter && page === 1,
      }),
      resolveValue,
    });
    await engine.loadOptions(engine.loadContext);
    assert.strictEqual(
      await engine.resolveSelection(old.id),
      old,
      "an accepted page answers a held value"
    );
    assert.false(resolveValue.called, "the accepted row avoids the resolver");

    engine.setFilter("new query");
    assert.strictEqual(
      engine.resolveSingleSync(old.id),
      undefined,
      "the old accumulator stops answering as soon as the filter changes"
    );
    await engine.loadOptions(engine.loadContext);
    assert.strictEqual(
      engine.resolveSingleSync(old.id),
      undefined,
      "the new first page does not retain old rows"
    );
    assert.strictEqual(
      engine.resolveSingleSync(other.id),
      other,
      "the new query's first page is known"
    );
    assert.true(engine.revealMore(), "the new query has another page");
    await engine.loadOptions(engine.loadContext);
    assert.strictEqual(
      engine.resolveSingleSync(old.id),
      fresh,
      "a later accepted page answers with the fresh record"
    );
    assert.strictEqual(
      await engine.resolveSelection(old.id),
      fresh,
      "selection resolution also uses the fresh page"
    );
    assert.false(
      resolveValue.called,
      "known rows remain independent of the resolver cache"
    );

    engine.reload();
    assert.strictEqual(
      engine.resolveSingleSync(old.id),
      undefined,
      "reload also clears the later-page record"
    );
    assert.strictEqual(
      engine.resolveSingleSync(other.id),
      undefined,
      "reload also clears the first-page record"
    );
    await engine.loadOptions(engine.loadContext);
    assert.strictEqual(
      engine.resolveSingleSync(other.id),
      other,
      "the reloaded first page answers again"
    );
    assert.strictEqual(
      engine.resolveSingleSync(old.id),
      undefined,
      "reload does not revive a page that has not been accepted again"
    );
  });

  test("excludes paged rows discarded by maxLoaded", async function (assert) {
    const first = { id: 1, name: "First" };
    const accepted = { id: 2, name: "Accepted at cap" };
    const discarded = { id: 3, name: "Discarded at cap" };
    const tail = { id: 4, name: "Unvisited page tail" };
    const resolveValue = sinon.spy();
    const engine = new SelectEngine({
      maxLoaded: 2,
      load: (_filter, { page }) => ({
        options: page === 1 ? [first] : [accepted, discarded, tail],
        hasMore: true,
      }),
      resolveValue,
    });
    await engine.loadOptions(engine.loadContext);
    assert.true(engine.revealMore(), "another page can fill the cap");
    const options = await engine.loadOptions(engine.loadContext);
    assert.deepEqual(
      options.map((option) => option.record),
      [first, accepted],
      "only the capped rows are accepted"
    );
    assert.strictEqual(
      engine.resolveSingleSync(accepted.id),
      accepted,
      "the last accepted row answers"
    );

    for (const record of [discarded, tail]) {
      assert.strictEqual(
        engine.resolveSingleSync(record.id),
        undefined,
        "a discarded row never enters the known answers"
      );
      const fallback = await engine.resolveSelection(record.id);
      assert.deepEqual(
        fallback,
        { id: record.id, name: String(record.id) },
        "a discarded row resolves to a fallback instead of its page record"
      );
      const cachedFallback = engine.resolveSingleSync(record.id);
      assert.deepEqual(
        cachedFallback,
        { id: record.id, name: String(record.id) },
        "the discarded row does not displace that cached fallback"
      );
      assert.strictEqual(
        engine.resolveSingleSync(record.id),
        cachedFallback,
        "synchronous reads retain the cached fallback"
      );
    }
    assert.deepEqual(
      resolveValue.args.map(([value]) => value),
      [discarded.id, tail.id],
      "only discarded values need the resolver"
    );
  });

  test("does not rescan a stable function options array", function (assert) {
    const counted = countedRecords(64);
    const engine = new SelectEngine({
      valueField: "value",
      options: () => counted.records,
    });

    assertNoRescans(assert, engine, counted, "client options");
  });

  test("does not rescan the paged accumulator", async function (assert) {
    const counted = countedRecords(64);
    const midpoint = counted.records.length / 2;
    const engine = new SelectEngine({
      valueField: "value",
      valueRecords: [],
      load: (_filter, { page }) => ({
        options:
          page === 1
            ? counted.records.slice(0, midpoint)
            : counted.records.slice(midpoint),
        hasMore: page === 1,
      }),
    });
    await engine.loadOptions(engine.loadContext);
    assert.true(
      engine.revealMore(),
      "both pages contribute to the accumulator"
    );
    await engine.loadOptions(engine.loadContext);

    assertNoRescans(assert, engine, counted, "paged accumulator");
  });

  test("tracks an options array pushed in place inside a cached computation", function (assert) {
    const first = { id: 1, name: "First" };
    const late = { id: 2, name: "Pushed later" };
    const options = trackedArray([first]);
    const engine = new SelectEngine({ options });
    const selection = createCache(() => ({
      first: engine.resolveSingleSync(first.id),
      late: engine.resolveSingleSync(late.id),
    }));
    const before = getValue(selection);
    assert.strictEqual(
      before.first,
      first,
      "the tracked computation warms the existing record"
    );
    assert.strictEqual(
      before.late,
      undefined,
      "the later key initially has no known record"
    );

    options.push(late);

    const after = getValue(selection);
    assert.notStrictEqual(
      after,
      before,
      "pushing in place invalidates the tracked computation"
    );
    assert.strictEqual(after.first, first, "the original record remains known");
    assert.strictEqual(
      after.late,
      late,
      "the same tracked computation resolves the newly pushed record"
    );
    assert.strictEqual(
      engine.resolveSelection(late.id),
      late,
      "selection resolution also sees the in-place edit"
    );
  });

  module("record keys edited in place", function () {
    const sources = {
      options: (record) => ({ options: [record] }),
      valueRecords: (record) => ({ options: [], valueRecords: [record] }),
      load: (record) => ({
        load: () => [record],
        resolveValue: () => undefined,
      }),
    };

    for (const [source, argsFor] of Object.entries(sources)) {
      test(`a ${source} record whose key changes in place answers for its new key`, async function (assert) {
        const record = { id: 1, name: "Moving" };
        const engine = new SelectEngine(argsFor(record));
        await engine.loadOptions(engine.loadContext);
        assert.strictEqual(
          engine.resolveSingleSync(1),
          record,
          "the record answers for its original key"
        );

        record.id = 2;

        assert.strictEqual(
          engine.resolveSingleSync(2),
          record,
          "the record answers for its new key"
        );
        assert.notStrictEqual(
          engine.resolveSingleSync(1),
          record,
          "the record no longer answers for its old key"
        );
      });
    }

    test("a tracked record whose key changes invalidates a lookup that missed", function (assert) {
      const record = trackedObject({ id: 1, name: "Tracked" });
      const engine = new SelectEngine({ options: [record] });
      const lookup = createCache(() => engine.resolveSingleSync(2));
      assert.strictEqual(getValue(lookup), undefined, "key 2 starts unknown");

      record.id = 2;

      assert.strictEqual(
        getValue(lookup),
        record,
        "the lookup recomputes once the record takes the key"
      );
    });

    test("a valueRecords slot deleted in place stops answering", function (assert) {
      const records = [{ id: 1, name: "Deleted" }];
      const engine = new SelectEngine({ options: [], valueRecords: records });
      assert.strictEqual(
        engine.resolveSingleSync(1),
        records[0],
        "the record answers before the deletion"
      );

      delete records[0];

      assert.strictEqual(
        engine.resolveSingleSync(1),
        undefined,
        "a hole in the list answers nothing"
      );
    });
  });
});
