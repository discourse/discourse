import { trackedObject } from "@ember/reactive/collections";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SelectEngine from "discourse/ui-kit/select/select-engine";

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

    test("filtering honors labelField and both filterBy forms", function (assert) {
      const labelEngine = new SelectEngine({
        items: [
          ...items(50, { prefix: "Hidden" }),
          { id: 51, title: "Visible result" },
        ],
        labelField: "title",
      });
      labelEngine.setFilter("VISIBLE");
      assert.deepEqual(
        labelEngine.loadItems(labelEngine.loadContext).map((item) => item.id),
        [51],
        "labelField filtering selects the single visible row out of the corpus"
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

    test("a large client list renders in full with no reveal or cap", function (assert) {
      const engine = new SelectEngine({ items: items(MAX_RENDERED + 1) });

      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        MAX_RENDERED + 1,
        "the whole client list renders, past the retired 200-row client cap"
      );
      assert.false(
        engine.canRevealMore,
        "a client source has no page to reveal"
      );
      assert.false(
        engine.revealMore(),
        "revealMore is an inert no-op for a client source"
      );
      assert.false(
        engine.atCapWithMore,
        "no client cap means the narrow hint never fires"
      );
      assert.strictEqual(
        engine.loadItems(engine.loadContext).length,
        MAX_RENDERED + 1,
        "the inert reveal left the rendered set whole"
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

  module("grouping", function () {
    // Descriptors for the current filtered list, the way the component builds them.
    function descriptors(engine) {
      return engine.buildItems(engine.loadItems(engine.loadContext));
    }

    function kinds(rows) {
      return rows.map((row) =>
        row.flags.group
          ? `H:${row.item.label}`
          : row.flags.divider
            ? "DIV"
            : row.value
      );
    }

    function options(rows) {
      return rows.filter((row) => !row.flags.group && !row.flags.divider);
    }

    test("groupBy injects a header before each group in first-appearance order", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Carrot", group: "Vegetables" },
          { id: 2, name: "Apple", group: "Fruits" },
          { id: 3, name: "Pea", group: "Vegetables" },
        ],
        groupBy: "group",
      });

      assert.deepEqual(
        kinds(descriptors(engine)),
        ["H:Vegetables", 1, 3, "H:Fruits", 2],
        "each group is preceded by its header; group and row order follow first appearance"
      );
    });

    test("a header row is non-selectable and carries no ARIA position", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Pear", group: "Fruits" },
        ],
        groupBy: "group",
      });
      const header = descriptors(engine).find((row) => row.flags.group);

      assert.true(header.flags.group, "the header carries the group flag");
      assert.false(header.flags.selected, "a header is never selected");
      assert.strictEqual(
        header.posInSet,
        undefined,
        "a header has no position in the option set"
      );
      assert.strictEqual(header.setSize, undefined, "a header has no set size");
    });

    test("options are numbered over options only, ignoring interleaved headers", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Carrot", group: "Vegetables" },
          { id: 2, name: "Apple", group: "Fruits" },
          { id: 3, name: "Pea", group: "Vegetables" },
        ],
        groupBy: "group",
      });
      const opts = options(descriptors(engine));

      assert.deepEqual(
        opts.map((option) => option.posInSet),
        [1, 2, 3],
        "posInSet counts options across groups, skipping headers"
      );
      opts.forEach((option) =>
        assert.strictEqual(
          option.setSize,
          3,
          "setSize is the option count, not the row count"
        )
      );
    });

    test("groupBy accepts a function and groupLabel maps the key to header text", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "A", level: 2 },
          { id: 2, name: "B", level: 2 },
        ],
        groupBy: (item) => item.level,
        groupLabel: (key) => `Level ${key}`,
      });
      const header = descriptors(engine).find((row) => row.flags.group);

      assert.strictEqual(
        header.item.label,
        "Level 2",
        "groupLabel produces the header text from the group key"
      );
    });

    test("a group whose rows all filter out drops its header", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Carrot", group: "Vegetables" },
        ],
        groupBy: "group",
      });
      engine.setFilter("apple");
      const rows = descriptors(engine);

      assert.deepEqual(
        rows.filter((row) => row.flags.group).map((row) => row.item.label),
        ["Fruits"],
        "only the surviving group keeps a header"
      );
      assert.deepEqual(
        options(rows).map((option) => option.value),
        [1],
        "only the surviving option remains"
      );
      assert.strictEqual(
        options(rows)[0].setSize,
        1,
        "setSize reflects the one surviving option"
      );
    });

    test("without groupBy, descriptor positions are unchanged", function (assert) {
      const engine = new SelectEngine({ items: items(3) });
      const rows = descriptors(engine);

      assert.true(
        rows.every((row) => !row.flags.group && !row.flags.divider),
        "no structural rows are injected without groupBy"
      );
      assert.deepEqual(
        rows.map((row) => row.posInSet),
        [1, 2, 3],
        "options keep their contiguous 1-based positions"
      );
      rows.forEach((row) =>
        assert.strictEqual(row.setSize, 3, "setSize is unchanged")
      );
    });

    test("a divider marker row is normalized as a skipped structural row", function (assert) {
      const engine = new SelectEngine({ items: items(2) });
      const rows = engine.buildItems([
        { __divider: true },
        ...engine.loadItems(engine.loadContext),
      ]);

      assert.true(rows[0].flags.divider, "the marker sets the divider flag");
      assert.false(rows[0].flags.selected, "a divider is never selected");
      assert.strictEqual(
        rows[0].posInSet,
        undefined,
        "a divider has no option position"
      );
      assert.deepEqual(
        options(rows).map((option) => option.posInSet),
        [1, 2],
        "options after a divider are numbered from one"
      );
    });

    test("a special option is numbered before the grouped options", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Carrot", group: "Vegetables" },
        ],
        groupBy: "group",
        specialItems: () => [{ id: 0, name: "None" }],
      });
      const rows = descriptors(engine);
      const opts = options(rows);

      assert.deepEqual(
        opts.map((option) => option.value),
        [0, 1, 2],
        "the special row leads, then the grouped options"
      );
      assert.deepEqual(
        opts.map((option) => option.posInSet),
        [1, 2, 3],
        "the special row is position one; grouped options follow"
      );
      opts.forEach((option) =>
        assert.strictEqual(
          option.setSize,
          3,
          "setSize counts the special plus the grouped options, not the headers"
        )
      );
      assert.deepEqual(
        rows.filter((row) => row.flags.group).map((row) => row.item.label),
        ["Fruits", "Vegetables"],
        "each group still gets a header"
      );
    });

    test("the create row closes the set after the grouped options", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Beet", group: "Vegetables" },
        ],
        groupBy: "group",
        allowCreate: true,
        createItem: (filter) => ({
          id: `new:${filter}`,
          name: filter,
          __create: true,
        }),
      });
      engine.setFilter("Ap");
      const rows = descriptors(engine);
      const opts = options(rows);

      assert.true(
        rows.at(-1).flags.__create,
        "the create row is appended after the groups, never inside one"
      );
      assert.deepEqual(
        opts.map((option) => option.flags.__create),
        [false, true],
        "the surviving option, then the create row"
      );
      assert.deepEqual(
        opts.map((option) => option.posInSet),
        [1, 2],
        "the create row closes the set at the last option position"
      );
      opts.forEach((option) =>
        assert.strictEqual(option.setSize, 2, "setSize counts both options")
      );
      assert.deepEqual(
        rows.filter((row) => row.flags.group).map((row) => row.item.label),
        ["Fruits"],
        "only the surviving group keeps a header"
      );
    });
  });
});
