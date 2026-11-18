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

    test("preserves block math nested in a blockquote", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      // the closing fence has to keep the "> " prefix, or the reparse swallows
      // it into the math and leaves a stray empty block behind
      const markdown = "> $$\n> E=mc^2\n> $$";

      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.dom("blockquote .composer-preview-node").exists();
        },
        markdown
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

    test("keeps the indentation of the first line of block math", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const markdown = "$$\n  \\begin{x}\n  a\n  \\end{x}\n$$";
      await testMarkdown(assert, markdown, () => {}, markdown);
    });

    test("pastes the source of block math rendered by KaTeX", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const [editorClass] = await setupRichEditor(assert, "");
      editorClass.view.pasteHTML(
        `<div class="math math-container block-math katex-math" data-math-original="E=mc^2"><span class="katex"><span class="katex-mathml"><math><semantics><mi>E</mi><annotation encoding="application/x-tex">E=mc^2</annotation></semantics></math></span><span class="katex-html" aria-hidden="true">E=mc2</span></span></div>`
      );
      await settled();

      assert.strictEqual(editorClass.value.trim(), "$$\nE=mc^2\n$$");
    });

    test("pastes the source of inline math rendered by KaTeX", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const [editorClass] = await setupRichEditor(assert, "");
      editorClass.view.pasteHTML(
        `<p>x <span class="math math-container inline-math katex-math" data-math-original="E=mc^2"><span class="katex"><span class="katex-html" aria-hidden="true">E=mc2</span></span></span> y</p>`
      );
      await settled();

      assert.strictEqual(editorClass.value.trim(), "x $E=mc^2$ y");
    });

    test("pastes math rendered by MathJax without its rendered output", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const [editorClass] = await setupRichEditor(assert, "");
      editorClass.view.pasteHTML(
        `<div class="math" hidden>E=mc^2</div><div class="math-container block-math mathjax-math"><mjx-container>E=mc2</mjx-container></div><p>x <span class="math" hidden>a</span><span class="math-container inline-math mathjax-math"><mjx-container>a</mjx-container></span> y</p>`
      );
      await settled();

      assert.strictEqual(editorClass.value.trim(), "$$\nE=mc^2\n$$\n\nx $a$ y");
    });

    test("preserves multi-line block math nested in a list", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const markdown = "* $$\n  a\n    b\n  $$";
      const [editorClass] = await setupRichEditor(assert, markdown);

      assert.strictEqual(editorClass.value, markdown);
      assert.strictEqual(
        editorClass.view.state.doc.textContent,
        "a\n  b",
        "the source has no list indent"
      );
    });

    test("preserves multi-line block math nested in a blockquote", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const markdown = "> $$\n> a\n> b\n> $$";
      const [editorClass] = await setupRichEditor(assert, markdown);

      assert.strictEqual(editorClass.value, markdown);
      assert.strictEqual(
        editorClass.view.state.doc.textContent,
        "a\nb",
        "the source has no quote markers"
      );
    });

    test("keeps dollar signs in block math as written", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      await testMarkdown(
        assert,
        "$$\n\\text{if $x>0$}\n$$",
        () => {},
        "$$\n\\text{if $x>0$}\n$$"
      );
    });

    test("escapes a source line that would close the block", async function (assert) {
      this.siteSettings.discourse_math_enabled = true;

      const [editorClass] = await setupRichEditor(assert, BLOCK_MARKDOWN);
      const { view } = editorClass;

      await toggleSource(view);
      view.dispatch(
        view.state.tr.insertText("\n  $$ ", view.state.selection.from)
      );
      await settled();

      assert.strictEqual(editorClass.value, "$$\nE=mc^2\n  \\$\\$ \n$$");
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
