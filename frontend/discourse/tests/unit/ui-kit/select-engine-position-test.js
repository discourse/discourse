import { tracked } from "@glimmer/tracking";
import { destroy } from "@ember/destroyable";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import SelectEngine, {
  selectOption,
} from "discourse/ui-kit/select/select-engine";

const optionRows = (rows) =>
  rows.filter((row) => !row.flags.divider && !row.flags.textBoundary);
const values = (rows) => optionRows(rows).map((row) => row.value);
const labels = (rows) =>
  rows.map((row) =>
    row.flags.divider ? "DIV" : (row.record.name ?? row.record.label)
  );

module(
  "Unit | ui-kit | SelectEngine | position and dividers",
  function (hooks) {
    setupTest(hooks);

    let engines;

    hooks.beforeEach(function () {
      engines = [];
    });

    hooks.afterEach(function () {
      engines.forEach((engine) => destroy(engine));
    });

    function createEngine(init) {
      const engine = new SelectEngine(init);
      engines.push(engine);
      return engine;
    }

    function appendContent(callback) {
      withPluginApi((api) => {
        api.registerValueTransformer("select-customizations", ({ value }) =>
          value.forAll((spec) => spec.content(callback))
        );
      });
    }

    async function build(engine) {
      return engine.buildRows(await engine.loadOptions(engine.loadContext));
    }

    test("end options follow group footers and take the last option indices", async function (assert) {
      const tail = { id: "tail", name: "Source end", section: "A" };
      const apple = { id: "apple", name: "Apple", section: "A" };
      const beet = { id: "beet", name: "Beet", section: "B" };
      const seen = [];
      const engine = createEngine({
        options: [
          selectOption(tail, { position: "end" }),
          apple,
          selectOption(
            { id: "pin", name: "Source pin", section: "B" },
            { position: "sticky" }
          ),
          beet,
        ],
        getArgs: () => ({ noneOption: true }),
        allowCreate: true,
        createOption: (filter) => ({
          id: `create-${filter}`,
          name: `Create ${filter}`,
        }),
        extraOptions: () => [
          selectOption({ id: "end", name: "Extra end" }, { position: "end" }),
          { id: "extra", name: "Extra" },
          selectOption(
            { id: "pin-extra", name: "Extra pin" },
            { position: "sticky" }
          ),
        ],
        groupBy(record) {
          seen.push(record.id);
          return record.section;
        },
        groupHeader: (key) => `Header ${key}`,
        groupFooter: (key) =>
          selectOption(
            { id: `footer-${key}`, name: `Footer ${key}` },
            { onSelect() {} }
          ),
      });

      const rows = await build(engine);
      assert.deepEqual(
        labels(rows),
        [
          "Extra pin",
          "Source pin",
          "None",
          "Extra",
          "Header A",
          "Apple",
          "Footer A",
          "Header B",
          "Beet",
          "Footer B",
          "Extra end",
          "Source end",
        ],
        "end options follow even action footers"
      );
      assert.deepEqual(
        [...new Set(seen)].sort(),
        ["apple", "beet"],
        "only ordinary source records reach grouping"
      );
      assert.deepEqual(
        optionRows(rows).map((row) => row.posInSet),
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        "text headers consume no positions"
      );
      assert.true(
        optionRows(rows).every((row) => row.setSize === 10),
        "actions and none count, text does not"
      );
      assert.deepEqual(
        optionRows(rows).map((row) => row.logicalIndex),
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        "logical indices count options only"
      );
      assert.strictEqual(
        rows.at(-1).record,
        tail,
        "moving an option preserves its record"
      );
      assert.deepEqual(
        tail,
        { id: "tail", name: "Source end", section: "A" },
        "moving does not mutate a record"
      );
      assert.strictEqual(
        rows.at(-1).groupOrdinal,
        undefined,
        "end belongs to no group"
      );
      assert.false(rows.at(-1).flags.sticky, "end is not pinned");
      engine.setFilter("new");
      assert.deepEqual(
        labels(await build(engine)),
        ["Extra pin", "Extra", "Create new", "Extra end"],
        "end also follows create, while none and nonmatching source options disappear"
      );
    });

    test("held end options count in set size before the final page reveals them", async function (assert) {
      const end = selectOption(
        { id: "source-end", name: "Source end" },
        { position: "end" }
      );
      const offsets = [];
      const engine = createEngine({
        load: (_filter, { offset }) => {
          offsets.push(offset);
          return offset === 0
            ? {
                options: [end, { id: "a", name: "A" }],
                total: 3,
                hasMore: true,
              }
            : { options: [{ id: "b", name: "B" }], total: 3, hasMore: false };
        },
        extraOptions: () => [
          selectOption(
            { id: "extra-end", name: "Extra end" },
            { position: "end" }
          ),
          selectOption({ id: "pin", name: "Pin" }, { position: "sticky" }),
        ],
      });

      const first = await build(engine);
      assert.deepEqual(
        values(first),
        ["pin", "a"],
        "both end options wait while ordinary options and more pages exist"
      );
      assert.true(
        optionRows(first).every((row) => row.setSize === 5),
        "both hidden end options are reserved in the size"
      );
      assert.strictEqual(
        engine.loadedCount,
        2,
        "source end remains a loaded source option"
      );
      assert.true(engine.revealMore(), "holding end does not terminate paging");
      const last = await build(engine);
      assert.deepEqual(
        values(last),
        ["pin", "a", "b", "extra-end", "source-end"],
        "end appears in partition order after the final source option"
      );
      assert.deepEqual(
        last.map((row) => row.posInSet),
        [1, 2, 3, 4, 5],
        "end takes the last indices"
      );
      assert.true(
        last.every((row) => row.setSize === first[0].setSize),
        "revealing end does not change set size"
      );
      assert.deepEqual(
        offsets,
        [0, 2],
        "paging offsets count raw source options only"
      );
      assert.false(engine.canRevealMore, "the final page ends paging");
    });

    test("an empty query shows end alone and preserves reach-end eligibility", async function (assert) {
      const engine = createEngine({
        load: () => ({ options: [], hasMore: true }),
        extraOptions: () => [
          selectOption({ id: "end", name: "End" }, { position: "end" }),
        ],
      });
      const rows = await build(engine);
      assert.deepEqual(
        values(rows),
        ["end"],
        "the list has an option to mount instead of the empty state"
      );
      assert.strictEqual(rows[0].setSize, 1, "the lone end option counts once");
      assert.true(
        engine.canRevealMore,
        "an empty page still allows reach-end paging"
      );
      assert.true(
        engine.revealMore(),
        "the next page can actually be requested"
      );
    });

    test("source end options filter but extra and content end options do not", async function (assert) {
      appendContent((options) => [
        ...options,
        selectOption(
          { id: "content", name: "Global content" },
          { position: "end" }
        ),
      ]);
      const engine = createEngine({
        options: [
          selectOption({ id: "miss", name: "Remove" }, { position: "end" }),
          selectOption(
            { id: "match", name: "Apple action" },
            { position: "end" }
          ),
          { id: "apple", name: "Apple" },
        ],
        extraOptions: () => [
          selectOption(
            { id: "extra", name: "Global extra" },
            { position: "end" }
          ),
        ],
      });
      engine.setFilter("apple");
      const rows = await build(engine);
      assert.deepEqual(
        values(rows),
        ["apple", "extra", "match", "content"],
        "only the source entries filter, and all end entries follow the match"
      );
      assert.true(
        rows.every((row) => row.setSize === 4),
        "filtered-out end is not counted"
      );
      engine.setFilter("global");
      assert.deepEqual(
        values(await build(engine)),
        [],
        "unfiltered content and extra end options cannot survive alone under a query"
      );
      engine.setFilter("apple action");
      assert.deepEqual(
        values(await build(engine)),
        [],
        "even a matching source end option is dropped when no ordinary option matches"
      );
    });

    test("positioned source options never split runs or release the held footer", async function (assert) {
      const footerCalls = [];
      const firstPage = [
        { id: "a1", name: "A1", section: "A" },
        selectOption(
          { id: "pin", name: "Pin", section: "X" },
          { position: "sticky" }
        ),
        selectOption(
          { id: "end", name: "End", section: "X" },
          { position: "end" }
        ),
        { id: "a2", name: "A2", section: "A" },
        selectOption(
          { id: "tail", name: "Tail", section: "Y" },
          { position: "end" }
        ),
      ];
      const engine = createEngine({
        load: (_filter, { offset }) =>
          offset === 0
            ? { options: firstPage, hasMore: true }
            : {
                options: [{ id: "b", name: "B", section: "B" }],
                hasMore: false,
              },
        groupBy: "section",
        groupHeader: (key) => `Header ${key}`,
        groupFooter: (key, members) => {
          footerCalls.push([key, members.map((option) => option.record.id)]);
          return `Footer ${key}`;
        },
      });
      const first = await build(engine);
      assert.deepEqual(
        labels(first),
        ["Pin", "Header A", "A1", "A2"],
        "positioned entries neither split A nor close its footer"
      );
      assert.deepEqual(footerCalls, [], "even the footer builder stays held");
      assert.true(engine.revealMore(), "another page is available");
      const last = await build(engine);
      assert.deepEqual(
        labels(last),
        [
          "Pin",
          "Header A",
          "A1",
          "A2",
          "Footer A",
          "Header B",
          "B",
          "Footer B",
          "End",
          "Tail",
        ],
        "each source run closes before end"
      );
      assert.deepEqual(
        footerCalls,
        [
          ["A", ["a1", "a2"]],
          ["B", ["b"]],
        ],
        "group builders receive only ordinary run members"
      );
      assert.strictEqual(
        first.find((row) => row.flags.groupHeader)?.key,
        last.find((row) => row.flags.groupHeader)?.key,
        "extending pages preserves the first run key"
      );
    });

    test("divider precedence keeps group keys and before wins over after", async function (assert) {
      const engine = createEngine({
        options: [
          selectOption(
            { id: "a1", name: "A1", section: "A" },
            { divider: "after" }
          ),
          selectOption(
            { id: "a2", name: "A2", section: "A" },
            { divider: "before" }
          ),
          selectOption(
            { id: "a3", name: "A3", section: "A" },
            { divider: "after" }
          ),
          selectOption(
            { id: "b1", name: "B1", section: "B" },
            { divider: "before" }
          ),
          selectOption(
            { id: "b2", name: "B2", section: "B" },
            { divider: "after" }
          ),
          { id: "b3", name: "B3", section: "B" },
        ],
        groupBy: "section",
      });
      const rows = await build(engine);
      assert.deepEqual(
        labels(rows),
        ["A1", "DIV", "A2", "A3", "DIV", "B1", "B2", "DIV", "B3"],
        "exactly one divider occupies each requested gap"
      );
      assert.deepEqual(
        rows.filter((row) => row.flags.divider).map((row) => row.key),
        ["__ds:db:a2", "__ds:d:s:B", "__ds:da:b2"],
        "group splitter wins, otherwise next-before wins over previous-after"
      );
      assert.deepEqual(
        optionRows(rows).map((row) => row.posInSet),
        [1, 2, 3, 4, 5, 6],
        "dividers consume no positions"
      );
      assert.true(
        optionRows(rows).every((row) => row.setSize === 6),
        "dividers consume no size"
      );
      assert.true(
        rows
          .filter((row) => row.flags.divider)
          .every(
            (row) =>
              row.posInSet === undefined &&
              row.setSize === undefined &&
              row.logicalIndex === undefined
          ),
        "divider descriptors have no option indices"
      );
    });

    test("deliberate divider keys follow their owner across rebuilds", async function (assert) {
      const owner = { id: "__ds:owner", name: "Owner" };
      const entries = tracked([
        { id: "first", name: "First" },
        selectOption(owner, { divider: "before" }),
        selectOption({ id: "after", name: "After" }, { divider: "after" }),
        { id: "last", name: "Last" },
      ]);
      const engine = createEngine({ options: () => entries.value });
      const first = await build(engine);
      const ownerKey = first.find((row) => row.record === owner).key;
      const expected = [`__ds:db:${ownerKey}`, "__ds:da:after"];
      assert.deepEqual(
        first.filter((row) => row.flags.divider).map((row) => row.key),
        expected,
        "owner keys include the existing reserved-key escape"
      );
      entries.value = [{ id: "prefix", name: "Prefix" }, ...entries.value];
      const second = await build(engine);
      assert.deepEqual(
        second.filter((row) => row.flags.divider).map((row) => row.key),
        expected,
        "inserting an earlier option does not rekey either deliberate divider"
      );
      assert.strictEqual(
        new Set(second.map((row) => row.key)).size,
        second.length,
        "every row key remains unique"
      );
    });

    test("option row keys stay stable and unique when a deliberate divider appears or disappears", async function (assert) {
      const showDivider = tracked(false);
      const actions = ["A", "B", "C"].map((name) =>
        selectOption({ id: null, name }, { onSelect() {} })
      );
      const keyed = { id: "__ds:row:2", name: "Keyed" };
      const engine = createEngine({
        extraOptions: () => [
          actions[0].with({ divider: showDivider.value ? "after" : null }),
          ...actions.slice(1),
          keyed,
        ],
      });
      const initial = await build(engine);
      const initialKeys = new Map(
        optionRows(initial).map((row) => [row.record, row.key])
      );
      assert.deepEqual(
        labels(initial),
        ["A", "B", "C", "Keyed"],
        "three value-less actions and the keyed option start without a divider"
      );
      assert.strictEqual(
        new Set(initial.map((row) => row.key)).size,
        initial.length,
        "all initial row keys are unique"
      );

      let previous = initial;
      for (const visible of [true, false]) {
        showDivider.value = visible;
        const rows = await build(engine);
        const transition = visible ? "appears" : "disappears";
        const previousKeys = new Map(
          optionRows(previous).map((row) => [row.record, row.key])
        );
        assert.deepEqual(
          labels(rows),
          visible ? ["A", "DIV", "B", "C", "Keyed"] : ["A", "B", "C", "Keyed"],
          `only the deliberate divider changes when it ${transition}`
        );
        for (const row of optionRows(rows)) {
          assert.strictEqual(
            row.key,
            previousKeys.get(row.record),
            `${row.record.name} keeps its previous key when the divider ${transition}`
          );
          assert.strictEqual(
            row.key,
            initialKeys.get(row.record),
            `${row.record.name} keeps its original key when the divider ${transition}`
          );
        }
        assert.strictEqual(
          new Set(rows.map((row) => row.key)).size,
          rows.length,
          `all row keys remain unique when the divider ${transition}`
        );
        previous = rows;
      }
    });

    test("dividers disappear with their owner and at list edges or the sticky seam", async function (assert) {
      const hidden = tracked(false);
      const engine = createEngine({
        options: () => [
          selectOption(
            { id: "top", name: "Top" },
            { position: "sticky", divider: "before" }
          ),
          selectOption({ id: "seam", name: "Seam" }, { divider: "before" }),
          ...(!hidden.value
            ? [
                selectOption(
                  { id: "owner", name: "Owner" },
                  { divider: "before" }
                ),
              ]
            : []),
          selectOption({ id: "bottom", name: "Bottom" }, { divider: "after" }),
        ],
      });
      assert.deepEqual(
        labels(await build(engine)),
        ["Top", "Seam", "DIV", "Owner", "Bottom"],
        "only the interior owner has a divider; no edge or seam divider"
      );
      hidden.value = true;
      assert.deepEqual(
        labels(await build(engine)),
        ["Top", "Seam", "Bottom"],
        "removing the owner cannot leave an orphan divider"
      );
      const afterSeam = createEngine({
        options: [
          selectOption(
            { id: "pin", name: "Pin" },
            { position: "sticky", divider: "after" }
          ),
          { id: "a", name: "A" },
        ],
      });
      assert.deepEqual(
        labels(await build(afterSeam)),
        ["Pin", "A"],
        "after on the last sticky option also leaves the seam to styling"
      );
      const selected = createEngine({
        options: [
          { id: "a", name: "A" },
          selectOption({ id: "held", name: "Held" }, { divider: "after" }),
          { id: "b", name: "B" },
        ],
        getValue: () => "held",
        hideSelected: true,
      });
      assert.deepEqual(
        labels(await build(selected)),
        ["A", "B"],
        "hideSelected removes the owner's divider too"
      );
    });

    test("text headers suppress a preceding divider but action headers keep it", async function (assert) {
      for (const action of [false, true]) {
        const engine = createEngine({
          options: [{ id: "a", name: "A", section: "A" }],
          extraOptions: () => [
            selectOption({ id: "extra", name: "Extra" }, { divider: "after" }),
          ],
          groupBy: "section",
          groupHeader: () =>
            action
              ? selectOption(
                  { id: "header", name: "Header" },
                  { onSelect() {} }
                )
              : "Header",
        });
        const rows = await build(engine);
        assert.deepEqual(
          labels(rows),
          action ? ["Extra", "DIV", "Header", "A"] : ["Extra", "Header", "A"],
          `${action ? "action" : "text"} header has the appropriate preceding rule`
        );
        assert.deepEqual(
          optionRows(rows).map((row) => row.posInSet),
          action ? [1, 2, 3] : [1, 2],
          "only an action boundary is numbered"
        );
        assert.true(
          optionRows(rows).every((row) => row.setSize === (action ? 3 : 2)),
          "text and divider do not enter set size"
        );
      }
    });

    test("a divider between sticky options stays in the contiguous sticky prefix", async function (assert) {
      const engine = createEngine({
        options: [
          selectOption(
            { id: "s1", name: "S1" },
            { position: "sticky", divider: "after" }
          ),
          selectOption(
            { id: "s2", name: "S2" },
            { position: "sticky", divider: "before" }
          ),
          selectOption({ id: "s3", name: "S3" }, { position: "sticky" }),
          { id: "a", name: "A" },
        ],
      });
      const rows = await build(engine);
      assert.deepEqual(
        labels(rows),
        ["S1", "DIV", "S2", "S3", "A"],
        "the sticky gap has one divider"
      );
      assert.deepEqual(
        rows.map((row) => row.flags.sticky),
        [true, true, true, true, false],
        "the divider cannot terminate the pinned prefix early"
      );
      assert.deepEqual(
        optionRows(rows).map((row) => row.logicalIndex),
        [0, 1, 2, 3],
        "the sticky divider still takes no logical index"
      );
    });

    test("dividers and text boundaries leave paged net change and raw offsets unchanged", async function (assert) {
      appendContent((options) => [
        ...options.filter(({ record }) => record.id !== "drop"),
        selectOption(
          { id: "content", name: "Content" },
          { position: "end", divider: "before" }
        ),
      ]);
      const offsets = [];
      const engine = createEngine({
        load: (_filter, { offset }) => {
          offsets.push(offset);
          return {
            options:
              offset === 0
                ? [
                    { id: "drop", name: "Drop", section: "A" },
                    selectOption(
                      { id: "a", name: "A", section: "A" },
                      { divider: "after" }
                    ),
                    { id: "b", name: "B", section: "A" },
                  ]
                : [{ id: "c", name: "C", section: "A" }],
            total: 8,
            hasMore: true,
          };
        },
        groupBy: "section",
        groupHeader: (key) => `Header ${key}`,
        extraOptions: () => [
          selectOption({ id: "extra", name: "Extra" }, { position: "end" }),
        ],
      });
      const first = await build(engine);
      assert.deepEqual(
        labels(first),
        ["Header A", "A", "DIV", "B"],
        "held end and structural rows do not become source options"
      );
      assert.true(
        optionRows(first).every((row) => row.setSize === 9),
        "one removed and one added content option cancel, then extra end adds one"
      );
      assert.true(engine.revealMore(), "the next source page is available");
      const second = await build(engine);
      assert.deepEqual(
        values(second),
        ["a", "b", "c"],
        "only source options are shown while end waits"
      );
      assert.true(
        optionRows(second).every((row) => row.setSize === 9),
        "adding a divider and text header does not inflate net change"
      );
      assert.deepEqual(
        offsets,
        [0, 3],
        "source offset ignores removed content, extras, text and dividers"
      );
      assert.strictEqual(
        engine.loadedCount,
        4,
        "loadedCount remains the raw deduped source population"
      );
    });

    test("new divider rows cannot defeat the barren-page brake", async function (assert) {
      appendContent((options) =>
        options.filter(({ record }) => record.id === "a")
      );
      const calls = [];
      let extras = [];
      const engine = createEngine({
        load: (_filter, { offset }) => {
          calls.push(offset);
          return {
            options: [
              {
                id: offset === 0 ? "a" : `hidden-${offset}`,
                name: `Source ${offset}`,
              },
            ],
            total: 100,
            hasMore: true,
          };
        },
        extraOptions: () => extras,
        groupBy: "section",
        groupHeader: () => "Header",
      });
      for (let page = 0; page < 3; page++) {
        extras = [
          ...extras,
          selectOption(
            { id: `extra-${page}`, name: `Extra ${page}` },
            { divider: "after" }
          ),
        ];
        const rows = await build(engine);
        assert.strictEqual(
          rows.filter((row) => row.flags.divider).length,
          page,
          "extra divider rows grow while the source population stays flat"
        );
        assert.strictEqual(
          engine.revealMore(),
          page < 2,
          "two barren source pages stop revealing despite growing decorations"
        );
      }
      assert.deepEqual(
        calls,
        [0, 1, 2],
        "unique raw pages advance the cursor but two pages without visible growth stop paging"
      );
      assert.strictEqual(
        engine.loadedCount,
        3,
        "all three unique source options count, including the two removed by content"
      );
      assert.false(
        engine.canRevealMore,
        "growing rendered rows cannot rearm the exhausted source"
      );
    });
  }
);
