import { createCache, getValue } from "@glimmer/tracking/primitives/cache";
import { trackedObject } from "@ember/reactive/collections";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import SelectEngine, {
  selectOption,
} from "discourse/ui-kit/select/select-engine";

function deferred() {
  let resolve;
  const promise = new Promise((res) => {
    resolve = res;
  });
  return { promise, resolve };
}

function assertRecord(assert, engine, record, input = record) {
  assert.strictEqual(
    engine.resolveSingleSync(record.id),
    record,
    "the synchronous lookup returns the key's record"
  );
  assert.strictEqual(
    engine.resolveSelection(record.id),
    record,
    "selection resolves synchronously to the same record"
  );
  for (const kind of ["list", "held"]) {
    assert.strictEqual(
      engine.itemFor(String(record.id), { kind, input })?.record,
      record,
      `the ${kind} item shares the lookup's record`
    );
  }
}

module("Unit | ui-kit | SelectEngine | records", function (hooks) {
  setupTest(hooks);

  for (const form of ["array", "record", "getter", "builder"]) {
    test(`gives ${form} valueRecords authority over local records and view copies`, function (assert) {
      const provided = { id: "held", name: "Provided" };
      const listed = { id: provided.id, name: "Listed", detail: "Full record" };
      const copy = { ...listed, name: "View copy" };
      const sources = {
        array: { valueRecords: [provided] },
        record: { valueRecords: provided },
        getter: { getValueRecords: () => [provided] },
        builder: { valueRecords: () => [provided] },
      };
      const resolveValue = sinon.spy();
      const engine = new SelectEngine({
        ...sources[form],
        getValue: () => provided.id,
        options: [listed],
        extraOptions: () => [{ ...listed, name: "Extra" }],
        resolveValue,
      });

      assertRecord(assert, engine, provided, copy);
      assert.false(
        resolveValue.called,
        "an authoritative record needs no resolve"
      );
    });
  }

  for (const origin of ["resolver", "pick"]) {
    test(`lets a full local record replace an earlier ${origin} on every surface`, async function (assert) {
      const thin = { id: "held", name: "Thin" };
      const full = { ...thin, name: "Full", detail: "Locally available" };
      const state = trackedObject({ rows: [], value: null });
      const resolveValue = sinon.spy(() => thin);
      const engine = new SelectEngine({
        options: () => state.rows,
        getValue: () => state.value,
        onChange: (value) => (state.value = value),
        resolveValue,
      });
      if (origin === "pick") {
        engine.select(thin);
      } else {
        state.value = thin.id;
        await engine.resolveSelection(thin.id);
      }
      assert.strictEqual(
        engine.resolveSingleSync(thin.id),
        thin,
        "the earlier sighting initially answers"
      );

      state.rows = [full];
      await engine.loadOptions(engine.loadContext);

      assertRecord(assert, engine, full, thin);
      assert.strictEqual(
        resolveValue.callCount,
        origin === "resolver" ? 1 : 0,
        "the local arrival requires no new resolver call"
      );
    });
  }

  test("ranks local records above at-rest extras and extras above sightings", async function (assert) {
    const answer = { id: "held", name: "Answer" };
    const extra = { id: answer.id, name: "All" };
    const local = { id: answer.id, name: "Local" };
    const state = trackedObject({ rows: [], extras: [] });
    const engine = new SelectEngine({
      getValue: () => answer.id,
      options: () => state.rows,
      extraOptions: () => state.extras,
      resolveValue: () => answer,
    });
    assert.strictEqual(
      await engine.resolveSelection(answer.id),
      answer,
      "the resolver establishes the lowest real rung"
    );

    state.extras = [extra];
    assertRecord(assert, engine, extra, answer);
    state.rows = [local];
    assertRecord(assert, engine, local, extra);
    state.rows = [];
    assertRecord(assert, engine, extra, local);
  });

  test("resolves an extra-only held key at an empty filter without a resolver", function (assert) {
    const all = { id: "all", name: "All" };
    const queryOnly = { id: all.id, name: "Query extra" };
    const resolveValue = sinon.spy();
    const extraOptions = sinon.spy((snapshot) =>
      snapshot.filter === "" ? [all] : [queryOnly]
    );
    const engine = new SelectEngine({
      getValue: () => all.id,
      options: [],
      extraOptions,
      resolveValue,
    });
    engine.setFilter("query");

    assertRecord(assert, engine, all, queryOnly);
    assert.true(
      extraOptions.args.some(([snapshot]) => snapshot.filter === ""),
      "the extras lookup evaluates an at-rest snapshot despite the live query"
    );
    assert.false(resolveValue.called, "the extra-only held key never resolves");
  });

  test("remembers pages that landed before their keys became held", async function (assert) {
    const first = { id: "first", name: "First page" };
    const later = { id: "later", name: "Later page" };
    const state = trackedObject({ value: null });
    const resolveValue = sinon.spy();
    const engine = new SelectEngine({
      getValue: () => state.value,
      load: (_filter, { page }) => ({
        options: page === 1 ? [first] : [later],
        hasMore: page === 1,
      }),
      resolveValue,
    });
    await engine.loadOptions(engine.loadContext);
    assert.true(engine.revealMore(), "the later page is requested");
    await engine.loadOptions(engine.loadContext);

    for (const record of [first, later]) {
      state.value = record.id;
      assertRecord(assert, engine, record);
    }
    assert.false(
      resolveValue.called,
      "every accepted row is known before a pick"
    );
  });

  test("lets a later accepted page replace a resolver answer", async function (assert) {
    const answer = { id: "held", name: "Resolver answer" };
    const page = { id: answer.id, name: "Later page", detail: "Full" };
    const resolveValue = sinon.spy(() => Promise.resolve(answer));
    const engine = new SelectEngine({
      getValue: () => answer.id,
      load: () => [page],
      resolveValue,
    });
    assert.strictEqual(
      await engine.resolveSelection(answer.id),
      answer,
      "the answer arrives before the page"
    );
    await engine.loadOptions(engine.loadContext);

    assertRecord(assert, engine, page, answer);
    assert.strictEqual(
      resolveValue.callCount,
      1,
      "the page needs no re-resolve"
    );
  });

  test("accepts newer picks and pages but ignores duplicate rows within a query", async function (assert) {
    const first = { id: "held", name: "First page" };
    const pick = { id: first.id, name: "Accepted pick" };
    const duplicate = { id: first.id, name: "Dropped duplicate" };
    const fresh = { id: first.id, name: "New query page" };
    const other = { id: "other", name: "Unique second-page row" };
    const state = trackedObject({ value: null });
    const engine = new SelectEngine({
      getValue: () => state.value,
      onChange: (value) => (state.value = value),
      load: (filter, { page }) => ({
        options: filter ? [fresh] : [first],
        hasMore: page === 1,
        ...(page === 2 && { options: [duplicate, other] }),
      }),
      resolveValue: () => undefined,
    });
    await engine.loadOptions(engine.loadContext);
    engine.select(pick);
    assertRecord(assert, engine, pick, first);

    assert.true(engine.revealMore(), "the overlapping page is requested");
    await engine.loadOptions(engine.loadContext);
    assertRecord(assert, engine, pick, duplicate);
    assertRecord(assert, engine, other);

    engine.setFilter("fresh query");
    assert.strictEqual(
      engine.resolveSingleSync(first.id),
      pick,
      "the held sighting survives the query reset"
    );
    await engine.loadOptions(engine.loadContext);
    assertRecord(assert, engine, fresh, pick);
  });

  for (const reset of ["filter", "reload"]) {
    test(`prunes non-held sightings on ${reset} while retaining held sightings`, async function (assert) {
      const held = { id: "held", name: "Held page row" };
      const unheld = { id: "unheld", name: "Unheld page row" };
      const unheldAnswer = {
        id: "unheld-answer",
        name: "Unheld resolver answer",
      };
      const state = trackedObject({ rows: [held, unheld] });
      const engine = new SelectEngine({
        getValue: () => held.id,
        load: () => state.rows,
        resolveValue: (value) =>
          value === unheldAnswer.id ? unheldAnswer : undefined,
      });
      await engine.loadOptions(engine.loadContext);
      assert.strictEqual(
        engine.resolveSingleSync(unheld.id),
        unheld,
        "the unheld row is initially known"
      );
      assert.strictEqual(
        await engine.resolveSelection(unheldAnswer.id),
        unheldAnswer,
        "a resolver also supplies a non-held sighting before the reset"
      );
      state.rows = [];
      if (reset === "filter") {
        engine.setFilter("empty query");
      } else {
        engine.reload();
      }

      for (const record of [unheld, unheldAnswer]) {
        assert.strictEqual(
          engine.resolveSingleSync(record.id),
          undefined,
          "the reset immediately prunes each non-held sighting"
        );
      }
      await engine.loadOptions(engine.loadContext);
      assertRecord(assert, engine, held);
      for (const record of [unheld, unheldAnswer]) {
        assert.strictEqual(
          engine.resolveSingleSync(record.id),
          undefined,
          "an empty replacement page does not revive a non-held sighting"
        );
      }
    });
  }

  test("uses a view's input only as the floor and a legacy copy never replaces a known record", function (assert) {
    const record = { id: "known", name: "Original", detail: "Full" };
    const copy = { ...record, name: "Legacy copy" };
    const onlyInView = { id: "view-only", name: "Content-step record" };
    const engine = new SelectEngine({ options: [record] });

    assertRecord(assert, engine, record, copy);
    for (const kind of ["list", "held"]) {
      assert.strictEqual(
        engine.itemFor(onlyInView.id, { kind, input: onlyInView })?.record,
        onlyInView,
        `the ${kind} input supplies an otherwise unknown record`
      );
    }
    assert.strictEqual(
      engine.resolveSingleSync(onlyInView.id),
      undefined,
      "reading the view never publishes a sighting"
    );
    assert.strictEqual(
      engine.itemFor("absent", { kind: "held" }),
      undefined,
      "an unknown key without an input has no item before resolution"
    );
    const fallback = engine.resolveSelection(onlyInView.id);
    assert.strictEqual(
      engine.itemFor(onlyInView.id, { kind: "list", input: onlyInView })
        ?.record,
      onlyInView,
      "a cached fallback never outranks a real view input"
    );
    assert.strictEqual(
      engine.resolveSingleSync(onlyInView.id),
      fallback,
      "the view's floor remains scoped to its request"
    );
  });

  for (const origin of ["local", "extra", "page", "pick"]) {
    test(`replaces a cached fallback with a later ${origin} record`, async function (assert) {
      const real = { id: "missing", name: `Real ${origin} record` };
      const state = trackedObject({ rows: [], extras: [], value: null });
      const resolveValue = sinon.spy(() => undefined);
      const engine = new SelectEngine({
        ...(origin === "page"
          ? { load: () => state.rows }
          : { options: () => state.rows }),
        getValue: () => state.value,
        onChange: (value) => (state.value = value),
        extraOptions: () => state.extras,
        resolveValue,
      });
      const fallback = await engine.resolveSelection(real.id);
      const unresolved = engine.itemFor(real.id, { kind: "held" });
      assert.strictEqual(
        unresolved.record,
        fallback,
        "the item holds the fallback"
      );
      assert.true(unresolved.unresolved, "the fallback item is unresolved");
      assert.strictEqual(
        unresolved.label,
        engine.getSelectionLabel(fallback),
        "the unresolved item uses the engine's fallback name"
      );

      if (origin === "pick") {
        engine.select(real);
      } else if (origin === "extra") {
        state.extras = [real];
      } else {
        state.rows = [real];
        await engine.loadOptions(engine.loadContext);
      }

      assertRecord(assert, engine, real, fallback);
      assert.false(
        engine.itemFor(real.id, { kind: "held" }).unresolved,
        "the later real record clears the unresolved item state"
      );
      assert.strictEqual(
        resolveValue.callCount,
        1,
        "there is no resolver retry"
      );
    });
  }

  test("reload evicts fallbacks while preserving held real sightings and their properties", async function (assert) {
    const answer = { id: "answer", name: "Resolved" };
    const page = { id: "page", name: "Paged" };
    const pick = { id: "pick", name: "Picked" };
    const missing = "missing";
    const answerSettings = { description: "Answer description" };
    const pickSettings = { description: "Pick description" };
    const state = trackedObject({
      value: [answer.id, page.id, missing],
      rows: [page],
    });
    const resolveValue = sinon.spy((value) =>
      value === answer.id ? selectOption(answer, answerSettings) : undefined
    );
    const engine = new SelectEngine({
      multiple: true,
      getValue: () => state.value,
      onChange: (value) => (state.value = value),
      load: () => state.rows,
      resolveValue,
    });
    await engine.loadOptions(engine.loadContext);
    const before = await engine.resolveSelection(state.value);
    const fallback = before.find((record) => record.id === missing);
    engine.select(selectOption(pick, pickSettings));
    state.rows = [];
    engine.reload();

    for (const record of [answer, page, pick]) {
      assert.strictEqual(
        engine.resolveSingleSync(record.id),
        record,
        "a held real sighting survives reload"
      );
      assert.strictEqual(
        engine.itemFor(record.id, { kind: "held" })?.record,
        record,
        "the held item retains that same record"
      );
    }
    for (const [record, settings] of [
      [answer, answerSettings],
      [pick, pickSettings],
    ]) {
      assert.strictEqual(
        engine.itemFor(record.id, { kind: "held" }).description,
        settings.description,
        "reload preserves real outcome properties"
      );
    }
    assert.strictEqual(
      engine.resolveSingleSync(missing),
      undefined,
      "reload evicts the fallback"
    );
    const callsBeforeRetry = resolveValue.callCount;
    const after = await engine.resolveSelection(state.value);
    for (const record of [answer, page, pick]) {
      assert.strictEqual(
        after[state.value.indexOf(record.id)],
        record,
        "the awaited selection retains each real held record's identity"
      );
    }
    assert.notStrictEqual(
      after[2],
      fallback,
      "the missing key gets a fresh fallback"
    );
    assert.strictEqual(
      resolveValue.callCount,
      callsBeforeRetry + 1,
      "only the evicted fallback is retried"
    );
  });

  test("merges view properties above valueRecords above a held pick above a matching answer", async function (assert) {
    const answer = { id: "held", name: "Answer" };
    const picked = { id: answer.id, name: "Pick" };
    const provided = { id: answer.id, name: "Provided" };
    const viewRecord = { id: answer.id, name: "View" };
    const answerSettings = {
      description: "Answer description",
      disabled: true,
    };
    const pickSettings = { description: "Pick description" };
    const providedSettings = { description: "Provided description" };
    const viewSettings = { description: "View description" };
    const gate = deferred();
    const state = trackedObject({ value: null, records: [] });
    const engine = new SelectEngine({
      options: [],
      getValue: () => state.value,
      getValueRecords: () => state.records,
      onChange: (value) => (state.value = value),
      resolveValue: () => gate.promise,
    });
    const pending = engine.resolveSelection(answer.id);
    engine.select(selectOption(picked, pickSettings));
    gate.resolve(selectOption(answer, answerSettings));
    await pending;

    const held = engine.itemFor(answer.id, { kind: "held" });
    assert.strictEqual(
      held.record,
      answer,
      "the later answer is the newest sighting"
    );
    assert.strictEqual(
      held.description,
      pickSettings.description,
      "the held pick wins the property conflict"
    );
    assert.true(
      held.disabled,
      "a silent pick does not erase the matching answer's other property"
    );

    state.records = [selectOption(provided, providedSettings)];
    assert.strictEqual(
      engine.itemFor(answer.id, { kind: "held" }).description,
      providedSettings.description,
      "valueRecords settings beat the held pick's settings"
    );
    for (const kind of ["list", "held"]) {
      const item = engine.itemFor(answer.id, {
        kind,
        input: selectOption(viewRecord, viewSettings),
      });
      assert.strictEqual(
        item.record,
        provided,
        "properties never replace the authoritative record"
      );
      assert.strictEqual(
        item.description,
        viewSettings.description,
        "the requesting view wins the property conflict"
      );
      assert.false(
        item.disabled,
        "a displaced answer no longer contributes settings"
      );
    }
  });

  for (const timing of ["synchronous", "asynchronous"]) {
    test(`retains ${timing} answer settings only while the answer owns the record`, async function (assert) {
      const answer = { id: "held", name: "Answer" };
      const local = {
        id: answer.id,
        name: "Local",
        detail: "Derived description",
      };
      const settings = { description: "Resolver description" };
      const state = trackedObject({ rows: [] });
      const option = selectOption(answer, settings);
      const engine = new SelectEngine({
        getValue: () => answer.id,
        options: () => state.rows,
        descriptionField: "detail",
        resolveValue: () =>
          timing === "asynchronous" ? Promise.resolve(option) : option,
      });
      await engine.resolveSelection(answer.id);
      assert.strictEqual(
        engine.itemFor(answer.id, { kind: "held" }).description,
        settings.description,
        "a matching answer's explicit description is visible"
      );

      state.rows = [local];
      const item = engine.itemFor(answer.id, { kind: "held" });
      assert.strictEqual(item.record, local, "the local record takes the key");
      assert.strictEqual(
        item.description,
        local.detail,
        "the displaced answer's description stops contributing"
      );
    });
  }

  test("page sightings never invalidate or abort a pending tracked selection", async function (assert) {
    const page = { id: "held", name: "Page while pending" };
    const answer = { id: page.id, name: "Later answer" };
    const gate = deferred();
    let requestSignal;
    let recomputes = 0;
    const engine = new SelectEngine({
      getValue: () => page.id,
      load: () => [page],
      resolveValue: (_value, { signal }) => {
        requestSignal = signal;
        return gate.promise;
      },
    });
    const selection = createCache(() => {
      recomputes++;
      return engine.resolveSelection(page.id);
    });
    const pending = getValue(selection);
    assert.true(
      pending instanceof Promise,
      "the tracked selection starts pending"
    );
    await engine.loadOptions(engine.loadContext);
    assert.strictEqual(
      getValue(selection),
      pending,
      "a page arrival leaves the async computation intact"
    );
    assert.strictEqual(recomputes, 1, "the page causes no recomputation");
    assert.false(requestSignal.aborted, "the in-flight resolver remains alive");
    gate.resolve(answer);

    assert.strictEqual(
      await pending,
      answer,
      "the later answer becomes the newest sighting"
    );
    assert.strictEqual(
      getValue(selection),
      pending,
      "settling a sighting also leaves async data intact"
    );
    assert.strictEqual(
      recomputes,
      1,
      "answer publication does not rerun async data"
    );
    assertRecord(assert, engine, answer, page);
  });

  test("pending batches ignore page invalidation and re-read refreshed real records and fallbacks at settlement", async function (assert) {
    const known = { id: "known", name: "Earlier answer" };
    const fresh = { id: known.id, name: "Refreshed by page" };
    const formerlyMissing = { id: "missing", name: "Page replaces fallback" };
    const pendingPage = { id: "pending", name: "Page while resolving" };
    const answer = { id: pendingPage.id, name: "Last answer" };
    const gate = deferred();
    const values = [known.id, formerlyMissing.id, pendingPage.id];
    const engine = new SelectEngine({
      multiple: true,
      getValue: () => values,
      load: () => [fresh, formerlyMissing, pendingPage],
      resolveValue: (value) => {
        if (value === known.id) {
          return known;
        }
        return value === pendingPage.id ? gate.promise : undefined;
      },
    });
    await engine.resolveSelection(values.slice(0, 2));
    let recomputes = 0;
    const selection = createCache(() => {
      recomputes++;
      return engine.resolveSelection(values);
    });
    const pending = getValue(selection);
    await engine.loadOptions(engine.loadContext);
    assert.strictEqual(
      getValue(selection),
      pending,
      "neither a fallback replacement nor a real refresh invalidates async data"
    );
    assert.strictEqual(
      recomputes,
      1,
      "the whole batch stays in one computation"
    );
    gate.resolve(answer);

    const result = await pending;
    for (const [index, record] of [fresh, formerlyMissing, answer].entries()) {
      assert.strictEqual(
        result[index],
        record,
        "settlement re-reads each key instead of captured records"
      );
    }
  });

  for (const surface of ["resolveSingleSync", "itemFor"]) {
    for (const arrival of ["page", "answer"]) {
      test(`tracks ${arrival} sightings outside async data through ${surface}`, async function (assert) {
        const record = { id: "held", name: `Arriving ${arrival}` };
        const gate = deferred();
        const engine = new SelectEngine({
          getValue: () => record.id,
          load: () => [record],
          resolveValue: () => gate.promise,
        });
        let recomputes = 0;
        const lookup = createCache(() => {
          recomputes++;
          return surface === "resolveSingleSync"
            ? engine.resolveSingleSync(record.id)
            : engine.itemFor(record.id, { kind: "held" })?.record;
        });
        assert.strictEqual(
          getValue(lookup),
          undefined,
          "the synchronous surface initially has no record"
        );
        if (arrival === "page") {
          await engine.loadOptions(engine.loadContext);
        } else {
          const pending = engine.resolveSelection(record.id);
          gate.resolve(record);
          await pending;
        }

        assert.strictEqual(
          getValue(lookup),
          record,
          "the sighting invalidates the synchronous surface"
        );
        assert.strictEqual(
          recomputes,
          2,
          "the cached lookup recomputes after the arrival"
        );
      });
    }
  }

  for (const form of ["getter", "builder"]) {
    test(`tracks ${form} valueRecords arriving during a pending resolve`, async function (assert) {
      const provided = { id: "held", name: "Authoritative arrival" };
      const answer = { id: provided.id, name: "Later resolver answer" };
      const gate = deferred();
      const state = trackedObject({ records: [] });
      const engine = new SelectEngine({
        getValue: () => provided.id,
        ...(form === "getter"
          ? { getValueRecords: () => state.records }
          : { valueRecords: () => state.records }),
        resolveValue: () => gate.promise,
      });
      let recomputes = 0;
      const selection = createCache(() => {
        recomputes++;
        return engine.resolveSelection(provided.id);
      });
      const pending = getValue(selection);
      assert.true(pending instanceof Promise, "the held record starts pending");
      state.records = [provided];
      assert.strictEqual(
        getValue(selection),
        provided,
        "the authoritative arrival releases the pending state synchronously"
      );
      assert.strictEqual(
        recomputes,
        2,
        "valueRecords stays tracked inside async data"
      );
      gate.resolve(answer);
      assert.strictEqual(
        await pending,
        provided,
        "even the original pending resolve returns the authoritative record"
      );
      assertRecord(assert, engine, provided, answer);
    });
  }

  for (const multiple of [false, true]) {
    test(`re-reads local records when an async ${multiple ? "batch" : "single"} answer settles`, async function (assert) {
      const answer = { id: "held", name: "Answer" };
      const local = { id: answer.id, name: "Local arrival" };
      const other = { id: "other", name: "Already known" };
      const state = trackedObject({ rows: [other] });
      const gate = deferred();
      const value = multiple ? [other.id, answer.id] : answer.id;
      const engine = new SelectEngine({
        multiple,
        getValue: () => value,
        options: () => state.rows,
        resolveValue: () => gate.promise,
      });
      const pending = engine.resolveSelection(value);
      state.rows = [other, local];
      gate.resolve(answer);
      const result = await pending;

      const records = multiple ? result : [result];
      const expected = multiple ? [other, local] : [local];
      for (const [index, record] of expected.entries()) {
        assert.strictEqual(
          records[index],
          record,
          "the original pending call returns the current record for each key"
        );
      }
      assert.strictEqual(
        engine.resolveSingleSync(local.id),
        local,
        "the synchronous lookup agrees after settlement"
      );
    });
  }

  module("answers, aborts and keys edited in place", function () {
    test("typing never re-runs a pending tracked selection", async function (assert) {
      const gate = deferred();
      let recomputes = 0;
      const engine = new SelectEngine({
        getValue: () => 7,
        load: () => [],
        extraOptions: () => [],
        resolveValue: () => gate.promise,
      });
      const selection = createCache(() => {
        recomputes++;
        return engine.resolveSelection(7);
      });
      const pending = getValue(selection);
      engine.setFilter("a");
      assert.strictEqual(
        getValue(selection),
        pending,
        "the pending selection is still the same computation"
      );
      assert.strictEqual(recomputes, 1, "typing causes no recomputation");
      gate.resolve({ id: 7, name: "Seven" });
      await pending;
    });

    test("a held record moved to a new key survives a reset and a write to its old key", async function (assert) {
      const moving = { id: 1, name: "Moving" };
      const newcomer = { id: 1, name: "Newcomer" };
      const engine = new SelectEngine({
        getValue: () => 2,
        load: () => [moving],
        resolveValue: () => undefined,
      });
      await engine.loadOptions(engine.loadContext);
      moving.id = 2;
      assert.strictEqual(
        engine.resolveSingleSync(2),
        moving,
        "the moved record answers for its new key"
      );

      engine.setFilter("query");
      assert.strictEqual(
        engine.resolveSingleSync(2),
        moving,
        "a reset keeps the record its held key now names"
      );

      engine.select(newcomer);
      assert.strictEqual(
        engine.resolveSingleSync(1),
        newcomer,
        "the old key takes the new record"
      );
      assert.strictEqual(
        engine.resolveSingleSync(2),
        moving,
        "the moved record still answers for its new key"
      );
    });

    test("an aborted answer contributes no properties", async function (assert) {
      const provided = { id: "held", name: "Provided" };
      const gate = deferred();
      const state = trackedObject({ records: [] });
      const engine = new SelectEngine({
        getValue: () => provided.id,
        getValueRecords: () => state.records,
        resolveValue: () => gate.promise,
      });
      const controller = new AbortController();
      const pending = engine.resolveSelection(provided.id, {
        signal: controller.signal,
      });
      controller.abort();
      gate.resolve(
        selectOption(provided, { description: "Aborted", disabled: true })
      );
      await Promise.resolve(pending).catch(() => {});
      await new Promise((resolve) => setTimeout(resolve, 0));

      state.records = [provided];
      const item = engine.itemFor(provided.id, { kind: "held" });
      assert.strictEqual(item.record, provided, "valueRecords owns the key");
      assert.strictEqual(
        item.description,
        undefined,
        "the aborted answer's description never shows"
      );
      assert.false(item.disabled, "the aborted answer's state never shows");
    });

    test("an aborted answer never lends its settings to a retry", async function (assert) {
      const record = { id: "r", name: "R" };
      const gates = [deferred(), deferred()];
      let calls = 0;
      const engine = new SelectEngine({
        getValue: () => null,
        options: [],
        resolveValue: () => gates[calls++].promise,
      });
      const controller = new AbortController();
      const first = engine.resolveSelection("r", { signal: controller.signal });
      controller.abort();
      const second = engine.resolveSelection("r");
      gates[1].resolve(selectOption(record, { description: "Retry" }));
      gates[0].resolve(
        selectOption(record, { description: "Aborted", disabled: true })
      );
      await second;
      await Promise.resolve(first).catch(() => {});
      await new Promise((resolve) => setTimeout(resolve, 0));

      const item = engine.itemFor("r", { kind: "held" });
      assert.strictEqual(item.record, record, "the retry owns the key");
      assert.strictEqual(
        item.description,
        "Retry",
        "only the accepted answer's description shows"
      );
      assert.false(item.disabled, "the aborted answer's state never shows");
    });

    test("a record moved onto a stale slot's key keeps answering for it", async function (assert) {
      const first = { id: 1, name: "First" };
      const second = { id: 2, name: "Second" };
      const newcomer = { id: 1, name: "Newcomer" };
      const engine = new SelectEngine({
        getValue: () => 2,
        load: () => [first, second],
        resolveValue: () => undefined,
      });
      await engine.loadOptions(engine.loadContext);
      first.id = 2;
      second.id = 3;
      engine.select(newcomer);

      assert.strictEqual(
        engine.resolveSingleSync(2),
        first,
        "the record that now names the key answers for it"
      );
      assert.strictEqual(
        engine.resolveSingleSync(3),
        second,
        "the other moved record answers for its own new key"
      );
    });

    test("a displaced answer's settings never come back with its record", async function (assert) {
      const answer = { id: "k", name: "Answer" };
      const page = { id: "k", name: "Page" };
      const state = trackedObject({ records: [] });
      const engine = new SelectEngine({
        getValue: () => null,
        load: () => [page],
        getValueRecords: () => state.records,
        resolveValue: () =>
          selectOption(answer, { description: "Old", disabled: true }),
      });
      await engine.resolveSelection("k");
      await engine.loadOptions(engine.loadContext);
      engine.setFilter("query");
      state.records = [answer];

      const item = engine.itemFor("k", { kind: "held" });
      assert.strictEqual(item.record, answer, "valueRecords brings it back");
      assert.strictEqual(
        item.description,
        undefined,
        "the displaced answer's description stays gone"
      );
      assert.false(item.disabled, "the displaced answer's state stays gone");
    });

    test("a reset forgets a record moved off the held key", async function (assert) {
      const moving = { id: 1, name: "Moving" };
      const engine = new SelectEngine({
        getValue: () => 1,
        load: () => [moving],
        resolveValue: () => undefined,
      });
      await engine.loadOptions(engine.loadContext);
      moving.id = 2;
      engine.setFilter("query");

      assert.strictEqual(
        engine.resolveSingleSync(2),
        undefined,
        "the unheld key the record moved to is forgotten"
      );
    });

    test("a bare accepted answer clears an earlier answer's settings", async function (assert) {
      const record = { id: "k", name: "K" };
      let answer = selectOption(record, { description: "Old", disabled: true });
      const engine = new SelectEngine({
        getValue: () => null,
        options: [],
        resolveValue: () => answer,
      });
      await engine.resolveSelection("k");
      record.id = "other";
      answer = record;
      const pending = engine.resolveSelection("k");
      record.id = "k";
      await pending;

      const item = engine.itemFor("k", { kind: "held" });
      assert.strictEqual(item.record, record, "the record answers for its key");
      assert.strictEqual(
        item.description,
        undefined,
        "the bare answer leaves no description"
      );
      assert.false(item.disabled, "the bare answer leaves no state");
    });

    test("a load-only select holding an extra-only value needs no resolver argument", async function (assert) {
      const all = { id: "all", name: "All" };
      const engine = new SelectEngine({
        getValue: () => "all",
        load: () => [],
        extraOptions: () => [all],
      });
      assert.strictEqual(
        engine.resolveSelection("all"),
        all,
        "the at-rest extra resolves the held value"
      );
    });
  });
});
