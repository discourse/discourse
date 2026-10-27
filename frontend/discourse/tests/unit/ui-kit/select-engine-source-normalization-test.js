import { trackedArray, trackedObject } from "@ember/reactive/collections";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
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

    // Header tests opt into labels explicitly: `groupBy` alone means splitter
    // boundaries, so a labeled group always names its label source.
    const identityLabel = (key) => key;

    /** Text boundaries print their label, action boundaries their name, options their id. */
    function kinds(rows) {
      return rows.map((row) => {
        const { action, divider, groupFooter, groupHeader } = row.flags;
        if (divider) {
          return "DIV";
        }
        if (groupHeader || groupFooter) {
          const prefix = `${action ? "A" : ""}${groupHeader ? "H" : "F"}`;
          return `${prefix}:${action ? row.item.name : row.item.label}`;
        }
        return row.value;
      });
    }

    function options(rows) {
      return rows.filter(
        (row) => !row.flags.textBoundary && !row.flags.divider
      );
    }

    /** A paging engine whose pages are the given row lists, in order. */
    function pagedEngine(pages, extra = {}) {
      return new SelectEngine({
        load: (_filter, opts = {}) =>
          Promise.resolve({
            items: pages[opts.page - 1] ?? [],
            hasMore: opts.page < pages.length,
          }),
        groupBy: "group",
        groupHeader: identityLabel,
        ...extra,
      });
    }

    async function loadAll(engine, pageCount) {
      let loaded = await engine.loadItems(engine.loadContext);
      for (let page = 1; page < pageCount; page++) {
        engine.revealMore();
        loaded = await engine.loadItems(engine.loadContext);
      }
      return loaded;
    }

    const member = (id, group) => ({ id, name: `Row ${id}`, group });

    module("stable keys", function () {
      const keyOf = (rows, predicate) => rows.find(predicate)?.key;
      const isHeader = (label) => (row) =>
        row.flags.groupHeader && row.item.label === label;

      test("a header keeps its key when the create row disappears", function (assert) {
        const fruits = [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Apricot", group: "Fruits" },
        ];
        const engine = new SelectEngine({
          items: fruits,
          groupBy: "group",
          groupHeader: identityLabel,
          allowCreate: true,
          createItem: (filter) => ({ id: filter, name: filter }),
        });

        engine.setFilter("ap");
        const withCreate = engine.buildItems(fruits);
        engine.setFilter("apple");
        const withoutCreate = engine.buildItems(fruits);

        assert.true(
          withCreate.some((row) => row.flags.__create),
          "the first build offers the create row"
        );
        assert.false(
          withoutCreate.some((row) => row.flags.__create),
          "the second build does not"
        );
        assert.strictEqual(
          keyOf(withoutCreate, isHeader("Fruits")),
          keyOf(withCreate, isHeader("Fruits")),
          "the header's key does not follow its position"
        );
      });

      test("emptying an earlier group does not move a later group's keys", function (assert) {
        const produce = [
          { id: 1, name: "Carrot", group: "Vegetables" },
          { id: 2, name: "Apple", group: "Fruits" },
        ];
        const value = trackedArray([]);
        const engine = new SelectEngine({
          items: produce,
          multiple: true,
          hideSelected: true,
          getValue: () => value,
          groupBy: "group",
          groupHeader: identityLabel,
        });

        const before = keyOf(engine.buildItems(produce), isHeader("Fruits"));
        value.push(1);
        const after = engine.buildItems(produce);

        assert.false(
          after.some(isHeader("Vegetables")),
          "the emptied group is gone"
        );
        assert.strictEqual(
          keyOf(after, isHeader("Fruits")),
          before,
          "the later header keeps its key"
        );
      });

      test("the none row never shares a key with a record", function (assert) {
        const records = [{ id: "__row:0", name: "Looks synthetic" }];
        const engine = new SelectEngine({ items: records, noneLabel: "None" });

        const keys = engine.buildItems(records).map((row) => row.key);

        assert.strictEqual(keys.length, 2, "both rows are listed");
        assert.strictEqual(new Set(keys).size, 2, "their keys differ");
      });

      test("a record whose id looks like an engine key is escaped", function (assert) {
        const engine = new SelectEngine({
          items: [],
          groupBy: "group",
          groupHeader: identityLabel,
        });
        const sample = [{ id: 1, name: "Apple", group: "Fruits" }];
        const headerKey = keyOf(engine.buildItems(sample), isHeader("Fruits"));

        const rows = engine.buildItems([
          ...sample,
          { id: headerKey, name: "Impostor", group: "Fruits" },
        ]);
        const keys = rows.map((row) => row.key);

        assert.strictEqual(
          new Set(keys).size,
          keys.length,
          "every key is unique"
        );
        assert.strictEqual(
          keyOf(rows, isHeader("Fruits")),
          headerKey,
          "the header keeps its own key"
        );
      });

      test("group keys that print the same form one group", function (assert) {
        const numbered = [
          { id: 1, name: "One", group: 1 },
          { id: 2, name: "Two", group: "1" },
        ];
        const engine = new SelectEngine({
          items: numbered,
          groupBy: "group",
          groupHeader: (key) => `Group ${key}`,
        });

        assert.deepEqual(
          kinds(engine.buildItems(numbered)),
          ["H:Group 1", 1, 2],
          "the number 1 and the string 1 share a header"
        );
      });
    });

    test("groupBy injects a header before each group in first-appearance order", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Carrot", group: "Vegetables" },
          { id: 2, name: "Apple", group: "Fruits" },
          { id: 3, name: "Pea", group: "Vegetables" },
        ],
        groupBy: "group",
        groupHeader: identityLabel,
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
        groupHeader: identityLabel,
      });
      const header = descriptors(engine).find((row) => row.flags.groupHeader);

      assert.true(
        header.flags.groupHeader,
        "the header carries the group flag"
      );
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
        groupHeader: identityLabel,
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

    test("groupBy accepts a function and groupHeader maps the key to header text", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "A", level: 2 },
          { id: 2, name: "B", level: 2 },
        ],
        groupBy: (item) => item.level,
        groupHeader: (key) => `Level ${key}`,
      });
      const header = descriptors(engine).find((row) => row.flags.groupHeader);

      assert.strictEqual(
        header.item.label,
        "Level 2",
        "groupHeader produces the header text from the group key"
      );
    });

    test("a group whose rows all filter out drops its header", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Carrot", group: "Vegetables" },
        ],
        groupBy: "group",
        groupHeader: identityLabel,
      });
      engine.setFilter("apple");
      const rows = descriptors(engine);

      assert.deepEqual(
        rows
          .filter((row) => row.flags.groupHeader)
          .map((row) => row.item.label),
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
        rows.every((row) => !row.flags.groupHeader && !row.flags.divider),
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
        groupHeader: identityLabel,
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
        rows
          .filter((row) => row.flags.groupHeader)
          .map((row) => row.item.label),
        ["Fruits", "Vegetables"],
        "each group still gets a header"
      );
    });

    test("the create row leads the set before the grouped options", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Beet", group: "Vegetables" },
        ],
        groupBy: "group",
        groupHeader: identityLabel,
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
        rows[0].flags.__create,
        "the create row is prepended before the groups, never inside one"
      );
      assert.deepEqual(
        opts.map((option) => option.flags.__create),
        [true, false],
        "the create row, then the surviving option"
      );
      assert.deepEqual(
        opts.map((option) => option.posInSet),
        [1, 2],
        "the create row opens the set at the first option position"
      );
      opts.forEach((option) =>
        assert.strictEqual(option.setSize, 2, "setSize counts both options")
      );
      assert.deepEqual(
        rows
          .filter((row) => row.flags.groupHeader)
          .map((row) => row.item.label),
        ["Fruits"],
        "only the surviving group keeps a header"
      );
    });

    test("groupBy without groupHeader renders splitter boundaries, not headers", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Carrot", group: "Vegetables" },
          { id: 2, name: "Apple", group: "Fruits" },
          { id: 3, name: "Pea", group: "Vegetables" },
        ],
        groupBy: "group",
      });
      const rows = descriptors(engine);

      assert.deepEqual(
        kinds(rows),
        [1, 3, "DIV", 2],
        "group boundaries render as splitters; the leading boundary is suppressed"
      );
      assert.true(
        rows.every((row) => !row.flags.groupHeader),
        "no header row exists without groupHeader"
      );
      assert.deepEqual(
        options(rows).map((option) => option.groupOrdinal),
        [0, 0, 1],
        "every group carries an ordinal, with or without a header"
      );
      assert.deepEqual(
        options(rows).map((option) => option.posInSet),
        [1, 2, 3],
        "positions stay global and contiguous across splitters"
      );
      options(rows).forEach((option) =>
        assert.strictEqual(
          option.setSize,
          3,
          "setSize counts options only, never splitters"
        )
      );
    });

    test("a nullish groupHeader turns that boundary into a splitter", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Carrot", group: "Vegetables" },
          { id: 3, name: "Oat", group: "Grains" },
        ],
        groupBy: "group",
        groupHeader: (key) => (key === "Vegetables" ? key : null),
      });
      const rows = descriptors(engine);

      assert.deepEqual(
        kinds(rows),
        [1, "H:Vegetables", 2, "DIV", 3],
        "unlabeled first boundary is suppressed; labeled boundary is a header; later unlabeled boundary is a splitter"
      );
      assert.deepEqual(
        rows
          .filter((row) => row.flags.groupHeader)
          .map((row) => row.groupOrdinal),
        [1],
        "a header takes its group's ordinal, which counts every group"
      );
      assert.deepEqual(
        options(rows).map((option) => option.groupOrdinal),
        [0, 1, 2],
        "options carry their group's ordinal, headed or not"
      );
    });

    test("a labeled group may lead; the next unlabeled boundary is a splitter", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Carrot", group: "Vegetables" },
        ],
        groupBy: "group",
        groupHeader: (key) => (key === "Fruits" ? key : null),
      });

      assert.deepEqual(
        kinds(descriptors(engine)),
        ["H:Fruits", 1, "DIV", 2],
        "a leading header renders; only splitters are suppressed at the head"
      );
    });

    test("splitters are recomputed from the filtered list", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "a" },
          { id: 2, name: "Banana", group: "b" },
          { id: 3, name: "Apricot", group: "c" },
        ],
        groupBy: "group",
      });
      engine.setFilter("ap");

      assert.deepEqual(
        kinds(descriptors(engine)),
        [1, "DIV", 3],
        "one splitter separates the two surviving groups; none is orphaned"
      );
    });

    test("the create row is never tagged with a group", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Beet", group: "Vegetables" },
        ],
        groupBy: "group",
        groupHeader: identityLabel,
        allowCreate: true,
        createItem: (filter) => ({
          id: `new:${filter}`,
          name: filter,
          __create: true,
        }),
      });
      engine.setFilter("Ap");
      const rows = descriptors(engine);
      const createRow = rows[0];

      assert.true(
        createRow.flags.__create,
        "the leading row is the create row"
      );
      assert.strictEqual(
        createRow.groupOrdinal,
        undefined,
        "the create row belongs to no group"
      );
      assert.strictEqual(
        options(rows)[1].groupOrdinal,
        0,
        "the surviving grouped option keeps its group tagging"
      );
    });

    test("an empty-string label is a header; only a nullish label is a splitter", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Carrot", group: "Vegetables" },
        ],
        groupBy: "group",
        groupHeader: () => "",
      });

      assert.deepEqual(
        kinds(descriptors(engine)),
        ["H:", 1, "H:", 2],
        "an empty string is a deliberate (if blank) header, never a splitter"
      );
    });

    test("an upstream structural row is dropped while grouping is active", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Carrot", group: "Vegetables" },
        ],
        groupBy: "group",
        groupHeader: identityLabel,
      });
      const rows = engine.buildItems([
        { __divider: true },
        ...engine.loadItems(engine.loadContext),
      ]);

      assert.deepEqual(
        kinds(rows),
        ["H:Fruits", 1, "H:Vegetables", 2],
        "grouping re-derives all structure; an injected structural row is not grouped or kept"
      );
    });

    test("group ordinals stay dense across an interleaved splitter", function (assert) {
      const engine = new SelectEngine({
        items: [
          { id: 1, name: "Apple", group: "Fruits" },
          { id: 2, name: "Carrot", group: "Vegetables" },
          { id: 3, name: "Oat", group: "Grains" },
        ],
        groupBy: "group",
        groupHeader: (key) => (key === "Vegetables" ? null : key),
      });
      const rows = descriptors(engine);

      assert.deepEqual(
        kinds(rows),
        ["H:Fruits", 1, "DIV", 2, "H:Grains", 3],
        "labeled, unlabeled, and labeled boundaries render in order"
      );
      assert.deepEqual(
        rows
          .filter((row) => row.flags.groupHeader)
          .map((row) => row.groupOrdinal),
        [0, 2],
        "the splitter-bounded group between them takes an ordinal too"
      );
      assert.deepEqual(
        options(rows).map((option) => option.groupOrdinal),
        [0, 1, 2],
        "ordinals stay dense over every group"
      );
    });

    test("groupBy matching the value field is rejected outright", function (assert) {
      assert.throws(
        () => new SelectEngine({ items: items(2), groupBy: "id" }),
        /value field/,
        "grouping by the default value field is certain misuse"
      );
      assert.throws(
        () =>
          new SelectEngine({
            items: [{ slug: "a", name: "A" }],
            valueField: "slug",
            groupBy: "slug",
          }),
        /value field/,
        "a custom value field is guarded the same way"
      );
    });

    module("a source that pages", function () {
      test("a paging source groups consecutive rows", async function (assert) {
        const engine = pagedEngine([
          [
            member(1, "A"),
            member(2, "A"),
            member(3, "B"),
            member(4, "A"),
            member(5, "A#1"),
          ],
        ]);
        const rows = engine.buildItems(await loadAll(engine, 1));

        assert.deepEqual(
          kinds(rows),
          ["H:A", 1, 2, "H:B", 3, "H:A", 4, "H:A#1", 5],
          "each run of one key is a group, and a key that returns starts another"
        );
        const keys = rows.map((descriptor) => descriptor.key);
        assert.strictEqual(
          new Set(keys).size,
          keys.length,
          "repeated runs, and a key that spells a run count, have distinct header keys"
        );
      });

      test("a later page continues the last run and only ever appends", async function (assert) {
        const engine = pagedEngine([
          [member(1, "A"), member(2, "B")],
          [member(3, "B"), member(4, "C")],
        ]);
        const first = kinds(engine.buildItems(await loadAll(engine, 1)));
        engine.revealMore();
        const second = kinds(
          engine.buildItems(await engine.loadItems(engine.loadContext))
        );

        assert.deepEqual(first, ["H:A", 1, "H:B", 2], "the first page");
        assert.deepEqual(
          second,
          ["H:A", 1, "H:B", 2, 3, "H:C", 4],
          "the family split across pages joins up, and earlier rows keep their places"
        );
      });

      test("hiding an earlier run keeps a later run's keys", async function (assert) {
        const value = trackedArray([]);
        const engine = pagedEngine(
          [[member(1, "A"), member(2, "B"), member(3, "A")]],
          {
            multiple: true,
            hideSelected: true,
            getValue: () => value,
          }
        );
        const loaded = await loadAll(engine, 1);
        const keyOfRun = (rows, id) => {
          const index = rows.findIndex((descriptor) => descriptor.value === id);
          return rows[index - 1].key;
        };
        const before = keyOfRun(engine.buildItems(loaded), 3);

        value.push(1);
        const rows = engine.buildItems(loaded);

        assert.deepEqual(
          kinds(rows),
          ["H:B", 2, "H:A", 3],
          "the first run is gone"
        );
        assert.strictEqual(
          keyOfRun(rows, 3),
          before,
          "the second run of A keeps its header key"
        );
      });

      test("rows a customization adds reach groupBy", async function (assert) {
        withPluginApi((api) =>
          api.registerValueTransformer(
            "select-customizations",
            ({ value: selects }) =>
              selects.forAll((spec) =>
                spec.content((list) => [
                  ...list,
                  { id: "extra", name: "Extra" },
                ])
              )
          )
        );
        const seen = [];
        const engine = pagedEngine([[member(1, "A")]], {
          groupBy: (item) => {
            seen.push(item.id);
            return item.group;
          },
        });
        const rows = engine.buildItems(await loadAll(engine, 1));

        assert.true(seen.includes("extra"), "the added row was grouped");
        assert.deepEqual(
          kinds(rows),
          ["H:A", 1, "DIV", "extra"],
          "with no key it gets a splitter, not a header"
        );
      });
    });

    module("headers and footers", function () {
      const produce = [
        { id: 1, name: "Apple", group: "Fruits" },
        { id: 2, name: "Pear", group: "Fruits" },
        { id: 3, name: "Carrot", group: "Vegetables" },
      ];
      const ending = (key) => `${key} end`;
      const bulk = (key) => ({
        id: `all:${key}`,
        name: `All ${key}`,
        onSelect() {},
      });

      test("a text footer follows its group's rows", function (assert) {
        const engine = new SelectEngine({
          items: produce,
          groupBy: "group",
          groupHeader: identityLabel,
          groupFooter: ending,
        });
        const rows = descriptors(engine);

        assert.deepEqual(
          kinds(rows),
          [
            "H:Fruits",
            1,
            2,
            "F:Fruits end",
            "H:Vegetables",
            3,
            "F:Vegetables end",
          ],
          "each group closes with its footer"
        );
        const footer = rows.find((row) => row.flags.groupFooter);
        assert.true(footer.flags.textBoundary, "a text footer is structural");
        assert.strictEqual(footer.posInSet, undefined, "it takes no position");
        assert.deepEqual(
          options(rows).map((option) => [option.posInSet, option.setSize]),
          [
            [1, 3],
            [2, 3],
            [3, 3],
          ],
          "options are numbered over options only"
        );
      });

      test("a group with only a footer gets a splitter, except at the head", function (assert) {
        const engine = new SelectEngine({
          items: produce,
          groupBy: "group",
          groupFooter: ending,
        });

        assert.deepEqual(
          kinds(descriptors(engine)),
          [1, 2, "F:Fruits end", "DIV", 3, "F:Vegetables end"],
          "a missing header still means a splitter"
        );
      });

      test("an action footer is a navigable option counted in the set", function (assert) {
        const engine = new SelectEngine({
          items: produce,
          groupBy: "group",
          groupFooter: bulk,
        });
        const rows = descriptors(engine);

        assert.deepEqual(
          kinds(rows),
          [1, 2, "AF:All Fruits", "DIV", 3, "AF:All Vegetables"],
          "each group closes with its action row"
        );
        const footer = rows.find((row) => row.item.id === "all:Fruits");
        assert.true(footer.flags.action, "it is an action row");
        assert.false(footer.flags.textBoundary, "it is not presentational");
        assert.true(footer.item.__groupFooter, "the copy is stamped");
        assert.strictEqual(footer.item.groupKey, "Fruits", "with its group");
        assert.deepEqual(
          options(rows).map((option) => [
            option.posInSet,
            option.logicalIndex,
            option.setSize,
          ]),
          [
            [1, 0, 5],
            [2, 1, 5],
            [3, 2, 5],
            [4, 3, 5],
            [5, 4, 5],
          ],
          "action footers take positions and count toward the set"
        );
      });

      test("an action header leads its rows without a splitter", function (assert) {
        const engine = new SelectEngine({
          items: produce,
          groupBy: "group",
          groupHeader: bulk,
        });
        const rows = descriptors(engine);

        assert.deepEqual(
          kinds(rows),
          ["AH:All Fruits", 1, 2, "AH:All Vegetables", 3],
          "an action header is a header, so no splitter is added"
        );
        assert.deepEqual(
          rows.map((row) => row.posInSet),
          [1, 2, 3, 4, 5],
          "action headers take positions"
        );
      });

      test("an action row is copied and never sticky", function (assert) {
        const returned = [];
        const engine = new SelectEngine({
          items: produce,
          groupBy: "group",
          groupFooter: (key) => {
            const item = { ...bulk(key), sticky: true };
            returned.push(item);
            return item;
          },
        });
        const rows = descriptors(engine);
        const footer = rows.find((row) => row.item.id === "all:Fruits");

        assert.notStrictEqual(footer.item, returned[0], "the row is a copy");
        assert.false(
          "__groupFooter" in returned[0],
          "the returned item is untouched"
        );
        assert.false(footer.flags.sticky, "it is not sticky");
        assert.strictEqual(
          kinds(rows).indexOf("AF:All Fruits"),
          2,
          "it stays after its rows instead of leading the list"
        );
      });

      test("builders receive the key, the group's surviving rows frozen, and the options", function (assert) {
        const calls = [];
        let groupByOptions;
        const engine = new SelectEngine({
          items: produce,
          multiple: true,
          hideSelected: true,
          getValue: () => [2],
          groupBy: (item, resolved) => {
            groupByOptions = resolved;
            return item.group;
          },
          groupHeader: (key, rows, resolved) => {
            calls.push({ kind: "header", key, rows, resolved });
            return key;
          },
          groupFooter: (key, rows, resolved) => {
            calls.push({ kind: "footer", key, rows, resolved });
            return null;
          },
        });
        descriptors(engine);

        const fruits = calls.filter((call) => call.key === "Fruits");
        assert.deepEqual(
          fruits.map((call) => call.kind),
          ["header", "footer"],
          "both builders run for the group"
        );
        fruits.forEach((call) => {
          assert.deepEqual(
            call.rows.map((item) => item.id),
            [1],
            "the hidden selected row is not passed"
          );
          assert.true(Object.isFrozen(call.rows), "the rows are frozen");
          assert.strictEqual(
            call.resolved,
            groupByOptions,
            "the options are the resolved options"
          );
        });
      });

      test("an undefined key reaches the builders, which turn its boundaries off", function (assert) {
        const keys = [];
        const engine = new SelectEngine({
          items: [...produce, { id: 4, name: "Rock" }],
          groupBy: "group",
          groupHeader: (key) => {
            keys.push(key);
            return key;
          },
          groupFooter: (key) => (key === undefined ? null : ending(key)),
        });
        const rows = descriptors(engine);

        assert.true(keys.includes(undefined), "the unset key is passed");
        assert.deepEqual(
          kinds(rows).slice(-2),
          ["DIV", 4],
          "the ungrouped row gets neither a header nor a footer"
        );
      });

      test("a builder result that is neither text nor an action row is rejected", function (assert) {
        const footerEngine = new SelectEngine({
          items: produce,
          groupBy: "group",
          groupFooter: () => 5,
        });
        assert.throws(
          () => descriptors(footerEngine),
          /groupFooter/,
          "a number is rejected"
        );

        const headerEngine = new SelectEngine({
          items: produce,
          groupBy: "group",
          groupHeader: (key) => ({ id: key, name: key }),
        });
        assert.throws(
          () => descriptors(headerEngine),
          /groupHeader/,
          "a record without onSelect is rejected"
        );
      });

      test("every group carries its ordinal and the text boundaries it has", function (assert) {
        const engine = new SelectEngine({
          items: [...produce, { id: 4, name: "Oat", group: "Grains" }],
          groupBy: "group",
          groupHeader: (key) => (key === "Vegetables" ? null : key),
          groupFooter: (key) => (key === "Fruits" ? null : ending(key)),
        });
        const rows = descriptors(engine);
        const of = (id) => rows.find((row) => row.value === id);

        assert.deepEqual(
          kinds(rows),
          [
            "H:Fruits",
            1,
            2,
            "DIV",
            3,
            "F:Vegetables end",
            "H:Grains",
            4,
            "F:Grains end",
          ],
          "headers, splitters and footers mix per group"
        );
        assert.deepEqual(
          rows
            .filter((row) => !row.flags.divider)
            .map((row) => row.groupOrdinal),
          [0, 0, 0, 1, 1, 2, 2, 2],
          "every row of a group carries its ordinal"
        );
        assert.deepEqual(
          [of(1), of(3), of(4)].map((row) => row.groupText),
          [
            { header: true, footer: false },
            { header: false, footer: true },
            { header: true, footer: true },
          ],
          "members know which text boundaries their group has"
        );
      });

      test("the boundaries of one group have distinct engine keys", function (assert) {
        const engine = new SelectEngine({
          items: produce,
          groupBy: "group",
          groupHeader: (key) => (key === "Fruits" ? key : null),
          groupFooter: (key) => (key === "Fruits" ? ending(key) : bulk(key)),
        });
        const rows = descriptors(engine);
        const keys = rows.map((row) => row.key);

        assert.strictEqual(new Set(keys).size, keys.length, "no key repeats");
        assert.true(
          rows
            .filter((row) => row.flags.groupFooter)
            .every((row) => row.key.startsWith("__ds:")),
          "footers take engine keys, an action footer included"
        );
      });

      test("an action boundary is closed off at the selection limit", function (assert) {
        const engine = new SelectEngine({
          items: produce,
          multiple: true,
          maximum: 1,
          getValue: () => [1],
          groupBy: "group",
          groupHeader: bulk,
          groupFooter: bulk,
          specialItems: () => [{ id: "act", name: "Act", onSelect() {} }],
        });
        const rows = descriptors(engine);
        const boundaries = rows.filter(
          (row) => row.flags.groupHeader || row.flags.groupFooter
        );

        assert.true(
          boundaries.every(
            (row) => row.flags.capDisabled && row.flags.disabled
          ),
          "header and footer actions add values, so the limit closes them"
        );
        assert.false(
          rows.find((row) => row.value === "act").flags.capDisabled,
          "another action row stays open"
        );
      });

      module("a source that pages", function () {
        test("the trailing run's footer waits until the source cannot grow", async function (assert) {
          const footers = [];
          const engine = pagedEngine(
            [
              [member(1, "A"), member(2, "B")],
              [member(3, "B"), member(4, "C")],
            ],
            {
              groupFooter: (key) => {
                footers.push(key);
                return ending(key);
              },
            }
          );

          const first = engine.buildItems(await loadAll(engine, 1));
          assert.deepEqual(
            kinds(first),
            ["H:A", 1, "F:A end", "H:B", 2],
            "the last run may still grow, so its footer waits"
          );
          assert.deepEqual(footers, ["A"], "its builder is not called");

          engine.revealMore();
          const second = engine.buildItems(
            await engine.loadItems(engine.loadContext)
          );
          assert.deepEqual(
            kinds(second),
            ["H:A", 1, "F:A end", "H:B", 2, 3, "F:B end", "H:C", 4, "F:C end"],
            "the next page closes B, and the end of paging closes C"
          );
        });

        test("the footer stays held while a reveal is in flight", async function (assert) {
          let release;
          const engine = new SelectEngine({
            load: (_filter, opts) =>
              opts.page === 1
                ? Promise.resolve({ items: [member(1, "A")], hasMore: true })
                : new Promise((resolve) => {
                    release = () =>
                      resolve({ items: [member(2, "B")], hasMore: false });
                  }),
            groupBy: "group",
            groupFooter: ending,
          });
          const first = await engine.loadItems(engine.loadContext);
          engine.revealMore();
          const next = engine.loadItems(engine.loadContext);
          // The loader is asked a few microtasks later.
          for (let tick = 0; !release && tick < 50; tick++) {
            await Promise.resolve();
          }

          assert.deepEqual(
            kinds(engine.buildItems(first)),
            [1],
            "the pending page may still continue A"
          );

          release();
          assert.deepEqual(
            kinds(engine.buildItems(await next)),
            [1, "F:A end", "DIV", 2, "F:B end"],
            "both footers appear once the page lands and paging ends"
          );
        });

        test("a page ending in a sticky or structural row holds back the run before it", async function (assert) {
          const sticky = pagedEngine(
            [
              [member(1, "A"), { id: "s", name: "S", sticky: true }],
              [member(2, "A")],
            ],
            { groupFooter: ending }
          );
          assert.deepEqual(
            kinds(sticky.buildItems(await loadAll(sticky, 1))),
            ["s", "H:A", 1],
            "a trailing sticky row does not release A"
          );

          const structural = pagedEngine(
            [[member(1, "A"), { __divider: true }], [member(2, "A")]],
            { groupFooter: ending }
          );
          assert.deepEqual(
            kinds(structural.buildItems(await loadAll(structural, 1))),
            ["H:A", 1],
            "a trailing structural row does not release A"
          );
        });

        test("a last row a customization removes holds back the run before it", async function (assert) {
          withPluginApi((api) =>
            api.registerValueTransformer(
              "select-customizations",
              ({ value: selects }) =>
                selects.forAll((spec) =>
                  spec.content((list) => list.filter((item) => item.id !== 2))
                )
            )
          );
          const engine = pagedEngine(
            [[member(1, "A"), member(2, "B")], [member(3, "A")]],
            {
              groupFooter: ending,
            }
          );

          assert.deepEqual(
            kinds(engine.buildItems(await loadAll(engine, 1))),
            ["H:A", 1],
            "A is the last run the source placed"
          );
        });

        test("hiding the trailing run releases the footer before it", async function (assert) {
          const value = trackedArray([]);
          const engine = pagedEngine(
            [[member(1, "A"), member(2, "B")], [member(3, "A")]],
            {
              multiple: true,
              hideSelected: true,
              getValue: () => value,
              groupFooter: ending,
            }
          );
          const loaded = await loadAll(engine, 1);
          value.push(2);

          assert.deepEqual(
            kinds(engine.buildItems(loaded)),
            ["H:A", 1, "F:A end"],
            "B is held back and emptied, so A is closed"
          );

          engine.revealMore();
          const rows = engine.buildItems(
            await engine.loadItems(engine.loadContext)
          );
          assert.deepEqual(
            kinds(rows),
            ["H:A", 1, "F:A end", "H:A", 3, "F:A end"],
            "more A rows start a new run instead of growing the closed one"
          );
        });

        test("paging stopped by maxLoaded closes the partial run", async function (assert) {
          const seen = [];
          const engine = pagedEngine(
            [[member(1, "A"), member(2, "A")], [member(3, "A")]],
            {
              maxLoaded: 2,
              groupFooter: (key, rows) => {
                seen.push(rows.map((item) => item.id));
                return ending(key);
              },
            }
          );

          assert.deepEqual(
            kinds(engine.buildItems(await loadAll(engine, 1))),
            ["H:A", 1, 2, "F:A end"],
            "the footer appears once no more rows may load"
          );
          assert.deepEqual(seen, [[1, 2]], "with only the loaded rows");
        });

        test("an action footer counts toward a declared total", async function (assert) {
          const engine = new SelectEngine({
            load: () =>
              Promise.resolve({
                items: [member(1, "A"), member(2, "A"), member(3, "B")],
                total: 3,
              }),
            groupBy: "group",
            groupFooter: bulk,
          });
          const rows = engine.buildItems(
            await engine.loadItems(engine.loadContext)
          );

          assert.deepEqual(
            [...new Set(options(rows).map((option) => option.setSize))],
            [5],
            "the total plus the two action footers"
          );
        });

        test("an action header acts on the rows loaded so far", async function (assert) {
          const seen = [];
          const engine = pagedEngine([[member(1, "A")], [member(2, "A")]], {
            groupHeader: (key, rows) => {
              seen.push(rows.map((item) => item.id));
              return bulk(key);
            },
          });
          engine.buildItems(await loadAll(engine, 1));
          engine.revealMore();
          engine.buildItems(await engine.loadItems(engine.loadContext));

          assert.deepEqual(seen, [[1], [1, 2]], "its rows grow with the run");
        });

        test("a boundary that changes kind as a run grows warns", async function (assert) {
          const stub = sinon.stub(console, "warn");
          let footerFor = () => null;
          let headerFor = (key) => key;
          const engine = pagedEngine(
            [
              [member(1, "A"), member(2, "B")],
              [member(3, "B"), member(4, "C")],
            ],
            {
              groupHeader: (key) => headerFor(key),
              groupFooter: (key) => footerFor(key),
            }
          );
          try {
            engine.buildItems(await loadAll(engine, 1));
            headerFor = (key) => (key === "A" ? null : key);
            footerFor = (key) => (key === "A" ? bulk(key) : null);
            engine.revealMore();
            engine.buildItems(await engine.loadItems(engine.loadContext));

            assert.true(
              stub.calledWithMatch("header of a group"),
              "a header that disappears warns"
            );
            assert.true(
              stub.calledWithMatch("footer of a group"),
              "a footer that becomes an action warns"
            );
          } finally {
            stub.restore();
          }
        });

        test("a new query may change a boundary without a warning", async function (assert) {
          const stub = sinon.stub(console, "warn");
          let headerFor = (key) => key;
          const engine = pagedEngine([[member(1, "A")], [member(2, "A")]], {
            groupHeader: (key) => headerFor(key),
          });
          try {
            engine.buildItems(await loadAll(engine, 1));
            headerFor = () => null;
            engine.setFilter("a");
            engine.buildItems(await engine.loadItems(engine.loadContext));

            assert.false(
              stub.calledWithMatch("of a group"),
              "only page extensions are compared"
            );
          } finally {
            stub.restore();
          }
        });
      });
    });
  });
});
