import { render, click, waitFor, settled } from "@ember/test-helpers";
import { tracked } from "@glimmer/tracking";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DEditor from "discourse/components/d-editor";

module(
  "Integration | Component | prosemirror-editor - prosemirror-markdown defaults",
  function (hooks) {
    setupRenderingTest(hooks);

    // Paragraphs, hard breaks
    testMarkdown("Hello", "<p>Hello</p>", "Hello");
    testMarkdown("Hello\nWorld", "<p>Hello<br>World</p>", "Hello\nWorld");
    testMarkdown(
      "Hello\n\nWorld",
      "<p>Hello</p><p>World</p>",
      "Hello\n\nWorld"
    );

    // Blockquotes
    testMarkdown("> Hello", "<blockquote><p>Hello</p></blockquote>", "> Hello");
    testMarkdown(
      "> Hello\n> World",
      "<blockquote><p>Hello<br>World</p></blockquote>",
      "> Hello\n> World"
    );
    testMarkdown(
      "> Hello\n\n> World",
      "<blockquote><p>Hello</p></blockquote><blockquote><p>World</p></blockquote>",
      "> Hello\n\n> World"
    );

    // Horizontal rule
    testMarkdown(
      "Hey\n\n---",
      `<p>Hey</p><div contenteditable="false" draggable="true"><hr></div>`,
      "Hey\n\n---"
    );
    testMarkdown(
      "***",
      '<div contenteditable="false" draggable="true"><hr></div>',
      "---"
    );

    // Heading (level 1-6)
    testMarkdown("# Hello", "<h1>Hello</h1>", "# Hello");
    testMarkdown(
      "# Hello\nWorld",
      "<h1>Hello</h1><p>World</p>",
      "# Hello\n\nWorld"
    );
    testMarkdown("## Hello", "<h2>Hello</h2>", "## Hello");
    testMarkdown("### Hello", "<h3>Hello</h3>", "### Hello");
    testMarkdown("#### Hello", "<h4>Hello</h4>", "#### Hello");
    testMarkdown("##### Hello", "<h5>Hello</h5>", "##### Hello");
    testMarkdown("###### Hello", "<h6>Hello</h6>", "###### Hello");

    // Code block
    testMarkdown(
      "```\nHello\n```",
      "<pre><code>Hello</code></pre>",
      "```\nHello\n```"
    );
    testMarkdown(
      "```\nHello\nWorld\n```",
      "<pre><code>Hello\nWorld</code></pre>",
      "```\nHello\nWorld\n```"
    );
    testMarkdown(
      "```\nHello\n\nWorld\n```",
      "<pre><code>Hello\n\nWorld</code></pre>",
      "```\nHello\n\nWorld\n```"
    );
    testMarkdown(
      "```ruby\nHello\n```\n\nWorld",
      '<pre data-params="ruby"><code>Hello</code></pre><p>World</p>',
      "```ruby\nHello\n```\n\nWorld"
    );

    // Ordered lists
    testMarkdown(
      "1. Hello",
      `<ol data-tight="true"><li><p>Hello</p></li></ol>`,
      "1. Hello"
    );
    testMarkdown(
      "1. Hello\n2. World",
      `<ol data-tight="true"><li><p>Hello</p></li><li><p>World</p></li></ol>`,
      "1. Hello\n2. World"
    );
    testMarkdown(
      "5. Hello\n\n6. World",
      `<ol start="5"><li><p>Hello</p></li><li><p>World</p></li></ol>`,
      "5. Hello\n\n6. World"
    );

    // Bullet lists
    testMarkdown(
      "* Hello",
      '<ul data-tight="true"><li><p>Hello</p></li></ul>',
      "* Hello"
    );
    testMarkdown(
      "* Hello\n* World",
      '<ul data-tight="true"><li><p>Hello</p></li><li><p>World</p></li></ul>',
      "* Hello\n* World"
    );
    testMarkdown(
      "* Hello\n\n* World",
      "<ul><li><p>Hello</p></li><li><p>World</p></li></ul>",
      "* Hello\n\n* World"
    );

    // Images
    testMarkdown(
      "![alt](src)\nImage",
      '<p><img src="src" alt="alt" contenteditable="false" draggable="true"><br>Image</p>',
      "![alt](src)\nImage"
    );
    testMarkdown(
      '![alt](src "title")\n\nImage',
      '<p><img src="src" alt="alt" title="title" contenteditable="false" draggable="true"></p><p>Image</p>',
      '![alt](src "title")\n\nImage'
    );

    // Em
    testMarkdown("*Hello*", "<p><em>Hello</em></p>", "*Hello*");
    testMarkdown("_Hello_", "<p><em>Hello</em></p>", "*Hello*");

    // Strong
    testMarkdown("**Hello**", "<p><strong>Hello</strong></p>", "**Hello**");
    testMarkdown("__Hello__", "<p><strong>Hello</strong></p>", "**Hello**");

    // Link
    testMarkdown(
      "[text](href)",
      '<p><a href="href">text</a></p>',
      "[text](href)"
    );
    testMarkdown(
      '[text](href "title")',
      '<p><a href="href" title="title">text</a></p>',
      '[text](href "title")'
    );

    // Code
    testMarkdown(
      "Hel`lo wo`rld",
      "<p>Hel<code>lo wo</code>rld</p>",
      "Hel`lo wo`rld"
    );

    // All marks
    testMarkdown(
      "___[`Hello`](https://example.com)___",
      '<p><em><strong><a href="https://example.com"><code>Hello</code></a></strong></em></p>',
      "***[`Hello`](https://example.com)***"
    );
  }
);

function testMarkdown(markdown, expectedHtml, expectedMarkdown) {
  test(`updates editor value correctly: "${markdown}"`, async function (assert) {
    this.siteSettings.experimental_rich_editor = true;

    const self = new (class {
      @tracked value = markdown;
      @tracked view;
    })();
    const handleSetup = (textManipulation) => {
      self.view = textManipulation.view;
    };

    await render(<template>
      <DEditor
        @value={{self.value}}
        @processPreview={{false}}
        @onSetup={{handleSetup}}
      />
    </template>);
    await click(".composer-toggle-switch");

    await waitFor(".ProseMirror");
    await settled();
    const editor = document.querySelector(".ProseMirror");

    // typeIn for contentEditable isn't reliable, and is slower
    // insert a paragraph with "X" to enforce serialization
    self.view.dispatch(
      self.view.state.tr.insert(
        self.view.state.doc.content.size,
        self.view.state.schema.node(
          "paragraph",
          null,
          self.view.state.schema.text("X")
        )
      )
    );

    await settled();

    const html = editor.innerHTML
      // we don't care about some PM-specifics
      .replace(' class="ProseMirror-selectednode"', "")
      .replace('<img class="ProseMirror-separator" alt="">', "")
      .replace('<br class="ProseMirror-trailingBreak">', "")
      // or artifacts
      .replace('class=""', "");

    assert.strictEqual(
      html,
      `${expectedHtml}<p>X</p>`,
      `HTML should match for "${markdown}"`
    );
    assert.strictEqual(
      self.value,
      `${expectedMarkdown}\n\nX`,
      `Markdown should match for "${markdown}"`
    );
  });
}
