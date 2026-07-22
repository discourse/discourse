import { trackedObject } from "@ember/reactive/collections";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SelectEngine from "discourse/ui-kit/select/select-engine";

const CLIENT_CHUNK = 50;
const MAX_RENDERED = 200;

function items(count, { start = 1, prefix = "Item" } = {}) {
  return Array.from({ length: count }, (_, index) => ({
    id: start + index,
    name: `${prefix} ${start + index}`,
  }));
}

module("Unit | ui-kit | SelectEngine | source normalization", function (hooks) {
  setupTest(hooks);

  module("client source", function () {
    test("loadItems remains synchronous without a pending phase", function (assert) {
      const engine = new SelectEngine({ items: items(2) });

      const result = engine.loadItems(engine.loadContext);

      assert.true(
        Array.isArray(result),
        "loadItems returns an array immediately"
      );
      assert.strictEqual(
        typeof result?.then,
        "undefined",
        "loadItems does not return a thenable"
      );
      assert.false(engine.isAsync, "a client source is not asynchronous");
      assert.false(engine.serverPending, "a client source is never pending");
    });

    test("derived reads follow a live items thunk", function (assert) {
      const source = trackedObject({
        items: [
          { id: 1, name: "Apple" },
          { id: 2, name: "Banana" },
        ],
      });
      const engine = new SelectEngine({ items: () => source.items });
      engine.setFilter("ap");

      assert.deepEqual(
        engine.filteredItems.map((item) => item.id),
        [1],
        "the initial filtered projection reads the thunk"
      );
      assert.strictEqual(engine.total, 1, "the initial total reads the thunk");

      source.items = [
        { id: 3, name: "Apricot" },
        { id: 4, name: "Grape" },
        { id: 5, name: "Banana" },
      ];

      assert.deepEqual(
        engine.filteredItems.map((item) => item.id),
        [3, 4],
        "filteredItems follows the replacement array"
      );
      assert.strictEqual(
        engine.total,
        2,
        "total follows the replacement array"
      );
      assert.deepEqual(
        engine.loadItems(engine.loadContext).map((item) => item.id),
        [3, 4],
        "loadItems follows the replacement array"
      );
    });

    test("filtering honors labelField and both filterBy forms before windowing", function (assert) {
      const labelEngine = new SelectEngine({
        items: [
          ...items(CLIENT_CHUNK, { prefix: "Hidden" }),
          { id: 51, title: "Visible result" },
        ],
        labelField: "title",
      });
      labelEngine.setFilter("VISIBLE");
      assert.deepEqual(
        labelEngine.loadItems(labelEngine.loadContext).map((item) => item.id),
        [51],
        "labelField filtering occurs before the first window is sliced"
      );

      const fieldEngine = new SelectEngine({
        items: [
          { id: 1, name: "same value", keywords: "hidden" },
          { id: 1, name: "same value", keywords: "needle" },
        ],
        filterBy: "keywords",
      });
      fieldEngine.setFilter("NEEDLE");
      assert.strictEqual(
        fieldEngine.loadItems(fieldEngine.loadContext)[0].keywords,
        "needle",
        "string filterBy runs before duplicate values could be discarded"
      );

      const predicateEngine = new SelectEngine({
        items: [
          { id: 1, name: "Alpha", enabled: false },
          { id: 2, name: "Beta", enabled: true },
        ],
        filterBy: (item, term) => item.enabled && term === "enabled",
      });
      predicateEngine.setFilter("ENABLED");
      assert.deepEqual(
        predicateEngine
          .loadItems(predicateEngine.loadContext)
          .map((item) => item.id),
        [2],
        "predicate filterBy receives the normalized term"
      );
    });

    test("total is the filtered length rather than the corpus length", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Match one" },
          { id: 2, name: "Miss" },
          { id: 3, name: "Match two" },
        ],
      });
      engine.setFilter("match");

      assert.strictEqual(
        engine.total,
        2,
        "only filtered rows contribute to total"
      );
    });

    test("reveal state grows by chunks and stops at the client cap", function (assert) {
      const engine = new SelectEngine({ items: items(MAX_RENDERED + 1) });

      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        CLIENT_CHUNK,
        "the initial window is one client chunk"
      );
      assert.true(
        engine.canRevealMore,
        "another chunk can initially be revealed"
      );
      assert.false(engine.atCapWithMore, "the initial window is below the cap");

      assert.true(engine.revealMore(), "the second chunk can be revealed");
      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        CLIENT_CHUNK * 2,
        "revealMore grows the prefix by one chunk"
      );

      assert.true(engine.revealMore(), "the third chunk can be revealed");
      assert.true(engine.revealMore(), "the fourth chunk can be revealed");
      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        MAX_RENDERED,
        "the client window stops at the render cap"
      );
      assert.false(
        engine.canRevealMore,
        "nothing can be revealed past the cap"
      );
      assert.true(engine.atCapWithMore, "the extra filtered row is reported");
      assert.false(engine.revealMore(), "revealMore refuses to pass the cap");

      const exactFit = new SelectEngine({ items: items(MAX_RENDERED) });
      exactFit.revealMore();
      exactFit.revealMore();
      exactFit.revealMore();
      assert.false(
        exactFit.atCapWithMore,
        "an exact-cap result does not claim hidden rows"
      );
    });

    test("resolveSelection uses the unfiltered client corpus", function (assert) {
      const hidden = { id: 2, name: "Banana" };
      const engine = new SelectEngine({
        items: [{ id: 1, name: "Apple" }, hidden],
      });
      engine.setFilter("apple");

      assert.deepEqual(
        engine.loadItems(engine.loadContext).map((item) => item.id),
        [1],
        "the current list excludes the held value"
      );
      assert.strictEqual(
        engine.resolveSelection(2),
        hidden,
        "the held value still resolves from the full corpus"
      );
    });
  });

  module("server source", function () {
    test("remains async, forwards paging options, and accumulates until complete", async function (assert) {
      const calls = [];
      const controller = new AbortController();
      const engine = new SelectEngine({
        load: (filter, opts) => {
          calls.push({ filter, ...opts });
          if (opts.offset === 0) {
            return Promise.resolve({
              items: items(2),
              total: 3,
              hasMore: true,
            });
          }
          return Promise.resolve({
            items: items(1, { start: 3 }),
            total: 3,
            hasMore: false,
          });
        },
      });
      engine.setFilter("query");

      const first = engine.loadItems(engine.loadContext, {
        signal: controller.signal,
      });
      assert.strictEqual(
        typeof first?.then,
        "function",
        "a server load returns a promise"
      );
      assert.true(engine.isAsync, "a server source remains asynchronous");
      assert.deepEqual(
        (await first).map((item) => item.id),
        [1, 2],
        "the first page is returned"
      );

      assert.true(engine.revealMore(), "hasMore permits another page");
      const accumulated = await engine.loadItems(engine.loadContext, {
        signal: controller.signal,
      });

      assert.deepEqual(
        accumulated.map((item) => item.id),
        [1, 2, 3],
        "the second page is appended to the first"
      );
      assert.deepEqual(
        calls.map(({ filter, offset, limit, signal }) => ({
          filter,
          offset,
          limit,
          signal,
        })),
        [
          {
            filter: "query",
            offset: 0,
            limit: undefined,
            signal: controller.signal,
          },
          {
            filter: "query",
            offset: 2,
            limit: 2,
            signal: controller.signal,
          },
        ],
        "filter, offset, learned limit, and signal are forwarded"
      );
      assert.strictEqual(engine.total, 3, "the reported total is retained");
      assert.false(engine.canRevealMore, "hasMore false ends paging");
    });
  });
});
