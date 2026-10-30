import { trackedArray, trackedObject } from "@ember/reactive/collections";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import SelectEngine from "discourse/ui-kit/select/select-engine";

// The cap a consumer opts into with `maxLoaded`. A server source has no row ceiling by
// default, and a client source renders its whole filtered list while `DVirtualList` owns
// the render window.
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
 * @param page - `(offset, limit) => items | { items, total?, hasMore? }` for one page.
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
    test("renders the whole filtered list, not a bounded window", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        5000,
        "the full client list renders — DVirtualList owns the render window now"
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

    test("a large client list never reveals and never caps", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      assert.false(
        engine.canRevealMore,
        "a fully-rendered client list has nothing left to reveal"
      );
      assert.false(
        engine.revealMore(),
        "revealMore is an inert no-op for a client source"
      );
      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        5000,
        "the rendered set is unchanged by the no-op reveal"
      );
      assert.false(
        engine.atCapWithMore,
        "no client cap means the narrow hint never fires for a client source"
      );
    });

    test("total is the full filtered length and stays reactive to the filter", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      assert.strictEqual(engine.total, 5000, "the whole client list");

      // Narrowing to a single match must re-derive from the live filter. An implementation
      // that stashed the count in an untracked field during loadItems would still say 5000.
      engine.setFilter("Item 4242");

      assert.strictEqual(
        engine.total,
        1,
        "re-derived live from the filter, not a stale snapshot"
      );
      assert.false(
        engine.atCapWithMore,
        "a single match is never the narrow hint"
      );
      assert.false(engine.canRevealMore, "nothing left to reveal");
      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        1,
        "the rendered set narrows with the filter"
      );
    });

    test("changing the filter re-renders the full filtered list", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      engine.setFilter("Item");

      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        5000,
        "every row matches the term, so the whole filtered list renders"
      );
    });

    test("reload re-renders the full list", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      engine.reload();

      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        5000,
        "a retry re-renders the whole list, not a bounded prefix"
      );
    });

    test("a client reveal leaves loadContext identity intact; a new filter invalidates it", function (assert) {
      const engine = new SelectEngine({ items: clientItems(5000) });

      const before = engine.loadContext;
      engine.revealMore();

      assert.strictEqual(
        before,
        engine.loadContext,
        "a client source has no reveal cursor, so the inert reveal cannot re-key the context"
      );

      engine.setFilter("Item 1");
      assert.notStrictEqual(
        before,
        engine.loadContext,
        "a new filter still invalidates the context DAsyncContent watches"
      );
    });

    test("loadItems and loadContext follow the live items thunk, never a buffered copy", function (assert) {
      // A tracked source, so replacing the array actually invalidates the @cached reads — a
      // plain variable reassignment would not, which is the point of the reactivity net.
      const source = trackedObject({ items: clientItems(3) });
      const engine = new SelectEngine({ items: () => source.items });

      const before = engine.loadContext;
      assert.strictEqual(
        engine.loadItems(before).length,
        3,
        "the initial live corpus"
      );

      source.items = clientItems(7);

      assert.notStrictEqual(
        before,
        engine.loadContext,
        "a changed source invalidates the context so the list re-fetches"
      );
      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        7,
        "loadItems reflects the live thunk — a buffered LocalSource would still report 3"
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
      const { load, calls } = recordingLoad((offset) => ({
        items: Array.from({ length: 10 }, (_, i) => {
          const id = offset + i + 1 - (offset > 0 ? 5 : 0);
          return { id, name: `Item ${id}` };
        }),
        hasMore: true,
      }));
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
      const { load } = recordingLoad((offset) => ({
        items: Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        })),
        hasMore: true,
      }));
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
      const { load } = recordingLoad((offset) => ({
        items: Array.from({ length: 60 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        })),
        hasMore: true,
      }));
      const engine = new SelectEngine({ load, maxLoaded: MAX_RENDERED });

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
      const engine = new SelectEngine({ load, maxLoaded: MAX_RENDERED });

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
      const { load } = recordingLoad((offset) => ({
        items: Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        })),
        hasMore: true,
      }));
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

    test("paging stops the moment a page stops declaring more", async function (assert) {
      // Page shape says nothing: the second page here is the same length as the first, which
      // under the old contract left the source revealable. Only the declaration ends it.
      const { load } = recordingLoad((offset) => ({
        items: Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        })),
        hasMore: offset === 0,
      }));
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      assert.true(engine.revealMore(), "the first page declared more");
      await engine.loadItems(engine.loadContext);

      assert.false(engine.canRevealMore, "exhausted, so the sentinel is off");
      assert.false(engine.atCapWithMore, "no narrow hint when nothing is left");
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
      const { load, calls } = recordingLoad((offset) => ({
        items: Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        })),
        hasMore: true,
      }));
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      const accumulated = await engine.loadItems(engine.loadContext);
      assert.strictEqual(accumulated.length, 20, "two pages accumulated");

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
      const { load, calls } = recordingLoad((offset) => ({
        items: Array.from({ length: 10 }, (_, i) => ({
          id: offset + i + 1,
          name: `Item ${offset + i + 1}`,
        })),
        hasMore: true,
      }));
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      const accumulated = await engine.loadItems(engine.loadContext);
      assert.strictEqual(accumulated.length, 20, "two pages accumulated");

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
        return {
          items: Array.from({ length: 10 }, (_, i) => ({
            id: offset + i + 1,
            name: `Item ${offset + i + 1}`,
          })),
          hasMore: true,
        };
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
        load: () =>
          gate.then(() => ({ items: clientItems(10), hasMore: true })),
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
            : Promise.resolve({ items: clientItems(10), hasMore: true }),
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

    test("a source that declares nothing is never asked for a second page", async function (assert) {
      // A source that cannot say whether more exists is not a paginated source, so the engine
      // takes it at its word rather than probing. This is the whole reason the contract was
      // inverted: the probe cost every such source two wasted round-trips, each one long
      // enough to paint a loading placeholder.
      const { load, calls } = recordingLoad(() => clientItems(10));
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 6; i++) {
        await engine.loadItems(engine.loadContext);
        if (!engine.revealMore()) {
          break;
        }
      }

      assert.false(engine.canRevealMore, "silence ends the paging");
      assert.false(engine.revealMore(), "further reveals are refused");
      assert.strictEqual(calls.length, 1, "no speculative refetch at all");
      assert.strictEqual(
        engine.total,
        10,
        "and what it returned is taken as the whole set"
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

  module("hasMore vs total", function () {
    function uniquePage(offset, length) {
      return Array.from({ length }, (_, i) => ({
        id: offset + i + 1,
        name: `Item ${offset + i + 1}`,
      }));
    }

    test("an explicit hasMore:false ends the source, same as silence", async function (assert) {
      // Redundant with omitting the field, and deliberately still legal: a cursor API can
      // forward its own flag straight through without having to strip the false case.
      const { load, calls } = recordingLoad((offset) => ({
        items: uniquePage(offset, 50),
        hasMore: false,
      }));
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);

      assert.false(
        engine.canRevealMore,
        "the source said there is no next page"
      );
      assert.false(engine.revealMore(), "further reveals are refused");
      assert.strictEqual(calls.length, 1, "no speculative second fetch");
    });

    test("hasMore:true keeps a SHORT page revealable", async function (assert) {
      // A source that DB-pages 20 and returns 18 survivors after permission filtering is
      // not exhausted, but page shape alone cannot tell that from a genuine last page.
      const { load } = recordingLoad((offset) =>
        offset === 0
          ? { items: uniquePage(0, 20), hasMore: true }
          : { items: uniquePage(offset, 18), hasMore: true }
      );
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      assert.true(engine.revealMore(), "the first reveal is accepted");
      await engine.loadItems(engine.loadContext);

      assert.true(
        engine.canRevealMore,
        "a short page the source declares non-final stays revealable"
      );
    });

    test("hasMore:false on a one-row first page fetches exactly once", async function (assert) {
      // A single row never fills the listbox, so the reveal sentinel is in view from the
      // start and fires the moment anything lets it. Only the source's own declaration keeps
      // that from becoming a second fetch and a second loading placeholder.
      const { load, calls } = recordingLoad(() => ({
        items: [{ id: 1, name: "only" }],
        hasMore: false,
      }));
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 4; i++) {
        await engine.loadItems(engine.loadContext);
        if (!engine.revealMore()) {
          break;
        }
      }

      assert.strictEqual(calls.length, 1, "no second page is requested");
    });

    test("hasMore:false makes the loaded count the reportable total", async function (assert) {
      // A cursor source that pages to completion knows its size only in retrospect. Without
      // this the set size stays -1 forever, even once every row is in hand.
      const { load } = recordingLoad(() => ({
        items: uniquePage(0, 7),
        hasMore: false,
      }));
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);

      assert.strictEqual(
        engine.total,
        7,
        "a declared-complete source reports what it handed us"
      );
    });

    test("hasMore:true never defeats the barren-page brake", async function (assert) {
      // The termination proof. `hasMore` is a claim from the source, and a source that
      // ignores `offset` while hardcoding `hasMore: true` would otherwise re-fetch
      // identical rows forever: the accumulator stays flat, so the cap guard never arms,
      // and every reveal mints a fresh load key past the per-key guard.
      const { load, calls } = recordingLoad(() => ({
        items: clientItems(20),
        hasMore: true,
      }));
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 8; i++) {
        await engine.loadItems(engine.loadContext);
        if (!engine.revealMore()) {
          break;
        }
      }

      assert.false(engine.canRevealMore, "the brake still stops it");
      assert.true(
        calls.length <= 3,
        `terminated in a bounded number of pages (${calls.length})`
      );
    });

    test("hasMore:true never pages past a reported total", async function (assert) {
      // The other safety clause: a source cannot claim more rows than it said exist.
      const { load, calls } = recordingLoad((offset) => ({
        items: uniquePage(offset, 10),
        total: 20,
        hasMore: true,
      }));
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 8; i++) {
        await engine.loadItems(engine.loadContext);
        if (!engine.revealMore()) {
          break;
        }
      }

      assert.false(engine.canRevealMore, "the reported total is a ceiling");
      assert.true(
        calls.length <= 3,
        `stopped at the total (${calls.length} pages)`
      );
    });

    test("a source stopped by the brake never gets to size the set", async function (assert) {
      // The one invariant this contract must hold. The barren-page brake is the "source is
      // replaying rows" detector: this source claims more forever while serving the same 20
      // rows behind a set of unknown size. Sizing the set from where the brake happened to
      // stop would announce "20 results" — a paging stop condition promoted into a factual
      // claim to assistive tech, from the one source already proven untrustworthy.
      const { load, calls } = recordingLoad(() => ({
        items: clientItems(20),
        hasMore: true,
      }));
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 6; i++) {
        await engine.loadItems(engine.loadContext);
        if (!engine.revealMore()) {
          break;
        }
      }

      assert.false(engine.canRevealMore, "the brake stopped the paging");
      assert.true(
        calls.length > 1,
        "the brake was what stopped it, not silence"
      );
      assert.strictEqual(
        engine.total,
        undefined,
        "but it says nothing about how many results exist"
      );
    });

    test("a truncated declared-complete page still hints and reports no total", async function (assert) {
      // 300 rows with `hasMore: false` both fills the cap and latches exhaustion. Without
      // consulting truncation the user gets exactly 200 rows with no hint, no total and no
      // sentinel: 100 results gone with zero signal.
      const { load } = recordingLoad(() => ({
        items: uniquePage(0, 300),
        hasMore: false,
      }));
      const engine = new SelectEngine({ load, maxLoaded: MAX_RENDERED });

      const result = await engine.loadItems(engine.loadContext);

      assert.strictEqual(
        result.length,
        MAX_RENDERED,
        "the render stays capped"
      );
      assert.true(engine.atCapWithMore, "the narrow hint still shows");
      assert.strictEqual(
        engine.total,
        undefined,
        "the loaded count is not the set size when rows were discarded"
      );
    });

    test("a declared-complete page outranks a larger reported total", async function (assert) {
      // "99 matched, you may see 5, no more pages" is a legitimate permission-filtered
      // shape. Letting the reported total win claims a sixth option that does not exist.
      const { load } = recordingLoad(() => ({
        items: uniquePage(0, 5),
        total: 99,
        hasMore: false,
      }));
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);

      assert.strictEqual(
        engine.total,
        5,
        "the set size describes navigable options, not matched rows"
      );
    });

    test("an overflow tail of duplicates is not truncation", async function (assert) {
      // Truncation must mean "a row we did not already hold was discarded at the cap", not
      // "the page was longer than the room left". 250 rows whose last 50 repeat ids already
      // held lose nothing, so the derived total survives.
      const { load } = recordingLoad(() => ({
        items: [
          ...uniquePage(0, MAX_RENDERED),
          ...uniquePage(0, 50).map((item) => ({ ...item })),
        ],
        hasMore: false,
      }));
      const engine = new SelectEngine({ load, maxLoaded: MAX_RENDERED });

      await engine.loadItems(engine.loadContext);

      assert.strictEqual(
        engine.total,
        MAX_RENDERED,
        "nothing was lost, so completeness still bounds the set"
      );
    });

    test("the derived total counts deduped rows, not the raw cursor", async function (assert) {
      // Overlapping pages make the raw cursor outrun the accumulator. Completeness bounds
      // the set at what is actually navigable, so the derived total must come from the
      // deduped rows — 15 distinct ids served as two 10-row pages overlapping by 5.
      const pages = [
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        [6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      ];
      let call = 0;
      const load = () =>
        Promise.resolve({
          items: pages[Math.min(call++, pages.length - 1)].map((id) => ({
            id,
            name: `Item ${id}`,
          })),
          hasMore: call < pages.length,
        });
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 6; i++) {
        await engine.loadItems(engine.loadContext);
        if (!engine.revealMore()) {
          break;
        }
      }

      assert.strictEqual(
        engine.total,
        15,
        "the set size is the distinct rows held, not the pages consumed"
      );
    });

    test("a new query drops the previous query's declared completeness", async function (assert) {
      const { load } = recordingLoad((offset) => ({
        items: uniquePage(offset, 6),
        hasMore: false,
      }));
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      assert.strictEqual(engine.total, 6, "settled and complete");

      engine.setFilter("q");
      assert.strictEqual(
        engine.total,
        undefined,
        "a new filter knows nothing about its own result count yet"
      );

      await engine.loadItems(engine.loadContext);
      assert.strictEqual(engine.total, 6, "the new query settles complete too");

      engine.reload();
      assert.strictEqual(
        engine.total,
        undefined,
        "reload() clears it as well as a filter change"
      );
    });

    test("a bare source overshooting the cap hints instead of losing rows silently", async function (assert) {
      // A source handing over more than the cap in one response has its tail discarded. It
      // declared completeness by staying silent, but 50 rows were dropped, so the count is
      // NOT a truthful set size and the user must be told the list is clipped.
      const { load } = recordingLoad(() => uniquePage(0, 250));
      const engine = new SelectEngine({ load, maxLoaded: MAX_RENDERED });

      const result = await engine.loadItems(engine.loadContext);

      assert.strictEqual(result.length, MAX_RENDERED, "the cap holds");
      assert.false(engine.canRevealMore, "there is no second page to ask for");
      assert.true(
        engine.atCapWithMore,
        "discarded rows are surfaced rather than silently dropped"
      );
      assert.strictEqual(
        engine.total,
        undefined,
        "and truncation withdraws the derived set size"
      );
    });

    test("a bare page landing exactly on the cap is complete, not clipped", async function (assert) {
      // The boundary the truncation flag exists to get right: the 200th row is the last one
      // pushed, so nothing was discarded. A "keep typing to narrow" hint here would be a lie.
      const { load } = recordingLoad(() => uniquePage(0, MAX_RENDERED));
      const engine = new SelectEngine({ load, maxLoaded: MAX_RENDERED });

      const result = await engine.loadItems(engine.loadContext);

      assert.strictEqual(result.length, MAX_RENDERED, "every row is mounted");
      assert.false(engine.atCapWithMore, "nothing was dropped, so no hint");
      assert.strictEqual(engine.total, MAX_RENDERED, "and the set is sized");
    });

    test("a bare array declares completeness and reports its count", async function (assert) {
      // The inverted contract stated directly. A source that says nothing about paging is
      // taken to have returned everything, which is what makes its count a truthful
      // `aria-setsize` rather than the -1 unknown encoding.
      const { load, calls } = recordingLoad(() => uniquePage(0, 10));
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);

      assert.strictEqual(calls.length, 1, "one fetch, no probing");
      assert.false(engine.canRevealMore, "nothing left to reveal");
      assert.strictEqual(engine.total, 10, "the count is the set size");
    });

    test("an empty bare response reports a set size of zero, like a client source", async function (assert) {
      const { load } = recordingLoad(() => []);
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);

      assert.strictEqual(
        engine.total,
        0,
        "an empty result set has a known size, not an unknown one"
      );
    });
  });
});

module(
  "Unit | ui-kit | SelectEngine | transformer safeguard",
  function (hooks) {
    setupTest(hooks);

    function page(offset, length) {
      return Array.from({ length }, (_, i) => ({
        id: offset + i + 1,
        name: `Item ${offset + i + 1}`,
      }));
    }

    function hideRows(predicate) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items) => items.filter((item) => !predicate(item)))
            )
        );
      });
    }

    /** Pages until a reveal is refused; false when six reveals all went through. */
    async function pageUntilRefused(engine) {
      for (let i = 0; i < 6; i++) {
        const { revealed } = await settleBuildAndReveal(engine);
        if (!revealed) {
          return true;
        }
      }
      return false;
    }

    /** Loads, renders the settled rows, then asks for more, as the listbox does. */
    async function settleBuildAndReveal(engine) {
      const rows = await engine.loadItems(engine.loadContext);
      const descriptors = engine.buildItems(rows);
      return { revealed: engine.revealMore(), descriptors };
    }

    test("two reveals with no visible growth stop paging", async function (assert) {
      const { load, calls } = recordingLoad((offset) => ({
        items: page(offset, 10),
        hasMore: true,
      }));
      hideRows((item) => item.id > 10);
      const engine = new SelectEngine({ load });

      const results = [];
      for (let i = 0; i < 6; i++) {
        const { revealed } = await settleBuildAndReveal(engine);
        results.push(revealed);
        if (!revealed) {
          break;
        }
      }

      assert.deepEqual(
        results,
        [true, true, false],
        "the second barren reveal is refused"
      );
      assert.strictEqual(calls.length, 3, "three loads, then no more");
      assert.false(engine.canRevealMore, "paging stays stopped");
    });

    test("two barren reveals stop paging when pages carry structural rows", async function (assert) {
      const { load, calls } = recordingLoad((offset) => ({
        items: [...page(offset, 1), { __divider: true }],
        hasMore: true,
      }));
      hideRows((item) => item.id > 1);
      const engine = new SelectEngine({ load });

      assert.true(
        await pageUntilRefused(engine),
        "a reveal is refused although every page holds a divider"
      );
      assert.strictEqual(calls.length, 3, "three loads, then no more");
    });

    test("a single barren reveal is tolerated and growth keeps paging", async function (assert) {
      const { load, calls } = recordingLoad((offset) => ({
        items: page(offset, 10),
        hasMore: offset < 40,
      }));
      // Every page keeps half its rows, except the second, which loses all of them.
      hideRows((item) => (item.id > 10 && item.id <= 20) || item.id % 2 === 0);
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 8; i++) {
        const { revealed } = await settleBuildAndReveal(engine);
        if (!revealed) {
          break;
        }
      }

      assert.strictEqual(
        calls.length,
        5,
        "paging runs until the source itself is done"
      );
    });

    test("a new filter or a reload pages again after the brake trips", async function (assert) {
      const { load, calls } = recordingLoad((offset) => ({
        items: page(offset, 10),
        hasMore: true,
      }));
      hideRows((item) => item.id > 10);
      const engine = new SelectEngine({ load });

      assert.true(await pageUntilRefused(engine), "the brake tripped");

      engine.setFilter("Item");
      const afterFilter = await settleBuildAndReveal(engine);
      assert.true(afterFilter.revealed, "a new query can reveal again");
      assert.strictEqual(
        calls.at(-1).offset,
        0,
        "and it started over from the first page"
      );

      assert.true(
        await pageUntilRefused(engine),
        "the brake trips again for that query"
      );

      engine.reload();
      const afterReload = await settleBuildAndReveal(engine);
      assert.true(afterReload.revealed, "a reload can reveal again");
    });

    test("a tripped brake sizes the set by the rows shown", async function (assert) {
      const { load } = recordingLoad((offset) => ({
        items: page(offset, 10),
        total: 100,
        hasMore: true,
      }));
      hideRows((item) => item.id > 10);
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 6; i++) {
        const { revealed } = await settleBuildAndReveal(engine);
        if (!revealed) {
          break;
        }
      }
      const descriptors = engine.buildItems(
        await engine.loadItems(engine.loadContext)
      );

      assert.strictEqual(
        engine.total,
        undefined,
        "the declared total no longer describes what can be reached"
      );
      assert.strictEqual(descriptors.length, 10, "ten rows are shown");
      assert.true(
        descriptors.every((descriptor) => descriptor.setSize === 10),
        "and the set is exactly those rows"
      );
    });

    test("reveals without a build in between never trip the brake", async function (assert) {
      const { load, calls } = recordingLoad((offset) => ({
        items: page(offset, 10),
        hasMore: true,
      }));
      hideRows((item) => item.id > 10);
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 5; i++) {
        await engine.loadItems(engine.loadContext);
        engine.revealMore();
      }

      assert.true(
        calls.length >= 5,
        `nothing was measured, so nothing stopped paging (${calls.length})`
      );
    });

    test("a render of the rows from before a reveal settled is not a measurement", async function (assert) {
      const { load, calls } = recordingLoad((offset) => ({
        items: page(offset, 10),
        hasMore: true,
      }));
      const engine = new SelectEngine({ load });

      const firstPage = await engine.loadItems(engine.loadContext);
      engine.buildItems(firstPage);
      const results = [];
      for (let i = 0; i < 4; i++) {
        results.push(engine.revealMore());
        await engine.loadItems(engine.loadContext);
        // The list can re-render rows it already had after a request clears and before the new
        // rows arrive. Such a render shows nothing about the page that just landed.
        engine.buildItems(firstPage);
      }

      assert.deepEqual(
        results,
        [true, true, true, true],
        "a growing list is never braked by a stale render"
      );
      assert.strictEqual(calls.length, 5, "every reveal loaded a page");
    });

    test("rows kept on screen during a pending client filter keep their own size", async function (assert) {
      const items = [
        { id: 1, name: "Apple red" },
        { id: 2, name: "Apple green" },
        { id: 3, name: "Cherry" },
      ];
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) => spec.content((rows) => rows.slice(0, 1)))
        );
      });
      const engine = new SelectEngine({ items });
      engine.setFilter("Apple");
      const retained = await engine.loadItems(engine.loadContext);
      engine.setFilter("");

      assert.strictEqual(
        engine.total,
        3,
        "the source already answers the new query"
      );
      assert.deepEqual(
        engine.buildItems(retained).map((row) => row.setSize),
        [1],
        "the rows still shown describe their own set"
      );
    });

    test("structural rows do not count toward the paged net change", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items) => [...items, { id: 2, name: "Banana" }])
            )
        );
      });
      const engine = new SelectEngine({
        load: () => ({
          items: [
            { id: 1, name: "Apple" },
            { __header: true, label: "Fruit" },
            { __divider: true },
          ],
          total: 100,
          hasMore: true,
        }),
      });
      const rows = engine.buildItems(
        await engine.loadItems(engine.loadContext)
      );
      assert.deepEqual(
        rows.filter((row) => row.setSize != null).map((row) => row.setSize),
        [101, 101],
        "only the added option adjusts the declared total"
      );
    });

    test("visible growth clears a barren streak", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items) =>
                items.filter((item) => item.id === 1 || item.id === 3)
              )
            )
        );
      });
      const engine = new SelectEngine({
        load: (_filter, { offset }) => ({
          items: [{ id: offset + 1, name: `Item ${offset + 1}` }],
          hasMore: true,
        }),
      });
      const reveals = [];
      for (let i = 0; i < 5; i++) {
        engine.buildItems(await engine.loadItems(engine.loadContext));
        reveals.push(engine.revealMore());
      }
      assert.deepEqual(
        reveals,
        [true, true, true, true, false],
        "growth separates two barren streaks, each tolerating one reveal"
      );
    });
  }
);

module(
  "Unit | ui-kit | SelectEngine | sticky leading accounting",
  function (hooks) {
    setupTest(hooks);

    test("hoisting source options preserves the declared asynchronous total", async function (assert) {
      const engine = new SelectEngine({
        load: () => ({
          items: [
            { id: 1, name: "Action", sticky: true },
            { id: 2, name: "Result" },
          ],
          total: 100,
          hasMore: true,
        }),
        getOptions: () => ({ noneRow: true }),
        specialItems: () => [{ id: "special", name: "Special", sticky: true }],
      });
      const rows = engine.buildItems(
        await engine.loadItems(engine.loadContext)
      );
      assert.deepEqual(
        rows.map((row) => row.setSize),
        [102, 102, 102, 102],
        "hoisted source rows count once alongside true specials and none"
      );
      assert.deepEqual(
        rows.map((row) => row.posInSet),
        [1, 2, 3, 4],
        "loaded positions remain contiguous"
      );
    });

    test("server pages containing only sticky actions still make visible progress", async function (assert) {
      const engine = new SelectEngine({
        load: (_filter, { offset }) => ({
          items: [{ id: offset, name: `Action ${offset}`, sticky: true }],
          hasMore: true,
        }),
      });
      for (let page = 0; page < 4; page++) {
        engine.buildItems(await engine.loadItems(engine.loadContext));
        assert.true(
          engine.canRevealMore,
          `page ${page} is visible growth before hoisting`
        );
        assert.true(engine.revealMore(), `page ${page} permits another reveal`);
      }
    });
  }
);

module(
  "Unit | ui-kit | SelectEngine | uncapped server source",
  function (hooks) {
    setupTest(hooks);

    function page(offset, length) {
      return Array.from({ length }, (_, i) => ({
        id: offset + i + 1,
        name: `Item ${offset + i + 1}`,
      }));
    }

    test("keeps paging past 200 rows when no maxLoaded is set", async function (assert) {
      const { load } = recordingLoad((offset) => ({
        items: page(offset, 60),
        hasMore: true,
      }));
      const engine = new SelectEngine({ load });

      let result;
      for (let i = 0; i < 6; i++) {
        result = await engine.loadItems(engine.loadContext);
        if (i < 5) {
          engine.revealMore();
        }
      }

      assert.strictEqual(
        result.length,
        360,
        "six 60-row pages accumulate past the former 200-row ceiling"
      );
      assert.true(
        engine.canRevealMore,
        "the source still declares more, so another reveal is allowed"
      );
      assert.false(engine.atCapWithMore, "no narrow hint without a cap");
    });

    test("keeps every row of a single response over 200 rows", async function (assert) {
      const { load } = recordingLoad(() => page(0, 250));
      const engine = new SelectEngine({ load });

      const result = await engine.loadItems(engine.loadContext);

      assert.strictEqual(result.length, 250, "no row is discarded");
      assert.false(engine.atCapWithMore, "nothing was clipped");
      assert.strictEqual(engine.total, 250, "the set is sized by every row");
    });

    test("maxLoaded restores the cap and the narrow hint", async function (assert) {
      const { load } = recordingLoad((offset) => ({
        items: page(offset, 60),
        hasMore: true,
      }));
      const engine = new SelectEngine({ load, maxLoaded: 120 });

      let result;
      for (let i = 0; i < 4; i++) {
        result = await engine.loadItems(engine.loadContext);
        engine.revealMore();
      }

      assert.strictEqual(result.length, 120, "paging stops at maxLoaded");
      assert.false(engine.canRevealMore, "no reveal past the cap");
      assert.true(engine.atCapWithMore, "the narrow hint shows at the cap");
    });

    test("hands a page's cursor to the next request", async function (assert) {
      const cursors = [];
      const load = (_filter, opts = {}) => {
        cursors.push(opts.cursor);
        const index = cursors.length;
        return Promise.resolve({
          items: page((index - 1) * 10, 10),
          hasMore: true,
          cursor: `after-${index}`,
        });
      };
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      assert.deepEqual(
        cursors,
        [undefined, "after-1", "after-2"],
        "each request receives the cursor the previous page returned"
      );
    });

    test("starts a new filter and a reload without a cursor", async function (assert) {
      const cursors = [];
      const load = (_filter, opts = {}) => {
        cursors.push(opts.cursor);
        return Promise.resolve({
          items: page(cursors.length * 10, 10),
          hasMore: true,
          cursor: `after-${cursors.length}`,
        });
      };
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      engine.setFilter("q");
      await engine.loadItems(engine.loadContext);

      engine.reload();
      await engine.loadItems(engine.loadContext);

      assert.deepEqual(
        cursors,
        [undefined, "after-1", undefined, undefined],
        "a new query and a reload never resume the previous query's cursor"
      );
    });

    test("keeps the last successful cursor after a failed page", async function (assert) {
      const cursors = [];
      const load = (_filter, opts = {}) => {
        cursors.push(opts.cursor);
        if (cursors.length === 2) {
          return Promise.reject(new Error("offline"));
        }
        return Promise.resolve({
          items: page(cursors.length * 10, 10),
          hasMore: true,
          cursor: `after-${cursors.length}`,
        });
      };
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await assert.rejects(engine.loadItems(engine.loadContext), /offline/);

      assert.true(engine.revealMore(), "the failed reveal can be retried");
      await engine.loadItems(engine.loadContext);

      assert.deepEqual(
        cursors,
        [undefined, "after-1", "after-1"],
        "the retry resumes from the page that last succeeded"
      );
    });

    test("opts.page numbers settled pages from 1, barren ones included", async function (assert) {
      const pages = [];
      const load = (_filter, opts = {}) => {
        pages.push(opts.page);
        // The second page repeats the first, so it adds nothing but still settles.
        const offset = pages.length === 2 ? 0 : (pages.length - 1) * 10;
        return Promise.resolve({ items: page(offset, 10), hasMore: true });
      };
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      assert.deepEqual(pages, [1, 2, 3], "each settled page advances by one");
    });

    test("opts.page restarts at 1 for a new filter and a reload", async function (assert) {
      const pages = [];
      const load = (_filter, opts = {}) => {
        pages.push(opts.page);
        return Promise.resolve({
          items: page(pages.length * 10, 10),
          hasMore: true,
        });
      };
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      engine.setFilter("q");
      await engine.loadItems(engine.loadContext);

      engine.reload();
      await engine.loadItems(engine.loadContext);

      assert.deepEqual(pages, [1, 2, 1, 1], "a new query starts again");
    });

    test("opts.page repeats for the retry of a failed page", async function (assert) {
      const pages = [];
      const load = (_filter, opts = {}) => {
        pages.push(opts.page);
        if (pages.length === 2) {
          return Promise.reject(new Error("offline"));
        }
        return Promise.resolve({
          items: page(pages.length * 10, 10),
          hasMore: true,
        });
      };
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await assert.rejects(engine.loadItems(engine.loadContext), /offline/);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      assert.deepEqual(pages, [1, 2, 2], "a failure is not counted");
    });

    test("opts.page repeats for a re-ask after an aborted page", async function (assert) {
      const pages = [];
      let release;
      const load = (_filter, opts = {}) => {
        pages.push(opts.page);
        if (pages.length === 2) {
          return new Promise((resolve) => (release = resolve));
        }
        return Promise.resolve({
          items: page(pages.length * 10, 10),
          hasMore: true,
        });
      };
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      const controller = new AbortController();
      const aborted = engine.loadItems(engine.loadContext, {
        signal: controller.signal,
      });
      await Promise.resolve();
      await Promise.resolve();
      controller.abort();
      await engine.loadItems(engine.loadContext);
      release({ items: page(10, 10), hasMore: true });
      await aborted;
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      assert.deepEqual(
        pages,
        [1, 2, 2, 3],
        "the aborted page is asked again under its number, and its late answer is not counted"
      );
    });

    test("opts.page ignores a superseded query's late page", async function (assert) {
      const pages = [];
      let release;
      const load = (filter, opts = {}) => {
        pages.push(opts.page);
        if (!filter) {
          return new Promise((resolve) => (release = resolve));
        }
        return Promise.resolve({
          items: page(pages.length * 10, 10),
          hasMore: true,
        });
      };
      const engine = new SelectEngine({ load });

      const stale = engine.loadItems(engine.loadContext);
      await Promise.resolve();
      await Promise.resolve();
      engine.setFilter("current");
      await engine.loadItems(engine.loadContext);
      release({ items: page(0, 10), hasMore: true });
      await stale;
      engine.revealMore();
      await engine.loadItems(engine.loadContext);

      assert.deepEqual(
        pages,
        [1, 1, 2],
        "only the current query's pages count"
      );
    });

    /**
     * A loader whose `held`-th call answers only when released, for requests abandoned in
     * flight. Every other call answers its page at once.
     */
    function heldLoad(held) {
      const pages = [];
      const gate = {};
      const load = (_filter, opts = {}) => {
        pages.push(opts.page);
        const response = {
          items: page((opts.page - 1) * 10, 10),
          hasMore: true,
        };
        if (pages.length === held) {
          return new Promise(
            (resolve) => (gate.release = () => resolve(response))
          );
        }
        return Promise.resolve(response);
      };
      return { load, pages, gate };
    }

    /** Aborts the held request once the loader has received it. */
    async function abandon(engine, gate) {
      const controller = new AbortController();
      const request = engine.loadItems(engine.loadContext, {
        signal: controller.signal,
      });
      for (let tick = 0; !gate.release && tick < 50; tick++) {
        await Promise.resolve();
      }
      controller.abort();
      // Wrapped so awaiting the helper does not wait for the held request itself.
      return { request };
    }

    test("an abandoned request that settles last leaves paging open", async function (assert) {
      const { load, pages, gate } = heldLoad(2);
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      const { request: abandoned } = await abandon(engine, gate);
      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      await engine.loadItems(engine.loadContext);
      gate.release();
      await abandoned;

      assert.deepEqual(pages, [1, 2, 2, 3], "the retry and a later page ran");
      assert.true(
        engine.canRevealMore,
        "the late answer does not mark the list as loading again"
      );
      assert.true(engine.revealMore(), "another page can be revealed");
    });

    test("an abandoned first request that settles last leaves paging open", async function (assert) {
      const { load, gate } = heldLoad(1);
      const engine = new SelectEngine({ load });

      const { request: abandoned } = await abandon(engine, gate);
      await engine.loadItems(engine.loadContext);
      gate.release();
      await abandoned;

      assert.true(engine.canRevealMore, "the retried first page counts");
    });

    test("an abandoned request that was never retried still finishes its load", async function (assert) {
      const { load, pages, gate } = heldLoad(2);
      const engine = new SelectEngine({ load });

      await engine.loadItems(engine.loadContext);
      engine.revealMore();
      const { request: abandoned } = await abandon(engine, gate);
      gate.release();
      await abandoned;

      assert.true(
        engine.canRevealMore,
        "the abandoned request ends its load instead of leaving it pending"
      );
      engine.revealMore();
      await engine.loadItems(engine.loadContext);
      assert.deepEqual(pages, [1, 2, 2], "the reveal asks again for its page");
    });

    test("de-duplicates each row once, not once per later page", async function (assert) {
      let keyReads = 0;
      const countedPage = (offset) =>
        Array.from({ length: 10 }, (_, i) => ({
          get id() {
            keyReads++;
            return offset + i + 1;
          },
          name: `Item ${offset + i + 1}`,
        }));
      const { load } = recordingLoad((offset) => ({
        items: countedPage(offset),
        hasMore: true,
      }));
      const engine = new SelectEngine({ load });

      for (let i = 0; i < 10; i++) {
        await engine.loadItems(engine.loadContext);
        engine.revealMore();
      }

      assert.true(
        keyReads <= 200,
        `100 rows over 10 pages read their key ${keyReads} times; re-keying every held row on each page would read it at least 550 times`
      );
    });
  }
);

module("Unit | ui-kit | SelectEngine | held value reuse", function (hooks) {
  setupTest(hooks);

  test("unchanged held values have bounded reads across rebuilds and public reads", function (assert) {
    const items = clientItems(1000);
    let reads = 0;
    const counted = (ids) =>
      new Proxy(ids, {
        get(target, property, receiver) {
          if (typeof property === "string" && /^\d+$/.test(property)) {
            reads++;
          }
          return Reflect.get(target, property, receiver);
        },
      });
    const state = trackedObject({
      value: counted(items.slice(0, 50).map((item) => item.id)),
    });
    const engine = new SelectEngine({
      items,
      multiple: true,
      getValue: () => state.value,
    });

    reads = 0;
    for (let rebuild = 0; rebuild < 5; rebuild++) {
      engine.setFilter(rebuild % 2 ? "Item" : "");
      engine.reload();
      const descriptors = engine.buildItems(
        engine.loadItems(engine.loadContext)
      );
      assert.strictEqual(
        descriptors.filter((row) => row.flags.selected).length,
        50,
        "each rebuild marks every held option"
      );
      assert.strictEqual(
        engine.value.length,
        50,
        "the public value stays current"
      );
      assert.true(engine.isSelected(items[0]), "direct selection reads agree");
    }
    assert.true(reads <= 100, `unchanged values cost ${reads} input reads`);

    reads = 0;
    state.value = counted([900, 901]);
    for (let rebuild = 0; rebuild < 5; rebuild++) {
      assert.deepEqual(
        engine
          .buildItems(items)
          .filter((row) => row.flags.selected)
          .map((row) => row.value),
        [900, 901],
        "replacement changes every subsequent rebuild"
      );
    }
    assert.true(reads <= 4, `the replacement costs ${reads} input reads`);
  });

  test("matching rows has bounded held-id conversions across rebuilds", function (assert) {
    const items = clientItems(1000);
    let conversions = 0;
    const value = items.slice(0, 50).map((item) => ({
      toString() {
        conversions++;
        return String(item.id);
      },
    }));
    const engine = new SelectEngine({
      items,
      multiple: true,
      getValue: () => value,
    });

    conversions = 0;
    for (let rebuild = 0; rebuild < 3; rebuild++) {
      assert.strictEqual(
        engine.buildItems(items).filter((row) => row.flags.selected).length,
        50,
        "object ids match rows by their string form"
      );
      assert.false(
        engine.isSelected(items[999]),
        "an unheld row stays unselected"
      );
    }
    assert.true(
      conversions <= 100,
      `matching unchanged held ids costs ${conversions} conversions`
    );
  });

  test("same-length tracked edits update hidden rows and emitted selections immediately", function (assert) {
    const items = clientItems(5);
    const value = trackedArray([1, 2]);
    const changes = [];
    const engine = new SelectEngine({
      items,
      multiple: true,
      hideSelected: true,
      getValue: () => value,
      onChange: (next) => changes.push(next),
    });
    const before = engine.value;
    assert.deepEqual(
      engine.buildItems(items).map((row) => row.value),
      [3, 4, 5],
      "held rows start hidden"
    );

    value.splice(0, 1, 3);
    assert.deepEqual(
      engine.buildItems(items).map((row) => row.value),
      [1, 4, 5],
      "a same-length splice changes the hidden set"
    );
    value[1] = 4;
    assert.false(
      engine.isSelected(items[1]),
      "index replacement releases the old id"
    );
    assert.true(
      engine.isSelected(items[3]),
      "index replacement holds the new id"
    );
    engine.select(items[4]);
    engine.deselect(items[2]);
    assert.deepEqual(
      changes,
      [[3, 4, 5], [4]],
      "actions use the current consumer value without assuming emitted changes were applied"
    );
    assert.deepEqual(
      before,
      [1, 2],
      "earlier public snapshots remain unchanged"
    );
    assert.true(
      Object.isFrozen(engine.value),
      "the current public snapshot is frozen"
    );
    value.length = 0;
    assert.false(
      engine.hasValue,
      "truncating the tracked collection clears the selection"
    );
    assert.deepEqual(
      engine.buildItems(items).map((row) => row.value),
      [1, 2, 3, 4, 5],
      "truncating releases every hidden row"
    );
  });

  test("tracked growth and replacement update limits before the next action", function (assert) {
    const items = clientItems(5);
    const state = trackedObject({ value: trackedArray([1]) });
    const changes = [];
    const engine = new SelectEngine({
      items,
      multiple: true,
      maximum: 2,
      minimum: 2,
      getValue: () => state.value,
      onChange: (next) => changes.push(next),
    });
    assert.true(engine.belowMinimum, "the initial value is below the minimum");
    assert.strictEqual(engine.remaining, 1, "one slot starts available");
    state.value.push(2);
    assert.true(engine.atMaximum, "in-place growth reaches the cap");
    assert.false(engine.belowMinimum, "in-place growth reaches the minimum");
    engine.select(items[2]);
    assert.deepEqual(changes, [], "the cap rejects an immediate add");

    state.value = [4];
    assert.strictEqual(engine.remaining, 1, "replacement restores a slot");
    engine.select(items[2]);
    assert.deepEqual(
      changes,
      [[4, 3]],
      "the next add preserves the replacement"
    );
  });

  test("mode readers remain live while the held value stays unchanged", function (assert) {
    let multiple = true;
    const value = [2];
    const engine = new SelectEngine({
      items: clientItems(5),
      getMultiple: () => multiple,
      getValue: () => value,
    });
    assert.deepEqual(engine.value, [2], "multi mode starts with an array");
    multiple = false;
    assert.strictEqual(
      engine.value,
      2,
      "the live mode reader changes the public shape"
    );
    multiple = true;
    assert.deepEqual(
      engine.value,
      [2],
      "switching back restores the multi shape"
    );
  });

  test("normalization keeps first ids, nullish counting and mode changes reactive", function (assert) {
    const items = clientItems(5);
    const state = trackedObject({
      value: [1, "1", null, undefined, 0, "0"],
      multiple: true,
    });
    const engine = new SelectEngine({
      items,
      getMultiple: () => state.multiple,
      getValue: () => state.value,
    });
    assert.deepEqual(
      engine.value,
      [1, null, 0],
      "equivalent ids retain their first occurrence, including nullish ids"
    );
    assert.true(Object.isFrozen(engine.value), "multi values are frozen");
    assert.false(
      engine.isSelected({ id: null }),
      "nullish ids never match an ordinary row"
    );

    state.value = [2];
    state.multiple = false;
    assert.strictEqual(engine.value, 2, "single mode exposes the id");
    assert.true(engine.isSelected(items[1]), "single mode matches the new id");
    state.value = null;
    assert.strictEqual(engine.value, null, "an empty single selection is null");
    assert.true(
      engine.isSelected({ __none: true, id: null }),
      "the none row represents empty single selection"
    );
    state.multiple = true;
    assert.deepEqual(engine.value, [], "empty multi mode exposes an array");
    state.value = 0;
    assert.deepEqual(
      engine.value,
      [0],
      "a falsy scalar is retained in multi mode"
    );
    assert.true(
      engine.isSelected({ id: "0" }),
      "falsy ids still match by string form"
    );
  });
});
