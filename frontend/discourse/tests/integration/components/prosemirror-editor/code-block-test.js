import { triggerKeyEvent } from "@ember/test-helpers";
import { TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - code-block extension",
  function (hooks) {
    setupRenderingTest(hooks);

    const select = (lang = "") =>
      `<select contenteditable="false" class="code-language-select"><option>${lang}</option><option>javascript</option><option>ruby</option><option>sql</option></select>`;

    Object.entries({
      "basic code block": [
        "```plaintext\nconsole.log('Hello, world!');\n```",
        `<pre><code>console.log('Hello, world!');</code>${select(
          "plaintext"
        )}</pre>`,
        "```plaintext\nconsole.log('Hello, world!');\n```",
      ],
      "basic code block without a language": [
        "```\nconsole.log('Hello, world!');\n```",
        `<pre><code>console.log('Hello, world!');</code>${select()}</pre>`,
        "```\nconsole.log('Hello, world!');\n```",
      ],
      "code block within list item": [
        "- ```plaintext\n  console.log('Hello, world!');\n  ```",
        `<ul><li><pre><code>console.log('Hello, world!');</code>${select(
          "plaintext"
        )}</pre></li></ul>`,
        "* ```plaintext\n  console.log('Hello, world!');\n  ```",
      ],
      "code block with language": [
        '```javascript\nconsole.log("Hello, world!");\n```',
        `<pre><code><span class="hljs-variable language_">console</span>.<span class="hljs-title function_">log</span>(<span class="hljs-string">"Hello, world!"</span>);</code>${select()}</pre>`,
        '```javascript\nconsole.log("Hello, world!");\n```',
      ],
      "code block with 4 spaces": [
        "    print('Hello, world!')",
        `<pre><code>print('Hello, world!')</code>${select()}</pre>`,
        "```\nprint('Hello, world!')\n```",
      ],
      "code block with 4 spaces within list item": [
        "-     print('Hello, world!')",
        `<ul><li><pre><code>print('Hello, world!')</code>${select()}</pre></li></ul>`,
        "* ```\n  print('Hello, world!')\n  ```",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown, {
          multiToggle: true,
        });
      });
    });

    test("language selector options are alphabetically sorted", async function (assert) {
      await testMarkdown(
        assert,
        "```\nconsole.log('Hello, world!');\n```",
        () => {
          const options = [
            ...document.querySelectorAll(".code-language-select option"),
          ]
            .slice(1)
            .map((option) => option.textContent);

          assert.deepEqual(
            options,
            [...options].sort((a, b) => a.localeCompare(b))
          );
        },
        "```\nconsole.log('Hello, world!');\n```",
        { multiToggle: true }
      );
    });

    test("Tab indents selected code block lines with two spaces", async function (assert) {
      const markdown =
        '```csharp\n      this.board.acl = [\n        {\n          type: "group",\n        },\n      ];\n```';
      const [editor] = await setupRichEditor(assert, markdown);
      const { view } = editor;
      const codeBlock = view.state.doc.firstChild;

      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(view.state.doc, 7, codeBlock.content.size + 1)
        )
      );
      await triggerKeyEvent(".ProseMirror", "keydown", "Tab");

      assert.strictEqual(
        view.state.doc.firstChild.textContent,
        '        this.board.acl = [\n          {\n            type: "group",\n          },\n        ];',
        "all partially selected lines are indented"
      );
      assert.strictEqual(
        view.state.doc.textBetween(
          view.state.selection.from,
          view.state.selection.to
        ),
        'this.board.acl = [\n          {\n            type: "group",\n          },\n        ];',
        "the code remains selected after indenting"
      );
    });

    test("Shift-Tab removes up to two spaces from selected code block lines", async function (assert) {
      const markdown = "```\n  one\n two\nthree\n```";
      const [editor] = await setupRichEditor(assert, markdown);
      const { view } = editor;
      const codeBlock = view.state.doc.firstChild;

      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(view.state.doc, 1, codeBlock.content.size + 1)
        )
      );
      await triggerKeyEvent(".ProseMirror", "keydown", "Tab", {
        shiftKey: true,
      });

      assert.strictEqual(
        view.state.doc.firstChild.textContent,
        "one\ntwo\nthree",
        "each selected line is outdented as far as possible"
      );
    });

    test("Tab still nests list items", async function (assert) {
      const [editor] = await setupRichEditor(assert, "* first\n* second");
      const { view } = editor;

      view.dispatch(
        view.state.tr.setSelection(TextSelection.create(view.state.doc, 12))
      );
      await triggerKeyEvent(".ProseMirror", "keydown", "Tab");

      assert
        .dom(".ProseMirror > ul > li > ul > li")
        .hasText("second", "the second item is nested under the first");

      await triggerKeyEvent(".ProseMirror", "keydown", "Tab", {
        shiftKey: true,
      });

      assert
        .dom(".ProseMirror > ul > li")
        .exists({ count: 2 }, "Shift-Tab lifts the nested item");
    });
  }
);
