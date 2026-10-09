import { settled } from "@ember/test-helpers";
import { TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - link extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "basic link": [
        "[Example](https://example.com)",
        '<p><a href="https://example.com">Example</a></p>',
        "[Example](https://example.com)",
      ],
      "link with title": [
        '[Example](https://example.com "Example Title")',
        '<p><a href="https://example.com" title="Example Title">Example</a></p>',
        '[Example](https://example.com "Example Title")',
      ],
      autolink: [
        "<https://example.com>",
        '<p><a href="https://example.com" data-markup="autolink">https://example.com</a></p>',
        "<https://example.com>",
      ],
      "auto links with ~": [
        "<https://example.com/~user> https://example.com/~user",
        '<p><a href="https://example.com/~user" data-markup="autolink">https://example.com/~user</a> <a href="https://example.com/~user" data-markup="linkify">https://example.com/~user</a></p>',
        "<https://example.com/~user> https://example.com/~user",
      ],
      "attachment link": [
        "[File|attachment](https://example.com/file.pdf)",
        '<p><a href="https://example.com/file.pdf" class="attachment">File</a></p>',
        "[File|attachment](https://example.com/file.pdf)",
      ],
      "attachment link with hash upload": [
        "[File|attachment](upload://some-hash)",
        '<p><a href="/404" class="attachment" data-orig-href="upload://some-hash">File</a></p>',
        "[File|attachment](upload://some-hash)",
      ],
      "link with anchor": [
        "[Docs](https://example.com/docs/#section)",
        '<p><a href="https://example.com/docs/#section">Docs</a></p>',
        "[Docs](https://example.com/docs/#section)",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });

    module("pasting rich content over a selection", function () {
      async function pasteOverWorld(assert, html) {
        const [editor] = await setupRichEditor(assert, "Hello world");
        const { view } = editor;
        view.dispatch(
          view.state.tr.setSelection(
            TextSelection.create(view.state.doc, 7, 12)
          )
        );
        view.pasteHTML(html);
        await settled();
        return editor;
      }

      test("a lone URL links the selection", async function (assert) {
        const editor = await pasteOverWorld(
          assert,
          "<span>https://discourse.org</span>"
        );

        assert.strictEqual(
          editor.value,
          "Hello [world](https://discourse.org)"
        );
      });

      test("text with a URL among other words replaces the selection", async function (assert) {
        const editor = await pasteOverWorld(
          assert,
          "<span>see https://discourse.org</span>"
        );

        assert.strictEqual(editor.value, "Hello see https://discourse.org");
      });
    });
  }
);
