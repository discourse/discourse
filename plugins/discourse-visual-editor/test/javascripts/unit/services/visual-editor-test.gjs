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

@block("ve-svc-test:tile", { args: { title: { type: "string" } } })
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
          key: "ve-svc-test:tile:1",
          name: "ve-svc-test:tile",
        });
        assert.strictEqual(this.editor.selectedBlockKey, "ve-svc-test:tile:1");
        assert.strictEqual(
          this.editor.selectedBlockData.name,
          "ve-svc-test:tile"
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
          key: "ve-svc-test:tile:7",
          name: "ve-svc-test:tile",
        });
        assert.true(this.editor.isBlockSelected("ve-svc-test:tile:7"));
        assert.false(this.editor.isBlockSelected("ve-svc-test:tile:8"));
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
          key: `ve-svc-test:tile:${stableKey}`,
          name: "ve-svc-test:tile",
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
  }
);
