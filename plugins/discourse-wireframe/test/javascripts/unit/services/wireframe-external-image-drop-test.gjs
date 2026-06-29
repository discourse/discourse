import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

// A block with an image-typed arg stands in for the builtin `image` block:
// `completeExternalImageDrop` derives the target arg from whatever block the
// drop inserted, so the test exercises that derivation generically.
@block("wf:svc-img-drop-image", {
  args: { image: { type: "image" }, alt: { type: "string" } },
})
class TestImageBlock extends Component {
  <template>
    <div class="ti">{{@image.url}}</div>
  </template>
}

// A block with NO image arg, to assert the post-dispatch guard.
@block("wf:svc-img-drop-tile", { args: { title: { type: "string" } } })
class TestTile extends Component {
  <template>
    <div class="tile">{{@title}}</div>
  </template>
}

function outletChildren(editor, outlet = "homepage-blocks") {
  return editor.layoutQuery.readResolvedLayout(outlet)?.[0]?.children ?? [];
}

// Stands in for the descriptor the dragover handlers publish — an insert of
// the given block at the outlet root, exactly what a synthetic image-block
// drag would build.
function insertPreview(blockName) {
  return {
    dispatch: {
      action: "insertBlock",
      args: {
        blockName,
        defaultArgs: {},
        targetKey: null,
        position: "after",
        targetOutletName: "homepage-blocks",
      },
    },
  };
}

module(
  "Unit | Discourse Wireframe | service:wireframe | completeExternalImageDrop",
  function (hooks) {
    setupTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.beforeEach(async function () {
      withTestBlockRegistration(() => {
        registerBlock(TestImageBlock);
        registerBlock(TestTile);
      });
      this.editor = getOwner(this).lookup("service:wireframe");
      this.imageUpload = getOwner(this).lookup(
        "service:wireframe-image-upload"
      );
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      await _renderBlocks(
        "homepage-blocks",
        [{ block: TestTile, args: { title: "Existing" } }],
        getOwner(this)
      );
      this.editor.enter();

      // Guard: the drop should STAGE the file for the new block's overlay,
      // not upload directly through the service.
      this.uploads = [];
      this.imageUpload.uploadImageForArg = (file, opts) => {
        this.uploads.push({ file, opts });
        return Promise.resolve({ url: "/uploads/x.png", width: 1, height: 1 });
      };

      this.file = new File(["x"], "a.png", { type: "image/png" });
    });

    test("creates the previewed image block and stages the file for it", function (assert) {
      this.editor.wireframeDragOverlay.claimSlotInsert(
        insertPreview("wf:svc-img-drop-image")
      );

      const result = this.imageUpload.completeExternalImageDrop(this.file);

      assert.true(result, "the drop reports success");
      const children = outletChildren(this.editor);
      assert.true(
        children.some((c) => c.block === "wf:svc-img-drop-image"),
        "an image block was inserted at the slot"
      );
      const blockKey = this.editor.selectedBlockKey;
      assert.true(
        blockKey?.startsWith("wf:svc-img-drop-image:"),
        "the new image block is selected"
      );
      assert.strictEqual(
        this.uploads.length,
        0,
        "the service does not upload directly"
      );
      assert.strictEqual(
        this.imageUpload.consumePendingDropFile(blockKey, "image"),
        this.file,
        "the dropped file is staged for the new block's image arg"
      );
    });

    test("is a no-op with no file (does not dispatch or stage)", function (assert) {
      this.editor.wireframeDragOverlay.claimSlotInsert(
        insertPreview("wf:svc-img-drop-image")
      );

      const result = this.imageUpload.completeExternalImageDrop(null);

      assert.false(result);
      assert.strictEqual(
        outletChildren(this.editor).length,
        1,
        "no block was inserted"
      );
    });

    test("is a no-op when the slot rejects the drop (no preview to dispatch)", function (assert) {
      // No preview claimed -> coordinator.dispatch() returns false.
      const result = this.imageUpload.completeExternalImageDrop(this.file);

      assert.false(result);
      assert.strictEqual(
        outletChildren(this.editor).length,
        1,
        "no block was inserted"
      );
    });

    test("inserts but does not stage when the new block has no image arg", function (assert) {
      this.editor.wireframeDragOverlay.claimSlotInsert(
        insertPreview("wf:svc-img-drop-tile")
      );

      const result = this.imageUpload.completeExternalImageDrop(this.file);

      const blockKey = this.editor.selectedBlockKey;
      assert.true(
        blockKey?.startsWith("wf:svc-img-drop-tile:"),
        "the block was still inserted and selected"
      );
      assert.false(result, "the drop reports no staging");
      assert.strictEqual(
        this.imageUpload.consumePendingDropFile(blockKey, "image"),
        null,
        "nothing is staged when there's no image arg to fill"
      );
    });
  }
);
