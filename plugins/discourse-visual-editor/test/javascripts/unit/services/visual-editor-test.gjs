import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

@block("ve:svc-test-tile", { args: { title: { type: "string" } } })
class TestTile extends Component {
  <template>
    <div class="tile">{{@title}}</div>
  </template>
}

function registerTestLayout(owner) {
  return _renderBlocks(
    "homepage-blocks",
    [{ block: TestTile, args: { title: "Original" } }],
    owner
  );
}

/**
 * Records a pending arg change and immediately flushes the batch.
 * Production code debounces — tests bypass that to assert synchronously.
 */
async function editArg(editor, argName, value) {
  editor.updateSelectedArg(argName, value);
  return editor._flushPendingArgs();
}

module(
  "Unit | Discourse Visual Editor | service:visual-editor",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.editor = getOwner(this).lookup("service:visual-editor");
    });

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
      this.editor.exit();
    });

    module("selectBlock / isBlockSelected", function () {
      test("selectBlock stores the key and the snapshot", function (assert) {
        this.editor.selectBlock({
          key: "ve:svc-test-tile:1",
          name: "ve:svc-test-tile",
        });
        assert.strictEqual(this.editor.selectedBlockKey, "ve:svc-test-tile:1");
        assert.strictEqual(
          this.editor.selectedBlockData.name,
          "ve:svc-test-tile"
        );
      });

      test("selectBlock(null) clears the selection", function (assert) {
        this.editor.selectBlock({ key: "x", name: "y" });
        this.editor.selectBlock(null);
        assert.strictEqual(this.editor.selectedBlockKey, null);
        assert.strictEqual(this.editor.selectedBlockData, null);
      });

      test("isBlockSelected matches the stored key only", function (assert) {
        this.editor.selectBlock({
          key: "ve:svc-test-tile:7",
          name: "ve:svc-test-tile",
        });
        assert.true(this.editor.isBlockSelected("ve:svc-test-tile:7"));
        assert.false(this.editor.isBlockSelected("ve:svc-test-tile:8"));
        assert.false(this.editor.isBlockSelected(null));
      });
    });

    module("updateSelectedArg / undo / redo / resetAll", function (innerHooks) {
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        const layout = await registerTestLayout(getOwner(this));
        // Stable keys are minted from a module-level counter that
        // `_resetOutletLayoutsForTesting` resets between tests, so we
        // can't hardcode the suffix — read it back from the layout.
        const stableKey = layout[0].__stableKey;
        this.editor.selectBlock({
          key: `ve:svc-test-tile:${stableKey}`,
          name: "ve:svc-test-tile",
          args: { title: "Original" },
          metadata: { args: { title: { type: "string" } } },
        });
      });

      test("updateSelectedArg refreshes the selection snapshot", async function (assert) {
        const ok = await editArg(this.editor, "title", "Edited");
        assert.true(ok);
        assert.strictEqual(this.editor.selectedBlockData.args.title, "Edited");
      });

      test("an edit pushes onto the undo stack and clears redo", async function (assert) {
        assert.false(this.editor.canUndo);
        await editArg(this.editor, "title", "Edited");
        assert.true(this.editor.canUndo);
        assert.false(this.editor.canRedo);
      });

      test("undo restores the previous value and enables redo", async function (assert) {
        await editArg(this.editor, "title", "Edited");
        const undone = await this.editor.undo();
        assert.true(undone);
        assert.strictEqual(
          this.editor.selectedBlockData.args.title,
          "Original"
        );
        assert.true(this.editor.canRedo);
        assert.false(this.editor.canUndo);
      });

      test("redo re-applies the most recently undone edit", async function (assert) {
        await editArg(this.editor, "title", "Edited");
        await this.editor.undo();
        const redone = await this.editor.redo();
        assert.true(redone);
        assert.strictEqual(this.editor.selectedBlockData.args.title, "Edited");
        assert.true(this.editor.canUndo);
        assert.false(this.editor.canRedo);
      });

      test("a fresh edit after undo discards the redo stack", async function (assert) {
        await editArg(this.editor, "title", "First");
        await this.editor.undo();
        assert.true(this.editor.canRedo);
        await editArg(this.editor, "title", "Second");
        assert.false(this.editor.canRedo);
      });

      test("isDirty flips on the first edit and back off after resetAll", async function (assert) {
        assert.false(this.editor.isDirty);
        await editArg(this.editor, "title", "Edited");
        assert.true(this.editor.isDirty);
        const reset = await this.editor.resetAll();
        assert.true(reset);
        assert.false(this.editor.isDirty);
        assert.false(this.editor.canUndo);
        assert.false(this.editor.canRedo);
      });

      test("undo / redo return false when their stacks are empty", async function (assert) {
        assert.false(await this.editor.undo());
        assert.false(await this.editor.redo());
      });
    });

    module("moveBlock", function (innerHooks) {
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        // Two top-level tiles in homepage-blocks; we'll exercise reordering
        // them via `moveBlock`. Mid-validation `entry.args` are wrapped in
        // trackedObject — `moveEntry` doesn't touch args, just structure.
        this.layout = await _renderBlocks(
          "homepage-blocks",
          [
            { block: TestTile, args: { title: "First" } },
            { block: TestTile, args: { title: "Second" } },
          ],
          getOwner(this)
        );
        // The plugin ships disabled by default; `enter()` early-returns
        // when `canEdit` is false. Enabling the setting + logging in as
        // a staff user lets `_materializeAllDrafts()` populate
        // `_originalLayouts`, which `resetAll` reads from on rollback.
        // After this re-lookup the rest of the moveBlock tests use the
        // editor with editing enabled.
        this.editor.siteSettings.visual_editor_enabled = true;
        logIn(getOwner(this));
        this.editor = getOwner(this).lookup("service:visual-editor");
        this.editor.enter();
      });

      test("moves a block within the same outlet (after)", function (assert) {
        // Read keys after enter() — drafts get fresh stable keys minted by
        // _setLayoutLayer's assignStableKeys pass.
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const firstKey = `ve:svc-test-tile:${draft[0].__stableKey}`;
        const secondKey = `ve:svc-test-tile:${draft[1].__stableKey}`;

        const ok = this.editor.moveBlock({
          sourceKey: firstKey,
          targetKey: secondKey,
          position: "after",
          targetOutletName: "homepage-blocks",
        });

        assert.true(ok);
        const after = this.editor.readResolvedLayout("homepage-blocks");
        assert.strictEqual(after[0].args.title, "Second");
        assert.strictEqual(after[1].args.title, "First");
      });

      test("isDirty flips on after a move", function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const firstKey = `ve:svc-test-tile:${draft[0].__stableKey}`;
        const secondKey = `ve:svc-test-tile:${draft[1].__stableKey}`;

        assert.false(this.editor.isDirty);
        this.editor.moveBlock({
          sourceKey: firstKey,
          targetKey: secondKey,
          position: "before",
          targetOutletName: "homepage-blocks",
        });
        assert.true(this.editor.isDirty);
      });

      test("resetAll restores the pre-edit layout after a move", async function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const firstKey = `ve:svc-test-tile:${draft[0].__stableKey}`;
        const secondKey = `ve:svc-test-tile:${draft[1].__stableKey}`;

        this.editor.moveBlock({
          sourceKey: firstKey,
          targetKey: secondKey,
          position: "after",
          targetOutletName: "homepage-blocks",
        });

        const ok = await this.editor.resetAll();
        assert.true(ok);
        const restored = this.editor.readResolvedLayout("homepage-blocks");
        assert.strictEqual(restored[0].args.title, "First");
        assert.strictEqual(restored[1].args.title, "Second");
        assert.false(this.editor.isDirty);
      });

      test("rejects moves with an unknown source key", function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const realKey = `ve:svc-test-tile:${draft[0].__stableKey}`;

        const ok = this.editor.moveBlock({
          sourceKey: "absent:0",
          targetKey: realKey,
          position: "after",
          targetOutletName: "homepage-blocks",
        });
        assert.false(ok);
      });

      test("dragging state toggles via startDrag/endDrag", function (assert) {
        assert.false(this.editor.isDragging);
        this.editor.startDrag({
          blockKey: "ve:svc-test-tile:1",
          outletName: "homepage-blocks",
        });
        assert.true(this.editor.isDragging);
        assert.true(
          document.body.classList.contains("visual-editor-dragging"),
          "body class is added during drag"
        );
        this.editor.endDrag();
        assert.false(this.editor.isDragging);
        assert.false(
          document.body.classList.contains("visual-editor-dragging"),
          "body class is removed after drag"
        );
      });

      test("setActiveDropTarget / clearActiveDropTarget round-trips", function (assert) {
        assert.strictEqual(this.editor.activeDropTarget, null);
        const target = {
          targetKey: "ve:svc-test-tile:1",
          position: "before",
          outletName: "homepage-blocks",
        };
        this.editor.setActiveDropTarget(target);
        assert.deepEqual(this.editor.activeDropTarget, target);
        this.editor.clearActiveDropTarget(target);
        assert.strictEqual(this.editor.activeDropTarget, null);
      });

      test("clearActiveDropTarget ignores stale targets", function (assert) {
        const a = {
          targetKey: "key-a",
          position: "before",
          outletName: "homepage-blocks",
        };
        const b = {
          targetKey: "key-b",
          position: "before",
          outletName: "homepage-blocks",
        };
        this.editor.setActiveDropTarget(a);
        this.editor.clearActiveDropTarget(b);
        assert.deepEqual(
          this.editor.activeDropTarget,
          a,
          "clearing a different target leaves the active one intact"
        );
      });
    });

    module("insertBlock", function (innerHooks) {
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        this.layout = await _renderBlocks(
          "homepage-blocks",
          [{ block: TestTile, args: { title: "Existing" } }],
          getOwner(this)
        );
        this.editor.siteSettings.visual_editor_enabled = true;
        logIn(getOwner(this));
        this.editor = getOwner(this).lookup("service:visual-editor");
        this.editor.enter();
      });

      test("inserts a freshly-minted entry after the target", function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const targetKey = `ve:svc-test-tile:${draft[0].__stableKey}`;

        const ok = this.editor.insertBlock({
          blockName: "ve:svc-test-tile",
          defaultArgs: { title: "Inserted" },
          targetKey,
          position: "after",
          targetOutletName: "homepage-blocks",
        });

        assert.true(ok);
        const after = this.editor.readResolvedLayout("homepage-blocks");
        assert.strictEqual(after.length, 2);
        assert.strictEqual(after[0].args.title, "Existing");
        assert.strictEqual(after[1].args.title, "Inserted");
      });

      test("appends to the outlet root when targetKey is null", function (assert) {
        const ok = this.editor.insertBlock({
          blockName: "ve:svc-test-tile",
          defaultArgs: { title: "Appended" },
          targetKey: null,
          position: "after",
          targetOutletName: "homepage-blocks",
        });

        assert.true(ok);
        const after = this.editor.readResolvedLayout("homepage-blocks");
        assert.strictEqual(after.at(-1).args.title, "Appended");
      });

      test("isDirty flips on after an insert", function (assert) {
        assert.false(this.editor.isDirty);
        this.editor.insertBlock({
          blockName: "ve:svc-test-tile",
          targetKey: null,
          position: "after",
          targetOutletName: "homepage-blocks",
        });
        assert.true(this.editor.isDirty);
      });

      test("resetAll restores the pre-insert layout", async function (assert) {
        this.editor.insertBlock({
          blockName: "ve:svc-test-tile",
          defaultArgs: { title: "Throwaway" },
          targetKey: null,
          position: "after",
          targetOutletName: "homepage-blocks",
        });

        const ok = await this.editor.resetAll();
        assert.true(ok);
        const restored = this.editor.readResolvedLayout("homepage-blocks");
        assert.strictEqual(restored.length, 1);
        assert.strictEqual(restored[0].args.title, "Existing");
        assert.false(this.editor.isDirty);
      });

      test("default args don't bleed back into the source object", function (assert) {
        const defaults = { title: "Shared" };

        this.editor.insertBlock({
          blockName: "ve:svc-test-tile",
          defaultArgs: defaults,
          targetKey: null,
          position: "after",
          targetOutletName: "homepage-blocks",
        });

        // Future mutations on the rendered entry must not reach back into
        // the defaults payload the palette passed in.
        const after = this.editor.readResolvedLayout("homepage-blocks");
        const inserted = after.at(-1);
        inserted.args.title = "Mutated";
        assert.strictEqual(defaults.title, "Shared");
      });
    });

    module("clipboard (copy / cut / paste)", function (innerHooks) {
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        this.layout = await _renderBlocks(
          "homepage-blocks",
          [
            { block: TestTile, args: { title: "First" } },
            { block: TestTile, args: { title: "Second" } },
          ],
          getOwner(this)
        );
        this.editor.siteSettings.visual_editor_enabled = true;
        logIn(getOwner(this));
        this.editor = getOwner(this).lookup("service:visual-editor");
        this.editor.enter();
      });

      test("copySelected stores a clone with mode='copy'", function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const firstKey = `ve:svc-test-tile:${draft[0].__stableKey}`;
        this.editor.selectBlock({
          key: firstKey,
          name: "ve:svc-test-tile",
        });

        assert.true(this.editor.copySelected());
        assert.true(this.editor.hasClipboardEntry);
        assert.strictEqual(this.editor._clipboard.mode, "copy");
        assert.strictEqual(this.editor._clipboard.entry.args.title, "First");
        assert.strictEqual(
          this.editor._clipboard.entry.__stableKey,
          undefined,
          "clipboard entry strips __stableKey so paste mints a fresh one"
        );
      });

      test("copySelected returns false when nothing is selected", function (assert) {
        assert.false(this.editor.copySelected());
        assert.false(this.editor.hasClipboardEntry);
      });

      test("cutSelected stores the entry and removes it from the canvas", function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const firstKey = `ve:svc-test-tile:${draft[0].__stableKey}`;
        this.editor.selectBlock({
          key: firstKey,
          name: "ve:svc-test-tile",
        });

        assert.true(this.editor.cutSelected());
        assert.strictEqual(this.editor._clipboard.mode, "cut");
        const after = this.editor.readResolvedLayout("homepage-blocks");
        assert.strictEqual(after.length, 1);
        assert.strictEqual(after[0].args.title, "Second");
      });

      test("pasteFromClipboard inserts a fresh clone after the selection", function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const firstKey = `ve:svc-test-tile:${draft[0].__stableKey}`;
        this.editor.selectBlock({
          key: firstKey,
          name: "ve:svc-test-tile",
        });
        this.editor.copySelected();
        assert.true(this.editor.pasteFromClipboard());

        const after = this.editor.readResolvedLayout("homepage-blocks");
        assert.strictEqual(after.length, 3);
        assert.strictEqual(after[0].args.title, "First");
        assert.strictEqual(
          after[1].args.title,
          "First",
          "paste lands immediately after the selection"
        );
        assert.strictEqual(after[2].args.title, "Second");
      });

      test("pasteFromClipboard mints a fresh stable key for the paste", function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const firstKey = `ve:svc-test-tile:${draft[0].__stableKey}`;
        this.editor.selectBlock({
          key: firstKey,
          name: "ve:svc-test-tile",
        });
        this.editor.copySelected();
        this.editor.pasteFromClipboard();

        const after = this.editor.readResolvedLayout("homepage-blocks");
        const sourceKey = after[0].__stableKey;
        const pastedKey = after[1].__stableKey;
        assert.notStrictEqual(sourceKey, pastedKey);
      });

      test("multiple pastes insert independent subtrees", function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const firstKey = `ve:svc-test-tile:${draft[0].__stableKey}`;
        this.editor.selectBlock({
          key: firstKey,
          name: "ve:svc-test-tile",
        });
        this.editor.copySelected();
        this.editor.pasteFromClipboard();
        this.editor.pasteFromClipboard();

        const after = this.editor.readResolvedLayout("homepage-blocks");
        assert.strictEqual(after.length, 4);
      });

      test("pasteFromClipboard returns false when clipboard is empty", function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const firstKey = `ve:svc-test-tile:${draft[0].__stableKey}`;
        this.editor.selectBlock({
          key: firstKey,
          name: "ve:svc-test-tile",
        });
        assert.false(this.editor.pasteFromClipboard());
      });

      test("pasteFromClipboard returns false when no block is selected", function (assert) {
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const firstKey = `ve:svc-test-tile:${draft[0].__stableKey}`;
        this.editor.selectBlock({
          key: firstKey,
          name: "ve:svc-test-tile",
        });
        this.editor.copySelected();
        this.editor.selectBlock(null);

        assert.false(this.editor.pasteFromClipboard());
      });
    });

    module("canInsertBlockAt", function () {
      test("permits inserts for blocks with no outlet restrictions", function (assert) {
        withTestBlockRegistration(() => registerBlock(TestTile));
        assert.true(
          this.editor.canInsertBlockAt({
            blockName: "ve:svc-test-tile",
            targetOutletName: "homepage-blocks",
          })
        );
      });

      test("refuses inserts for unknown outlets when allowedOutlets is set", function (assert) {
        @block("ve:svc-test-restricted", { allowedOutlets: ["other-outlet"] })
        class RestrictedTile extends Component {}

        withTestBlockRegistration(() => registerBlock(RestrictedTile));
        assert.false(
          this.editor.canInsertBlockAt({
            blockName: "ve:svc-test-restricted",
            targetOutletName: "homepage-blocks",
          })
        );
        assert.true(
          this.editor.canInsertBlockAt({
            blockName: "ve:svc-test-restricted",
            targetOutletName: "other-outlet",
          })
        );
      });

      test("refuses inserts for outlets in deniedOutlets", function (assert) {
        @block("ve:svc-test-denied", { deniedOutlets: ["homepage-blocks"] })
        class DeniedTile extends Component {}

        withTestBlockRegistration(() => registerBlock(DeniedTile));
        assert.false(
          this.editor.canInsertBlockAt({
            blockName: "ve:svc-test-denied",
            targetOutletName: "homepage-blocks",
          })
        );
      });

      test("is permissive for unknown block names (validator catches on save)", function (assert) {
        assert.true(
          this.editor.canInsertBlockAt({
            blockName: "ve:svc-test-unknown",
            targetOutletName: "homepage-blocks",
          })
        );
      });
    });

    module("updateSelectedConditions", function (innerHooks) {
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        await _renderBlocks(
          "homepage-blocks",
          [{ block: TestTile, args: { title: "First" } }],
          getOwner(this)
        );
        this.editor.siteSettings.visual_editor_enabled = true;
        logIn(getOwner(this));
        this.editor = getOwner(this).lookup("service:visual-editor");
        this.editor.enter();

        const draft = this.editor.readResolvedLayout("homepage-blocks");
        const key = `ve:svc-test-tile:${draft[0].__stableKey}`;
        this.editor.selectBlock({ key, name: "ve:svc-test-tile" });
        this.firstKey = key;
      });

      test("commits a fresh condition tree on the selected block", function (assert) {
        const next = { type: "user", loggedIn: true };
        assert.true(this.editor.updateSelectedConditions(next));

        const draft = this.editor.readResolvedLayout("homepage-blocks");
        assert.deepEqual(draft[0].conditions, next);
        assert.true(this.editor.isDirty);
      });

      test("clears conditions when passed null", function (assert) {
        this.editor.updateSelectedConditions({ type: "user", loggedIn: true });
        assert.true(this.editor.updateSelectedConditions(null));

        const draft = this.editor.readResolvedLayout("homepage-blocks");
        assert.strictEqual(draft[0].conditions, undefined);
      });

      test("returns false when no block is selected", function (assert) {
        this.editor.selectBlock(null);
        assert.false(
          this.editor.updateSelectedConditions({ type: "user", loggedIn: true })
        );
      });

      test("selectedBlockConditions live-resolves the latest tree", function (assert) {
        const next = { type: "user", admin: true };
        this.editor.updateSelectedConditions(next);
        assert.deepEqual(this.editor.selectedBlockConditions, next);
      });

      test("selectedBlockConditions returns null when no selection", function (assert) {
        this.editor.selectBlock(null);
        assert.strictEqual(this.editor.selectedBlockConditions, null);
      });
    });

    module("simulation", function (innerHooks) {
      innerHooks.beforeEach(function () {
        // The simulation slot is editor-session-state and survives without
        // an active editor session; we still test from a clean state.
      });

      innerHooks.afterEach(function () {
        this.editor.clearSimulation();
      });

      test("isSimulating is false by default", function (assert) {
        assert.false(this.editor.isSimulating);
        assert.strictEqual(this.editor.simulation, null);
      });

      test("setSimulatedUser with a persona object marks isSimulating true", function (assert) {
        this.editor.setSimulatedUser({ trust_level: 2, admin: false });
        assert.true(this.editor.isSimulating);
        assert.strictEqual(this.editor.simulation.user.trust_level, 2);
      });

      test("setSimulatedUser(null) means anonymous, still isSimulating", function (assert) {
        this.editor.setSimulatedUser(null);
        assert.true(this.editor.isSimulating);
        assert.true("user" in this.editor.simulation);
        assert.strictEqual(this.editor.simulation.user, null);
      });

      test("setSimulatedUser(undefined) clears the persona slot", function (assert) {
        this.editor.setSimulatedUser({ trust_level: 4 });
        this.editor.setSimulatedUser(undefined);
        assert.false(this.editor.isSimulating);
      });

      test("setSimulatedViewport(undefined) clears viewport but keeps persona", function (assert) {
        this.editor.setSimulatedUser({ trust_level: 2 });
        this.editor.setSimulatedViewport({
          viewport: { sm: true },
          touch: true,
        });
        assert.true(this.editor.isSimulating);

        this.editor.setSimulatedViewport(undefined);
        assert.true(
          this.editor.isSimulating,
          "persona-only sim is still active"
        );
        assert.false("viewport" in this.editor.simulation);
      });

      test("clearSimulation resets everything to null", function (assert) {
        this.editor.setSimulatedUser({ trust_level: 4 });
        this.editor.setSimulatedViewport({
          viewport: { sm: true },
          touch: true,
        });
        this.editor.clearSimulation();
        assert.false(this.editor.isSimulating);
        assert.strictEqual(this.editor.simulation, null);
      });

      test("each sim change bumps structuralVersion (re-renders consumers)", function (assert) {
        const before = this.editor.structuralVersion;
        this.editor.setSimulatedUser({ trust_level: 2 });
        assert.true(this.editor.structuralVersion > before);
      });
    });
  }
);
