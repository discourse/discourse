import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

// Stubs the layout-query seam methods the selection service reads through, so
// `selectBlock` can hydrate / bind / resolve against a controllable fixture
// without a live block registry. `entries` maps a block key to a located
// `{ entry, outletName }`; `parents` maps a child key to its parent entry;
// `layouts` is the outlet->layout map `_resolvedLayouts` walks for live args.
function stubQuery(
  query,
  { entries = {}, parents = {}, layouts = {}, metadata = {} } = {}
) {
  sinon
    .stub(query, "findEntryAndOutletSync")
    .callsFake((key) => entries[key] ?? null);
  sinon.stub(query, "findEntryParent").callsFake((key) => parents[key] ?? null);
  sinon.stub(query, "blockNameOf").callsFake((entry) => entry?.__name ?? null);
  sinon
    .stub(query, "metadataForName")
    .callsFake((name) => metadata[name] ?? null);
  sinon.stub(query, "readResolvedLayout").callsFake((outletName) => {
    const record = layouts[outletName];
    return record ? record.layout : null;
  });
  const layoutMap = new Map();
  for (const [outletName, layout] of Object.entries(layouts)) {
    layoutMap.set(outletName, layout);
  }
  sinon.stub(query, "_resolvedLayouts").callsFake(() => layoutMap);
  return query;
}

module(
  "Unit | Discourse Wireframe | service:wireframe-selection",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.selection = this.owner.lookup("service:wireframe-selection");
      this.query = this.owner.lookup("service:wireframe-layout-query");
      this.revision = this.owner.lookup("service:wireframe-layout-signal");
    });

    module("selectBlock", function () {
      test("sets the primary key and builds selectedBlockData", function (assert) {
        stubQuery(this.query);
        this.selection.selectBlock({ key: "tile:1", name: "tile", args: {} });

        assert.strictEqual(this.selection.selectedBlockKey, "tile:1");
        assert.strictEqual(
          this.selection.selectedBlockData.key,
          "tile:1",
          "selectedBlockData carries the key"
        );
        assert.deepEqual(
          this.selection.selectedBlockData.argsSnapshot,
          {},
          "an args snapshot is built"
        );
      });

      test("hydrates name/args/metadata from the layout for a key-only select", function (assert) {
        const entry = { __name: "tile", args: { title: "Hi" } };
        const metadata = { args: { title: { type: "string" } } };
        stubQuery(this.query, {
          entries: { "tile:1": { entry, outletName: "home" } },
          metadata: { tile: metadata },
          layouts: { home: { layout: [entry] } },
        });
        // Make findEntry inside #bindLiveArgs locate the entry by key.
        entry.__stableKey = 1;
        entry.block = "tile";

        this.selection.selectBlock({ key: "tile:1" });

        assert.strictEqual(this.selection.selectedBlockData.name, "tile");
        assert.strictEqual(
          this.selection.selectedBlockData.metadata,
          metadata,
          "metadata resolves from the registry"
        );
      });

      test("selectBlock(null) clears the selection", function (assert) {
        stubQuery(this.query);
        this.selection.selectBlock({ key: "tile:1", name: "tile", args: {} });
        this.selection.selectBlock(null);

        assert.strictEqual(this.selection.selectedBlockKey, null);
        assert.strictEqual(this.selection.selectedBlockData, null);
        assert.strictEqual(this.selection.selectionCount, 0);
      });
    });

    module("multi-selection", function () {
      test("toggle grows and shrinks the selection set", function (assert) {
        stubQuery(this.query);
        this.selection.selectBlock({ key: "a:1", name: "a", args: {} });
        assert.strictEqual(this.selection.selectionCount, 1);
        assert.false(this.selection.hasMultiSelection);

        this.selection.toggleBlockSelection({
          key: "b:2",
          name: "b",
          args: {},
        });
        assert.strictEqual(this.selection.selectionCount, 2);
        assert.true(this.selection.hasMultiSelection);
        assert.true(this.selection.isBlockSelected("a:1"));
        assert.true(this.selection.isBlockSelected("b:2"));

        // Toggling the primary off re-anchors to the remaining member.
        this.selection.toggleBlockSelection({ key: "b:2" });
        assert.strictEqual(this.selection.selectionCount, 1);
        assert.true(this.selection.isBlockSelected("a:1"));
        assert.false(this.selection.isBlockSelected("b:2"));
      });

      test("setSelectionRange replaces the set and anchors the primary", function (assert) {
        stubQuery(this.query);
        this.selection.setSelectionRange(["a:1", "b:2", "c:3"], {
          key: "c:3",
          name: "c",
          args: {},
        });

        assert.strictEqual(this.selection.selectionCount, 3);
        assert.strictEqual(this.selection.selectedBlockKey, "c:3");
        assert.true(this.selection.isBlockSelected("a:1"));
        assert.true(this.selection.isBlockSelected("b:2"));
      });

      test("isBlockSelected is false for null / unselected keys", function (assert) {
        stubQuery(this.query);
        this.selection.selectBlock({ key: "a:1", name: "a", args: {} });
        assert.false(this.selection.isBlockSelected(null));
        assert.false(this.selection.isBlockSelected("z:9"));
      });

      test("selectedKeysSnapshot returns a frozen copy", function (assert) {
        stubQuery(this.query);
        this.selection.setSelectionRange(["a:1", "b:2"], {
          key: "a:1",
          name: "a",
          args: {},
        });
        const snapshot = this.selection.selectedKeysSnapshot();
        assert.deepEqual([...snapshot].sort(), ["a:1", "b:2"]);
        assert.true(Object.isFrozen(snapshot), "the snapshot is frozen");
        // Mutating the snapshot must not affect the live selection.
        assert.throws(() => snapshot.push("c:3"));
        assert.strictEqual(this.selection.selectionCount, 2);
      });
    });

    module("reactivity", function () {
      test("a derived getter re-runs after revision.bump()", function (assert) {
        let failureType = null;
        const entry = {};
        Object.defineProperty(entry, "__failureType", {
          get: () => failureType,
        });
        stubQuery(this.query, {
          entries: { "tile:1": { entry, outletName: "home" } },
        });
        this.selection.selectBlock({ key: "tile:1", name: "tile", args: {} });

        assert.strictEqual(
          this.selection.selectedBlockFailure,
          null,
          "healthy block has no failure"
        );

        // Simulate a republish stamping a failure on the entry, then bumping
        // the layout-signal beacon — the getter reads `version`, so it re-runs.
        failureType = "TYPE_MISMATCH";
        this.revision.bump();

        assert.strictEqual(
          this.selection.selectedBlockFailure.failureType,
          "TYPE_MISMATCH",
          "the failure getter re-evaluates after a bump"
        );
      });
    });

    module("event seam", function () {
      test("registerBeforeChange sees the old key before the mutation", function (assert) {
        stubQuery(this.query);
        this.selection.selectBlock({ key: "a:1", name: "a", args: {} });

        const seen = [];
        this.selection.registerBeforeChange(({ prevKey, nextKey }) => {
          seen.push({
            prevKey,
            nextKey,
            // The mutation hasn't happened yet, so the live key still reads old.
            liveKey: this.selection.selectedBlockKey,
          });
        });

        this.selection.selectBlock({ key: "b:2", name: "b", args: {} });

        assert.deepEqual(seen, [
          { prevKey: "a:1", nextKey: "b:2", liveKey: "a:1" },
        ]);
      });

      test("registerAfterChange sees the new key after the mutation", function (assert) {
        stubQuery(this.query);

        const seen = [];
        this.selection.registerAfterChange(({ key }) => {
          seen.push({ key, liveKey: this.selection.selectedBlockKey });
        });

        this.selection.selectBlock({ key: "b:2", name: "b", args: {} });

        assert.deepEqual(seen, [{ key: "b:2", liveKey: "b:2" }]);
      });

      test("reset() clears without firing hooks", function (assert) {
        stubQuery(this.query);
        this.selection.selectBlock({ key: "a:1", name: "a", args: {} });

        let beforeFired = 0;
        let afterFired = 0;
        this.selection.registerBeforeChange(() => beforeFired++);
        this.selection.registerAfterChange(() => afterFired++);

        this.selection.reset();

        assert.strictEqual(this.selection.selectedBlockKey, null);
        assert.strictEqual(this.selection.selectedBlockData, null);
        assert.strictEqual(this.selection.selectionCount, 0);
        assert.strictEqual(beforeFired, 0, "no before-change hook fired");
        assert.strictEqual(afterFired, 0, "no after-change hook fired");
      });
    });
  }
);
