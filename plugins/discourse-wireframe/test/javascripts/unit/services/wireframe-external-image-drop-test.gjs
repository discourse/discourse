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
import BlockChrome from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/block-chrome";
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";
import { queryOf } from "../../helpers/wireframe-peers";

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
  return queryOf(editor).readResolvedLayout(outlet)?.[0]?.children ?? [];
}

module("Unit | discourse-wireframe | shared image frame resize", function () {
  test("resize handles preserve the authored frame ratio instead of the source ratio", function (assert) {
    const ratio = Object.getOwnPropertyDescriptor(
      BlockChrome.prototype,
      "imageResizeAspectRatio"
    ).get;
    assert.strictEqual(
      ratio.call({
        imageArgEntries: [
          {
            def: { allowResize: true },
            value: {
              width: 1600,
              height: 900,
              frame: { width: 300, height: 400 },
            },
          },
        ],
      }),
      0.75
    );
  });
});

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
      this.editor = getOwner(this).lookup("service:wireframe-workspace");
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
      const blockKey = this.editor.wireframeSelection.selectedBlockKey;
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

    test("shared image composition previews without persistence and commits one undo step", async function (assert) {
      this.editor.wireframeDragOverlay.claimSlotInsert(
        insertPreview("wf:svc-img-drop-image")
      );
      this.imageUpload.completeExternalImageDrop(this.file);
      const target = {
        blockKey: this.editor.wireframeSelection.selectedBlockKey,
        argName: "image",
      };
      const original = {
        url: "/a.png",
        width: 1600,
        height: 900,
        frame: { width: 320, height: 180 },
        dark: { url: "/dark.png", width: 800, height: 600 },
      };
      this.imageUpload.setImageArg(target.blockKey, target.argName, original);
      const engine = this.owner.lookup("service:wireframe-mutation-engine");
      engine.clearStacks();
      const session = this.owner.lookup("service:wireframe-image-composition");
      const entry = queryOf(this.editor).findEntryAndOutletSync(
        target.blockKey
      ).entry;

      session.begin(target, true);
      session.preview(target, { position: { x: 20, y: 75 } });
      session.change(target, { zoom: 175 });
      session.change(target, { fit: "contain" });
      assert.deepEqual(
        entry.args.image,
        original,
        "previews never enter the saved argument"
      );
      assert.false(engine.canUndo, "previews do not create history");
      session.commit();
      assert.strictEqual(
        entry.args.image.zoom,
        175,
        "Done commits the full draft"
      );
      assert.deepEqual(
        entry.args.image.frame,
        original.frame,
        "composition preserves frame sizing"
      );
      await engine.undo();
      assert.deepEqual(
        entry.args.image,
        original,
        "one undo restores the complete original value"
      );
      assert.false(engine.canUndo, "there is exactly one undo entry");
      await engine.redo();
      assert.strictEqual(
        entry.args.image.fit,
        "contain",
        "redo restores the committed composition"
      );
      session.begin(target, true);
      session.preview(target, { zoom: 250 });
      session.cancel();
      assert.strictEqual(
        entry.args.image.zoom,
        175,
        "Cancel keeps the last committed value"
      );
    });

    test("shared image unchanged composition does not create history", function (assert) {
      this.editor.wireframeDragOverlay.claimSlotInsert(
        insertPreview("wf:svc-img-drop-image")
      );
      this.imageUpload.completeExternalImageDrop(this.file);
      const target = {
        blockKey: this.editor.wireframeSelection.selectedBlockKey,
        argName: "image",
      };
      const original = { url: "/a.png", width: 1600, height: 900 };
      this.imageUpload.setImageArg(target.blockKey, target.argName, original);
      const engine = this.owner.lookup("service:wireframe-mutation-engine");
      engine.clearStacks();
      const session = this.owner.lookup("service:wireframe-image-composition");
      session.begin(target, true);
      session.preview(target, { zoom: 175 });
      session.preview(target, { zoom: 100 });
      session.commit();
      assert.false(
        engine.canUndo,
        "returning to the original composition creates no undo entry"
      );
      assert.deepEqual(
        queryOf(this.editor).findEntryAndOutletSync(target.blockKey).entry.args
          .image,
        original,
        "defaults do not change the saved value"
      );
    });

    test("shared image undo cancels a transient composition before restoring history", async function (assert) {
      this.editor.wireframeDragOverlay.claimSlotInsert(
        insertPreview("wf:svc-img-drop-image")
      );
      this.imageUpload.completeExternalImageDrop(this.file);
      const target = {
        blockKey: this.editor.wireframeSelection.selectedBlockKey,
        argName: "image",
      };
      this.imageUpload.setImageArg(target.blockKey, target.argName, {
        url: "/a.png",
      });
      const engine = this.owner.lookup("service:wireframe-mutation-engine");
      engine.clearStacks();
      const session = this.owner.lookup("service:wireframe-image-composition");
      session.change(target, { zoom: 150 });
      session.begin(target, true);
      session.preview(target, { zoom: 225 });
      await engine.undo();
      assert.strictEqual(
        session.target,
        null,
        "undo closes the active preview"
      );
      assert.strictEqual(
        queryOf(this.editor).findEntryAndOutletSync(target.blockKey).entry.args
          .image.zoom,
        undefined,
        "undo restores the original image"
      );
      await engine.redo();
      assert.strictEqual(
        queryOf(this.editor).findEntryAndOutletSync(target.blockKey).entry.args
          .image.zoom,
        150,
        "redo restores only the committed composition"
      );
    });

    test("shared image selection changes apply previews and reject stale source operations", async function (assert) {
      this.editor.wireframeDragOverlay.claimSlotInsert(
        insertPreview("wf:svc-img-drop-image")
      );
      this.imageUpload.completeExternalImageDrop(this.file);
      const target = {
        blockKey: this.editor.wireframeSelection.selectedBlockKey,
        argName: "image",
      };
      this.imageUpload.setImageArg(target.blockKey, target.argName, {
        url: "/a.png",
      });
      const complete = this.imageUpload.beginReplacement(target);
      const engine = this.owner.lookup("service:wireframe-mutation-engine");
      engine.clearStacks();
      const session = this.owner.lookup("service:wireframe-image-composition");
      session.begin(target, true);
      session.preview(target, { position: { x: 25, y: 75 } });
      session.preview(target, { zoom: 200 });
      this.editor.wireframeSelection.selectBlock(null);
      complete({ url: "/stale.png" });
      assert.strictEqual(session.target, null, "selection clears the preview");
      assert.strictEqual(
        queryOf(this.editor).findEntryAndOutletSync(target.blockKey).entry.args
          .image.url,
        "/a.png",
        "the old selection's pending source does not overwrite its image"
      );
      const entry = queryOf(this.editor).findEntryAndOutletSync(
        target.blockKey
      ).entry;
      assert.deepEqual(
        entry.args.image.position,
        { x: 25, y: 75 },
        "deselecting applies the position"
      );
      assert.strictEqual(
        entry.args.image.zoom,
        200,
        "deselecting applies the whole draft"
      );
      await engine.undo();
      assert.deepEqual(
        entry.args.image,
        { url: "/a.png" },
        "one undo restores the starting image"
      );
      assert.false(
        engine.canUndo,
        "the entire reposition session is one undo step"
      );
      await engine.redo();
      assert.strictEqual(
        entry.args.image.zoom,
        200,
        "redo restores the applied draft"
      );
    });

    test("shared image selecting another block applies repositioning without stealing focus", function (assert) {
      this.editor.wireframeDragOverlay.claimSlotInsert(
        insertPreview("wf:svc-img-drop-image")
      );
      this.imageUpload.completeExternalImageDrop(this.file);
      const selection = this.editor.wireframeSelection;
      const target = { blockKey: selection.selectedBlockKey, argName: "image" };
      this.imageUpload.setImageArg(target.blockKey, target.argName, {
        url: "/a.png",
      });
      const session = this.owner.lookup("service:wireframe-image-composition");
      const trigger = document.createElement("button");
      const destination = document.createElement("button");
      document.body.append(trigger, destination);
      try {
        trigger.focus();
        session.begin(target, true);
        session.preview(target, { position: { x: 30, y: 60 } });
        selection.selectBlock({ key: target.blockKey });
        assert.true(
          session.repositioning,
          "selecting the same block keeps repositioning active"
        );
        destination.focus();
        const otherKey = entryKey(
          queryOf(this.editor).readResolvedLayout("homepage-blocks")[0]
        );
        selection.selectBlock({ key: otherKey });
        assert.strictEqual(
          selection.selectedBlockKey,
          otherKey,
          "the destination becomes selected"
        );
        assert.strictEqual(
          document.activeElement,
          destination,
          "focus stays on the destination"
        );
        assert.deepEqual(
          queryOf(this.editor).findEntryAndOutletSync(target.blockKey).entry
            .args.image.position,
          { x: 30, y: 60 },
          "switching blocks applies the position"
        );
        assert.strictEqual(session.target, null, "repositioning ends");
      } finally {
        trigger.remove();
        destination.remove();
      }
    });

    test("shared image deletion discards repositioning without adding an image history entry", async function (assert) {
      this.editor.wireframeDragOverlay.claimSlotInsert(
        insertPreview("wf:svc-img-drop-image")
      );
      this.imageUpload.completeExternalImageDrop(this.file);
      const target = {
        blockKey: this.editor.wireframeSelection.selectedBlockKey,
        argName: "image",
      };
      this.imageUpload.setImageArg(target.blockKey, target.argName, {
        url: "/a.png",
      });
      const engine = this.owner.lookup("service:wireframe-mutation-engine");
      engine.clearStacks();
      const session = this.owner.lookup("service:wireframe-image-composition");
      session.begin(target, true);
      session.preview(target, { zoom: 200 });
      this.owner
        .lookup("service:wireframe-block-mutations")
        .removeBlock(target.blockKey);
      assert.strictEqual(session.target, null, "deletion clears the preview");
      await engine.undo();
      assert.deepEqual(
        queryOf(this.editor).findEntryAndOutletSync(target.blockKey).entry.args
          .image,
        { url: "/a.png" },
        "undo restores the image without the discarded preview"
      );
      assert.false(engine.canUndo, "deletion is the only history entry");
    });

    test("shared image cleared targets do not match during reposition teardown", function (assert) {
      const session = this.owner.lookup("service:wireframe-image-composition");
      assert.false(
        session.matches(null),
        "a cleared target never matches an inactive session"
      );
    });

    test("shared image replacement preserves composition and rejects stale completions", function (assert) {
      this.editor.wireframeDragOverlay.claimSlotInsert(
        insertPreview("wf:svc-img-drop-image")
      );
      this.imageUpload.completeExternalImageDrop(this.file);
      const target = {
        blockKey: this.editor.wireframeSelection.selectedBlockKey,
        argName: "image",
      };
      const original = {
        source: "upload",
        upload_id: 42,
        url: "/a.png",
        width: 1600,
        height: 900,
        frame: { width: 320, height: 180 },
        position: { x: 20, y: 70 },
        zoom: 150,
        dark: { url: "/dark.png" },
      };
      this.imageUpload.setImageArg(target.blockKey, target.argName, original);
      const older = this.imageUpload.beginReplacement(target);
      const newer = this.imageUpload.beginReplacement(target);
      newer({ source: "url", url: "/new.png", width: 2400, height: 1600 });
      older({ source: "upload", upload_id: 99, url: "/stale.png" });
      const entry = queryOf(this.editor).findEntryAndOutletSync(
        target.blockKey
      ).entry;
      assert.strictEqual(
        entry.args.image.url,
        "/new.png",
        "the latest operation wins"
      );
      assert.strictEqual(
        entry.args.image.upload_id,
        undefined,
        "URLs clear the previous upload identity"
      );
      assert.deepEqual(
        entry.args.image.dark,
        original.dark,
        "the other source is retained"
      );
      assert.deepEqual(
        entry.args.image.position,
        original.position,
        "position is retained"
      );
      assert.deepEqual(
        entry.args.image.frame,
        original.frame,
        "authored frame size is retained"
      );
      assert.strictEqual(
        entry.args.image.width,
        2400,
        "source resolution is replaced independently"
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

      const blockKey = this.editor.wireframeSelection.selectedBlockKey;
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
