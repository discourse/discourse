import { getOwner } from "@ember/owner";
import { click } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - math extension",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders inline math and preserves markdown", async function (assert) {
      this.siteSettings.rich_editor = true;
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

    test("renders block math and preserves markdown", async function (assert) {
      this.siteSettings.rich_editor = true;
      this.siteSettings.discourse_math_enabled = true;

      const markdown = "$$\nE=mc^2\n$$";
      const expectedMarkdown = "$$\nE=mc^2\n$$\n\n";

      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.dom("div.composer-math-node").exists();
          assert
            .dom("div.composer-math-node .math-node-content")
            .hasText("E=mc^2");
        },
        expectedMarkdown
      );
    });

    test("edits math via modal", async function (assert) {
      this.siteSettings.rich_editor = true;
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
