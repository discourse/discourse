import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";
import richEditorExtension from "discourse/plugins/footnote/lib/rich-editor-extension";

module(
  "Integration | Component | ProsemirrorEditor | Footnote text manipulation",
  function (hooks) {
    setupRenderingTest(hooks);
    hooks.beforeEach(async function () {
      await resetRichEditorExtensions();
      registerRichEditorExtension(richEditorExtension);
    });

    test("surrounds selected text with an editable footnote", async function (assert) {
      let textManipulation;
      const onSetup = (value) => {
        textManipulation = value;
      };
      await setupRichEditor(assert, "note", { onSetup });
      textManipulation.selectText(1, 4);
      textManipulation.applySurroundSelection("^[", "]", "wrap_text", {
        multiline: false,
      });
      await settled();
      assert.dom(".footnote").exists("a footnote is inserted");
      assert.strictEqual(
        textManipulation.view.state.selection.node?.type.name,
        "footnote",
        "the atomic node is selected to open its editor"
      );
      assert
        .dom(".footnote-tooltip .ProseMirror")
        .hasText("note", "the selected text can be edited in the footnote");
    });

    test("keeps text around an existing footnote selected after surrounding", async function (assert) {
      let textManipulation;
      const onSetup = (value) => {
        textManipulation = value;
      };
      await setupRichEditor(assert, "before ^[note] after", { onSetup });
      const { view } = textManipulation;
      textManipulation.selectText(1, view.state.doc.content.size - 2);
      textManipulation.applySurroundSelection(
        "<small>",
        "</small>",
        "wrap_text",
        {
          multiline: false,
        }
      );
      await settled();
      assert.strictEqual(
        view.state.doc
          .textBetween(view.state.selection.from, view.state.selection.to)
          .trimEnd(),
        "before note after",
        "the entire original content remains selected"
      );
      assert
        .dom(".footnote-tooltip")
        .doesNotExist(
          "formatting the range does not open the existing footnote"
        );
    });
  }
);
