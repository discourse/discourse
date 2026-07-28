import { settled } from "@ember/test-helpers";
import { setLocalCache } from "pretty-text/oneboxer-cache";
import { NodeSelection, TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import { buildEngine } from "discourse/static/markdown-it";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";

// Mocked by create-pretender for both /inline-onebox and /onebox.
const URL = "http://www.example.com/has-title.html";

function lastParagraphStart(doc) {
  let pos = null;
  doc.descendants((node, nodePos) => {
    if (node.type.name === "paragraph") {
      pos = nodePos + 1;
    }
  });
  return pos;
}

function moveCursorTo(view, pos) {
  view.dispatch(
    view.state.tr.setSelection(TextSelection.create(view.state.doc, pos))
  );
}

module(
  "Integration | Component | prosemirror-editor - onebox extension",
  function (hooks) {
    setupRenderingTest(hooks);

    // Oneboxes are parsed as links with "linkify" markup
    test("onebox can be omitted as a markdown-it feature", async function (assert) {
      const testUrl = "https://www.example.com";
      const cachedOneboxHtml = '<aside class="onebox">onebox</aside>';

      const cachedElement = document.createElement("div");
      cachedElement.innerHTML = cachedOneboxHtml;
      setLocalCache(testUrl, cachedElement);

      const markdownIt = buildEngine(null, ["onebox"]);
      const cookedHtml = markdownIt.cook(testUrl);

      assert.true(
        cookedHtml.includes(`<a href="${testUrl}">${testUrl}</a>`),
        "URL should render as plain link when onebox is omitted"
      );

      setLocalCache(testUrl, null);
    });

    test("holds a lone link inline while the cursor is on its line", async function (assert) {
      const [editor] = await setupRichEditor(assert, "a\n\nb");
      const { view } = editor;

      // Replace the first paragraph's "a" with the URL + a trailing space, and
      // put the cursor right after the space (still on the same line).
      const text = `${URL} `;
      const tr = view.state.tr.insertText(text, 1, 2);
      tr.setSelection(TextSelection.create(tr.doc, 1 + text.length));
      view.dispatch(tr);
      await settled();

      assert.dom("a.inline-onebox").exists("renders an inline onebox");
      assert
        .dom(".onebox-wrapper")
        .doesNotExist("does not render a full onebox yet");
    });

    test("promotes a lone inline onebox to a full onebox when the cursor leaves its line", async function (assert) {
      const [editor] = await setupRichEditor(assert, "a\n\nb");
      const { view } = editor;

      const text = `${URL} `;
      const tr = view.state.tr.insertText(text, 1, 2);
      tr.setSelection(TextSelection.create(tr.doc, 1 + text.length));
      view.dispatch(tr);
      await settled();
      assert.dom("a.inline-onebox").exists("starts as an inline onebox");

      // Move the cursor into the second paragraph.
      moveCursorTo(view, lastParagraphStart(view.state.doc));
      await settled();

      assert.dom(".onebox-wrapper").exists("promotes to a full onebox");
      assert
        .dom("a.inline-onebox")
        .doesNotExist("is no longer an inline onebox");
      assert.strictEqual(
        editor.value,
        `${URL}\n\nb`,
        "serializes the full onebox on its own line, matching the cooked output"
      );
    });

    // Top-level URLs never become inline oneboxes, so they reach the full
    // onebox via the scan with their trailing space still present. The full
    // onebox is a block node, so it must replace the whole paragraph rather
    // than split it and leave an empty paragraph behind.
    test("a top-level URL alone on its line becomes a full onebox with no empty paragraph before it", async function (assert) {
      const topLevelUrl = "http://www.example.com";
      pretender.get("/onebox", () => [
        200,
        { "Content-Type": "text/html" },
        '<aside class="onebox"><article class="onebox-body"><h3><a href="http://www.example.com">Example</a></h3></article></aside>',
      ]);

      const [editor] = await setupRichEditor(assert, "x");
      const { view } = editor;

      // Type the URL + trailing space (held as a plain link while editing)...
      view.dispatch(view.state.tr.insertText(`${topLevelUrl} `, 1, 2));
      await settled();
      assert
        .dom(".onebox-wrapper")
        .doesNotExist("stays a plain link while the cursor is on the line");

      // ...then press Enter, which promotes it to a full onebox.
      view.dispatch(view.state.tr.split(view.state.selection.from));
      await settled();

      assert.dom(".onebox-wrapper").exists("becomes a full onebox");
      assert.strictEqual(
        view.state.doc.firstChild.type.name,
        "onebox",
        "the onebox is the first node — no empty paragraph before it"
      );
    });

    // A URL alone on a line within a multi-line paragraph (a hard break, e.g.
    // shift+enter) must split into a clean block onebox plus a paragraph for the
    // following line — not a stray empty paragraph wrapping the block.
    test("a URL followed by a hard break and text splits into onebox + paragraph", async function (assert) {
      const [editor] = await setupRichEditor(assert, "x");
      const { view } = editor;
      const { schema } = view.state;

      // Build "URL<hard break>asd" with the cursor after the break.
      const linkMark = schema.marks.link.create({
        href: URL,
        markup: "linkify",
      });
      const tr = view.state.tr.replaceWith(1, 2, [
        schema.text(URL, [linkMark]),
        schema.nodes.hard_break.create(),
        schema.text("asd"),
      ]);
      tr.setSelection(TextSelection.create(tr.doc, 1 + URL.length + 1));
      view.dispatch(tr);
      await settled();

      assert.dom(".onebox-wrapper").exists("becomes a full onebox");
      assert.strictEqual(
        view.state.doc.firstChild.type.name,
        "onebox",
        "the onebox is the first node — no empty paragraph before it"
      );
      assert.strictEqual(
        editor.value,
        `${URL}\n\nasd`,
        "the trailing line becomes its own paragraph"
      );
      assert.false(
        view.state.selection instanceof NodeSelection,
        "the cursor lands after the onebox, not selecting the block"
      );
    });
  }
);
