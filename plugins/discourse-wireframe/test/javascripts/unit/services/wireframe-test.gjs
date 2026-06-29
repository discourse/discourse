import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Layout from "discourse/blocks/builtin/layout";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import { attachEditorShortcuts } from "discourse/plugins/discourse-wireframe/discourse/lib/editor-shortcuts";
import { GRID_DROP_GESTURES } from "discourse/plugins/discourse-wireframe/discourse/lib/grid-drop";
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/mutate-layout";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

@block("wf:svc-test-tile", { args: { title: { type: "string" } } })
class TestTile extends Component {
  <template>
    <div class="tile">{{@title}}</div>
  </template>
}

@block("wf:svc-test-constrained", {
  args: {
    label: { type: "string" },
    icon: { type: "string" },
  },
  constraints: { atLeastOne: ["label", "icon"] },
})
class TestConstrained extends Component {
  <template>
    <div class="constrained">{{@label}}</div>
  </template>
}

// A container that forces every direct child to be a `layout` (the same
// `childBlocks` contract the `tabs` block uses), so its panels are implicit
// layouts and the editor wraps anything else dropped in.
@block("wf:svc-test-tabs", {
  container: true,
  childBlocks: ["layout"],
})
class TestTabs extends Component {
  <template>
    <div class="test-tabs">{{yield}}</div>
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
 * Records a pending arg change and waits for the debounced flush to run.
 * Production code debounces the write; `settled()` lets that timer fire so
 * assertions observe the committed args.
 */
async function editArg(editor, argName, value) {
  getOwner(editor)
    .lookup("service:wireframe-arg-edit")
    .updateSelectedArg(argName, value);
  await settled();
}

/**
 * After `enter()`, each outlet is normalised to a single root `layout` block
 * whose children are the outlet's blocks. Most tests care about those content
 * blocks, so this reads the root layout's children rather than the outlet's
 * top-level array (which is just `[rootLayout]`).
 */
function outletChildren(editor, outlet = "homepage-blocks") {
  return (
    editor.wireframeLayoutQuery.readResolvedLayout(outlet)?.[0]?.children ?? []
  );
}

// Block insertion / relocation and grid placement live on their own peer
// services; these tests reach them directly through the owner rather than the
// kernel, which no longer injects them.
function mutationsOf(editor) {
  return getOwner(editor).lookup("service:wireframe-block-mutations");
}

function gridOf(editor) {
  return getOwner(editor).lookup("service:wireframe-grid-manipulator");
}

module("Unit | Discourse Wireframe | service:wireframe", function (hooks) {
  setupTest(hooks);
  setupBlockLayoutDraftsStub(hooks);

  hooks.beforeEach(function () {
    this.editor = getOwner(this).lookup("service:wireframe");
  });

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    this.editor.exit();
  });

  module("selectBlock / isBlockSelected", function () {
    test("selectBlock stores the key and the snapshot", function (assert) {
      this.editor.wireframeSelection.selectBlock({
        key: "wf:svc-test-tile:1",
        name: "wf:svc-test-tile",
      });
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockKey,
        "wf:svc-test-tile:1"
      );
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockData.name,
        "wf:svc-test-tile"
      );
    });

    test("selectBlock(null) clears the selection", function (assert) {
      this.editor.wireframeSelection.selectBlock({ key: "x", name: "y" });
      this.editor.wireframeSelection.selectBlock(null);
      assert.strictEqual(this.editor.wireframeSelection.selectedBlockKey, null);
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockData,
        null
      );
    });

    test("isBlockSelected matches the stored key only", function (assert) {
      this.editor.wireframeSelection.selectBlock({
        key: "wf:svc-test-tile:7",
        name: "wf:svc-test-tile",
      });
      assert.true(
        this.editor.wireframeSelection.isBlockSelected("wf:svc-test-tile:7")
      );
      assert.false(
        this.editor.wireframeSelection.isBlockSelected("wf:svc-test-tile:8")
      );
      assert.false(this.editor.wireframeSelection.isBlockSelected(null));
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
      this.editor.wireframeSelection.selectBlock({ key });

      assert.strictEqual(this.editor.wireframeSelection.selectedBlockKey, key);
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockData.name,
        "wf:svc-test-tile"
      );
      assert.deepEqual(
        this.editor.wireframeSelection.selectedBlockData.argsSnapshot,
        {
          title: "Original",
        }
      );
      assert.deepEqual(
        this.editor.wireframeSelection.selectedBlockData.metadata?.args,
        {
          title: { type: "string" },
        }
      );
    });

    test("selectBlock flags a registered block as isRegistered", function (assert) {
      withTestBlockRegistration(() => registerBlock(TestTile));
      this.editor.wireframeSelection.selectBlock({
        key: "wf:svc-test-tile:1",
        name: "wf:svc-test-tile",
        args: { title: "Hi" },
      });
      assert.true(
        this.editor.wireframeSelection.selectedBlockData.isRegistered,
        "a block whose type is in the registry is editable"
      );
    });

    test("selectBlock flags an unknown block type as not registered", function (assert) {
      // No registration — the editor has no schema for this type, so its
      // inspector fields must be read-only.
      this.editor.wireframeSelection.selectBlock({
        key: "wf:never-registered:1",
        name: "wf:never-registered",
        args: { title: "Hi" },
      });
      assert.false(
        this.editor.wireframeSelection.selectedBlockData.isRegistered,
        "an unregistered block type is locked"
      );
      assert.deepEqual(
        this.editor.wireframeSelection.selectedBlockData.argsSnapshot,
        { title: "Hi" },
        "its values still snapshot through so the inspector can show them"
      );
    });

    test("selectBlock leaves a nameless selection editable", function (assert) {
      // Defensive: a selection with no resolvable name (eg. outlet-style
      // entries) shouldn't be over-locked into read-only.
      this.editor.wireframeSelection.selectBlock({ key: "x:1" });
      assert.notStrictEqual(
        this.editor.wireframeSelection.selectedBlockData.isRegistered,
        false,
        "a nameless selection isn't treated as unregistered"
      );
    });
  });

  module("live re-validation on edit", function (innerHooks) {
    innerHooks.beforeEach(async function () {
      withTestBlockRegistration(() => registerBlock(TestConstrained));
      // Render it valid (label set) so the base layer publishes cleanly;
      // the edits below drive it in and out of validity.
      const layout = await _renderBlocks(
        "homepage-blocks",
        [{ block: TestConstrained, args: { label: "Go" } }],
        getOwner(this)
      );
      const stableKey = layout[0].__stableKey;
      this.editor.wireframeSelection.selectBlock({
        key: `wf:svc-test-constrained:${stableKey}`,
        name: "wf:svc-test-constrained",
      });
    });

    test("a constraint error appears and clears as the args change, without a republish", async function (assert) {
      assert.deepEqual(
        this.editor.wireframeSelection.selectedBlockNonFieldErrors,
        [],
        "valid to start"
      );

      // Clear the only provided arg → the atLeastOne constraint now fails.
      await editArg(this.editor, "label", null);
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockNonFieldErrors.length,
        1,
        "the constraint violation surfaces live"
      );
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockNonFieldErrors[0].code,
        "constraint-violation"
      );

      // Satisfy the constraint via the other arg → the error clears live.
      await editArg(this.editor, "icon", "house");
      assert.deepEqual(
        this.editor.wireframeSelection.selectedBlockNonFieldErrors,
        [],
        "fixing the block clears the error without republishing"
      );
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
      this.editor.wireframeSelection.selectBlock({
        key: `wf:svc-test-tile:${stableKey}`,
        name: "wf:svc-test-tile",
        args: { title: "Original" },
        metadata: { args: { title: { type: "string" } } },
      });
    });

    test("updateSelectedArg refreshes the selection snapshot", async function (assert) {
      await editArg(this.editor, "title", "Edited");
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockData.args.title,
        "Edited"
      );
    });

    test("an edit pushes onto the undo stack and clears redo", async function (assert) {
      assert.false(this.editor.wireframeEditEngine.canUndo);
      await editArg(this.editor, "title", "Edited");
      assert.true(this.editor.wireframeEditEngine.canUndo);
      assert.false(this.editor.wireframeEditEngine.canRedo);
    });

    test("undo restores the previous value and enables redo", async function (assert) {
      await editArg(this.editor, "title", "Edited");
      const undone = await this.editor.wireframeEditEngine.undo();
      assert.true(undone);
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockData.args.title,
        "Original"
      );
      assert.true(this.editor.wireframeEditEngine.canRedo);
      assert.false(this.editor.wireframeEditEngine.canUndo);
    });

    test("redo re-applies the most recently undone edit", async function (assert) {
      await editArg(this.editor, "title", "Edited");
      await this.editor.wireframeEditEngine.undo();
      const redone = await this.editor.wireframeEditEngine.redo();
      assert.true(redone);
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockData.args.title,
        "Edited"
      );
      assert.true(this.editor.wireframeEditEngine.canUndo);
      assert.false(this.editor.wireframeEditEngine.canRedo);
    });

    test("a fresh edit after undo discards the redo stack", async function (assert) {
      await editArg(this.editor, "title", "First");
      await this.editor.wireframeEditEngine.undo();
      assert.true(this.editor.wireframeEditEngine.canRedo);
      await editArg(this.editor, "title", "Second");
      assert.false(this.editor.wireframeEditEngine.canRedo);
    });

    test("isDirty flips on the first edit and back off after resetAll", async function (assert) {
      assert.false(this.editor.wireframeEditEngine.isDirty);
      await editArg(this.editor, "title", "Edited");
      assert.true(this.editor.wireframeEditEngine.isDirty);
      const reset = await this.editor.wireframeEditEngine.resetAll();
      assert.true(reset);
      assert.false(this.editor.wireframeEditEngine.isDirty);
      assert.false(this.editor.wireframeEditEngine.canUndo);
      assert.false(this.editor.wireframeEditEngine.canRedo);
    });

    test("undo / redo return false when their stacks are empty", async function (assert) {
      assert.false(await this.editor.wireframeEditEngine.undo());
      assert.false(await this.editor.wireframeEditEngine.redo());
    });

    test("setting an arg to null deletes the key", async function (assert) {
      // FormKit emits `null` when a text input is cleared. The validator
      // rejects null (typeof null === "object" !== "string"), so the
      // editor's contract is: cleared field → key omitted from args.
      await editArg(this.editor, "title", "Edited");
      await editArg(this.editor, "title", null);
      assert.false(
        "title" in this.editor.wireframeSelection.selectedBlockData.args,
        "the title key is absent from args"
      );
    });

    test("setting an arg to undefined deletes the key", async function (assert) {
      await editArg(this.editor, "title", "Edited");
      await editArg(this.editor, "title", undefined);
      assert.false(
        "title" in this.editor.wireframeSelection.selectedBlockData.args,
        "the title key is absent from args"
      );
    });

    test("setting an arg to empty string writes the empty string", async function (assert) {
      // `""` is a valid string the user may have intentionally typed.
      // Only `null` / `undefined` are stripped.
      await editArg(this.editor, "title", "");
      assert.true(
        "title" in this.editor.wireframeSelection.selectedBlockData.args,
        "the title key stays present"
      );
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockData.args.title,
        ""
      );
    });

    test("editing an arg clears stale validator soft-failure stamps", async function (assert) {
      // `markEntrySoftFailure` (in core's validator) stamps these
      // directly on the entry when permissive validation finds a
      // problem. They persist past the underlying fix until the next
      // layer republish; the live arg-write needs to clear them so
      // the outline / inspector stop showing the stale error.
      const entry = this.editor.wireframeSelection.selectedBlockData.args;
      // Look up the live entry (the bound args' parent) and stamp it
      // as the validator would.
      const located = this.editor.wireframeLayoutQuery.findEntryAndOutletSync(
        this.editor.wireframeSelection.selectedBlockKey
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
      const validation = getOwner(this).lookup("service:wireframe-validation");
      const located = this.editor.wireframeLayoutQuery.findEntryAndOutletSync(
        this.editor.wireframeSelection.selectedBlockKey
      );
      located.entry.__failureType = "arg-invalid";
      located.entry.__failureReason =
        'Arg "title" must be a string, got number.';

      assert.deepEqual(
        validation.validationWarnings.map((w) => w.message),
        ['Arg "title" must be a string, got number.'],
        "the stamp surfaces as a warning"
      );

      await editArg(this.editor, "title", "Edited");

      assert.deepEqual(
        validation.validationWarnings,
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
      // a staff user lets `#materializeAllDrafts()` populate
      // `#originalLayouts`, which `resetAll` reads from on rollback.
      // After this re-lookup the rest of the moveBlock tests use the
      // editor with editing enabled.
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.enter();
    });

    test("moves a block within the same outlet (after)", function (assert) {
      // Read keys after enter() — drafts get fresh stable keys minted by
      // _setLayoutLayer's assignStableKeys pass. The tiles are the children
      // of the outlet's implicit root layout.
      const draft = outletChildren(this.editor);
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      const secondKey = `wf:svc-test-tile:${draft[1].__stableKey}`;

      const ok = mutationsOf(this.editor).moveBlock({
        sourceKey: firstKey,
        targetKey: secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });

      assert.true(ok);
      const after = outletChildren(this.editor);
      assert.strictEqual(after[0].args.title, "Second");
      assert.strictEqual(after[1].args.title, "First");
    });

    test("isDirty flips on after a move", function (assert) {
      const draft = outletChildren(this.editor);
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      const secondKey = `wf:svc-test-tile:${draft[1].__stableKey}`;

      assert.false(this.editor.wireframeEditEngine.isDirty);
      // Move "First" AFTER "Second" — a genuine reorder. (A no-op move that
      // leaves the layout identical to its pristine state intentionally does
      // NOT dirty the outlet, since the reconcile pass clears it again.)
      mutationsOf(this.editor).moveBlock({
        sourceKey: firstKey,
        targetKey: secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      assert.true(this.editor.wireframeEditEngine.isDirty);
    });

    test("resetAll restores the pre-edit layout after a move", async function (assert) {
      const draft = outletChildren(this.editor);
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      const secondKey = `wf:svc-test-tile:${draft[1].__stableKey}`;

      mutationsOf(this.editor).moveBlock({
        sourceKey: firstKey,
        targetKey: secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });

      const ok = await this.editor.wireframeEditEngine.resetAll();
      assert.true(ok);
      const restored = outletChildren(this.editor);
      assert.strictEqual(restored[0].args.title, "First");
      assert.strictEqual(restored[1].args.title, "Second");
      assert.false(this.editor.wireframeEditEngine.isDirty);
    });

    test("rejects moves with an unknown source key", function (assert) {
      const draft = outletChildren(this.editor);
      const realKey = `wf:svc-test-tile:${draft[0].__stableKey}`;

      const ok = mutationsOf(this.editor).moveBlock({
        sourceKey: "absent:0",
        targetKey: realKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      assert.false(ok);
    });

    test("dragging state toggles via startDrag/endDrag", function (assert) {
      const dragSession = getOwner(this.editor).lookup(
        "service:wireframe-drag-session"
      );
      assert.false(dragSession.isDragging);
      dragSession.startDrag({
        blockKey: "wf:svc-test-tile:1",
        outletName: "homepage-blocks",
      });
      assert.true(dragSession.isDragging);
      assert.true(
        document.body.classList.contains("wireframe-dragging"),
        "body class is added during drag"
      );
      dragSession.endDrag();
      assert.false(dragSession.isDragging);
      assert.false(
        document.body.classList.contains("wireframe-dragging"),
        "body class is removed after drag"
      );
    });

    test("startPaletteDrag does not set isDragging (palette drags aren't moves)", function (assert) {
      const dragSession = getOwner(this.editor).lookup(
        "service:wireframe-drag-session"
      );
      dragSession.startPaletteDrag({
        blockName: "wf:svc-test-tile",
        defaultArgs: {},
      });
      assert.false(
        dragSession.isDragging,
        "a palette drag carries no source block"
      );
      assert.true(
        document.body.classList.contains("wireframe-dragging"),
        "but the canvas drag body class is still applied"
      );
      dragSession.endDrag();
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
      const draft = outletChildren(this.editor);
      const targetKey = `wf:svc-test-tile:${draft[0].__stableKey}`;

      const ok = mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "Inserted" },
        targetKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });

      assert.true(ok);
      const after = outletChildren(this.editor);
      assert.strictEqual(after.length, 2);
      assert.strictEqual(after[0].args.title, "Existing");
      assert.strictEqual(after[1].args.title, "Inserted");
    });

    test("inserts inside the outlet root layout when targetKey is null", function (assert) {
      const ok = mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "Appended" },
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      });

      assert.true(ok);
      // An outlet-level insert (null target) lands inside the implicit root
      // layout, not as a sibling of it.
      const after = outletChildren(this.editor);
      assert.true(
        after.some((c) => c.args.title === "Appended"),
        "the new block is a child of the root layout"
      );
    });

    test("isDirty flips on after an insert", function (assert) {
      assert.false(this.editor.wireframeEditEngine.isDirty);
      mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      assert.true(this.editor.wireframeEditEngine.isDirty);
    });

    test("resetAll restores the pre-insert layout", async function (assert) {
      mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "Throwaway" },
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      });

      const ok = await this.editor.wireframeEditEngine.resetAll();
      assert.true(ok);
      const restored = outletChildren(this.editor);
      assert.strictEqual(restored.length, 1);
      assert.strictEqual(restored[0].args.title, "Existing");
      assert.false(this.editor.wireframeEditEngine.isDirty);
    });

    test("adding a block then undoing clears the outlet's editing state", async function (assert) {
      assert.false(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks")
      );

      mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      assert.true(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks"),
        "the outlet is editing right after the insert"
      );

      await this.editor.wireframeEditEngine.undo();
      assert.false(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks"),
        "undo back to the pristine layout clears the editing state"
      );
      assert.false(
        this.editor.wireframeEditEngine.isDirty,
        "the editor is no longer dirty"
      );
    });

    test("adding a block then removing it clears the outlet's editing state", function (assert) {
      assert.false(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks")
      );

      const ok = mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "Throwaway" },
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      assert.true(ok);
      // insertBlock auto-selects the freshly inserted entry, so this is the
      // block we just added regardless of where it landed in the children.
      const insertedKey = this.editor.wireframeSelection.selectedBlockKey;
      assert.true(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks"),
        "the outlet is editing right after the insert"
      );

      assert.true(
        mutationsOf(this.editor).removeBlock(insertedKey),
        "the inserted block is removed"
      );
      assert.false(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks"),
        "removing the block back to the pristine layout clears the editing state"
      );
      assert.false(
        this.editor.wireframeEditEngine.isDirty,
        "the editor is no longer dirty"
      );
    });

    test("redo re-marks the outlet as editing", async function (assert) {
      mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      await this.editor.wireframeEditEngine.undo();
      assert.false(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks")
      );

      await this.editor.wireframeEditEngine.redo();
      assert.true(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks"),
        "redo restores the edit, so the outlet is editing again"
      );
    });

    test("editing a block's arg then undoing clears the outlet's editing state", async function (assert) {
      const tile = outletChildren(this.editor)[0];
      this.editor.wireframeSelection.selectBlock({
        key: `wf:svc-test-tile:${tile.__stableKey}`,
        name: "wf:svc-test-tile",
        args: { title: "Existing" },
        metadata: { args: { title: { type: "string" } } },
      });
      await editArg(this.editor, "title", "Changed");
      assert.true(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks")
      );

      await this.editor.wireframeEditEngine.undo();
      assert.false(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks"),
        "undo of the arg edit clears editing"
      );
    });

    test("discardOutlet drops the outlet's undo history", async function (assert) {
      pretender.delete(
        "/admin/plugins/wireframe/block-layout-drafts.json",
        () => response({ success: true })
      );
      mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      assert.true(
        this.editor.wireframeEditEngine.canUndo,
        "undo is available after the insert"
      );

      await this.editor.discardOutlet("homepage-blocks");
      assert.false(
        this.editor.wireframeEditEngine.canUndo,
        "discarding the outlet removes its undo entry"
      );
      assert.false(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks")
      );
    });

    test("default args don't bleed back into the source object", function (assert) {
      const defaults = { title: "Shared" };

      mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: defaults,
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      });

      // Future mutations on the rendered entry must not reach back into
      // the defaults payload the palette passed in.
      const inserted = outletChildren(this.editor).find(
        (c) => c.args.title === "Shared"
      );
      inserted.args.title = "Mutated";
      assert.strictEqual(defaults.title, "Shared");
    });
  });

  module("implicit-child containers (childBlocks)", function (innerHooks) {
    innerHooks.beforeEach(async function () {
      withTestBlockRegistration(() => {
        registerBlock(TestTile);
        registerBlock(TestTabs);
      });
      await _renderBlocks(
        "homepage-blocks",
        [
          {
            block: TestTabs,
            children: [
              {
                block: Layout,
                args: {},
                children: [{ block: TestTile, args: { title: "P1" } }],
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

    function tabsEntry(editor) {
      return outletChildren(editor)[0];
    }

    function blockNameOf(editor, entry) {
      return editor.wireframeLayoutQuery.lookupBlockMetadata(entry.block)
        ?.blockName;
    }

    test("appendImplicitChild appends an empty layout panel and selects it", function (assert) {
      const before = tabsEntry(this.editor).children.length;

      const ok = mutationsOf(this.editor).appendImplicitChild(
        entryKey(tabsEntry(this.editor))
      );
      assert.true(ok);

      const panels = tabsEntry(this.editor).children;
      assert.strictEqual(panels.length, before + 1, "a panel was appended");
      const added = panels[panels.length - 1];
      assert.strictEqual(
        blockNameOf(this.editor, added),
        "layout",
        "the new panel is a layout"
      );
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockKey,
        entryKey(added),
        "the new panel is selected"
      );
    });

    test("inserting an implicit-child container seeds one panel of its kind", function (assert) {
      mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tabs",
        targetKey: null,
        position: "inside",
        targetOutletName: "homepage-blocks",
      });

      const inserted = this.editor.wireframeLayoutQuery.findEntryByKey(
        this.editor.wireframeSelection.selectedBlockKey
      );
      assert.strictEqual(
        blockNameOf(this.editor, inserted),
        "wf:svc-test-tabs",
        "the freshly inserted tabs block is selected"
      );
      assert.strictEqual(
        inserted.children?.length,
        1,
        "it is seeded with exactly one panel (never empty)"
      );
      assert.strictEqual(
        blockNameOf(this.editor, inserted.children[0]),
        "layout",
        "the seeded panel is a layout (the declared child kind)"
      );
    });

    test("a non-layout block inserted into the container is wrapped and stays selected", function (assert) {
      const ok = mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "Bare" },
        targetKey: entryKey(tabsEntry(this.editor)),
        position: "inside-end",
        targetOutletName: "homepage-blocks",
      });
      assert.true(ok);

      const panels = tabsEntry(this.editor).children;
      const wrapper = panels[panels.length - 1];
      assert.strictEqual(
        blockNameOf(this.editor, wrapper),
        "layout",
        "the dropped block is wrapped in a layout panel"
      );
      const inner = wrapper.children[0];
      assert.strictEqual(
        inner.args.title,
        "Bare",
        "the dropped block is the wrapper's child"
      );
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockKey,
        entryKey(inner),
        "the dropped block stays selected through the wrap (same reference)"
      );
    });
  });

  module("annotate-on-insert (grid)", function (innerHooks) {
    innerHooks.beforeEach(async function () {
      withTestBlockRegistration(() => registerBlock(TestTile));
      // Pass the core `Layout` block by class (it can't be registered by its
      // unprefixed core id from a plugin test). `blockNameOf` derives
      // "layout" from the class, which is what the service's grid detection
      // and the `gridKey` below key off.
      this.layout = await _renderBlocks(
        "homepage-blocks",
        [
          {
            block: Layout,
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
      const draft =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      const gridKey = `layout:${draft[0].__stableKey}`;

      const ok = mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "In grid" },
        targetKey: gridKey,
        position: "inside",
        targetOutletName: "homepage-blocks",
      });

      assert.true(ok);
      const after =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
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

    test("resizeSlot updates a cell's column/row and is undoable", async function (assert) {
      const draft =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      const gridKey = `layout:${draft[0].__stableKey}`;

      // Seed a placed tile via a grid drop so we have a cell to reposition.
      gridOf(this.editor).drop({
        targetGridKey: gridKey,
        gesture: GRID_DROP_GESTURES.INTO,
        cell: { column: 2, row: 1 },
        source: {
          kind: "new",
          blockName: "wf:svc-test-tile",
          defaultArgs: { title: "Movable" },
        },
      });
      const afterInsert =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      const cell = afterInsert[0].children.find(
        (c) => c.args?.title === "Movable"
      );
      const cellKey = `wf:svc-test-tile:${cell.__stableKey}`;
      assert.strictEqual(cell.containerArgs.grid.column, "2");

      const ok = getOwner(this)
        .lookup("service:wireframe-grid-manipulator")
        .resizeSlot({
          slotKey: cellKey,
          column: "3",
          row: "2",
        });
      assert.true(ok);

      const afterMove =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      const movedCell = afterMove[0].children.find(
        (c) => c.__stableKey === cell.__stableKey
      );
      assert.strictEqual(movedCell.containerArgs.grid.column, "3");
      assert.strictEqual(movedCell.containerArgs.grid.row, "2");

      // Undo: back to the previous placement.
      await this.editor.wireframeEditEngine.undo();
      const undone =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      const undoneCell = undone[0].children.find(
        (c) => c.__stableKey === cell.__stableKey
      );
      assert.strictEqual(undoneCell.containerArgs.grid.column, "2");
      assert.strictEqual(undoneCell.containerArgs.grid.row, "1");
    });

    test("resizeSlot never grows the grid's declared columns / rows", function (assert) {
      // Regression: a resize must not bake a wider span into the grid's
      // declared track count — growth is reserved for drops. (The handle
      // clamps to the effective size; even if a placement past declared
      // reaches the manipulator, declared stays put.)
      const draft =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      const grid = draft[0];
      const seed = grid.children[0];
      const seedKey = `wf:svc-test-tile:${seed.__stableKey}`;
      assert.strictEqual(
        grid.args.columns,
        4,
        "grid starts at 4 declared columns"
      );

      const ok = getOwner(this)
        .lookup("service:wireframe-grid-manipulator")
        .resizeSlot({
          slotKey: seedKey,
          column: "1 / 6", // trailing edge (line 6) reaches past the 4 columns
          row: "1",
        });
      assert.true(ok);

      const after =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      const resized = after[0].children.find(
        (c) => c.__stableKey === seed.__stableKey
      );
      assert.strictEqual(
        resized.containerArgs.grid.column,
        "1 / 6",
        "the placement is written"
      );
      assert.strictEqual(
        after[0].args.columns,
        4,
        "declared columns are unchanged (resize does not grow the grid)"
      );
      assert.strictEqual(after[0].args.rows, 2, "declared rows are unchanged");
    });
  });

  module("merge / split empty cells (grid)", function (innerHooks) {
    innerHooks.beforeEach(async function () {
      withTestBlockRegistration(() => registerBlock(TestTile));
      // A 3×1 grid with one resident tile pinned to the top-left cell, so
      // columns 2–3 are blank space a merge can claim.
      await _renderBlocks(
        "homepage-blocks",
        [
          {
            block: Layout,
            args: { mode: "grid", columns: 3, rows: 1 },
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

    function gridKeyOf(editor) {
      return `layout:${editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks")[0].__stableKey}`;
    }

    function mergedCellOf(editor) {
      return editor.wireframeLayoutQuery
        .readResolvedLayout("homepage-blocks")[0]
        .children.find((c) => c.block === "layout-merged-cell");
    }

    test("mergeCells inserts a spanning merged cell and grows declared to fit", function (assert) {
      const ok = getOwner(this)
        .lookup("service:wireframe-grid-manipulator")
        .mergeCells({
          gridKey: gridKeyOf(this.editor),
          // Columns 2–3, rows 1–2 — free, and the second row is past the
          // declared single row, so declared must grow.
          rect: { column: { start: 2, end: 4 }, row: { start: 1, end: 3 } },
        });
      assert.true(ok);

      const cell = mergedCellOf(this.editor);
      assert.strictEqual(
        cell?.block,
        "layout-merged-cell",
        "a merged-cell entry was inserted"
      );
      assert.strictEqual(cell.containerArgs.grid.column, "2 / 4");
      assert.strictEqual(cell.containerArgs.grid.row, "1 / 3");
      const cellArgs = cell.args ?? {};
      assert.deepEqual(
        cellArgs,
        {},
        "the merged cell stamps no args of its own"
      );

      const grid =
        this.editor.wireframeLayoutQuery.readResolvedLayout(
          "homepage-blocks"
        )[0];
      assert.strictEqual(
        grid.args.rows,
        2,
        "declared rows grew to fit the span"
      );
      assert.strictEqual(
        grid.args.columns,
        3,
        "declared columns are unchanged"
      );
    });

    test("mergeCells refuses a rect that overlaps existing content", function (assert) {
      const before =
        this.editor.wireframeLayoutQuery.readResolvedLayout(
          "homepage-blocks"
        )[0].children.length;
      const ok = getOwner(this)
        .lookup("service:wireframe-grid-manipulator")
        .mergeCells({
          gridKey: gridKeyOf(this.editor),
          // Columns 1–2 overlaps the seed at column 1.
          rect: { column: { start: 1, end: 3 }, row: { start: 1, end: 2 } },
        });
      assert.false(ok, "the overlapping merge is refused");
      assert.strictEqual(
        this.editor.wireframeLayoutQuery.readResolvedLayout(
          "homepage-blocks"
        )[0].children.length,
        before,
        "no entry was inserted"
      );
    });

    test("splitCell dissolves a merged cell, leaving declared untouched", function (assert) {
      getOwner(this)
        .lookup("service:wireframe-grid-manipulator")
        .mergeCells({
          gridKey: gridKeyOf(this.editor),
          rect: { column: { start: 2, end: 4 }, row: { start: 1, end: 2 } },
        });
      const cell = mergedCellOf(this.editor);
      const cellKey = `layout-merged-cell:${cell.__stableKey}`;

      const ok = getOwner(this)
        .lookup("service:wireframe-grid-manipulator")
        .splitCell({ cellKey });
      assert.true(ok);
      assert.strictEqual(
        mergedCellOf(this.editor),
        undefined,
        "the merged-cell entry is gone (1×1s stay derived)"
      );
      assert.strictEqual(
        this.editor.wireframeLayoutQuery.readResolvedLayout(
          "homepage-blocks"
        )[0].args.columns,
        3,
        "declared columns are preserved so the freed cells stay held open"
      );
    });

    test("resizeSlot shrinking a merged cell to 1×1 dissolves it", function (assert) {
      getOwner(this)
        .lookup("service:wireframe-grid-manipulator")
        .mergeCells({
          gridKey: gridKeyOf(this.editor),
          rect: { column: { start: 2, end: 4 }, row: { start: 1, end: 2 } },
        });
      const cell = mergedCellOf(this.editor);
      const cellKey = `layout-merged-cell:${cell.__stableKey}`;

      const ok = getOwner(this)
        .lookup("service:wireframe-grid-manipulator")
        .resizeSlot({
          slotKey: cellKey,
          column: "2",
          row: "1",
        });
      assert.true(ok);
      assert.strictEqual(
        mergedCellOf(this.editor),
        undefined,
        "resizing down to a single cell dissolves the entry"
      );
    });

    test("resizeSlot keeps a merged cell that stays multi-cell", function (assert) {
      getOwner(this)
        .lookup("service:wireframe-grid-manipulator")
        .mergeCells({
          gridKey: gridKeyOf(this.editor),
          rect: { column: { start: 2, end: 4 }, row: { start: 1, end: 2 } },
        });
      const cell = mergedCellOf(this.editor);
      const cellKey = `layout-merged-cell:${cell.__stableKey}`;

      const ok = getOwner(this)
        .lookup("service:wireframe-grid-manipulator")
        .resizeSlot({
          slotKey: cellKey,
          column: "2 / 4",
          row: "1 / 3",
        });
      assert.true(ok);

      const resized = mergedCellOf(this.editor);
      assert.strictEqual(
        resized?.block,
        "layout-merged-cell",
        "a multi-cell resize keeps the merged cell"
      );
      assert.strictEqual(resized.containerArgs.grid.row, "1 / 3");
    });
  });

  module("move preserves a vacated span (grid)", function (innerHooks) {
    innerHooks.beforeEach(async function () {
      withTestBlockRegistration(() => registerBlock(TestTile));
      // A 3×2 grid with one tile spanning columns 1–2 of row 1; the rest is
      // blank, so the tile can be moved to an empty cell elsewhere.
      await _renderBlocks(
        "homepage-blocks",
        [
          {
            block: Layout,
            args: { mode: "grid", columns: 3, rows: 2 },
            children: [
              {
                block: TestTile,
                args: { title: "Hero" },
                containerArgs: {
                  grid: {
                    column: "1 / 3",
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

    test("moving a spanning block to an empty cell leaves a merged cell at its old rect", function (assert) {
      const grid =
        this.editor.wireframeLayoutQuery.readResolvedLayout(
          "homepage-blocks"
        )[0];
      const gridKey = `layout:${grid.__stableKey}`;
      const hero = grid.children.find((c) => c.args?.title === "Hero");
      const heroKey = `wf:svc-test-tile:${hero.__stableKey}`;

      // Move the spanning hero to an empty single cell at column 3, row 2.
      const ok = gridOf(this.editor).drop({
        targetGridKey: gridKey,
        gesture: GRID_DROP_GESTURES.INTO,
        cell: { column: 3, row: 2 },
        source: { kind: "existing", key: heroKey },
      });
      assert.true(ok);

      const after =
        this.editor.wireframeLayoutQuery.readResolvedLayout(
          "homepage-blocks"
        )[0];
      const moved = after.children.find(
        (c) => c.__stableKey === hero.__stableKey
      );
      assert.strictEqual(
        moved.containerArgs.grid.column,
        "3",
        "the moved block lands at the target cell"
      );
      assert.strictEqual(moved.containerArgs.grid.row, "2");

      // The vacated 2-cell region stays one merged cell, not two derived 1×1s.
      const merged = after.children.filter(
        (c) => c.block === "layout-merged-cell"
      );
      assert.strictEqual(merged.length, 1, "exactly one merged cell is minted");
      assert.strictEqual(
        merged[0].containerArgs.grid.column,
        "1 / 3",
        "the merged cell holds the block's old spanning rect"
      );
      assert.strictEqual(merged[0].containerArgs.grid.row, "1");
    });
  });

  module(
    "grid drop into a cell (cross-grid, same outlet)",
    function (innerHooks) {
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        // Two grid layouts in one outlet. The source grid holds a
        // full-width tile (placed lower than the destination's resident, so
        // an array-order reflow would swap their placements); the
        // destination grid holds one narrow top-left tile.
        await _renderBlocks(
          "homepage-blocks",
          [
            {
              block: Layout,
              args: { mode: "grid", columns: 3, rows: 2 },
              children: [
                {
                  block: TestTile,
                  args: { title: "Source" },
                  containerArgs: {
                    grid: {
                      column: "1 / 4",
                      row: "2",
                      align: "stretch",
                      justify: "stretch",
                    },
                  },
                },
              ],
            },
            {
              block: Layout,
              args: { mode: "grid", columns: 3, rows: 3 },
              children: [
                {
                  block: TestTile,
                  args: { title: "Resident" },
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

      test("dropping a block into a destination cell leaves the destination's existing cells in place", function (assert) {
        const root =
          this.editor.wireframeLayoutQuery.readResolvedLayout(
            "homepage-blocks"
          )[0];
        const [sourceGrid, destGrid] = root.children;
        const destGridKey = `layout:${destGrid.__stableKey}`;
        const sourceTile = sourceGrid.children[0];
        const sourceKey = `wf:svc-test-tile:${sourceTile.__stableKey}`;

        const ok = gridOf(this.editor).drop({
          targetGridKey: destGridKey,
          gesture: GRID_DROP_GESTURES.INTO,
          cell: { column: 1, row: 3 },
          source: { kind: "existing", key: sourceKey },
        });
        assert.true(ok);

        const afterRoot =
          this.editor.wireframeLayoutQuery.readResolvedLayout(
            "homepage-blocks"
          )[0];
        const afterDest = afterRoot.children.find(
          (c) => c.__stableKey === destGrid.__stableKey
        );
        const resident = afterDest.children.find(
          (c) => c.args?.title === "Resident"
        );
        const moved = afterDest.children.find(
          (c) => c.args?.title === "Source"
        );

        // The resident keeps its own top-left single cell — it must not
        // inherit the dragged tile's full-width span through an array-order
        // reflow that a cell drop should never trigger.
        assert.strictEqual(resident.containerArgs.grid.column, "1");
        assert.strictEqual(resident.containerArgs.grid.row, "1");
        // The dragged tile lands at the dropped cell.
        assert.strictEqual(moved.containerArgs.grid.column, "1");
        assert.strictEqual(moved.containerArgs.grid.row, "3");
      });
    }
  );

  module(
    "outline drop across grids (regression: span reset, no overflow, no dup)",
    function (innerHooks) {
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        // Grid A is 4 columns wide with a full-width tile ("1 / 5"); grid B
        // is only 3 columns with one resident at top-left. Dragging the
        // full-width tile into grid B via the outline (a before/after move,
        // NOT a precise cell drop) reproduces the live breakages: the tile
        // carries its "1 / 5" span into a 3-column grid (overflow + grow),
        // and the array-order reflow shuffles the resident's placement.
        await _renderBlocks(
          "homepage-blocks",
          [
            {
              block: Layout,
              args: { mode: "grid", columns: 4, rows: 2 },
              children: [
                {
                  block: TestTile,
                  args: { title: "Source" },
                  containerArgs: {
                    grid: {
                      column: "1 / 5",
                      row: "1",
                      align: "stretch",
                      justify: "stretch",
                    },
                  },
                },
              ],
            },
            {
              block: Layout,
              args: { mode: "grid", columns: 3, rows: 2 },
              children: [
                {
                  block: TestTile,
                  args: { title: "Resident" },
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

      // Performs the outline-style move (drop the source tile before the
      // resident cell of grid B) and returns the post-move grids.
      function dropSourceBeforeResident(editor) {
        const root =
          editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks")[0];
        const [sourceGrid, destGrid] = root.children;
        const residentKey = `wf:svc-test-tile:${destGrid.children[0].__stableKey}`;
        const sourceKey = `wf:svc-test-tile:${sourceGrid.children[0].__stableKey}`;
        const ok = mutationsOf(editor).moveBlock({
          sourceKey,
          targetKey: residentKey,
          position: "before",
          targetOutletName: "homepage-blocks",
        });
        const afterRoot =
          editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks")[0];
        return {
          ok,
          destGridKey: `layout:${destGrid.__stableKey}`,
          sourceGrid: afterRoot.children.find(
            (c) => c.__stableKey === sourceGrid.__stableKey
          ),
          destGrid: afterRoot.children.find(
            (c) => c.__stableKey === destGrid.__stableKey
          ),
        };
      }

      test("R1: the moved block enters as a single cell (foreign span discarded)", function (assert) {
        const { destGrid } = dropSourceBeforeResident(this.editor);
        const sources = destGrid.children.filter(
          (c) => c.args?.title === "Source"
        );
        assert.strictEqual(
          sources.length,
          1,
          "the source tile is present in the destination grid"
        );
        assert.false(
          sources[0].containerArgs.grid.column.includes("/"),
          `the carried "1 / 5" span is discarded (got "${sources[0].containerArgs.grid.column}")`
        );
      });

      test("R5: the destination grid does not grow to contain a foreign span", function (assert) {
        const { destGridKey } = dropSourceBeforeResident(this.editor);
        assert.strictEqual(
          getOwner(this)
            .lookup("service:wireframe-grid-template")
            .gridSizeFor(destGridKey).columns,
          3,
          "grid B stays 3 columns wide"
        );
      });

      test("R2: dropping before a cell cascades it to the right (not an array-order reflow swap)", function (assert) {
        const { destGrid } = dropSourceBeforeResident(this.editor);
        const resident = destGrid.children.find(
          (c) => c.args?.title === "Resident"
        );
        const moved = destGrid.children.find((c) => c.args?.title === "Source");
        // Dropping before the resident lands the source at the resident's
        // cell and shifts the resident one column right (into the free
        // column 2 — no growth). The resident does NOT inherit a span.
        assert.strictEqual(moved.containerArgs.grid.column, "1");
        assert.strictEqual(moved.containerArgs.grid.row, "1");
        assert.strictEqual(resident.containerArgs.grid.column, "2");
        assert.strictEqual(resident.containerArgs.grid.row, "1");
      });

      test("R4: the source is moved, not duplicated", function (assert) {
        const { sourceGrid, destGrid } = dropSourceBeforeResident(this.editor);
        const inSource = (sourceGrid?.children ?? []).filter(
          (c) => c.args?.title === "Source"
        ).length;
        const inDest = destGrid.children.filter(
          (c) => c.args?.title === "Source"
        ).length;
        assert.strictEqual(inSource, 0, "the source tile left grid A");
        assert.strictEqual(inDest, 1, "exactly one copy landed in grid B");
      });

      test("R4: the source grid keeps its declared size", function (assert) {
        const { sourceGrid } = dropSourceBeforeResident(this.editor);
        assert.strictEqual(sourceGrid.args.columns, 4);
        assert.strictEqual(sourceGrid.args.rows, 2);
      });
    }
  );

  module(
    "grid growth via drops (R2 cascade / R3 add-row)",
    function (innerHooks) {
      // A full 2×1 grid plus a loose tile in the outlet's root stack, so a
      // drop into the grid has nowhere free and must grow an axis.
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        await _renderBlocks(
          "homepage-blocks",
          [
            {
              block: Layout,
              args: { mode: "grid", columns: 2, rows: 1 },
              children: [
                {
                  block: TestTile,
                  args: { title: "A" },
                  containerArgs: {
                    grid: {
                      column: "1",
                      row: "1",
                      align: "stretch",
                      justify: "stretch",
                    },
                  },
                },
                {
                  block: TestTile,
                  args: { title: "B" },
                  containerArgs: {
                    grid: {
                      column: "2",
                      row: "1",
                      align: "stretch",
                      justify: "stretch",
                    },
                  },
                },
              ],
            },
            { block: TestTile, args: { title: "X" } },
          ],
          getOwner(this)
        );
        this.editor.siteSettings.wireframe_enabled = true;
        logIn(getOwner(this));
        this.editor = getOwner(this).lookup("service:wireframe");
        this.editor.enter();
      });

      function refs(editor) {
        const root =
          editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks")[0];
        const grid = root.children.find((c) => c.args?.mode === "grid");
        const loose = root.children.find((c) => c.args?.title === "X");
        const cellOf = (title) =>
          grid.children.find((c) => c.args?.title === title);
        return {
          grid,
          gridKey: `layout:${grid.__stableKey}`,
          xKey: `wf:svc-test-tile:${loose.__stableKey}`,
          aKey: `wf:svc-test-tile:${cellOf("A").__stableKey}`,
        };
      }

      test("dropping before a cell in a full row grows a column (R2)", function (assert) {
        const { gridKey, xKey, aKey } = refs(this.editor);
        const ok = mutationsOf(this.editor).moveBlock({
          sourceKey: xKey,
          targetKey: aKey,
          position: "before",
          targetOutletName: "homepage-blocks",
        });
        assert.true(ok);

        const grid = this.editor.wireframeLayoutQuery
          .readResolvedLayout("homepage-blocks")[0]
          .children.find((c) => c.args?.mode === "grid");
        assert.strictEqual(grid.args.columns, 3, "declared columns grew 2 → 3");
        const col = (title) =>
          grid.children.find((c) => c.args?.title === title).containerArgs.grid
            .column;
        assert.strictEqual(col("X"), "1", "X landed at the drop column");
        assert.strictEqual(col("A"), "2", "A cascaded right");
        assert.strictEqual(col("B"), "3", "B cascaded into the grown column");
        // R5: declared now matches the effective size (no drift).
        assert.deepEqual(
          getOwner(this)
            .lookup("service:wireframe-grid-template")
            .gridSizeFor(gridKey),
          {
            columns: 3,
            rows: 1,
          }
        );
      });

      test("a generic drop into a full grid adds a row (R3)", function (assert) {
        const { gridKey, xKey } = refs(this.editor);
        const ok = mutationsOf(this.editor).moveBlock({
          sourceKey: xKey,
          targetKey: gridKey,
          position: "inside",
          targetOutletName: "homepage-blocks",
        });
        assert.true(ok);

        const grid = this.editor.wireframeLayoutQuery
          .readResolvedLayout("homepage-blocks")[0]
          .children.find((c) => c.args?.mode === "grid");
        assert.strictEqual(grid.args.rows, 2, "declared rows grew 1 → 2");
        const x = grid.children.find((c) => c.args?.title === "X");
        assert.strictEqual(
          x.containerArgs.grid.row,
          "2",
          "X landed on a new row"
        );
        assert.deepEqual(
          getOwner(this)
            .lookup("service:wireframe-grid-template")
            .gridSizeFor(gridKey),
          {
            columns: 2,
            rows: 2,
          }
        );
      });
    }
  );

  module(
    "grid drop onto an occupied cell — cross-grid trade (R1)",
    function (innerHooks) {
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        await _renderBlocks(
          "homepage-blocks",
          [
            {
              block: Layout,
              args: { mode: "grid", columns: 3, rows: 2 },
              children: [
                {
                  block: TestTile,
                  args: { title: "A1" },
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
            {
              block: Layout,
              args: { mode: "grid", columns: 3, rows: 2 },
              children: [
                {
                  block: TestTile,
                  args: { title: "B1" },
                  containerArgs: {
                    grid: {
                      column: "2",
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

      test("dropping a block onto an occupied cell in another grid trades places", function (assert) {
        const root =
          this.editor.wireframeLayoutQuery.readResolvedLayout(
            "homepage-blocks"
          )[0];
        const [gridA, gridB] = root.children;
        const a1Key = `wf:svc-test-tile:${gridA.children[0].__stableKey}`;

        // Drag A1 onto B1's cell (column 2, the occupant). An INTO drop onto
        // an occupied cell decides SWAP, which trades the two across grids.
        const ok = gridOf(this.editor).drop({
          targetGridKey: `layout:${gridB.__stableKey}`,
          gesture: GRID_DROP_GESTURES.INTO,
          cell: { column: 2, row: 1 },
          source: { kind: "existing", key: a1Key },
        });
        assert.true(ok);

        const after =
          this.editor.wireframeLayoutQuery.readResolvedLayout(
            "homepage-blocks"
          )[0];
        const afterA = after.children.find(
          (c) => c.__stableKey === gridA.__stableKey
        );
        const afterB = after.children.find(
          (c) => c.__stableKey === gridB.__stableKey
        );
        const titlesIn = (grid) =>
          grid.children.map((c) => c.args?.title).sort();
        // A1 moved into grid B (taking B1's cell), B1 moved into grid A.
        assert.deepEqual(titlesIn(afterA), ["B1"], "grid A now holds B1");
        assert.deepEqual(titlesIn(afterB), ["A1"], "grid B now holds A1");
        const cell = (grid, title) =>
          grid.children.find((c) => c.args?.title === title).containerArgs.grid;
        assert.strictEqual(
          cell(afterB, "A1").column,
          "2",
          "A1 took B1's column"
        );
        assert.strictEqual(
          cell(afterA, "B1").column,
          "1",
          "B1 took A1's column"
        );
      });
    }
  );

  module(
    "grid edge drop — source paths (no duplication)",
    function (innerHooks) {
      // Two grids in one outlet so we can exercise the same-grid,
      // cross-grid-same-outlet, and palette source paths. The cross-grid
      // same-outlet case is the one that previously DUPLICATED the block.
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        const cell = (title, column) => ({
          block: TestTile,
          args: { title },
          containerArgs: {
            grid: { column, row: "1", align: "stretch", justify: "stretch" },
          },
        });
        await _renderBlocks(
          "homepage-blocks",
          [
            {
              block: Layout,
              args: { mode: "grid", columns: 3, rows: 1 },
              children: [cell("A1", "1"), cell("A2", "2")],
            },
            {
              block: Layout,
              args: { mode: "grid", columns: 3, rows: 1 },
              children: [cell("B1", "1")],
            },
          ],
          getOwner(this)
        );
        this.editor.siteSettings.wireframe_enabled = true;
        logIn(getOwner(this));
        this.editor = getOwner(this).lookup("service:wireframe");
        this.editor.enter();
      });

      // Total content blocks across both grids — conservation guard.
      function countContent(editor) {
        const root =
          editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks")[0];
        return root.children.reduce(
          (n, grid) =>
            n + (grid.children ?? []).filter((c) => c.args?.title).length,
          0
        );
      }

      function refs(editor) {
        const root =
          editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks")[0];
        const [gridA, gridB] = root.children;
        const keyIn = (grid, title) =>
          `wf:svc-test-tile:${
            grid.children.find((c) => c.args?.title === title).__stableKey
          }`;
        return {
          gridA,
          gridB,
          gridAKey: `layout:${gridA.__stableKey}`,
          gridBKey: `layout:${gridB.__stableKey}`,
          keyIn,
        };
      }

      function titlesByGrid(editor) {
        const root =
          editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks")[0];
        return root.children.map((grid) =>
          (grid.children ?? [])
            .map((c) => c.args?.title)
            .filter(Boolean)
            .sort()
        );
      }

      test("a cross-grid edge drop (same outlet) relocates the block without duplicating it", function (assert) {
        const before = countContent(this.editor);
        const { gridA, gridB, gridBKey, keyIn } = refs(this.editor);
        const ok = gridOf(this.editor).drop({
          targetGridKey: gridBKey,
          gesture: GRID_DROP_GESTURES.BESIDE,
          anchorKey: keyIn(gridB, "B1"),
          direction: "right",
          source: { kind: "existing", key: keyIn(gridA, "A1") },
        });
        assert.true(ok);
        assert.strictEqual(
          countContent(this.editor),
          before,
          "no block was duplicated"
        );
        assert.deepEqual(
          titlesByGrid(this.editor),
          [["A2"], ["A1", "B1"]],
          "A1 left grid A and joined grid B exactly once"
        );
      });

      test("a same-grid edge drop rotates without duplicating", function (assert) {
        const before = countContent(this.editor);
        const { gridA, gridAKey, keyIn } = refs(this.editor);
        const ok = gridOf(this.editor).drop({
          targetGridKey: gridAKey,
          gesture: GRID_DROP_GESTURES.BESIDE,
          anchorKey: keyIn(gridA, "A1"),
          direction: "left",
          source: { kind: "existing", key: keyIn(gridA, "A2") },
        });
        assert.true(ok);
        assert.strictEqual(countContent(this.editor), before, "no duplication");
        assert.deepEqual(
          titlesByGrid(this.editor)[0],
          ["A1", "A2"],
          "both cells still present in grid A"
        );
      });

      test("a palette edge drop mints exactly one new block", function (assert) {
        const before = countContent(this.editor);
        const { gridB, gridBKey, keyIn } = refs(this.editor);
        const ok = gridOf(this.editor).drop({
          targetGridKey: gridBKey,
          gesture: GRID_DROP_GESTURES.BESIDE,
          anchorKey: keyIn(gridB, "B1"),
          direction: "right",
          source: {
            kind: "new",
            blockName: "wf:svc-test-tile",
            defaultArgs: { title: "New" },
          },
        });
        assert.true(ok);
        assert.strictEqual(
          countContent(this.editor),
          before + 1,
          "exactly one new block was added"
        );
      });
    }
  );

  module(
    "drop before an empty cell (R2.3 — encodes the rule)",
    function (innerHooks) {
      // Row: [derived empty at col 1] [Important spanning cols 2-3], plus a
      // loose stack tile A. Per R2, dropping A *before* the empty cell should
      // land A at col 1, push the empty + Important right, and grow a column:
      // A · empty · Important(2-span). This pins the RULE outcome (the drop
      // pipeline + computeShiftPlan), independent of the overlay's cursor→
      // action mapping.
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        await _renderBlocks(
          "homepage-blocks",
          [
            {
              block: Layout,
              args: { mode: "grid", columns: 3, rows: 1 },
              children: [
                {
                  block: TestTile,
                  args: { title: "Important" },
                  containerArgs: {
                    grid: {
                      column: "2 / 4",
                      row: "1",
                      align: "stretch",
                      justify: "stretch",
                    },
                  },
                },
              ],
            },
            { block: TestTile, args: { title: "A" } },
          ],
          getOwner(this)
        );
        this.editor.siteSettings.wireframe_enabled = true;
        logIn(getOwner(this));
        this.editor = getOwner(this).lookup("service:wireframe");
        this.editor.enter();
      });

      test("dropping A before the empty cell yields A · empty · Important(2-span), grown to 4 columns", function (assert) {
        const root =
          this.editor.wireframeLayoutQuery.readResolvedLayout(
            "homepage-blocks"
          )[0];
        const grid = root.children.find((c) => c.args?.mode === "grid");
        const gridKey = `layout:${grid.__stableKey}`;
        const aKey = `wf:svc-test-tile:${
          root.children.find((c) => c.args?.title === "A").__stableKey
        }`;

        // Drop A before the empty cell at column 1, row 1 (left edge → cascade).
        const ok = gridOf(this.editor).drop({
          targetGridKey: gridKey,
          gesture: GRID_DROP_GESTURES.BESIDE,
          cell: { column: 1, row: 1 },
          direction: "left",
          source: { kind: "existing", key: aKey },
        });
        assert.true(ok);

        const after = this.editor.wireframeLayoutQuery
          .readResolvedLayout("homepage-blocks")[0]
          .children.find((c) => c.args?.mode === "grid");
        const at = (title) =>
          after.children.find((c) => c.args?.title === title).containerArgs.grid
            .column;
        assert.strictEqual(at("A"), "1", "A lands at column 1");
        assert.strictEqual(
          at("Important"),
          "3 / 5",
          "Important is pushed right, keeping its 2-span"
        );
        assert.strictEqual(after.args.columns, 4, "the grid grew to 4 columns");
      });
    }
  );

  module(
    "conservation battery — no move duplicates a block",
    function (innerHooks) {
      // One outlet, two grids + a loose stack tile + an empty layout-merged-cell, so a
      // single seed can exercise every move/insert method across source
      // contexts. The universal invariant: after the op, no content block
      // appears more than once (no duplication) and the total count changes
      // by exactly the operation's expected delta.
      const OUTLET = "homepage-blocks";

      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        const cell = (title, column, row) => ({
          block: TestTile,
          args: { title },
          containerArgs: {
            grid: { column, row, align: "stretch", justify: "stretch" },
          },
        });
        await _renderBlocks(
          OUTLET,
          [
            {
              block: Layout,
              args: { mode: "grid", columns: 3, rows: 2 },
              children: [cell("A1", "1", "1"), cell("A2", "2", "1")],
            },
            {
              block: Layout,
              args: { mode: "grid", columns: 3, rows: 2 },
              children: [
                cell("B1", "1", "1"),
                {
                  block: "layout-merged-cell",
                  containerArgs: {
                    grid: {
                      column: "3",
                      row: "1",
                      align: "stretch",
                      justify: "stretch",
                    },
                  },
                },
              ],
            },
            { block: TestTile, args: { title: "S" } },
          ],
          getOwner(this)
        );
        this.editor.siteSettings.wireframe_enabled = true;
        logIn(getOwner(this));
        this.editor = getOwner(this).lookup("service:wireframe");
        this.editor.enter();
      });

      // Resolves the keys each operation needs from the seeded layout.
      function keys(editor) {
        const root = editor.wireframeLayoutQuery.readResolvedLayout(OUTLET)[0];
        const [gridA, gridB] = root.children;
        const loose = root.children.find((c) => c.args?.title === "S");
        const tile = (grid, title) =>
          `wf:svc-test-tile:${
            grid.children.find((c) => c.args?.title === title).__stableKey
          }`;
        const emptyCell = gridB.children.find(
          (c) => c.block === "layout-merged-cell"
        );
        return {
          gridA: `layout:${gridA.__stableKey}`,
          gridB: `layout:${gridB.__stableKey}`,
          a1: tile(gridA, "A1"),
          a2: tile(gridA, "A2"),
          b1: tile(gridB, "B1"),
          emptyCell: `layout-merged-cell:${emptyCell.__stableKey}`,
          s: `wf:svc-test-tile:${loose.__stableKey}`,
        };
      }

      // Title → occurrence count across the whole outlet tree.
      function titleCounts(editor) {
        const counts = {};
        const walk = (entries) => {
          for (const entry of entries ?? []) {
            if (entry.args?.title) {
              counts[entry.args.title] = (counts[entry.args.title] ?? 0) + 1;
            }
            walk(entry.children);
          }
        };
        walk(
          editor.wireframeLayoutQuery.readResolvedLayout(OUTLET)[0].children
        );
        return counts;
      }

      // Each entry relocates or inserts a block; `delta` is the expected
      // change in total content blocks (0 = relocate, +1 = new, -1 = removes
      // a target). Every case asserts NO block is duplicated.
      const OPERATIONS = [
        {
          name: "moveBlock — cross-grid, same outlet (outline before)",
          delta: 0,
          run: (e, k) =>
            mutationsOf(e).moveBlock({
              sourceKey: k.a1,
              targetKey: k.b1,
              position: "before",
              targetOutletName: OUTLET,
            }),
        },
        {
          name: "moveBlock — from stack into a grid (inside)",
          delta: 0,
          run: (e, k) =>
            mutationsOf(e).moveBlock({
              sourceKey: k.s,
              targetKey: k.gridA,
              position: "inside",
              targetOutletName: OUTLET,
            }),
        },
        {
          name: "moveBlock — same-grid before a cell (cascade, not reflow)",
          delta: 0,
          run: (e, k) =>
            mutationsOf(e).moveBlock({
              sourceKey: k.a2,
              targetKey: k.a1,
              position: "before",
              targetOutletName: OUTLET,
            }),
        },
        {
          name: "applyGridDrop — into a cross-grid empty cell (fill)",
          delta: 0,
          run: (e, k) =>
            gridOf(e).drop({
              targetGridKey: k.gridB,
              gesture: GRID_DROP_GESTURES.INTO,
              cell: { column: 3, row: 2 },
              source: { kind: "existing", key: k.a1 },
            }),
        },
        {
          name: "moveBlockIntoCell — cross-grid empty cell",
          delta: 0,
          run: (e, k) =>
            gridOf(e).moveIntoCell({
              sourceKey: k.a1,
              cellKey: k.emptyCell,
            }),
        },
        {
          name: "applyGridDrop — beside a cross-grid cell (cascade)",
          delta: 0,
          run: (e, k) =>
            gridOf(e).drop({
              targetGridKey: k.gridB,
              gesture: GRID_DROP_GESTURES.BESIDE,
              anchorKey: k.b1,
              direction: "right",
              source: { kind: "existing", key: k.a1 },
            }),
        },
        {
          name: "applyGridDrop — same-grid rotation (cascade)",
          delta: 0,
          run: (e, k) =>
            gridOf(e).drop({
              targetGridKey: k.gridA,
              gesture: GRID_DROP_GESTURES.BESIDE,
              anchorKey: k.a1,
              direction: "left",
              source: { kind: "existing", key: k.a2 },
            }),
        },
        {
          name: "applyGridDrop — onto an occupied cross-grid cell (swap/trade)",
          delta: 0,
          run: (e, k) =>
            // B1 sits at column 1; an INTO drop onto it decides SWAP.
            gridOf(e).drop({
              targetGridKey: k.gridB,
              gesture: GRID_DROP_GESTURES.INTO,
              cell: { column: 1, row: 1 },
              source: { kind: "existing", key: k.a1 },
            }),
        },
        {
          name: "applyGridDrop — palette beside a cell (cascade, new block)",
          delta: 1,
          run: (e, k) =>
            gridOf(e).drop({
              targetGridKey: k.gridB,
              gesture: GRID_DROP_GESTURES.BESIDE,
              anchorKey: k.b1,
              direction: "right",
              source: {
                kind: "new",
                blockName: "wf:svc-test-tile",
                defaultArgs: { title: "New" },
              },
            }),
        },
        {
          name: "applyGridDrop — palette into an empty cell (fill)",
          delta: 1,
          run: (e, k) =>
            gridOf(e).drop({
              targetGridKey: k.gridB,
              gesture: GRID_DROP_GESTURES.INTO,
              cell: { column: 3, row: 2 },
              source: {
                kind: "new",
                blockName: "wf:svc-test-tile",
                defaultArgs: { title: "New2" },
              },
            }),
        },
        {
          name: "applyGridDrop — replace an occupied cell (Shift, removes target)",
          delta: -1,
          run: (e, k) =>
            // A2 sits at column 2; a Shift-held INTO drop onto it removes A2.
            gridOf(e).drop({
              targetGridKey: k.gridA,
              gesture: GRID_DROP_GESTURES.INTO,
              cell: { column: 2, row: 1 },
              shift: true,
              source: { kind: "existing", key: k.a1 },
            }),
        },
      ];

      for (const op of OPERATIONS) {
        test(op.name, function (assert) {
          const before = Object.values(titleCounts(this.editor)).reduce(
            (n, c) => n + c,
            0
          );
          const ok = op.run(this.editor, keys(this.editor));
          assert.true(ok, "the operation succeeded");

          const counts = titleCounts(this.editor);
          const duplicated = Object.entries(counts)
            .filter(([, c]) => c > 1)
            .map(([title]) => title);
          assert.deepEqual(duplicated, [], "no block is duplicated");

          const after = Object.values(counts).reduce((n, c) => n + c, 0);
          assert.strictEqual(
            after,
            before + op.delta,
            `total block count changed by exactly ${op.delta}`
          );
        });
      }
    }
  );

  module("drop-action coverage (exhaustiveness guard)", function () {
    // Tripwire: grid placement is funneled through the drop dispatch → the grid
    // manipulator → the decider, so no method on the block-mutations service
    // should place a block into a grid on its own. The methods matching the
    // placement-verb pattern below are the legitimately-remaining ones — linear
    // moves and the cross-outlet relocation primitive. A NEW `move*`/`insert*`/
    // etc. method turns this red, forcing a deliberate decision about whether it
    // belongs on the service at all or should route through the manipulator.
    // Introspects the prototype rather than a static list that drifts.
    test("no unrecognized grid-mutating method exists", function (assert) {
      const blockMutations = getOwner(this).lookup(
        "service:wireframe-block-mutations"
      );
      const expected = [
        "insertBlock",
        // Relocation primitive shared by `moveBlock` and the grid
        // manipulator — moves an entry between outlets, never decides a grid
        // placement on its own.
        "moveAcrossOutlets",
        "moveBlock",
        "moveBlockDown",
        "moveBlockUp",
      ];
      const pattern = /^(move|insert|place|swap|replace|setSlot)/;
      const found = Object.getOwnPropertyNames(
        Object.getPrototypeOf(blockMutations)
      ).filter(
        (name) =>
          pattern.test(name) && typeof blockMutations[name] === "function"
      );
      assert.deepEqual(
        found.sort(),
        expected,
        "grid-mutating methods match the known set — add new ones here AND " +
          "confirm they route through the placement rules"
      );
    });

    // Sibling tripwire on the manipulator itself: every public method either
    // routes a drop through `decideGridDrop` (the rule chokepoint) or, for the
    // direct cell ops, validates occupancy through the shared `rectIsFree`
    // primitive. A NEW public method turns this red, forcing a decision about
    // which path it belongs to before it can silently bypass the rules.
    test("manipulator's public surface is the known set", function (assert) {
      const gridManipulator = getOwner(this).lookup(
        "service:wireframe-grid-manipulator"
      );
      const expected = [
        // Decided placement — routes through `decideGridDrop`. (The pure
        // `positionEntering` / `syncDeclaredToUsage` placement transforms now
        // live in `lib/grid-placement.js`, not on the manipulator.)
        "drop",
        // Direct cell ops — validate occupancy via the shared `rectIsFree`
        // (`mergeCells`) or operate on an explicit chosen cell.
        "mergeCells",
        "moveIntoCell",
        "placeInCell",
        "splitCell",
        // Deterministic resizes — explicit rects, no decider.
        "resizeColumns",
        "resizeSlot",
      ];
      const found = Object.getOwnPropertyNames(
        Object.getPrototypeOf(gridManipulator)
      ).filter(
        (name) =>
          name !== "constructor" && typeof gridManipulator[name] === "function"
      );
      assert.deepEqual(
        found.sort(),
        expected.sort(),
        "manipulator methods match the known set — add new ones here AND " +
          "confirm they route through the decider or the shared occupancy check"
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
      this.inlineEdit = getOwner(this).lookup("service:wireframe-inline-edit");
      this.editor.enter();
    });

    test("writes the value when the entry started without an args object", async function (assert) {
      const draft = outletChildren(this.editor);
      const key = `wf:svc-test-tile:${draft[0].__stableKey}`;

      const opened = await this.inlineEdit.start(key, "title");
      assert.true(opened);

      this.inlineEdit.applyChange("Typed");

      const after = outletChildren(this.editor);
      assert.strictEqual(after[0].args?.title, "Typed");
    });

    test("committing an empty value is a no-op when the entry has no args", async function (assert) {
      const draft = outletChildren(this.editor);
      const key = `wf:svc-test-tile:${draft[0].__stableKey}`;

      const opened = await this.inlineEdit.start(key, "title");
      assert.true(opened);

      this.inlineEdit.applyChange("");

      const after = outletChildren(this.editor);
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
        this.inlineEdit = getOwner(this).lookup(
          "service:wireframe-inline-edit"
        );
        this.editor.enter();

        // Swap in a doc-JSON value post-render to mimic marked inline
        // text. The block validator declares `title` as a string, but
        // it only runs at render time; direct mutation isn't re-checked,
        // which is enough to exercise the undo-gating comparator.
        const draft = outletChildren(this.editor);
        draft[0].args.title = {
          type: "doc",
          content: [
            { type: "text", text: "hello", marks: [{ type: "strong" }] },
          ],
        };
        this.key = `wf:svc-test-tile:${draft[0].__stableKey}`;
      });

      test("committing an unchanged doc-JSON value doesn't push undo", async function (assert) {
        const opened = await this.inlineEdit.start(this.key, "title");
        assert.true(opened);
        assert.false(
          this.editor.wireframeEditEngine.canUndo,
          "no undo entry before commit"
        );

        // Fresh object reference, identical content — what
        // `toStorage(doc.toJSON())` produces on every commit for marked
        // text. `Object.is` returns false; only a deep-equal comparator
        // recognizes the no-op.
        this.inlineEdit.applyChange({
          type: "doc",
          content: [
            { type: "text", text: "hello", marks: [{ type: "strong" }] },
          ],
        });
        this.inlineEdit.stop({ commit: true });

        assert.false(
          this.editor.wireframeEditEngine.canUndo,
          "no spurious undo entry for an unchanged doc-JSON commit"
        );
      });

      test("committing a CHANGED doc-JSON value DOES push undo", async function (assert) {
        const opened = await this.inlineEdit.start(this.key, "title");
        assert.true(opened);

        this.inlineEdit.applyChange({
          type: "doc",
          content: [
            { type: "text", text: "world", marks: [{ type: "strong" }] },
          ],
        });
        this.inlineEdit.stop({ commit: true });

        assert.true(
          this.editor.wireframeEditEngine.canUndo,
          "real content changes still push undo entries"
        );
      });
    }
  );

  module(
    "inlineEdit.startContainerArg — a child's containerArg",
    function (innerHooks) {
      innerHooks.beforeEach(async function () {
        withTestBlockRegistration(() => registerBlock(TestTile));
        this.layout = await _renderBlocks(
          "homepage-blocks",
          [{ block: TestTile, args: { title: "First" } }],
          getOwner(this)
        );
        this.editor.siteSettings.wireframe_enabled = true;
        logIn(getOwner(this));
        this.editor = getOwner(this).lookup("service:wireframe");
        this.inlineEdit = getOwner(this).lookup(
          "service:wireframe-inline-edit"
        );
        this.editor.enter();
        const draft = outletChildren(this.editor);
        this.key = `wf:svc-test-tile:${draft[0].__stableKey}`;
      });

      test("start snapshots the child's containerArg value", async function (assert) {
        const opened = await this.inlineEdit.startContainerArg(
          this.key,
          "tab",
          "label"
        );
        assert.true(opened, "the session opens");
        assert.strictEqual(
          this.inlineEdit.argValue,
          undefined,
          "snapshots the (absent) label as the pre-edit value"
        );
        assert.deepEqual(
          this.inlineEdit.containerArgContext,
          { childKey: this.key, namespace: "tab", field: "label" },
          "exposes the containerArg target to the controller"
        );
      });

      test("commit writes the label into the child's containerArgs and is undoable", async function (assert) {
        await this.inlineEdit.startContainerArg(this.key, "tab", "label");
        assert.false(
          this.editor.wireframeEditEngine.canUndo,
          "nothing on the undo stack yet"
        );

        this.inlineEdit.applyChange("First tab");
        this.inlineEdit.stop({ commit: true });

        const after = outletChildren(this.editor);
        assert.strictEqual(
          after[0].containerArgs?.tab?.label,
          "First tab",
          "the label lands in the child's containerArgs"
        );
        assert.true(
          this.editor.wireframeEditEngine.canUndo,
          "the structural commit is undoable"
        );
      });

      test("committing an empty value removes the label", async function (assert) {
        await this.inlineEdit.startContainerArg(this.key, "tab", "label");
        this.inlineEdit.applyChange("Seed");
        this.inlineEdit.stop({ commit: true });

        await this.inlineEdit.startContainerArg(this.key, "tab", "label");
        this.inlineEdit.applyChange("");
        this.inlineEdit.stop({ commit: true });

        const after = outletChildren(this.editor);
        assert.false(
          "label" in (after[0].containerArgs?.tab ?? {}),
          "an empty commit deletes the label rather than storing an empty value"
        );
      });

      test("committing an unchanged value doesn't push an undo entry", async function (assert) {
        await this.inlineEdit.startContainerArg(this.key, "tab", "label");
        this.inlineEdit.applyChange("Seed");
        this.inlineEdit.stop({ commit: true });
        const undoCount = this.editor.wireframeEditEngine.undoDepth;

        await this.inlineEdit.startContainerArg(this.key, "tab", "label");
        this.inlineEdit.applyChange("Seed");
        this.inlineEdit.stop({ commit: true });

        assert.strictEqual(
          this.editor.wireframeEditEngine.undoDepth,
          undoCount,
          "re-committing the same label is a no-op on the undo stack"
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
      this.clipboard = getOwner(this).lookup("service:wireframe-clipboard");
      this.editor.enter();
    });

    test("copySelected stashes the selected block with mode='copy'", function (assert) {
      const draft = outletChildren(this.editor);
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
      });

      assert.true(this.clipboard.copySelected());
      assert.true(this.clipboard.hasClipboardEntry);
      // The clone's stripped __stableKey and preserved args are asserted
      // observably by the paste tests below; here just pin the mode.
      assert.strictEqual(
        getOwner(this).lookup("service:wireframe-clipboard").clipboardMode,
        "copy"
      );
    });

    test("copySelected returns false when nothing is selected", function (assert) {
      assert.false(this.clipboard.copySelected());
      assert.false(this.clipboard.hasClipboardEntry);
    });

    test("cutSelected stores the entry and removes it from the canvas", function (assert) {
      const draft = outletChildren(this.editor);
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
      });

      assert.true(this.clipboard.cutSelected());
      assert.strictEqual(
        getOwner(this).lookup("service:wireframe-clipboard").clipboardMode,
        "cut"
      );
      const after = outletChildren(this.editor);
      assert.strictEqual(after.length, 1);
      assert.strictEqual(after[0].args.title, "Second");
    });

    test("pasteFromClipboard inserts a fresh clone after the selection", function (assert) {
      const draft = outletChildren(this.editor);
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
      });
      this.clipboard.copySelected();
      assert.true(this.clipboard.pasteFromClipboard());

      const after = outletChildren(this.editor);
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
      const draft = outletChildren(this.editor);
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
      });
      this.clipboard.copySelected();
      this.clipboard.pasteFromClipboard();

      const after = outletChildren(this.editor);
      const sourceKey = after[0].__stableKey;
      const pastedKey = after[1].__stableKey;
      assert.notStrictEqual(sourceKey, pastedKey);
    });

    test("multiple pastes insert independent subtrees", function (assert) {
      const draft = outletChildren(this.editor);
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
      });
      this.clipboard.copySelected();
      this.clipboard.pasteFromClipboard();
      this.clipboard.pasteFromClipboard();

      const after = outletChildren(this.editor);
      assert.strictEqual(after.length, 4);
    });

    test("pasteFromClipboard returns false when clipboard is empty", function (assert) {
      const draft = outletChildren(this.editor);
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
      });
      assert.false(this.clipboard.pasteFromClipboard());
    });

    test("pasteFromClipboard returns false when no block is selected", function (assert) {
      const draft = outletChildren(this.editor);
      const firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key: firstKey,
        name: "wf:svc-test-tile",
      });
      this.clipboard.copySelected();
      this.editor.wireframeSelection.selectBlock(null);

      assert.false(this.clipboard.pasteFromClipboard());
    });
  });

  module("canInsertBlockAt", function () {
    test("permits inserts for blocks with no outlet restrictions", function (assert) {
      withTestBlockRegistration(() => registerBlock(TestTile));
      assert.true(
        getOwner(this)
          .lookup("service:wireframe-drop-authority")
          .canInsertBlockAt({
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
        getOwner(this)
          .lookup("service:wireframe-drop-authority")
          .canInsertBlockAt({
            blockName: "wf:svc-test-restricted",
            targetOutletName: "homepage-blocks",
          })
      );
      assert.true(
        getOwner(this)
          .lookup("service:wireframe-drop-authority")
          .canInsertBlockAt({
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
        getOwner(this)
          .lookup("service:wireframe-drop-authority")
          .canInsertBlockAt({
            blockName: "wf:svc-test-denied",
            targetOutletName: "homepage-blocks",
          })
      );
    });

    test("is permissive for unknown block names (validator catches on save)", function (assert) {
      assert.true(
        getOwner(this)
          .lookup("service:wireframe-drop-authority")
          .canInsertBlockAt({
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

      const draft = outletChildren(this.editor);
      const key = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key,
        name: "wf:svc-test-tile",
      });
      this.firstKey = key;
    });

    test("commits a fresh condition tree on the selected block", function (assert) {
      const next = { type: "user", loggedIn: true };
      assert.true(
        getOwner(this)
          .lookup("service:wireframe-entry-edits")
          .updateSelectedConditions(next)
      );

      const draft = outletChildren(this.editor);
      assert.deepEqual(draft[0].conditions, next);
      assert.true(this.editor.wireframeEditEngine.isDirty);
    });

    test("clears conditions when passed null", function (assert) {
      getOwner(this)
        .lookup("service:wireframe-entry-edits")
        .updateSelectedConditions({
          type: "user",
          loggedIn: true,
        });
      assert.true(
        getOwner(this)
          .lookup("service:wireframe-entry-edits")
          .updateSelectedConditions(null)
      );

      const draft = outletChildren(this.editor);
      assert.strictEqual(draft[0].conditions, undefined);
    });

    test("returns false when no block is selected", function (assert) {
      this.editor.wireframeSelection.selectBlock(null);
      assert.false(
        getOwner(this)
          .lookup("service:wireframe-entry-edits")
          .updateSelectedConditions({
            type: "user",
            loggedIn: true,
          })
      );
    });

    test("selectedBlockConditions live-resolves the latest tree", function (assert) {
      const next = { type: "user", admin: true };
      getOwner(this)
        .lookup("service:wireframe-entry-edits")
        .updateSelectedConditions(next);
      assert.deepEqual(
        this.editor.wireframeSelection.selectedBlockConditions,
        next
      );
    });

    test("selectedBlockConditions returns null when no selection", function (assert) {
      this.editor.wireframeSelection.selectBlock(null);
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockConditions,
        null
      );
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

      const draft = outletChildren(this.editor);
      this.firstKey = `wf:svc-test-tile:${draft[0].__stableKey}`;
      this.secondKey = `wf:svc-test-tile:${draft[1].__stableKey}`;
    });

    test("moveBlock pushes an undoable structural entry", async function (assert) {
      mutationsOf(this.editor).moveBlock({
        sourceKey: this.firstKey,
        targetKey: this.secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      assert.true(
        this.editor.wireframeEditEngine.canUndo,
        "undo stack is populated"
      );

      const moved = outletChildren(this.editor);
      assert.strictEqual(moved[0].args.title, "Second");

      const undone = await this.editor.wireframeEditEngine.undo();
      assert.true(undone);

      const restored = outletChildren(this.editor);
      assert.strictEqual(restored[0].args.title, "First");
      assert.strictEqual(restored[1].args.title, "Second");
    });

    test("redo re-applies a structural move", async function (assert) {
      mutationsOf(this.editor).moveBlock({
        sourceKey: this.firstKey,
        targetKey: this.secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      await this.editor.wireframeEditEngine.undo();
      const redone = await this.editor.wireframeEditEngine.redo();
      assert.true(redone);

      const after = outletChildren(this.editor);
      assert.strictEqual(after[0].args.title, "Second");
      assert.strictEqual(after[1].args.title, "First");
    });

    test("insertBlock can be undone, removing the inserted entry", async function (assert) {
      mutationsOf(this.editor).insertBlock({
        blockName: "wf:svc-test-tile",
        defaultArgs: { title: "Inserted" },
        targetKey: this.secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      const afterInsert = outletChildren(this.editor);
      assert.strictEqual(afterInsert.length, 3);

      await this.editor.wireframeEditEngine.undo();
      const restored = outletChildren(this.editor);
      assert.strictEqual(restored.length, 2);
      assert.strictEqual(restored[0].args.title, "First");
      assert.strictEqual(restored[1].args.title, "Second");
    });

    test("removeBlock can be undone, restoring the deleted entry", async function (assert) {
      this.editor.wireframeSelection.selectBlock({
        key: this.secondKey,
        name: "wf:svc-test-tile",
      });
      mutationsOf(this.editor).removeBlock(this.secondKey);
      let after = outletChildren(this.editor);
      assert.strictEqual(after.length, 1);

      await this.editor.wireframeEditEngine.undo();
      after = outletChildren(this.editor);
      assert.strictEqual(after.length, 2);
      assert.strictEqual(after[1].args.title, "Second");
    });

    test("duplicateBlock can be undone", async function (assert) {
      mutationsOf(this.editor).duplicateBlock(this.firstKey);
      let after = outletChildren(this.editor);
      assert.strictEqual(after.length, 3);

      await this.editor.wireframeEditEngine.undo();
      after = outletChildren(this.editor);
      assert.strictEqual(after.length, 2);
    });

    test("duplicateBlock(key, count) inserts that many clones in one undo step", async function (assert) {
      mutationsOf(this.editor).duplicateBlock(this.firstKey, 3);
      let after = outletChildren(this.editor);
      assert.strictEqual(
        after.length,
        5,
        "three clones added to the two blocks"
      );

      await this.editor.wireframeEditEngine.undo();
      after = outletChildren(this.editor);
      assert.strictEqual(
        after.length,
        2,
        "a single undo removes the whole ×N batch"
      );
    });

    test("duplicateBlock clamps a non-positive count to one clone", function (assert) {
      mutationsOf(this.editor).duplicateBlock(this.firstKey, 0);
      assert.strictEqual(
        outletChildren(this.editor).length,
        3,
        "always inserts at least one clone"
      );
    });

    test("selectBlock resets the selection to a single block", function (assert) {
      this.editor.wireframeSelection.selectBlock({ key: this.firstKey });
      this.editor.wireframeSelection.toggleBlockSelection({
        key: this.secondKey,
      });
      assert.strictEqual(
        this.editor.wireframeSelection.selectionCount,
        2,
        "two selected"
      );

      this.editor.wireframeSelection.selectBlock({ key: this.firstKey });
      assert.strictEqual(
        this.editor.wireframeSelection.selectionCount,
        1,
        "a plain select collapses back to one"
      );
      assert.true(
        this.editor.wireframeSelection.isBlockSelected(this.firstKey)
      );
      assert.false(
        this.editor.wireframeSelection.isBlockSelected(this.secondKey)
      );
    });

    test("toggleBlockSelection adds, re-anchors, and removes", function (assert) {
      this.editor.wireframeSelection.selectBlock({ key: this.firstKey });

      this.editor.wireframeSelection.toggleBlockSelection({
        key: this.secondKey,
      });
      assert.true(
        this.editor.wireframeSelection.hasMultiSelection,
        "now multi-selected"
      );
      assert.true(
        this.editor.wireframeSelection.isBlockSelected(this.firstKey)
      );
      assert.true(
        this.editor.wireframeSelection.isBlockSelected(this.secondKey)
      );
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockKey,
        this.secondKey,
        "the newly added block becomes the primary"
      );

      this.editor.wireframeSelection.toggleBlockSelection({
        key: this.secondKey,
      });
      assert.false(
        this.editor.wireframeSelection.isBlockSelected(this.secondKey),
        "removed"
      );
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockKey,
        this.firstKey,
        "removing the primary re-anchors to a remaining member"
      );
    });

    test("setSelectionRange selects every key and anchors the primary", function (assert) {
      this.editor.wireframeSelection.setSelectionRange(
        [this.firstKey, this.secondKey],
        {
          key: this.secondKey,
        }
      );
      assert.strictEqual(this.editor.wireframeSelection.selectionCount, 2);
      assert.true(
        this.editor.wireframeSelection.isBlockSelected(this.firstKey)
      );
      assert.true(
        this.editor.wireframeSelection.isBlockSelected(this.secondKey)
      );
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockKey,
        this.secondKey
      );
    });

    test("removeBlocks deletes the whole selection in one undo step", async function (assert) {
      mutationsOf(this.editor).removeBlocks([this.firstKey, this.secondKey]);
      assert.strictEqual(
        outletChildren(this.editor).length,
        0,
        "both blocks removed"
      );

      await this.editor.wireframeEditEngine.undo();
      assert.strictEqual(
        outletChildren(this.editor).length,
        2,
        "a single undo restores both"
      );
    });

    test("removeBlocks skips the outlet root", function (assert) {
      const rootKey =
        this.editor.wireframeLayoutQuery.readResolvedLayout(
          "homepage-blocks"
        )[0];
      const rootEntryKey = `layout:${rootKey.__stableKey}`;
      mutationsOf(this.editor).removeBlocks([rootEntryKey, this.firstKey]);

      const after = outletChildren(this.editor);
      assert.strictEqual(after.length, 1, "the non-root block is removed");
      assert.strictEqual(
        after[0].args.title,
        "Second",
        "the root (and its surviving child) stay"
      );
    });

    test("updateSelectedConditions feeds the undo stack", async function (assert) {
      this.editor.wireframeSelection.selectBlock({
        key: this.firstKey,
        name: "wf:svc-test-tile",
      });
      const next = { type: "user", admin: true };
      assert.true(
        getOwner(this)
          .lookup("service:wireframe-entry-edits")
          .updateSelectedConditions(next)
      );

      const undone = await this.editor.wireframeEditEngine.undo();
      assert.true(undone);
      const after = outletChildren(this.editor);
      assert.strictEqual(after[0].conditions, undefined);
    });

    test("a fresh structural mutation clears the redo stack", function (assert) {
      mutationsOf(this.editor).moveBlock({
        sourceKey: this.firstKey,
        targetKey: this.secondKey,
        position: "after",
        targetOutletName: "homepage-blocks",
      });
      this.editor.wireframeEditEngine.undo();
      assert.true(this.editor.wireframeEditEngine.canRedo);
      mutationsOf(this.editor).duplicateBlock(this.firstKey);
      assert.false(this.editor.wireframeEditEngine.canRedo);
    });
  });

  module("outlet as implicit layout", function (innerHooks) {
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
    });

    test("enter() wraps the outlet's blocks in a single root layout", function (assert) {
      const draft =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      assert.strictEqual(draft.length, 1, "exactly one root entry");
      assert.strictEqual(
        draft[0].block,
        "layout",
        "the root is a layout block"
      );
      assert.strictEqual(draft[0].args.mode, "stack", "defaults to stack mode");
      assert.strictEqual(
        draft[0].children.length,
        2,
        "the outlet's blocks become the root layout's children"
      );
      assert.strictEqual(draft[0].children[0].args.title, "First");
    });

    test("outletRootKey / isOutletRoot identify the implicit root", function (assert) {
      const rootKey =
        this.editor.wireframeLayoutQuery.outletRootKey("homepage-blocks");
      const draft =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      assert.strictEqual(rootKey, `layout:${draft[0].__stableKey}`);
      assert.true(
        this.editor.wireframeLayoutQuery.isOutletRoot(rootKey),
        "the root key is recognised"
      );

      const childKey = `wf:svc-test-tile:${draft[0].children[0].__stableKey}`;
      assert.false(
        this.editor.wireframeLayoutQuery.isOutletRoot(childKey),
        "a child block is not the root"
      );
      assert.false(this.editor.wireframeLayoutQuery.isOutletRoot(null));
    });

    test("selectOutlet selects the root layout so the layout form shows", function (assert) {
      this.editor.wireframeSelection.selectOutlet("homepage-blocks");
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockKey,
        this.editor.wireframeLayoutQuery.outletRootKey("homepage-blocks")
      );
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockData.name,
        "layout",
        "the inspector keys off name === 'layout' to show the layout form"
      );
    });

    test("removeBlock is a no-op on the outlet root", function (assert) {
      const rootKey =
        this.editor.wireframeLayoutQuery.outletRootKey("homepage-blocks");
      this.editor.wireframeSelection.selectOutlet("homepage-blocks");

      const removed = mutationsOf(this.editor).removeBlock(rootKey);

      assert.false(
        removed,
        "removeBlock reports no change for the outlet root"
      );
      const draft =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      assert.strictEqual(draft.length, 1, "the root layout still exists");
      assert.strictEqual(
        draft[0].block,
        "layout",
        "and is still the root layout"
      );
      assert.strictEqual(
        draft[0].children.length,
        2,
        "the outlet's children are untouched"
      );
    });

    test("pressing Delete with the outlet selected does not remove it", function (assert) {
      // Drive the real keyboard path: the Delete shortcut calls
      // `removeBlock(selectedBlockKey)` directly, bypassing the toolbar's
      // `{{#unless @isOutletRoot}}` gate. This is the exact reproduction of
      // the reported bug (selecting the outlet and pressing Delete).
      const detach = attachEditorShortcuts(this.editor);
      this.editor.wireframeSelection.selectOutlet("homepage-blocks");

      document.dispatchEvent(
        new KeyboardEvent("keydown", { key: "Delete", bubbles: true })
      );

      const draft =
        this.editor.wireframeLayoutQuery.readResolvedLayout("homepage-blocks");
      assert.strictEqual(draft.length, 1, "the root layout still exists");
      assert.strictEqual(
        draft[0].block,
        "layout",
        "and is still the root layout"
      );
      assert.strictEqual(
        draft[0].children.length,
        2,
        "the outlet's children are untouched"
      );

      detach();
    });

    test("exit() clears the recorded root key", function (assert) {
      assert.notStrictEqual(
        this.editor.wireframeLayoutQuery.outletRootKey("homepage-blocks"),
        null
      );
      this.editor.exit();
      assert.strictEqual(
        this.editor.wireframeLayoutQuery.outletRootKey("homepage-blocks"),
        null
      );
    });
  });

  module("simulation", function (innerHooks) {
    innerHooks.beforeEach(function () {
      // The simulation slot lives in its own service (editor-session-state that
      // survives without an active session); we still test from a clean state.
      // The simulation service bumps the revision signal directly on a change,
      // so consumers re-render — assert that through the revision service.
      this.sim = getOwner(this).lookup("service:wireframe-simulation");
      this.revision = getOwner(this).lookup("service:wireframe-revision");
    });

    innerHooks.afterEach(function () {
      this.sim.clear();
    });

    test("isSimulating is false by default", function (assert) {
      assert.false(this.sim.isSimulating);
      assert.strictEqual(this.sim.value, null);
    });

    test("setUser with a persona object marks isSimulating true", function (assert) {
      this.sim.setUser({ trust_level: 2, admin: false });
      assert.true(this.sim.isSimulating);
      assert.strictEqual(this.sim.value.user.trust_level, 2);
    });

    test("setUser(null) means anonymous, still isSimulating", function (assert) {
      this.sim.setUser(null);
      assert.true(this.sim.isSimulating);
      assert.true("user" in this.sim.value);
      assert.strictEqual(this.sim.value.user, null);
    });

    test("setUser(undefined) clears the persona slot", function (assert) {
      this.sim.setUser({ trust_level: 4 });
      this.sim.setUser(undefined);
      assert.false(this.sim.isSimulating);
    });

    test("setViewport(undefined) clears viewport but keeps persona", function (assert) {
      this.sim.setUser({ trust_level: 2 });
      this.sim.setViewport({
        viewport: { sm: true },
        touch: true,
      });
      assert.true(this.sim.isSimulating);

      this.sim.setViewport(undefined);
      assert.true(this.sim.isSimulating, "persona-only sim is still active");
      assert.false("viewport" in this.sim.value);
    });

    test("clear resets everything to null", function (assert) {
      this.sim.setUser({ trust_level: 4 });
      this.sim.setViewport({
        viewport: { sm: true },
        touch: true,
      });
      this.sim.clear();
      assert.false(this.sim.isSimulating);
      assert.strictEqual(this.sim.value, null);
    });

    test("a sim change bumps the revision signal (re-renders consumers)", function (assert) {
      const before = this.revision.version;
      this.sim.setUser({ trust_level: 2 });
      assert.true(
        this.revision.version > before,
        "the simulation change bumps the revision signal"
      );
    });
  });

  module("isInsideAllowedScope", function (innerHooks) {
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
      assert.true(this.editor.wireframeSelection.isInsideAllowedScope(child));
    });

    test("a click target inside a FloatKit menu stays in-scope", function (assert) {
      const child = appendScope("fk-d-menu");
      assert.true(this.editor.wireframeSelection.isInsideAllowedScope(child));
    });

    test("a click target outside any editor scope is out-of-scope", function (assert) {
      const child = appendScope("");
      assert.false(this.editor.wireframeSelection.isInsideAllowedScope(child));
    });
  });

  module("saveAllEditedDrafts", function (innerHooks) {
    const DRAFTS_URL = "/admin/plugins/wireframe/block-layout-drafts.json";
    const PUBLISH_URL = "/admin/customize/block-layouts.json";

    innerHooks.beforeEach(async function () {
      withTestBlockRegistration(() => registerBlock(TestTile));
      await registerTestLayout(getOwner(this));
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.enter();

      // Edit the outlet's tile so the outlet counts as edited.
      const tile = outletChildren(this.editor)[0];
      this.editor.wireframeSelection.selectBlock({
        key: `wf:svc-test-tile:${tile.__stableKey}`,
        name: "wf:svc-test-tile",
        args: { title: "Original" },
        metadata: { args: { title: { type: "string" } } },
      });
      await editArg(this.editor, "title", "Edited");
    });

    test("drafts every edited outlet without publishing it live", async function (assert) {
      pretender.post(DRAFTS_URL, (request) => {
        const body = parsePostData(request.requestBody);
        assert.step(`draft:${body.outlet_name}`);
        return response({ success: true });
      });
      // Saving a draft must never write the live field.
      pretender.post(PUBLISH_URL, () => {
        assert.true(
          false,
          "the publish endpoint must not be hit by Save draft"
        );
        return response({});
      });

      const banner = await this.editor.saveAllEditedDrafts();

      assert.strictEqual(banner, null, "no error banner on success");
      assert.verifySteps(["draft:homepage-blocks"]);
      assert.true(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks"),
        "the outlet stays edited — a draft never goes live"
      );
    });

    test("returns a banner naming an outlet whose draft fails", async function (assert) {
      pretender.post(DRAFTS_URL, () => response(500, {}));

      const banner = await this.editor.saveAllEditedDrafts();

      assert.true(
        banner?.includes("homepage-blocks"),
        "the failing outlet is named in the banner"
      );
      assert.true(
        this.editor.wireframeEditEngine.isOutletEdited("homepage-blocks"),
        "a failed draft leaves the outlet edited"
      );
    });
  });
});
