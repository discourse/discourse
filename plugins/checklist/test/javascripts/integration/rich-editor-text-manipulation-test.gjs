import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";
import richEditorExtension from "discourse/plugins/checklist/lib/rich-editor-extension";

module(
  "Integration | Component | ProsemirrorEditor | Checklist text manipulation",
  function (hooks) {
    setupRenderingTest(hooks);
    hooks.beforeEach(async function () {
      await resetRichEditorExtensions();
      registerRichEditorExtension(richEditorExtension);
    });

    for (const [name, markdown] of [
      ["paragraph", "**one**\n\ntwo"],
      ["line", "**one**\ntwo"],
    ]) {
      test(`applies a checklist prefix to each selected ${name}`, async function (assert) {
        let textManipulation;
        await setupRichEditor(assert, markdown, {
          onSetup: (value) => (textManipulation = value),
        });
        const { view } = textManipulation;
        textManipulation.selectText(1, view.state.doc.content.size - 2);
        textManipulation.applyList(
          textManipulation.getSelected(),
          "* [ ] ",
          "list_item",
          { multiline: true }
        );
        await settled();
        assert
          .dom(".ProseMirror li .chcklst-box")
          .exists({ count: 2 }, "each item has a checkbox");
        assert
          .dom(".ProseMirror li strong")
          .hasText("one", "formatting is retained");
        assert
          .dom(".ProseMirror li:last-child p")
          .hasText("two", "the second paragraph is retained");
      });
    }
  }
);
