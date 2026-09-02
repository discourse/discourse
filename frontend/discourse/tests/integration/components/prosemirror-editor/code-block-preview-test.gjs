import Component from "@glimmer/component";
import { settled, triggerEvent, triggerKeyEvent } from "@ember/test-helpers";
import { undo } from "prosemirror-history";
import { AllSelection, NodeSelection, TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import { previewNodeViewFor } from "discourse/components/composer/preview-node-view";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";

let previewRenders = 0;

class PreviewStub extends Component {
  constructor() {
    super(...arguments);
    previewRenders++;
  }

  <template>
    <span class="cb-preview-stub">{{@source}}</span>
  </template>
}

const extension = {
  codeBlockPreviews: { mermaid: PreviewStub },
};

const MARKDOWN = "before\n\n```mermaid height=500\nflowchart\n```\n\nafter";

function findCodeBlock(view) {
  let found;

  view.state.doc.descendants((node, pos) => {
    if (node.type.name === "code_block") {
      found = { node, pos };
      return false;
    }
  });

  return found;
}

async function toggleSource(view) {
  const { pos } = findCodeBlock(view);

  previewNodeViewFor(view.nodeDOM(pos)).toggleSource();
  await settled();
}

// PM resolves clicks through posAtCoords, so the synthetic events must carry
// the element's real coordinates
async function clickAt(element) {
  const rect = element.getBoundingClientRect();
  const coords = {
    button: 0,
    clientX: rect.left + rect.width / 2,
    clientY: rect.top + rect.height / 2,
  };

  await triggerEvent(element, "mousedown", coords);
  await triggerEvent(element, "mouseup", coords);
  await triggerEvent(element, "click", coords);
}

module(
  "Integration | Component | prosemirror-editor - code block preview",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      previewRenders = 0;
      await resetRichEditorExtensions();
      registerRichEditorExtension(extension);
    });

    hooks.afterEach(async function () {
      // the registration is global: leaking it would add the language to
      // other modules' selectors
      await resetRichEditorExtensions();
    });

    test("renders the registered preview in place of the code", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, MARKDOWN);

      assert
        .dom(".composer-code-block-preview-node .cb-preview-stub")
        .hasText("flowchart");
      assert
        .dom(".composer-code-block-preview-node")
        .hasClass("composer-preview-node", "reuses the preview block frame");
      assert
        .dom(".composer-code-block-preview-node pre")
        .doesNotExist("the code face is not in the DOM while previewing");

      const { pos } = findCodeBlock(editorClass.view);
      assert.strictEqual(
        editorClass.view.nodeDOM(pos).contentEditable,
        "false",
        "the block is not editable while previewing"
      );

      assert.strictEqual(
        editorClass.value,
        MARKDOWN,
        "the info string round-trips byte-identically"
      );
    });

    test("leaves unregistered languages untouched", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "```ruby\nputs 1\n```"
      );

      assert.dom(".composer-code-block-preview-node").doesNotExist();
      assert.dom(".cb-preview-stub").doesNotExist();
      assert.dom("pre code").hasText("puts 1");
      assert.dom("pre .code-language-select").exists();
      assert.strictEqual(editorClass.value, "```ruby\nputs 1\n```");
    });

    test("flips to the code face and back without re-rendering per keystroke", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, MARKDOWN);
      const { view } = editorClass;

      const initialRenders = previewRenders;

      await toggleSource(view);

      assert.dom(".cb-preview-stub").doesNotExist("the preview is put away");
      assert.dom("pre.--source code").hasText("flowchart");

      const { node, pos } = findCodeBlock(view);
      assert.true(
        view.state.selection instanceof TextSelection,
        "the caret is a text selection"
      );
      assert.strictEqual(
        view.state.selection.$head.parent,
        node,
        "inside the code"
      );
      assert.strictEqual(
        view.state.selection.$head.parentOffset,
        node.content.size,
        "at its end"
      );

      // type into the code face
      view.dispatch(
        view.state.tr.insertText(" xy", pos + 1 + node.content.size)
      );
      await settled();

      assert.strictEqual(
        previewRenders,
        initialRenders,
        "typing does not render the preview"
      );

      await toggleSource(view);

      assert.dom(".cb-preview-stub").hasText("flowchart xy");
      assert.strictEqual(
        previewRenders,
        initialRenders + 1,
        "showing the preview again renders it once"
      );
      assert.true(
        view.state.selection instanceof NodeSelection,
        "the block is selected, so its toolbar stays up"
      );
      assert.strictEqual(
        editorClass.value,
        "before\n\n```mermaid height=500\nflowchart xy\n```\n\nafter"
      );
    });

    test("a text selection cannot stay inside a previewing block", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, MARKDOWN);
      const { view } = editorClass;
      const { pos } = findCodeBlock(view);

      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(view.state.doc, pos + 3)
        )
      );
      await settled();

      const { selection } = view.state;
      assert.true(
        selection instanceof NodeSelection,
        "becomes a node selection"
      );
      assert.strictEqual(selection.from, pos, "of the block itself");
    });

    test("backspace after the block selects it instead of merging", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, MARKDOWN);
      const { view } = editorClass;
      const { node, pos } = findCodeBlock(view);

      // start of the "after" paragraph
      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(view.state.doc, pos + node.nodeSize + 1)
        )
      );
      await settled();

      await triggerKeyEvent(".ProseMirror", "keydown", "Backspace");

      assert.true(view.state.selection instanceof NodeSelection);
      assert.strictEqual(view.state.selection.from, pos);
      assert.strictEqual(editorClass.value, MARKDOWN, "nothing merged");
    });

    test("delete before the block selects it instead of merging", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, MARKDOWN);
      const { view } = editorClass;
      const { pos } = findCodeBlock(view);

      // end of the "before" paragraph
      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(view.state.doc, pos - 1)
        )
      );
      await settled();

      await triggerKeyEvent(".ProseMirror", "keydown", "Delete");

      assert.true(view.state.selection instanceof NodeSelection);
      assert.strictEqual(view.state.selection.from, pos);
      assert.strictEqual(editorClass.value, MARKDOWN, "nothing merged");
    });

    test("select-all removes the block, and undo brings the preview back", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, MARKDOWN);
      const { view } = editorClass;

      view.dispatch(
        view.state.tr.setSelection(new AllSelection(view.state.doc))
      );
      view.dispatch(view.state.tr.deleteSelection());
      await settled();

      assert.dom(".cb-preview-stub").doesNotExist();
      assert.strictEqual(findCodeBlock(view), undefined);

      undo(view.state, view.dispatch);
      await settled();

      assert.dom(".cb-preview-stub").hasText("flowchart");
      assert.strictEqual(editorClass.value, MARKDOWN);
    });

    test("switching the language away drops the preview, and back picks it up", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, MARKDOWN);
      const { view } = editorClass;
      const { pos } = findCodeBlock(view);

      view.dispatch(
        view.state.tr.setNodeMarkup(pos, null, { params: "javascript" })
      );
      await settled();

      assert.dom(".cb-preview-stub").doesNotExist();
      assert.dom("pre code").hasText("flowchart", "a plain code block again");
      assert.strictEqual(
        editorClass.value,
        "before\n\n```javascript\nflowchart\n```\n\nafter"
      );

      view.dispatch(
        view.state.tr.setNodeMarkup(pos, null, { params: "mermaid" })
      );
      await settled();

      assert.dom(".cb-preview-stub").hasText("flowchart");
      assert.strictEqual(
        editorClass.value,
        "before\n\n```mermaid\nflowchart\n```\n\nafter"
      );
    });

    test("picking a previewed language in the selector keeps the code face", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "```ruby\nflowchart\n```"
      );
      const { view } = editorClass;

      const select = document.querySelector(".code-language-select");
      select.value = "mermaid";
      await triggerEvent(select, "change");

      assert
        .dom("pre.--source code")
        .hasText("flowchart", "still on the code face");
      assert.dom(".cb-preview-stub").doesNotExist();
      assert.strictEqual(editorClass.value, "```mermaid\nflowchart\n```");

      await toggleSource(view);

      assert.dom(".cb-preview-stub").hasText("flowchart");
    });

    test("clicking the preview face selects the block, clicking the code face places the caret", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, MARKDOWN);
      const { view } = editorClass;
      const { node, pos } = findCodeBlock(view);

      await clickAt(document.querySelector(".composer-preview-node__preview"));

      assert.true(
        view.state.selection instanceof NodeSelection,
        "the block is node-selected, so its toolbar can show"
      );
      assert.strictEqual(view.state.selection.from, pos);

      await toggleSource(view);
      await clickAt(document.querySelector("pre.--source code"));

      assert.true(
        view.state.selection instanceof TextSelection,
        "the code face takes a caret"
      );
      assert.strictEqual(
        view.state.selection.$head.parent,
        view.state.doc.nodeAt(pos),
        "inside the block"
      );
      assert.strictEqual(node.attrs.params, "mermaid height=500");
    });

    test("foreign DOM mounted into the code face is left alone", async function (assert) {
      // the preview toolbar portals into the block's dom; reading that
      // mutation back into the document looped redraw against re-portal
      // until the editor hung
      const [editorClass] = await setupRichEditor(assert, MARKDOWN);
      const { view } = editorClass;

      await toggleSource(view);

      const pre = document.querySelector("pre.--source");
      const portal = document.createElement("div");
      portal.className = "fake-toolbar";
      portal.textContent = "portaled toolbar";
      pre.appendChild(portal);

      await settled();
      await new Promise((resolve) => setTimeout(resolve, 50));

      assert
        .dom("pre.--source .fake-toolbar")
        .exists("the mounted element is not torn down by a redraw");
      assert.strictEqual(
        editorClass.value,
        MARKDOWN,
        "and nothing leaks into the document"
      );

      portal.remove();
      await settled();
    });

    test("switching an empty block to a previewed language keeps a working code face", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "```ruby\nx\n```");
      const { view } = editorClass;
      const { node, pos } = findCodeBlock(view);

      // empty the block with the caret inside, like a user clearing it
      const emptying = view.state.tr.delete(
        pos + 1,
        pos + 1 + node.content.size
      );
      emptying.setSelection(TextSelection.create(emptying.doc, pos + 1));
      view.dispatch(emptying);
      await settled();

      const select = document.querySelector(".code-language-select");
      select.value = "mermaid";
      await triggerEvent(select, "change");

      assert.dom("pre code").exists("still on the code face");
      assert.dom(".cb-preview-stub").doesNotExist();

      view.dispatch(view.state.tr.insertText("flowchart", pos + 1));
      await settled();

      assert
        .dom("pre code")
        .hasText("flowchart", "typing lands in the block and does not flip it");
      assert.strictEqual(editorClass.value, "```mermaid\nflowchart\n```");

      await toggleSource(view);
      assert.dom(".cb-preview-stub").hasText("flowchart");
    });

    test("arrow keys select a previewing block instead of stalling at it", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, MARKDOWN);
      const { view } = editorClass;
      const { pos } = findCodeBlock(view);

      const isBlockSelected = () =>
        view.state.selection instanceof NodeSelection &&
        view.state.selection.from === pos;

      // ArrowDown from anywhere on the last line of the paragraph above
      view.dispatch(
        view.state.tr.setSelection(TextSelection.create(view.state.doc, 2))
      );
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowDown");
      assert.true(isBlockSelected(), "ArrowDown selects the block");

      // ArrowUp from the paragraph below
      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(
            view.state.doc,
            pos + view.state.doc.nodeAt(pos).nodeSize + 2
          )
        )
      );
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowUp");
      assert.true(isBlockSelected(), "ArrowUp selects the block");

      // ArrowRight from the end of the paragraph above
      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(view.state.doc, pos - 1)
        )
      );
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowRight");
      assert.true(isBlockSelected(), "ArrowRight selects the block");

      // ArrowLeft from the start of the paragraph below
      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(
            view.state.doc,
            pos + view.state.doc.nodeAt(pos).nodeSize + 1
          )
        )
      );
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowLeft");
      assert.true(isBlockSelected(), "ArrowLeft selects the block");
    });

    test("arrow keys are untouched next to a plain code block", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "before\n\n```ruby\nx\n```"
      );
      const { view } = editorClass;

      view.dispatch(
        view.state.tr.setSelection(TextSelection.create(view.state.doc, 2))
      );
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowDown");

      assert.false(
        view.state.selection instanceof NodeSelection,
        "no node selection is forced"
      );
    });

    test("an empty block starts on its code face and stays while typing", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      const { view } = editorClass;
      const { schema } = view.state;

      const block = schema.nodes.code_block.create({ params: "mermaid" });
      view.dispatch(
        view.state.tr.replaceWith(0, view.state.doc.content.size, block)
      );
      await settled();

      assert.dom(".cb-preview-stub").doesNotExist();
      assert.dom("pre code").exists("the code face is shown");

      const { pos } = findCodeBlock(view);
      view.dispatch(view.state.tr.insertText("flowchart", pos + 1));
      await settled();

      assert
        .dom("pre code")
        .hasText("flowchart", "typing does not flip the block");
      assert.dom(".cb-preview-stub").doesNotExist();

      await toggleSource(view);

      assert.dom(".cb-preview-stub").hasText("flowchart");
    });
  }
);
