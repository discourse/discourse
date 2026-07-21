import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SelectEngine from "discourse/ui-kit/select/select-engine";

// Mirrors the module-private constants in select-engine.ts. They are deliberately not
// exported (not public API), so the tests pin the behaviour they produce instead.
const CLIENT_CHUNK = 50;
const MAX_RENDERED = 200;

function clientItems(count) {
  return Array.from({ length: count }, (_, i) => ({
    id: i + 1,
    name: `Item ${i + 1}`,
  }));
}

/**
 * A fake server source that records every call's offset/limit so the tests can assert the
 * raw cursor advances independently of the deduped accumulator.
 *
 * @param page - `(offset, limit) => items | { items, total }` for one page.
 */
function recordingLoad(page) {
  const calls = [];
  const load = (filter, opts = {}) => {
    calls.push({ filter, offset: opts.offset, limit: opts.limit });
    return Promise.resolve(page(opts.offset ?? 0, opts.limit));
  };
  return { load, calls };
}

module("Unit | ui-kit | SelectEngine | reveal", function (hooks) {
  setupTest(hooks);

  module("client source", function () {
    test("renders only the first chunk of a large list", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        CLIENT_CHUNK,
        "the initial window is one chunk, not the whole list"
      );
    });

    test("filteredItems is a frozen projection, not a handle on engine state", function (assert) {
      // `readonly` is erased at runtime. Copying alone is not enough either: @cached returns
      // the same array to every reader in a render, so a mutable copy could still be spliced
      // out from under the engine.
      const items = clientItems(5);
      const engine = new SelectEngine({ items });

      assert.true(
        Object.isFrozen(engine.filteredItems),
        "the projection is frozen"
      );
      assert.throws(
        () => engine.filteredItems.splice(0, 1),
        /read only|not extensible|frozen/i,
        "mutating it fails loudly rather than corrupting state"
      );
      assert.strictEqual(items.length, 5, "the consumer's array is untouched");
      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        5,
        "the engine still sees every item"
      );
    });

    test("a short list renders whole and cannot reveal more", function (assert) {
      const engine = new SelectEngine({ items: clientItems(3) });

      assert.strictEqual(engine.loadItems(engine.loadContext).length, 3);
      assert.false(engine.canRevealMore, "nothing left to reveal");
      assert.false(engine.atCapWithMore, "not pinned at the cap");
    });

    test("revealMore grows the window by one chunk and reports that it grew", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      assert.true(engine.revealMore(), "reports the window grew");
      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        CLIENT_CHUNK * 2,
        "the window is two chunks wide"
      );
    });

    test("the window is a prefix — revealing never drops earlier rows", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      const first = engine.loadItems(engine.loadContext);
      engine.revealMore();
      const second = engine.loadItems(engine.loadContext);

      assert.deepEqual(
        second.slice(0, CLIENT_CHUNK).map((i) => i.id),
        first.map((i) => i.id),
        "the revealed window extends the previous one in place"
      );
    });

    test("the window stops at the hard cap and revealMore then refuses", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      for (let i = 0; i < 50; i++) {
        engine.revealMore();
      }

      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        MAX_RENDERED,
        "never renders more than the cap"
      );
      assert.false(
        engine.canRevealMore,
        "the sentinel is gated off at the cap"
      );
      assert.false(engine.revealMore(), "revealMore refuses past the cap");
      assert.true(
        engine.atCapWithMore,
        "pinned at the cap with more available drives the narrow hint"
      );
    });

    test("a list that exactly fits the cap is not reported as having more", function (assert) {
      const engine = new SelectEngine({ items: clientItems(MAX_RENDERED) });

      for (let i = 0; i < 50; i++) {
        engine.revealMore();
      }

      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        MAX_RENDERED
      );
      assert.false(
        engine.atCapWithMore,
        "no hint when the cap is exactly the whole list"
      );
    });

    test("gating getters stay reactive to the filter (no stale untracked snapshot)", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      for (let i = 0; i < 50; i++) {
        engine.revealMore();
      }
      assert.true(engine.atCapWithMore, "capped on the unfiltered list");

      // Narrowing to a single match must re-derive from the live filter. An implementation
      // that stashed the total in an untracked field during loadItems would still say true.
      engine.setFilter("Item 4242");

      assert.false(
        engine.atCapWithMore,
        "the hint clears once the filtered list fits"
      );
      assert.false(engine.canRevealMore, "nothing left to reveal");
    });

    test("changing the filter resets the window to the first chunk", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      engine.revealMore();
      engine.revealMore();
      engine.setFilter("Item");

      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        CLIENT_CHUNK,
        "a new search starts from the first chunk"
      );
    });

    test("reload resets the window", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      engine.revealMore();
      engine.reload();

      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        CLIENT_CHUNK,
        "a retry re-renders from the first chunk"
      );
    });

    test("revealing changes loadContext identity so the list re-renders", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      const before = engine.loadContext;
      engine.revealMore();

      assert.notStrictEqual(
        before,
        engine.loadContext,
        "a reveal invalidates the context DAsyncContent watches"
      );
    });
  });

  module("server source", function () {
    test("fetches the first page with offset 0 and no assumed limit", async function (assert) {
      const { load, calls } = recordingLoad((offset) =>
        clientItems(30).map((i) => ({ ...i, id: offset + i.id }))
      );
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);

      assert.deepEqual(
        calls.map((c) => c.offset),
        [0],
        "one page fetched, from the start"
      );
      assert.strictEqual(
        calls[0].limit,
        undefined,
        "page size is discovered from the response, not assumed"
      );
    });

    test("unwraps the { items, total } shape before returning", async function (assert) {
      const { load } = recordingLoad(() => ({
        items: clientItems(10),
        total: 900,
      }));
      const engine = new SelectEngine({ load });

      const result = await engine.loadItems(engine.loadContext);

      assert.true(Array.isArray(result), "an array reaches the render path");
      assert.strictEqual(result.length, 10);
      assert.strictEqual(engine.total, 900, "the reported total is exposed");
    });

    test("still accepts a bare array response", async function (assert) {
      const { load } = recordingLoad(() => clientItems(10));
      const engine = new SelectEngine({ load });

      const result = await engine.loadItems(engine.loadContext);

      assert.deepEqual(
        result.map((i) => i.id),
        clientItems(10).map((i) => i.id)
      );
    });

    test("the raw cursor advances by page length even when dedup collapses rows", async function (assert) {
      // Every page overlaps the previous by half. The accumulator therefore grows by 5 per
      // page while the cursor must still advance by the full 10, or the source is asked for
      // the same rows forever.
      const { load, calls } = recordingLoad((offset) =>
        Array.from({ length: 10 }, (_, i) => {
          const id = offset + i + 1 - (offset > 0 ? 5 : 0);
          return { id, name: `Item ${id}` };
        })
      );
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      const result = await engine.loadItems(engine.loadContext);

      assert.deepEqual(
        calls.map((c) => c.offset),
        [0, 10, 20],
        "the cursor tracks rows fetched, not rows kept"
      );

      const ids = result.map((i) => i.id);
      assert.deepEqual(
        ids,
        [...new Set(ids)],
        "the accumulator never yields a duplicate key"
      );
    });

    test("appends across reveals instead of replacing", async function (assert) {
      const { load } = recordingLoad((offset) =>
        Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        }))
      );
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      const result = await engine.loadItems(engine.loadContext);

      assert.strictEqual(result.length, 20, "both pages are present");
      assert.strictEqual(result[0].id, 1, "the first page is still at the top");
      assert.strictEqual(result[19].id, 20, "the second page is appended");
    });

    test("caps the RETURNED slice, not just the decision to fetch", async function (assert) {
      // 60-row pages: the accumulator reaches 180 (under the cap, so another page is
      // fetched) and that page would take it to 240.
      const { load } = recordingLoad((offset) =>
        Array.from({ length: 60 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        }))
      );
      const engine = new SelectEngine({ load });

      let result;
      for (let i = 0; i < 6; i++) {
        result = await engine.loadItems(engine.loadContext);
        engine.revealMore();
      }

      assert.strictEqual(
        result.length,
        MAX_RENDERED,
        "an over-long final page is trimmed to the cap"
      );
    });

    test("the cap hint respects a reported total", async function (assert) {
      // Pinned at the cap AND the total says that is everything: no more exist, so the
      // "narrow your search" hint would be a lie.
      const { load } = recordingLoad((offset) => ({
        items: Array.from({ length: 50 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        })),
        total: MAX_RENDERED,
      }));
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 6; i++) {
        await engine.loadItems(engine.loadContext);
        engine.revealMore();
      }

      assert.false(
        engine.atCapWithMore,
        "no hint when the cap is exactly the reported total"
      );
    });

    test("serverPending becomes true reactively when a reveal starts", async function (assert) {
      // Guards the aria-busy path: pending must be derivable from tracked state, not from
      // a flag raised synchronously inside loadItems (which runs during render and so
      // could never invalidate a consumer that already read it).
      const { load } = recordingLoad((offset) =>
        Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        }))
      );
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      assert.false(engine.serverPending, "settled after the first page");

      assert.true(engine.revealMore(), "the reveal is accepted");
      assert.true(
        engine.serverPending,
        "pending flips on from the reveal alone, before loadItems is called"
      );

      await engine.loadItems(engine.loadContext);
      assert.false(engine.serverPending, "cleared once the page lands");
    });

    test("a client source is never reported as pending", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      assert.false(engine.serverPending, "no server, nothing in flight");
    });

    test("an empty page marks the source exhausted", async function (assert) {
      const { load } = recordingLoad((offset) =>
        offset === 0 ? clientItems(10) : []
      );
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      assert.false(engine.canRevealMore, "exhausted, so the sentinel is off");
      assert.false(engine.atCapWithMore, "no narrow hint when nothing is left");
    });

    test("a short page marks the source exhausted", async function (assert) {
      const { load } = recordingLoad((offset) =>
        offset === 0
          ? Array.from({ length: 10 }, (_, i) => ({ id: i + 1, name: `I${i}` }))
          : [{ id: 99, name: "last" }]
      );
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      assert.false(
        engine.canRevealMore,
        "a page shorter than the detected size means the end"
      );
    });

    test("reaching the reported total marks the source exhausted", async function (assert) {
      const { load } = recordingLoad((offset) => ({
        items: Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        })),
        total: 20,
      }));
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      assert.false(engine.canRevealMore, "the whole set has been loaded");
    });

    test("changing the filter discards the accumulated pages", async function (assert) {
      const { load, calls } = recordingLoad((offset) =>
        Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        }))
      );
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      engine.setFilter("new search");
      const result = await engine.loadItems(engine.loadContext);

      assert.strictEqual(
        calls.at(-1).offset,
        0,
        "a new search re-pages from the start"
      );
      assert.strictEqual(
        result.length,
        10,
        "the previous search's rows are gone"
      );
    });

    test("reload discards the accumulated pages", async function (assert) {
      const { load, calls } = recordingLoad((offset) =>
        Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        }))
      );
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      engine.reload();
      const result = await engine.loadItems(engine.loadContext);

      assert.strictEqual(calls.at(-1).offset, 0, "a retry re-pages from zero");
      assert.strictEqual(
        result.length,
        10,
        "the stale accumulation is dropped"
      );
    });

    test("an aborted signal stops paging without corrupting the accumulator", async function (assert) {
      const controller = new AbortController();
      const { load } = recordingLoad((offset) => {
        if (offset > 0) {
          controller.abort();
        }
        return Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        }));
      });
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext, {
        signal: controller.signal,
      });
      engine.revealMore();
      const result = await engine.loadItems(engine.loadContext, {
        signal: controller.signal,
      });

      assert.true(Array.isArray(result), "an array is still returned");
      const ids = result.map((i) => i.id);
      assert.deepEqual(ids, [...new Set(ids)], "no duplicated rows");

      // The assertions above are satisfied by simply returning the first page, so they say
      // nothing about recoverability. An abort must leave the engine usable: if it stays
      // pending, aria-busy pins on and the list can never be revealed again.
      assert.false(
        engine.serverPending,
        "an aborted request is finished, not still in flight"
      );
      assert.true(
        engine.canRevealMore,
        "the list is still revealable after an abort"
      );
    });

    test("works when the caller passes no options at all", async function (assert) {
      // Existing callers invoke loadItems(loadContext) with no second argument; reading
      // opts.signal unguarded would throw here.
      const { load } = recordingLoad(() => clientItems(10));
      const engine = new SelectEngine({ load });

      const result = await engine.loadItems(engine.loadContext);

      assert.strictEqual(result.length, 10, "resolves without an options bag");
    });

    test("revealMore refuses while a page is already in flight", async function (assert) {
      // The sentinel and any future keyboard caller can both fire for the same reveal, so
      // the guard lives here rather than in each caller.
      let release;
      const gate = new Promise((resolve) => (release = resolve));
      const { load, calls } = recordingLoad(() =>
        gate.then(() => clientItems(10))
      );
      const engine = new SelectEngine({ load });

      const pending = engine.loadItems(engine.loadContext);
      assert.false(
        engine.revealMore(),
        "refuses to queue a second page mid-flight"
      );

      release();
      await pending;

      assert.strictEqual(calls.length, 1, "only one page was ever requested");
    });

    test("a fresh engine is settled, not pending", function (assert) {
      // The initial load renders DAsyncContent's :loading block, so the listbox `<ul>` that
      // carries aria-busy does not exist yet. Pending is about *reloads* of a mounted list.
      const engine = new SelectEngine({ load: () => Promise.resolve([]) });

      assert.false(engine.serverPending, "nothing requested yet");
    });

    test("pending tracks a reload from settled through in-flight and back", async function (assert) {
      let release;
      let gate = new Promise((resolve) => (release = resolve));
      const engine = new SelectEngine({
        load: () => gate.then(() => clientItems(10)),
      });

      release();
      await engine.loadItems(engine.loadContext);
      assert.false(engine.serverPending, "settled after the first page");

      gate = new Promise((resolve) => (release = resolve));
      assert.true(engine.revealMore(), "the reveal is accepted");
      assert.true(engine.serverPending, "in flight once a reveal is requested");

      const inFlight = engine.loadItems(engine.loadContext);
      release();
      await inFlight;

      assert.false(engine.serverPending, "cleared once the page lands");
    });

    test("a filter change marks the list as reloading", async function (assert) {
      // aria-busy must engage for a filter-driven reload too, not only a reveal — the
      // resolved list stays mounted via @retainWhileReloading while it refetches.
      const { load } = recordingLoad(() => clientItems(10));
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      assert.false(engine.serverPending, "settled");

      engine.setFilter("abc");
      assert.true(engine.serverPending, "a new query is a pending reload");

      await engine.loadItems(engine.loadContext);
      assert.false(engine.serverPending, "settled again");
    });

    test("a rejected page clears the pending state", async function (assert) {
      // Otherwise aria-busy stays pinned on and revealMore is dead until reload().
      const engine = new SelectEngine({
        load: () => Promise.reject(new Error("boom")),
      });

      engine.setFilter("q");
      try {
        await engine.loadItems(engine.loadContext);
      } catch {
        // DAsyncContent owns surfacing the rejection; the engine must still settle.
      }

      assert.false(
        engine.serverPending,
        "a failed page is not still in flight"
      );
    });

    test("a reveal that rejects clears the pending state", async function (assert) {
      // Rejecting the FIRST load proves little: a fresh engine is deliberately not pending,
      // so `false` afterwards is the starting value, not a transition. This establishes
      // pending is genuinely true first.
      let fail = false;
      const engine = new SelectEngine({
        load: () =>
          fail
            ? Promise.reject(new Error("boom"))
            : Promise.resolve(clientItems(10)),
      });

      await engine.loadItems(engine.loadContext);
      assert.false(engine.serverPending, "settled after the first page");

      fail = true;
      assert.true(engine.revealMore(), "the reveal is accepted");
      assert.true(
        engine.serverPending,
        "pending while the reveal is in flight"
      );

      await engine.loadItems(engine.loadContext).catch(() => {});

      assert.false(
        engine.serverPending,
        "a failed reveal is not still in flight"
      );
    });

    test("one all-duplicate page does not end a legitimate source", async function (assert) {
      // Zero new rows is how an offset-ignoring source is detected, but a real paginated
      // source can serve a duplicate-heavy page and still have more after it.
      const pages = [
        clientItems(10),
        clientItems(10),
        Array.from({ length: 10 }, (_, i) => ({
          id: i + 11,
          name: `Item ${i + 11}`,
        })),
      ];
      let call = 0;
      const load = () =>
        Promise.resolve({
          items: pages[Math.min(call++, pages.length - 1)],
          total: 20,
        });
      const engine = new SelectEngine({ load });

      let result = [];
      for (let i = 0; i < 12; i++) {
        result = await engine.loadItems(engine.loadContext);
        if (!engine.revealMore()) {
          break;
        }
      }

      assert.strictEqual(
        result.length,
        20,
        "pagination survived a fully duplicated page"
      );
    });

    test("a failed load keeps failing rather than yielding an empty list", async function (assert) {
      // Marking a failed context as settled would let the next call hand back the empty
      // accumulator, so DAsyncContent would swap the error block (and its retry action)
      // for the empty state.
      let calls = 0;
      const engine = new SelectEngine({
        load: () => {
          calls++;
          return Promise.reject(new Error("boom"));
        },
      });

      engine.setFilter("q");
      await engine.loadItems(engine.loadContext).catch(() => {});

      let secondRejected = false;
      await engine.loadItems(engine.loadContext).then(
        () => {},
        () => (secondRejected = true)
      );

      assert.true(
        secondRejected,
        "the failure is not swallowed into an empty result"
      );
      assert.strictEqual(
        calls,
        2,
        "the source was asked again, not short-circuited"
      );
    });

    test("a source that ignores offset is treated as exhausted", async function (assert) {
      // The whole pre-pagination back-compat surface: `offset`/`limit` are optional, so an
      // existing load() returns the same rows every time. Dedup keeps the accumulator flat,
      // which must terminate or the sentinel re-fetches identical data forever. One barren
      // page is tolerated (a real source can serve a duplicate-heavy page), so termination
      // lands on the second — bounded, not immediate.
      const { load, calls } = recordingLoad(() => clientItems(10));
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 6; i++) {
        await engine.loadItems(engine.loadContext);
        if (!engine.revealMore()) {
          break;
        }
      }

      assert.false(
        engine.canRevealMore,
        "a source replaying rows we hold is treated as exhausted"
      );
      assert.false(engine.revealMore(), "further reveals are refused");
      assert.true(
        calls.length <= 3,
        `stopped re-fetching after a bounded number of pages (${calls.length})`
      );
    });

    test("the reported total is compared against deduped rows, not the raw cursor", async function (assert) {
      // Exactly 20 distinct rows, served as 10-row pages that overlap the previous page by
      // 5. The raw cursor therefore reaches 20 after two pages while only 15 distinct rows
      // have accumulated — comparing the cursor to the total declares exhaustion 5 rows
      // early and strands them.
      const pages = [
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        [6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        [11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
      ];
      let call = 0;
      const load = () =>
        Promise.resolve({
          items: pages[Math.min(call++, pages.length - 1)].map((id) => ({
            id,
            name: `Item ${id}`,
          })),
          total: 20,
        });
      const engine = new SelectEngine({ load });

      let result = [];
      for (let i = 0; i < 12; i++) {
        result = await engine.loadItems(engine.loadContext);
        if (!engine.revealMore()) {
          break;
        }
      }

      assert.strictEqual(
        result.length,
        20,
        "every row the total promised is reachable"
      );
    });
  });
});
