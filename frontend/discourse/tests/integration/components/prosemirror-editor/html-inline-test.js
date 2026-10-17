import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - html-inline extension",
  function (hooks) {
    setupRenderingTest(hooks);

    const outlined = (selector, title) => (assert) =>
      assert
        .dom(`.ProseMirror ${selector}`)
        .hasClass("composer-html-inline-node")
        .hasAttribute("title", title);

    Object.entries({
      "basic inline HTML tags": [
        "<kbd>Ctrl</kbd>",
        "<p><kbd>Ctrl</kbd> </p>",
        "<kbd>Ctrl</kbd> ",
      ],
      "nested inline HTML": [
        "<sup><small>text</small></sup>",
        "<p><sup><small>text</small></sup> </p>",
        "<sup><small>text</small></sup> ",
      ],
      "inline marks using HTML": [
        "<strong>bold</strong> and <em>italic</em>",
        "<p><strong>bold</strong> and <em>italic</em></p>",
        "**bold** and *italic*",
      ],
      "mixed HTML inline and marks": [
        "<kbd><strong>Ctrl+B</strong></kbd>",
        "<p><kbd><strong>Ctrl+B</strong></kbd> </p>",
        "<kbd>**Ctrl+B**</kbd> ",
      ],
      "multiple inline elements": [
        "Text with <sub>subscript</sub> and <sup>superscript</sup>",
        "<p>Text with <sub>subscript</sub> and <sup>superscript</sup> </p>",
        "Text with <sub>subscript</sub> and <sup>superscript</sup> ",
      ],
      "several blocks ending in inline HTML": [
        "a <sup>1</sup>\n\nb <mark>m</mark>\n\nc <del>d</del>",
        "<p>a <sup>1</sup> </p><p>b <mark>m</mark> </p><p>c <del>d</del> </p>",
        "a <sup>1</sup> \n\nb <mark>m</mark> \n\nc <del>d</del> ",
      ],
      "HTML mark aliases": [
        "<b>bold</b> and <i>italic</i>",
        "<p><strong>bold</strong> and <em>italic</em></p>",
        "**bold** and *italic*",
      ],
      "semantic HTML elements": [
        "<ins>inserted</ins> and <del>deleted</del>",
        "<p><ins>inserted</ins> and <del>deleted</del> </p>",
        "<ins>inserted</ins> and <del>deleted</del> ",
      ],
      "link HTML with href attribute": [
        '<a href="https://example.com">text</a>',
        '<p><a href="https://example.com">text</a></p>',
        "[text](https://example.com)",
      ],
      "link HTML with href and title": [
        '<a href="https://example.com" title="Title">x</a>',
        '<p><a href="https://example.com" title="Title">x</a></p>',
        '[x](https://example.com "Title")',
      ],
      "unmatched opening inline tag auto-closes": [
        "<kbd>x",
        "<p><kbd>x</kbd> </p>",
        "<kbd>x</kbd> ",
      ],
      "unmatched opening link tag auto-closes": [
        '<a href="https://example.com">x',
        '<p><a href="https://example.com">x</a></p>',
        "[x](https://example.com)",
      ],
      "image HTML with src, alt, width and height": [
        '<img src="https://example.com/image.png" alt="Alt text" width="100" height="200">',
        (assert) => {
          assert
            .dom("p img")
            .hasAttribute("src", "https://example.com/image.png");
          assert.dom("p img").hasAttribute("alt", "Alt text");
          assert.dom("p img").hasAttribute("width", "100");
          assert.dom("p img").hasAttribute("height", "200");
        },
        "![Alt text|100x200](https://example.com/image.png)",
      ],
      "image HTMl with text after": [
        '<img src="https://example.com/image.png" alt="Alt text"> after',
        (assert) => {
          assert
            .dom("p img")
            .hasAttribute("src", "https://example.com/image.png");
          assert.dom("p img").hasAttribute("alt", "Alt text");
          assert.dom("p").hasText("after");
        },
        "![Alt text](https://example.com/image.png) after",
      ],
      "ruby annotation round-trip": [
        "<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>",
        "<p><ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby> </p>",
        "<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby> ",
      ],
      "span with lang attribute": [
        '<span lang="ja">日本語</span>',
        outlined("span[lang]", '<span lang="ja">'),
        '<span lang="ja">日本語</span> ',
      ],
      "span with an empty data attribute": [
        "a <span data-fish>fishy</span> word",
        outlined("span[data-fish]", "<span data-fish>"),
        "a <span data-fish>fishy</span> word",
      ],
      "span with an explicitly empty attribute is written bare": [
        'a <span data-fish="">fishy</span> word',
        outlined("span[data-fish]", "<span data-fish>"),
        "a <span data-fish>fishy</span> word",
      ],
      "span without attributes": [
        "<span>plain</span>",
        outlined("span", "<span>"),
        "<span>plain</span> ",
      ],
      "span with a valued data attribute": [
        '<span data-mood="happy">text</span>',
        outlined("span[data-mood]", '<span data-mood="happy">'),
        '<span data-mood="happy">text</span> ',
      ],
      "br tag converts to hard break": [
        "Line1<br>Line2",
        "<p>Line1<br>Line2</p>",
        "Line1\nLine2",
      ],
      "self-closing br tag converts to hard break": [
        "Line1<br/>Line2",
        "<p>Line1<br>Line2</p>",
        "Line1\nLine2",
      ],
      "self-closing br tag with space converts to hard break": [
        "Line1<br />Line2",
        "<p>Line1<br>Line2</p>",
        "Line1\nLine2",
      ],
      "br tag with attributes converts to hard break": [
        'Line1<br class="x">Line2',
        "<p>Line1<br>Line2</p>",
        "Line1\nLine2",
      ],
      "list HTML inside a table cell": [
        "| Column 1 | Column 2 |\n|---|---|\n| An HTML-built list | <ul><li>line 1</li><li>line 2</li></ul> |\n",
        (assert) => {
          assert.dom("td ul li").exists({ count: 2 });
          assert.dom("td ul li:first-child").hasText("line 1");
        },
        "| Column 1 | Column 2 |\n|----|----|\n| An HTML-built list | <ul><li>line 1</li><li>line 2</li></ul>  |\n\n",
      ],
      "unclosed inline HTML does not swallow the next cell": [
        "| a | b |\n|---|---|\n| <ul><li>x | y |\n",
        (assert) => {
          assert.dom("tbody td").exists({ count: 2 });
          assert.dom("tbody td:first-child ul li").hasText("x");
          assert.dom("tbody td:last-child").hasText("y");
        },
        "| a | b |\n|----|----|\n| <ul><li>x</li></ul>  | y |\n\n",
      ],
      "stray closing tag is ignored": ["a</li>b", "<p>ab</p>", "ab"],
      "closing an outer tag closes the inner ones": [
        "<kbd><sup>x</kbd> y",
        "<p><kbd><sup>x</sup></kbd> y</p>",
        "<kbd><sup>x</sup></kbd> y",
      ],
      "anchor without href keeps its name and own title": [
        'see <a name="top" title="Top">here</a>',
        outlined("a[name]", "Top"),
        'see <a name="top" title="Top">here</a> ',
      ],
      "allow-listed tags and attributes inside a table round-trip": [
        '| a |\n|---|\n| <ol start="3"><li>c</li></ol> <div data-x="1" onclick="y()">d</div> <abbr title="T">e</abbr> <h2>f</h2> |\n',
        (assert) => {
          assert.dom("td ol").hasAttribute("start", "3");
          assert.dom("td div[data-x='1']").doesNotHaveAttribute("onclick");
          assert.dom("td abbr").hasAttribute("title", "T");
          assert.dom("td h2").hasText("f");
        },
        '| a |\n|----|\n| <ol start="3"><li>c</li></ol> <div data-x="1">d</div> <abbr title="T">e</abbr> <h2>f</h2>  |\n\n',
      ],
      "only tags with no look of their own are outlined": [
        "| a |\n|---|\n| <p>p</p> <div>d</div> <ul><li>l</li></ul> <kbd>k</kbd> |\n",
        (assert) => {
          assert.dom("td p").hasClass("composer-html-inline-node");
          assert.dom("td div").hasAttribute("title", "<div>");
          assert.dom("td ul").doesNotHaveClass("composer-html-inline-node");
          assert.dom("td li").doesNotHaveClass("composer-html-inline-node");
          assert.dom("td kbd").doesNotHaveClass("composer-html-inline-node");
        },
        "| a |\n|----|\n| <p>p</p> <div>d</div> <ul><li>l</li></ul> <kbd>k</kbd>  |\n\n",
      ],
      "mark tags keep being marks when they carry attributes": [
        '<strong class="x">bold</strong> <code class="lang-js">c</code>',
        "<p><strong>bold</strong> <code>c</code></p>",
        "**bold** `c`",
      ],
      "tags the cook strips, embedded media and block-level tags outside a table are dropped":
        [
          'a <blink>b</blink> <iframe src="https://example.com"></iframe> <div>c</div> <ul><li>d</li></ul> e',
          "<p>a b  c d e</p>",
          "a b  c d e",
        ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });

    test("a list pasted into a table cell stays inline HTML", async function (assert) {
      const [editor] = await setupRichEditor(assert, "");

      editor.view.pasteHTML(
        "<table><tbody><tr><td><ul><li>a</li><li>b</li></ul></td></tr></tbody></table>"
      );
      await settled();

      assert.dom(".ProseMirror table ul li").exists({ count: 2 });
      assert.true(editor.value.includes("| <ul><li>a</li><li>b</li></ul>"));
    });

    test("inline HTML inserted after load is outlined", async function (assert) {
      const [editor] = await setupRichEditor(assert, "a");
      const { state, dispatch } = editor.view;
      const span = state.schema.nodes.html_inline.create(
        { tag: "span" },
        state.schema.text("b")
      );

      dispatch(state.tr.insert(2, span));
      await settled();

      assert.dom(".ProseMirror span").hasClass("composer-html-inline-node");
    });

    test("pasted phrasing tags keep allow-listed attributes", async function (assert) {
      const [editor] = await setupRichEditor(assert, "");

      editor.view.pasteHTML(
        'x <abbr title="T">a</abbr> <kbd>k</kbd> <blink>b</blink>'
      );
      await settled();

      assert.strictEqual(
        editor.value,
        'x <abbr title="T">a</abbr> <kbd>k</kbd> b'
      );
    });
  }
);
