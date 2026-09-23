import { click, settled, triggerKeyEvent } from "@ember/test-helpers";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";

const title = (emoji, text) =>
  `<p class="callout__title" contenteditable="false"><img class="emoji" alt=":${emoji}:" title=":${emoji}:" src="/images/emoji/twitter/${emoji}.png?v=${v}"> ${text}</p>`;

async function typeMarker(view, pos, marker) {
  const tr = view.state.tr.insertText(marker.slice(0, -1), pos);
  const end = pos + marker.length - 1;
  view.dispatch(tr.setSelection(TextSelection.create(tr.doc, end)));
  view.someProp("handleTextInput", (f) => f(view, end, end, marker.at(-1)));
  await settled();
}

module(
  "Integration | Component | prosemirror-editor - callout extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "note callout": [
        "> [!NOTE]\n> Hello",
        `<div class="callout" data-callout-type="note">${title("information_source", "Note")}<div class="callout__content"><p>Hello</p></div></div>`,
        "> [!NOTE]\n> Hello",
      ],
      "callout with a custom emoji": [
        "> [!TIP emoji=heart]\n> Hello",
        `<div class="callout" data-callout-type="tip" data-callout-emoji="heart">${title("heart", "Tip")}<div class="callout__content"><p>Hello</p></div></div>`,
        "> [!TIP emoji=heart]\n> Hello",
      ],
      "lowercase marker": [
        "> [!warning]\n> Hello",
        `<div class="callout" data-callout-type="warning">${title("warning", "Warning")}<div class="callout__content"><p>Hello</p></div></div>`,
        "> [!WARNING]\n> Hello",
      ],
      "callout with several blocks": [
        "> [!CAUTION]\n>\n> First\n>\n> Second",
        `<div class="callout" data-callout-type="caution">${title("stop_sign", "Caution")}<div class="callout__content"><p>First</p><p>Second</p></div></div>`,
        "> [!CAUTION]\n> First\n>\n> Second",
      ],
      "nested callouts": [
        "> [!NOTE]\n> Outer\n>\n> > [!IMPORTANT]\n> > Inner",
        `<div class="callout" data-callout-type="note">${title("information_source", "Note")}<div class="callout__content"><p>Outer</p><div class="callout" data-callout-type="important">${title("exclamation", "Important")}<div class="callout__content"><p>Inner</p></div></div></div></div>`,
        "> [!NOTE]\n> Outer\n>\n> > [!IMPORTANT]\n> > Inner",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });

    test("typing a marker in a blockquote turns it into a callout", async function (assert) {
      const [editor] = await setupRichEditor(assert, "> Hello");

      await typeMarker(editor.view, 2, "[!TIP]");

      assert.dom(".callout").hasAttribute("data-callout-type", "tip");
      assert.dom("blockquote").doesNotExist("the blockquote is converted");
      assert.strictEqual(editor.value, "> [!TIP]\n> Hello");
    });

    test("typing a marker in a paragraph wraps it in a callout", async function (assert) {
      const [editor] = await setupRichEditor(assert, "Hello");

      await typeMarker(editor.view, 1, "[!NOTE emoji=fire]");

      assert.dom(".callout").hasAttribute("data-callout-emoji", "fire");
      assert.strictEqual(editor.value, "> [!NOTE emoji=fire]\n> Hello");
    });

    test("clicking the title selects the callout", async function (assert) {
      await setupRichEditor(assert, "> [!NOTE]\n> Hello");

      await click(".callout__title");

      assert
        .dom(".callout")
        .hasClass("ProseMirror-selectednode", "the callout is selected");

      await triggerKeyEvent(".ProseMirror", "keydown", "Backspace");

      assert.dom(".callout").doesNotExist("the selected callout is removed");
    });
  }
);
