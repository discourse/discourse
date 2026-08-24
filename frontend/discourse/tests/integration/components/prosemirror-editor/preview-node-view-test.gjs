import { click, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import PreviewNodeView from "discourse/components/composer/preview-node-view";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";

let ranControl;

const PreviewStub = <template>
  <span class="preview-stub">{{@source}}</span>
</template>;

const extension = {
  nodeSpec: {
    test_preview: {
      group: "block",
      content: "preview_source",
      atom: true,
      defining: true,
      isolating: true,
      selectable: true,
      parseDOM: [{ tag: "div.test-preview", preserveWhitespace: "full" }],
      toDOM: () => ["div", { class: "test-preview" }, 0],
    },
  },

  nodeViews: {
    test_preview: {
      component: PreviewNodeView,
      hasContent: true,
      options: {
        preview: PreviewStub,
        controls: [
          {
            icon: "gear",
            label: "Do the thing",
            action: () => (ranControl = true),
          },
        ],
      },
    },
  },

  serializeNode: {
    test_preview(state, node) {
      state.write("[test]\n");
      state.text(node.textContent, false);
      state.write("\n[/test]");
      state.closeBlock(node);
    },
  },
};

// the extension has no markdown rule, so blocks are inserted into the document
// directly rather than parsed out of the editor's initial value
async function insertBlock(view, source) {
  const { schema } = view.state;
  const block = schema.nodes.test_preview.createAndFill(
    null,
    source
      ? schema.nodes.preview_source.create(null, schema.text(source))
      : null
  );

  view.dispatch(
    view.state.tr.replaceWith(0, view.state.doc.content.size, block)
  );
  await settled();
}

module(
  "Integration | Component | prosemirror-editor - preview node view",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      ranControl = false;
      await resetRichEditorExtensions();
      registerRichEditorExtension(extension);
    });

    test("shows the rendered source, and swaps faces on toggle", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "the source");

      assert.dom(".composer-preview-node").doesNotHaveClass("--source");
      assert.dom(".preview-stub").hasText("the source");

      await click(".composer-preview-node__toggle");
      assert.dom(".composer-preview-node").hasClass("--source");

      await click(".composer-preview-node__toggle");
      assert.dom(".composer-preview-node").doesNotHaveClass("--source");
    });

    test("puts the caret in the source when it is shown", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "abc");

      await click(".composer-preview-node__toggle");

      const { selection } = editorClass.view.state;
      assert.strictEqual(
        selection.$head.parent.type.name,
        "preview_source",
        "the caret is inside the source"
      );
      assert.true(selection.empty, "nothing is selected");
      assert.strictEqual(
        selection.$head.parentOffset,
        3,
        "the caret is at the end of the source"
      );
    });

    test("starts on the source when there is nothing to preview yet", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "");

      assert.dom(".composer-preview-node").hasClass("--source");
    });

    test("holds the preview still while the source is edited", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "before");

      await click(".composer-preview-node__toggle");

      const { view } = editorClass;
      view.dispatch(view.state.tr.insertText("-after", 2, 8));
      await settled();

      assert
        .dom(".preview-stub")
        .hasText("before", "the preview keeps the source it last rendered");

      await click(".composer-preview-node__toggle");
      assert
        .dom(".preview-stub")
        .hasText("-after", "and catches up once the source is hidden again");
    });

    test("renders a contributed control and runs it", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "the source");

      assert.dom(".composer-preview-node__control").exists({ count: 2 });
      assert
        .dom(".composer-preview-node__controls .btn:first-child")
        .hasAttribute("title", "Do the thing");

      await click(".composer-preview-node__controls .btn:first-child");
      assert.true(ranControl, "the control's action ran");
    });
  }
);
