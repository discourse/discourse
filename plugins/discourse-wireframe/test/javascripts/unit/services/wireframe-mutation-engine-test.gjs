import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { block } from "discourse/blocks";
import {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { cloneLayoutForDraft } from "discourse/plugins/discourse-wireframe/discourse/lib/mutate-layout";

@block("wf:engine-test-tile", { args: { title: { type: "string" } } })
class EngineTile extends Component {
  <template>
    <div class="engine-tile">{{@title}}</div>
  </template>
}

const OUTLET = "homepage-blocks";

// Registers a real outlet layout so the engine's `_setLayoutLayer` /
// `_clearLayoutLayer` writes resolve against a live block-outlet record — the
// same setup the persistence / navigation peer tests use. Returns the resolved
// (draft-aware) layout the editor sees.
async function registerLayout(owner, args = { title: "Original" }) {
  return _renderBlocks(OUTLET, [{ block: EngineTile, args }], owner);
}

module(
  "Unit | Discourse Wireframe | service:wireframe-mutation-engine",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.engine = this.owner.lookup("service:wireframe-mutation-engine");
      this.query = this.owner.lookup("service:wireframe-layout-query");
      this.selection = this.owner.lookup("service:wireframe-selection");
      withTestBlockRegistration(() => registerBlock(EngineTile));
    });

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
    });

    // Resolves the single tile entry + its key from the live layout.
    function tileOf(context) {
      const entry = context.query.readResolvedLayout(OUTLET)?.[0];
      return { entry, key: `wf:engine-test-tile:${entry.__stableKey}` };
    }

    module("recordStructural", function () {
      test("a no-op mutateFn records nothing and returns the falsy result", async function (assert) {
        await registerLayout(getOwner(this));
        const result = this.engine.recordStructural([OUTLET], () => false);

        assert.false(result, "the falsy result propagates");
        assert.false(this.engine.canUndo, "no undo entry is recorded");
        assert.false(this.engine.isDirty, "no outlet is flagged edited");
      });

      test("a successful mutation records one undo entry and clears redo", async function (assert) {
        const layout = await registerLayout(getOwner(this));
        this.engine.captureBaseline(OUTLET, layout);

        // Record then undo so the redo stack is primed.
        this.engine.recordStructural([OUTLET], () => {
          const next = this.query.readResolvedLayout(OUTLET);
          next[0].args.title = "v2";
          this.engine.publishStructuralChange(OUTLET, next);
          return true;
        });
        await this.engine.undo();
        assert.true(this.engine.canRedo, "redo is primed");

        this.engine.recordStructural([OUTLET], () => {
          const next = this.query.readResolvedLayout(OUTLET);
          next[0].args.title = "v3";
          this.engine.publishStructuralChange(OUTLET, next);
          return true;
        });

        assert.strictEqual(this.engine.undoDepth, 1, "one undo entry");
        assert.false(
          this.engine.canRedo,
          "recording a new edit clears the redo stack"
        );
      });

      test("a cross-outlet mutation records a single undo entry", async function (assert) {
        await registerLayout(getOwner(this));
        await _renderBlocks(
          "sidebar-blocks",
          [{ block: EngineTile, args: { title: "Side" } }],
          getOwner(this)
        );

        this.engine.recordStructural([OUTLET, "sidebar-blocks"], () => {
          const a = this.query.readResolvedLayout(OUTLET);
          a[0].args.title = "A2";
          this.engine.publishStructuralChange(OUTLET, a);
          const b = this.query.readResolvedLayout("sidebar-blocks");
          b[0].args.title = "B2";
          this.engine.publishStructuralChange("sidebar-blocks", b);
          return true;
        });

        assert.strictEqual(
          this.engine.undoDepth,
          1,
          "both outlets share one undo entry"
        );
      });

      test("an edit that lands back on the pristine layout reconciles to not-edited", async function (assert) {
        const layout = await registerLayout(getOwner(this));
        // Baseline equals the published layout; the mutation re-publishes the
        // same shape, so reconcile clears the edited flags (keeping the undo).
        this.engine.captureBaseline(
          OUTLET,
          this.query.readResolvedLayout(OUTLET)
        );
        this.engine.recordStructural([OUTLET], () => {
          this.engine.publishStructuralChange(OUTLET, layout);
          return true;
        });

        assert.false(
          this.engine.isOutletEdited(OUTLET),
          "the outlet reconciles to pristine"
        );
        assert.strictEqual(
          this.engine.undoDepth,
          1,
          "the undo entry survives reconciliation"
        );
      });
    });

    module("undo / redo", function () {
      test("structural undo restores the prev selection", async function (assert) {
        const restore = sinon.stub(this.selection, "restoreSelection");
        const layout = await registerLayout(getOwner(this));

        this.engine.recordStructural([OUTLET], () => {
          const next = this.query.readResolvedLayout(OUTLET);
          next[0].args.title = "Changed";
          this.engine.publishStructuralChange(OUTLET, next);
          return true;
        });

        const undone = await this.engine.undo();

        assert.true(undone, "undo resolves true");
        assert.true(
          restore.called,
          "selection.restoreSelection is invoked on structural undo"
        );
        assert.true(this.engine.canRedo, "the undone entry is redoable");
        // The prev layout is re-published, so the title reverts.
        assert.strictEqual(
          this.query.readResolvedLayout(OUTLET)[0].args.title,
          "Original",
          "undo restores the prev layout"
        );
        void layout;
      });

      test("undo / redo return a Promise<boolean> and are false on an empty stack", async function (assert) {
        const value = await this.engine.undo();
        assert.false(value, "undo on an empty stack resolves false");

        const redoValue = await this.engine.redo();
        assert.false(redoValue, "redo on an empty stack resolves false");
      });

      test("an arg edit round-trips through undo and redo", async function (assert) {
        await registerLayout(getOwner(this));
        const { entry } = tileOf(this);

        this.engine.recordArgBatch({
          entry,
          outletName: OUTLET,
          prevMap: new Map([["title", "Original"]]),
          nextMap: new Map([["title", "After"]]),
        });
        assert.strictEqual(
          entry.args.title,
          "After",
          "the new value is written"
        );

        await this.engine.undo();
        assert.strictEqual(
          entry.args.title,
          "Original",
          "undo restores the prev value"
        );

        await this.engine.redo();
        assert.strictEqual(
          entry.args.title,
          "After",
          "redo re-applies the next value"
        );
      });
    });

    module("recordArgEdit", function () {
      test("pushes an undo entry when the value changes", async function (assert) {
        await registerLayout(getOwner(this));
        const { entry } = tileOf(this);

        this.engine.recordArgEdit({
          entry,
          outletName: OUTLET,
          argName: "title",
          prevValue: "Original",
          nextValue: "Edited",
        });

        assert.strictEqual(entry.args.title, "Edited", "the value is written");
        assert.strictEqual(this.engine.undoDepth, 1, "an undo entry is pushed");
        assert.true(this.engine.isOutletEdited(OUTLET), "the outlet is edited");
      });

      test("does not push an undo entry for an equal value", async function (assert) {
        await registerLayout(getOwner(this));
        const { entry } = tileOf(this);

        this.engine.recordArgEdit({
          entry,
          outletName: OUTLET,
          argName: "title",
          prevValue: "Original",
          nextValue: "Original",
        });

        assert.strictEqual(
          this.engine.undoDepth,
          0,
          "no undo entry for an unchanged value"
        );
      });
    });

    module("captureInitialSnapshot", function () {
      test("first write wins — a later capture doesn't overwrite the snapshot", async function (assert) {
        const layout = await registerLayout(getOwner(this));
        this.engine.captureBaseline(OUTLET, cloneLayoutForDraft(layout));
        const { entry } = tileOf(this);

        this.engine.captureInitialSnapshot(
          entry,
          new Map([["title", "Original"]])
        );
        // A second capture after a mutation must NOT replace the first snapshot.
        entry.args.title = "Edited";
        this.engine.captureInitialSnapshot(
          entry,
          new Map([["title", "Edited"]])
        );

        await this.engine.resetAll();
        await settled();
        assert.strictEqual(
          this.query.readResolvedLayout(OUTLET)[0].args.title,
          "Original",
          "reset restores the first-captured value"
        );
      });
    });

    module("dirty bookkeeping", function () {
      test("clearOutletEditState drops the outlet's edit flags", async function (assert) {
        await registerLayout(getOwner(this));
        const { entry } = tileOf(this);
        this.engine.markOutletStructurallyEdited(OUTLET);
        this.engine.captureInitialSnapshot(
          entry,
          new Map([["title", "Original"]])
        );
        assert.true(this.engine.isOutletEdited(OUTLET), "starts edited");

        this.engine.clearOutletEditState(OUTLET);
        assert.false(
          this.engine.isOutletEdited(OUTLET),
          "the outlet is no longer edited"
        );
      });

      test("clearStacks empties undo and redo", async function (assert) {
        await registerLayout(getOwner(this));
        const { entry } = tileOf(this);
        this.engine.recordArgBatch({
          entry,
          outletName: OUTLET,
          prevMap: new Map([["title", "Original"]]),
          nextMap: new Map([["title", "Y"]]),
        });
        await this.engine.undo();

        this.engine.clearStacks();
        assert.false(this.engine.canUndo, "undo is empty");
        assert.false(this.engine.canRedo, "redo is empty");
      });

      test("dropOutlet forgets a drafted outlet's bookkeeping", async function (assert) {
        await registerLayout(getOwner(this));
        this.engine.markOutletDrafted(OUTLET);
        this.engine.markOutletStructurallyEdited(OUTLET);
        assert.true(this.engine.isOutletDrafted(OUTLET), "starts drafted");

        this.engine.dropOutlet(OUTLET);
        assert.false(this.engine.isOutletDrafted(OUTLET), "no longer drafted");
        assert.false(this.engine.isOutletEdited(OUTLET), "no longer edited");
      });
    });

    module("flushSnapshotsAndReset", function () {
      test("writes snapshots back, clears state, and returns drafted names", async function (assert) {
        await registerLayout(getOwner(this));
        const { entry } = tileOf(this);
        this.engine.markOutletDrafted(OUTLET);
        this.engine.markOutletDrafted("sidebar-blocks");
        // Capture the pristine snapshot, then mutate the live args.
        this.engine.captureInitialSnapshot(
          entry,
          new Map([["title", "Original"]])
        );
        entry.args.title = "Edited";

        const drafted = this.engine.flushSnapshotsAndReset();

        assert.deepEqual(
          [...drafted].sort(),
          ["homepage-blocks", "sidebar-blocks"],
          "returns the drafted outlet names"
        );
        assert.strictEqual(
          entry.args.title,
          "Original",
          "snapshots are written back BEFORE clearing"
        );
        assert.false(this.engine.isDirty, "dirty state is cleared");
        assert.false(this.engine.canUndo, "undo stack is cleared");
        assert.strictEqual(
          this.engine.draftedOutletNames().length,
          0,
          "drafted outlets are cleared"
        );
      });
    });
  }
);
