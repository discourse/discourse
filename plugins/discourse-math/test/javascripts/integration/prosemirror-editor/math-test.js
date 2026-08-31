import { getOwner } from "@ember/owner";
import { click, settled, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { previewNodeViewFor } from "discourse/components/composer/preview-node-view";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";

const BLOCK_MARKDOWN = "$$\nE=mc^2\n$$";

async function toggleSource(view) {
  previewNodeViewFor(view.nodeDOM(0)).toggleSource();
  await settled();
}

// exactly one of these matches the editor's Mod-z binding per platform
async function undo() {
  await triggerKeyEvent(".ProseMirror", "keydown", "Z", { ctrlKey: true });
  await triggerKeyEvent(".ProseMirror", "keydown", "Z", { metaKey: true });
}

module(
  "Integration | Component | prosemirror-editor - math extension",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders inline math and preserves markdown", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const markdown = "Inline $E=mc^2$ math.";

      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.dom("span.composer-math-node").exists();
          assert.dom(".math-node-content").hasText("E=mc^2");
        },
        markdown
      );
    });

    test("renders block math as a preview block and preserves markdown", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      await testMarkdown(
        assert,
        BLOCK_MARKDOWN,
        () => {
          assert.dom(".composer-preview-node").exists();
          assert
            .dom(".composer-preview-node")
            .doesNotHaveClass("--source", "starts on the preview face");
          assert.dom(".math-block-preview .math").hasText("E=mc^2");
        },
        BLOCK_MARKDOWN
      );
    });

    test("toggles block math between preview and source", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const [editorClass] = await setupRichEditor(assert, BLOCK_MARKDOWN);
      const { view } = editorClass;

      await toggleSource(view);
      assert.dom(".composer-preview-node").hasClass("--source");
      assert
        .dom(".composer-preview-node__source")
        .hasText("E=mc^2", "the source face holds the LaTeX");

      await toggleSource(view);
      assert.dom(".composer-preview-node").doesNotHaveClass("--source");
      assert.strictEqual(
        view.state.selection.node?.type.name,
        "math_block",
        "the block is selected again"
      );
    });

    test("puts the caret in the source when it is shown", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const [editorClass] = await setupRichEditor(assert, BLOCK_MARKDOWN);
      const { view } = editorClass;

      await toggleSource(view);

      const { $head } = view.state.selection;
      assert.strictEqual(
        $head.parent.type.name,
        "preview_source",
        "the caret is inside the source"
      );
      assert.strictEqual(
        $head.parentOffset,
        "E=mc^2".length,
        "the caret is at the end of the source"
      );
    });

    test("edits to the source update the markdown, and undo restores it", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const [editorClass] = await setupRichEditor(assert, BLOCK_MARKDOWN);
      const { view } = editorClass;

      await toggleSource(view);
      view.dispatch(view.state.tr.insertText("+p", view.state.selection.from));
      await settled();

      assert.strictEqual(
        editorClass.value,
        "$$\nE=mc^2+p\n$$",
        "the markdown follows the source"
      );

      await undo();
      assert.strictEqual(
        editorClass.value,
        BLOCK_MARKDOWN,
        "undo restores the original markdown"
      );
    });

    test("keeps the line breaks of pasted cooked block math", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const [editorClass] = await setupRichEditor(assert, "");
      const { view } = editorClass;

      view.pasteHTML("<div class='math'>\na^2\nb^2\n</div>");
      await settled();

      assert.strictEqual(
        editorClass.value.trim(),
        "$$\na^2\nb^2\n$$",
        "the source survives the round trip through cooked HTML"
      );
    });

    test("escapes bare dollar signs when serializing block math", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const [editorClass] = await setupRichEditor(assert, BLOCK_MARKDOWN);
      const { view } = editorClass;

      await toggleSource(view);
      view.dispatch(view.state.tr.insertText("$", view.state.selection.from));
      await settled();

      assert.strictEqual(editorClass.value, "$$\nE=mc^2\\$\n$$");
    });

    test("edits inline math via modal", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const markdown = "Inline $E=mc^2$ math.";
      const modalService = getOwner(this).lookup("service:modal");
      const originalShow = modalService.show;
      let modalModel;

      modalService.show = (_component, { model } = {}) => {
        modalModel = model;
      };

      try {
        const [editor] = await setupRichEditor(assert, markdown);

        await click(".math-node-edit-button");

        assert.notStrictEqual(
          modalModel,
          undefined,
          "Opens the math edit modal"
        );

        modalModel.onApply("a^2 + b^2 = c^2");

        assert.strictEqual(
          editor.value,
          "Inline $a^2 + b^2 = c^2$ math.",
          "Markdown updates after editing math"
        );
      } finally {
        modalService.show = originalShow;
      }
    });
  }
);
