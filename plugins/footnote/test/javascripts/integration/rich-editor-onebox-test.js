import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";
import richEditorExtension from "discourse/plugins/footnote/lib/rich-editor-extension";

const URL = "http://www.example.com/has-title.html";
const OTHER_URL = "http://www.example.com/no-title.html";

function inlineOneboxTitles(doc) {
  const titles = [];
  doc.descendants((node) => {
    if (node.type.name === "onebox_inline") {
      titles.push(node.attrs.title);
    }
  });
  return titles;
}

async function setupEditorWithFootnoteLink(assert) {
  let textManipulation;
  await setupRichEditor(assert, `note^[${URL}]\n\n${OTHER_URL}\n\nb`, {
    onSetup: (value) => (textManipulation = value),
  });
  const { view } = textManipulation;

  textManipulation.selectText(view.state.doc.content.size - 1, 0);
  await settled();

  return view;
}

module(
  "Integration | Component | ProsemirrorEditor | Footnote oneboxes",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      await resetRichEditorExtensions();
      registerRichEditorExtension(richEditorExtension);
    });

    test("counts footnote links after the main body for max_oneboxes_per_post", async function (assert) {
      this.siteSettings.max_oneboxes_per_post = 1;

      const view = await setupEditorWithFootnoteLink(assert);

      assert.dom(".onebox-wrapper").exists({ count: 1 });
      assert.dom(".onebox-wrapper").hasText("No title");
      assert.deepEqual(inlineOneboxTitles(view.state.doc), []);
    });

    test("previews footnote links within max_oneboxes_per_post", async function (assert) {
      this.siteSettings.max_oneboxes_per_post = 2;

      const view = await setupEditorWithFootnoteLink(assert);

      assert.dom(".onebox-wrapper").hasText("No title");
      assert.deepEqual(inlineOneboxTitles(view.state.doc), [
        "This is a great title",
      ]);
    });
  }
);
