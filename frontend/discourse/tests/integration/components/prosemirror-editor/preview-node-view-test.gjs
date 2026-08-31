import Component from "@glimmer/component";
import { settled } from "@ember/test-helpers";
import { NodeSelection, TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import PreviewNodeView from "discourse/components/composer/preview-node-view";
import { previewNodeViewFor } from "discourse/lib/composer/preview-block";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { activePreviewBlock } from "discourse/static/prosemirror/extensions/preview-toolbar";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";

let renders;

class PreviewStub extends Component {
  get shown() {
    renders++;
    return this.args.source;
  }

  <template>
    <span class="preview-stub">{{this.shown}}</span>
  </template>
}

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
      options: { preview: PreviewStub },
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

  const tr = view.state.tr.replaceWith(0, view.state.doc.content.size, block);
  view.dispatch(tr.setSelection(NodeSelection.create(tr.doc, 0)));
  await settled();
}

// the toolbar is a float-kit menu, which does not mount in a rendering test —
// it is covered by a system spec, and this drives the seam its button acts on
async function toggleSource(view) {
  previewNodeViewFor(view.nodeDOM(0)).toggleSource();
  await settled();
}

module(
  "Integration | Component | prosemirror-editor - preview node view",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      renders = 0;
      await resetRichEditorExtensions();
      registerRichEditorExtension(extension);
    });

    test("shows the rendered source, and swaps faces on toggle", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "the source");

      assert.dom(".composer-preview-node").doesNotHaveClass("--source");
      assert.dom(".preview-stub").hasText("the source");

      await toggleSource(editorClass.view);
      assert.dom(".composer-preview-node").hasClass("--source");

      await toggleSource(editorClass.view);
      assert.dom(".composer-preview-node").doesNotHaveClass("--source");
    });

    test("puts the caret in the source when it is shown", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "abc");

      await toggleSource(editorClass.view);

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

    test("selects the block again when the source is hidden", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "abc");

      await toggleSource(editorClass.view);
      await toggleSource(editorClass.view);

      assert.strictEqual(
        editorClass.view.state.selection.node?.type.name,
        "test_preview",
        "the block is selected, so its toolbar stays up"
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

      await toggleSource(editorClass.view);

      const { view } = editorClass;
      view.dispatch(view.state.tr.insertText("-after", 2, 8));
      await settled();

      assert
        .dom(".preview-stub")
        .hasText("before", "the preview keeps the source it last rendered");

      await toggleSource(view);
      assert
        .dom(".preview-stub")
        .hasText("-after", "and catches up once the source is hidden again");
    });

    test("finds the block a selection acts on, so the toolbar follows it", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "the source");
      const { view } = editorClass;

      assert.strictEqual(
        activePreviewBlock(view.state)?.node.type.name,
        "test_preview",
        "the selected block"
      );

      await toggleSource(view);
      const inSource = activePreviewBlock(view.state);
      assert.strictEqual(
        inSource?.node.type.name,
        "test_preview",
        "the block whose source the caret is in, not the source itself"
      );
      assert.strictEqual(
        view.state.doc.nodeAt(inSource.pos)?.type.name,
        "test_preview",
        "at the block's own position"
      );

      view.dispatch(
        view.state.tr.setSelection(TextSelection.atEnd(view.state.doc))
      );
      await settled();

      assert.strictEqual(
        activePreviewBlock(view.state),
        null,
        "and nothing once the caret leaves"
      );
    });

    test("serializes the same source after the faces are swapped", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "the source");

      await toggleSource(editorClass.view);
      await toggleSource(editorClass.view);

      assert.strictEqual(
        editorClass.value.trim(),
        "[test]\nthe source\n[/test]",
        "swapping faces leaves the markdown untouched"
      );
    });

    test("does not render the preview again over an untouched source", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "the source");

      const before = renders;
      await toggleSource(editorClass.view);
      await toggleSource(editorClass.view);

      assert.strictEqual(
        renders,
        before,
        "swapping faces leaves the feature's render alone"
      );
    });

    test("renders again when the source changes under a shown preview", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      await insertBlock(editorClass.view, "before");

      const { view } = editorClass;
      view.dispatch(view.state.tr.insertText("-after", 2, 8));
      await settled();

      assert.dom(".preview-stub").hasText("-after", "the preview catches up");
    });
  }
);
