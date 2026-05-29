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

@block("wf:svc-test-tile", { args: { title: { type: "string" } } })
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

module("Unit | Discourse Wireframe | service:wireframe", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.editor = getOwner(this).lookup("service:wireframe");
  });

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    this.editor.exit();
  });

  module("selectBlock / isBlockSelected", function () {
    test("selectBlock stores the key and the snapshot", function (assert) {
      this.editor.selectBlock({
        key: "wf:svc-test-tile:1",
        name: "wf:svc-test-tile",
      });
      assert.strictEqual(this.editor.selectedBlockKey, "wf:svc-test-tile:1");
      assert.strictEqual(
        this.editor.selectedBlockData.name,
        "wf:svc-test-tile"
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
        key: "wf:svc-test-tile:7",
        name: "wf:svc-test-tile",
      });
      assert.true(this.editor.isBlockSelected("wf:svc-test-tile:7"));
      assert.false(this.editor.isBlockSelected("wf:svc-test-tile:8"));
      assert.false(this.editor.isBlockSelected(null));
    });

    test("selectBlock({ key }) resolves name, args, and metadata from the layout", async function (assert) {
      withTestBlockRegistration(() => registerBlock(TestTile));
      const layout = await registerTestLayout(getOwner(this));
      const stableKey = layout[0].__stableKey;
      const key = `wf:svc-test-tile:${stableKey}`;

      // Programmatic callers (eg. drag-and-drop auto-select) only have the
      // block key. selectBlock must hydrate the rest from the live layout so
      // the inspector sees the real schema — without it the args render via
      // inferSchemaFromValues and image / icon / etc. controls degrade to
      // the generic "any" code editor.
      this.editor.selectBlock({ key });

      assert.strictEqual(this.editor.selectedBlockKey, key);
      assert.strictEqual(
        this.editor.selectedBlockData.name,
        "wf:svc-test-tile"
      );
      assert.deepEqual(this.editor.selectedBlockData.argsSnapshot, {
        title: "Original",
      });
      assert.deepEqual(this.editor.selectedBlockData.metadata?.args, {
        title: { type: "string" },
      });
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
        key: `wf:svc-test-tile:${stableKey}`,
        name: "wf:svc-test-tile",
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
      assert.strictEqual(this.editor.selectedBlockData.args.title, "Original");
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

    test("setting an arg to null deletes the key", async function (assert) {
      // FormKit emits `null` when a text input is cleared. The validator
      // rejects null (typeof null === "object" !== "string"), so the
      // editor's contract is: cleared field → key omitted from args.
      await editArg(this.editor, "title", "Edited");
      await editArg(this.editor, "title", null);
      assert.false(
        "title" in this.editor.selectedBlockData.args,
        "the title key is absent from args"
      );
    });

    test("setting an arg to undefined deletes the key", async function (assert) {
      await editArg(this.editor, "title", "Edited");
      await editArg(this.editor, "title", undefined);
      assert.false(
        "title" in this.editor.selectedBlockData.args,
        "the title key is absent from args"
      );
    });

    test("setting an arg to empty string writes the empty string", async function (assert) {
      // `""` is a valid string the user may have intentionally typed.
      // Only `null` / `undefined` are stripped.
      await editArg(this.editor, "title", "");
      assert.true(
        "title" in this.editor.selectedBlockData.args,
        "the title key stays present"
      );
      assert.strictEqual(this.editor.selectedBlockData.args.title, "");
    });

    test("editing an arg clears stale validator soft-failure stamps", async function (assert) {
      // `markEntrySoftFailure` (in core's validator) stamps these
      // directly on the entry when permissive validation finds a
      // problem. They persist past the underlying fix until the next
      // layer republish; the live arg-write needs to clear them so
      // the outline / inspector stop showing the stale error.
      const entry = this.editor.selectedBlockData.args;
      // Look up the live entry (the bound args' parent) and stamp it
      // as the validator would.
      const located = this.editor._findEntryAndOutletSync(
        this.editor.selectedBlockKey
      );
      located.entry.__failureType = "structural-invalid";
      located.entry.__failureReason = "stale";
      located.entry.__visible = false;

      await editArg(this.editor, "title", "Edited");

      assert.false("__failureType" in located.entry);
      assert.false("__failureReason" in located.entry);
      assert.false("__visible" in located.entry);
      // Sanity: the entry's args mutation still landed.
      assert.strictEqual(entry.title, "Edited");
    });

    test("validationWarnings drops the stale entry the moment its stamp clears", async function (assert) {
      // Mirrors the failure trail core's permissive validator leaves
      // behind: a per-entry `__failureReason` stamp PLUS an entry on
      // the layer record's `validationWarnings` array. The editor's
      // public getter must follow the stamp (the live truth) — not
      // the layer array (frozen at validation time) — so the
      // inspector banner clears as soon as the author edits the arg
      // that was failing.
      const located = this.editor._findEntryAndOutletSync(
        this.editor.selectedBlockKey
      );
      located.entry.__failureType = "arg-invalid";
      located.entry.__failureReason =
        'Arg "title" must be a string, got number.';

      assert.deepEqual(
        this.editor.validationWarnings.map((w) => w.message),
        ['Arg "title" must be a string, got number.'],
        "the stamp surfaces as a warning"
      );

      await editArg(this.editor, "title", "Edited");

      assert.deepEqual(
        this.editor.validationWarnings,
        [],
        "fixing the arg drops the warning in lockstep with the stamp clear"
      );
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
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.enter();
    });

    test("moves a block within the same outlet (after)", function (assert) {
      // Read keys after enter() — drafts get fresh stable keys minted by
      // _setLayoutLayer's assignStableKeys pass.
      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      const secondKey = `wf:svc-test-tile:${draft[1].__stableKey}`;

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
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      const secondKey = `wf:svc-test-tile:${draft[1].__stableKey}`;

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
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      const secondKey = `wf:svc-test-tile:${draft[1].__stableKey}`;

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
      const realKey = `wf:svc-test-tile:${draft[0].__stableKey}`;

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
        blockKey: "wf:svc-test-tile:1",
        outletName: "homepage-blocks",
      });
      assert.true(this.editor.isDragging);
      assert.true(
        document.body.classList.contains("wireframe-dragging"),
        "body class is added during drag"
      );
      this.editor.endDrag();
      assert.false(this.editor.isDragging);
      assert.false(
        document.body.classList.contains("wireframe-dragging"),
        "body class is removed after drag"
      );
    });

    test("setActiveDropTarget / clearActiveDropTarget round-trips", function (assert) {
      assert.strictEqual(this.editor.activeDropTarget, null);
      const target = {
        targetKey: "wf:svc-test-tile:1",
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
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.enter();
    });

    test("inserts a freshly-minted entry after the target", function (assert) {
      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const targetKey = `wf:svc-test-tile:${draft[0].__stableKey}`;

      const ok = this.editor.insertBlock({
        blockName: "wf:svc-test-tile",
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
        blockName: "wf:svc-test-tile",
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
        blockName: "wf:svc-test-tile",
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      assert.true(this.editor.isDirty);
    });

    test("resetAll restores the pre-insert layout", async function (assert) {
      this.editor.insertBlock({
        blockName: "wf:svc-test-tile",
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
        blockName: "wf:svc-test-tile",
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

  module("annotate-on-insert (grid)", function (innerHooks) {
    innerHooks.beforeEach(async function () {
      withTestBlockRegistration(() => registerBlock(TestTile));
      // Force-load the starter pre-initializer so `wf:layout`
      // (which declares the grid `childArgs` schema) is registered
      // for the assertions below.
      await import("discourse/plugins/discourse-wireframe/discourse/pre-initializers/register-starter-blocks");
      this.layout = await _renderBlocks(
        "homepage-blocks",
        [
          {
            block: "wf:layout",
            args: { mode: "grid", columns: 4, rows: 2 },
            children: [
              {
                block: TestTile,
                args: { title: "Seed" },
                containerArgs: {
                  grid: {
                    column: "1",
                    row: "1",
                    align: "stretch",
                    justify: "stretch",
                  },
                },
              },
            ],
          },
        ],
        getOwner(this)
      );
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.enter();
    });

    test("inserts into a grid layout annotate the entry with containerArgs.grid", function (assert) {
      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const gridKey = `wf:layout:${draft[0].__stableKey}`;

      const ok = this.editor.insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "In grid" },
        targetKey: gridKey,
        position: "inside",
        targetOutletName: "homepage-blocks",
      });

      assert.true(ok);
      const after = this.editor.readResolvedLayout("homepage-blocks");
      const gridChildren = after[0].children ?? [];
      assert.strictEqual(
        gridChildren.length,
        2,
        "the seed tile plus one new cell"
      );

      // insertEntryAt(_, _, _, "inside") prepends.
      const cell = gridChildren[0];
      assert.strictEqual(cell.args.title, "In grid");
      assert.deepEqual(cell.containerArgs.grid, {
        column: "auto",
        row: "auto",
        align: "stretch",
        justify: "stretch",
      });
    });

    test("setSlotPlacement updates a cell's column/row and is undoable", async function (assert) {
      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const gridKey = `wf:layout:${draft[0].__stableKey}`;

      // Seed a placed tile via insertBlockAtCell so we have a cell to
      // reposition.
      this.editor.insertBlockAtCell({
        gridKey,
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "Movable" },
        column: 2,
        row: 1,
      });
      const afterInsert = this.editor.readResolvedLayout("homepage-blocks");
      const cell = afterInsert[0].children.find(
        (c) => c.args?.title === "Movable"
      );
      const cellKey = `wf:svc-test-tile:${cell.__stableKey}`;
      assert.strictEqual(cell.containerArgs.grid.column, "2");

      const ok = this.editor.setSlotPlacement({
        slotKey: cellKey,
        column: "3",
        row: "2",
      });
      assert.true(ok);

      const afterMove = this.editor.readResolvedLayout("homepage-blocks");
      const movedCell = afterMove[0].children.find(
        (c) => c.__stableKey === cell.__stableKey
      );
      assert.strictEqual(movedCell.containerArgs.grid.column, "3");
      assert.strictEqual(movedCell.containerArgs.grid.row, "2");

      // Undo: back to the previous placement.
      await this.editor.undo();
      const undone = this.editor.readResolvedLayout("homepage-blocks");
      const undoneCell = undone[0].children.find(
        (c) => c.__stableKey === cell.__stableKey
      );
      assert.strictEqual(undoneCell.containerArgs.grid.column, "2");
      assert.strictEqual(undoneCell.containerArgs.grid.row, "1");
    });

    test("inserts into a non-grid container do NOT annotate containerArgs.grid", function (assert) {
      // The outlet root isn't a grid; inserts at root level should
      // skip the placement annotation.
      const ok = this.editor.insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "At root" },
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      });

      assert.true(ok);
      const after = this.editor.readResolvedLayout("homepage-blocks");
      const lastEntry = after.at(-1);
      assert.strictEqual(
        lastEntry.containerArgs?.grid,
        undefined,
        "root-level inserts carry no grid placement"
      );
    });
  });

  module("inlineEdit.applyChange — entry without args", function (innerHooks) {
    innerHooks.beforeEach(async function () {
      withTestBlockRegistration(() => registerBlock(TestTile));
      // Layout entry intentionally has no `args` field — mirrors what
      // `serializeEntryForSave` produces for a block whose schema args
      // are all empty (e.g. a freshly-dropped media card the user
      // hasn't filled in). On reload that entry comes back as
      // `{ block: ... }` with no args object.
      this.layout = await _renderBlocks(
        "homepage-blocks",
        [{ block: TestTile }],
        getOwner(this)
      );
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.enter();
    });

    test("writes the value when the entry started without an args object", async function (assert) {
      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const key = `wf:svc-test-tile:${draft[0].__stableKey}`;

      const opened = await this.editor.inlineEdit.start(key, "title");
      assert.true(opened);

      this.editor.inlineEdit.applyChange("Typed");

      const after = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(after[0].args?.title, "Typed");
    });

    test("committing an empty value is a no-op when the entry has no args", async function (assert) {
      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const key = `wf:svc-test-tile:${draft[0].__stableKey}`;

      const opened = await this.editor.inlineEdit.start(key, "title");
      assert.true(opened);

      this.editor.inlineEdit.applyChange("");

      const after = this.editor.readResolvedLayout("homepage-blocks");
      assert.false(
        "title" in (after[0].args ?? {}),
        "no key written for an empty commit"
      );
    });
  });

  module(
    "inlineEdit.stop — undo gate for doc-JSON values",
    function (innerHooks) {
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        this.layout = await _renderBlocks(
          "homepage-blocks",
          [{ block: TestTile, args: { title: "seed" } }],
          getOwner(this)
        );
        this.editor.siteSettings.wireframe_enabled = true;
        logIn(getOwner(this));
        this.editor = getOwner(this).lookup("service:wireframe");
        this.editor.enter();

        // Swap in a doc-JSON value post-render to mimic marked inline
        // text. The block validator declares `title` as a string, but
        // it only runs at render time; direct mutation isn't re-checked,
        // which is enough to exercise the undo-gating comparator.
        const draft = this.editor.readResolvedLayout("homepage-blocks");
        draft[0].args.title = {
          type: "doc",
          content: [
            { type: "text", text: "hello", marks: [{ type: "strong" }] },
          ],
        };
        this.key = `wf:svc-test-tile:${draft[0].__stableKey}`;
      });

      test("committing an unchanged doc-JSON value doesn't push undo", async function (assert) {
        const opened = await this.editor.inlineEdit.start(this.key, "title");
        assert.true(opened);
        assert.false(this.editor.canUndo, "no undo entry before commit");

        // Fresh object reference, identical content — what
        // `toStorage(doc.toJSON())` produces on every commit for marked
        // text. `Object.is` returns false; only a deep-equal comparator
        // recognizes the no-op.
        this.editor.inlineEdit.applyChange({
          type: "doc",
          content: [
            { type: "text", text: "hello", marks: [{ type: "strong" }] },
          ],
        });
        this.editor.inlineEdit.stop({ commit: true });

        assert.false(
          this.editor.canUndo,
          "no spurious undo entry for an unchanged doc-JSON commit"
        );
      });

      test("committing a CHANGED doc-JSON value DOES push undo", async function (assert) {
        const opened = await this.editor.inlineEdit.start(this.key, "title");
        assert.true(opened);

        this.editor.inlineEdit.applyChange({
          type: "doc",
          content: [
            { type: "text", text: "world", marks: [{ type: "strong" }] },
          ],
        });
        this.editor.inlineEdit.stop({ commit: true });

        assert.true(
          this.editor.canUndo,
          "real content changes still push undo entries"
        );
      });
    }
  );

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
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.enter();
    });

    test("copySelected stores a clone with mode='copy'", function (assert) {
      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
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
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
      });

      assert.true(this.editor.cutSelected());
      assert.strictEqual(this.editor._clipboard.mode, "cut");
      const after = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(after.length, 1);
      assert.strictEqual(after[0].args.title, "Second");
    });

    test("pasteFromClipboard inserts a fresh clone after the selection", function (assert) {
      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
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
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
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
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
      });
      this.editor.copySelected();
      this.editor.pasteFromClipboard();
      this.editor.pasteFromClipboard();

      const after = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(after.length, 4);
    });

    test("pasteFromClipboard returns false when clipboard is empty", function (assert) {
      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
      });
      assert.false(this.editor.pasteFromClipboard());
    });

    test("pasteFromClipboard returns false when no block is selected", function (assert) {
      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
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
          blockName: "wf:svc-test-tile",
          targetOutletName: "homepage-blocks",
        })
      );
    });

    test("refuses inserts for unknown outlets when allowedOutlets is set", function (assert) {
      @block("wf:svc-test-restricted", { allowedOutlets: ["other-outlet"] })
      class RestrictedTile extends Component {}

      withTestBlockRegistration(() => registerBlock(RestrictedTile));
      assert.false(
        this.editor.canInsertBlockAt({
          blockName: "wf:svc-test-restricted",
          targetOutletName: "homepage-blocks",
        })
      );
      assert.true(
        this.editor.canInsertBlockAt({
          blockName: "wf:svc-test-restricted",
          targetOutletName: "other-outlet",
        })
      );
    });

    test("refuses inserts for outlets in deniedOutlets", function (assert) {
      @block("wf:svc-test-denied", { deniedOutlets: ["homepage-blocks"] })
      class DeniedTile extends Component {}

      withTestBlockRegistration(() => registerBlock(DeniedTile));
      assert.false(
        this.editor.canInsertBlockAt({
          blockName: "wf:svc-test-denied",
          targetOutletName: "homepage-blocks",
        })
      );
    });

    test("is permissive for unknown block names (validator catches on save)", function (assert) {
      assert.true(
        this.editor.canInsertBlockAt({
          blockName: "wf:svc-test-unknown",
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
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.enter();

      const draft = this.editor.readResolvedLayout("homepage-blocks");
      const key = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.selectBlock({ key, name: "wf:svc-test-tile" });
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

  module("structural undo / redo", function (innerHooks) {
    innerHooks.beforeEach(async function () {
      withTestBlockRegistration(() => registerBlock(TestTile));
      await _renderBlocks(
        "homepage-blocks",
        [
          { block: TestTile, args: { title: "First" } },
          { block: TestTile, args: { title: "Second" } },
        ],
        getOwner(this)
      );
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.enter();

      const draft = this.editor.readResolvedLayout("homepage-blocks");
      this.firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.secondKey = `wf:svc-test-tile:${draft[1].__stableKey}`;
    });

    test("moveBlock pushes an undoable structural entry", async function (assert) {
      this.editor.moveBlock({
        sourceKey: this.firstKey,
        targetKey: this.secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      assert.true(this.editor.canUndo, "undo stack is populated");

      const moved = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(moved[0].args.title, "Second");

      const undone = await this.editor.undo();
      assert.true(undone);

      const restored = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(restored[0].args.title, "First");
      assert.strictEqual(restored[1].args.title, "Second");
    });

    test("redo re-applies a structural move", async function (assert) {
      this.editor.moveBlock({
        sourceKey: this.firstKey,
        targetKey: this.secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      await this.editor.undo();
      const redone = await this.editor.redo();
      assert.true(redone);

      const after = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(after[0].args.title, "Second");
      assert.strictEqual(after[1].args.title, "First");
    });

    test("insertBlock can be undone, removing the inserted entry", async function (assert) {
      this.editor.insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "Inserted" },
        targetKey: this.secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      const afterInsert = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(afterInsert.length, 3);

      await this.editor.undo();
      const restored = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(restored.length, 2);
      assert.strictEqual(restored[0].args.title, "First");
      assert.strictEqual(restored[1].args.title, "Second");
    });

    test("removeBlock can be undone, restoring the deleted entry", async function (assert) {
      this.editor.selectBlock({
        key: this.secondKey,
        name: "wf:svc-test-tile",
      });
      this.editor.removeBlock(this.secondKey);
      let after = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(after.length, 1);

      await this.editor.undo();
      after = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(after.length, 2);
      assert.strictEqual(after[1].args.title, "Second");
    });

    test("duplicateBlock can be undone", async function (assert) {
      this.editor.duplicateBlock(this.firstKey);
      let after = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(after.length, 3);

      await this.editor.undo();
      after = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(after.length, 2);
    });

    test("updateSelectedConditions feeds the undo stack", async function (assert) {
      this.editor.selectBlock({
        key: this.firstKey,
        name: "wf:svc-test-tile",
      });
      const next = { type: "user", admin: true };
      assert.true(this.editor.updateSelectedConditions(next));

      const undone = await this.editor.undo();
      assert.true(undone);
      const after = this.editor.readResolvedLayout("homepage-blocks");
      assert.strictEqual(after[0].conditions, undefined);
    });

    test("a fresh structural mutation clears the redo stack", function (assert) {
      this.editor.moveBlock({
        sourceKey: this.firstKey,
        targetKey: this.secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      this.editor.undo();
      assert.true(this.editor.canRedo);
      this.editor.duplicateBlock(this.firstKey);
      assert.false(this.editor.canRedo);
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
      assert.true(this.editor.isSimulating, "persona-only sim is still active");
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

  module("_isInsideAllowedScope", function (innerHooks) {
    innerHooks.afterEach(function () {
      document
        .querySelectorAll(".__wf-allowed-scope-test")
        .forEach((el) => el.remove());
    });

    function appendScope(className) {
      const wrap = document.createElement("div");
      wrap.className = `${className} __wf-allowed-scope-test`;
      const child = document.createElement("button");
      wrap.appendChild(child);
      document.body.appendChild(wrap);
      return child;
    }

    test("a click target inside a FloatKit tooltip's portaled content stays in-scope", function (assert) {
      // The portaled tooltip body carries `fk-d-tooltip__content`; the
      // bare `fk-d-tooltip` class never appears on the portal, so the
      // safety check must match `__content` for clicks inside an
      // interactive tooltip (the URL-edit chip) to NOT deselect.
      const child = appendScope("fk-d-tooltip__content");
      assert.true(this.editor._isInsideAllowedScope(child));
    });

    test("a click target inside a FloatKit menu stays in-scope", function (assert) {
      const child = appendScope("fk-d-menu");
      assert.true(this.editor._isInsideAllowedScope(child));
    });

    test("a click target outside any editor scope is out-of-scope", function (assert) {
      const child = appendScope("");
      assert.false(this.editor._isInsideAllowedScope(child));
    });
  });
});
