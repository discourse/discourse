import { click, settled } from "@ember/test-helpers";
import { setLocalCache } from "pretty-text/oneboxer-cache";
import { EditorState, NodeSelection, TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import { buildEngine } from "discourse/static/markdown-it";
import { oneboxPluginKey } from "discourse/static/prosemirror/extensions/onebox";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";

// Mocked by create-pretender for both /inline-onebox and /onebox.
const URL = "http://www.example.com/has-title.html";
const OTHER_URL = "http://www.example.com/no-title.html";
const ONEBOX_SCAN_WAIT_MS = 300;

function lastParagraphStart(doc) {
  let pos = null;
  doc.descendants((node, nodePos) => {
    if (node.type.name === "paragraph") {
      pos = nodePos + 1;
    }
  });
  return pos;
}

function waitForOneboxScan() {
  return new Promise((resolve) => setTimeout(resolve, ONEBOX_SCAN_WAIT_MS));
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

    test("respects max_oneboxes_per_post site setting", async function (assert) {
      this.siteSettings.max_oneboxes_per_post = 0;

      const [editor] = await setupRichEditor(assert, "a\n\nb");
      const { view } = editor;

      view.dispatch(view.state.tr.insertText(URL, 1, 2));
      moveCursorTo(view, lastParagraphStart(view.state.doc));
      await settled();

      assert.dom(".onebox-wrapper").doesNotExist("does not render a onebox");
      assert
        .dom("a.inline-onebox")
        .doesNotExist("does not render an inline onebox");
    });

    test("each copy of a repeated onebox takes a slot", async function (assert) {
      this.siteSettings.max_oneboxes_per_post = 1;

      const [editor] = await setupRichEditor(assert, `${URL}\n\n${URL}\n\nb`);

      moveCursorTo(editor.view, lastParagraphStart(editor.view.state.doc));
      await settled();

      assert.dom(".onebox-wrapper").exists({ count: 1 });
      assert.dom(`a[href="${URL}"]`).hasText(URL);
    });

    test("demotes a onebox pushed past max_oneboxes_per_post by an earlier link", async function (assert) {
      this.siteSettings.max_oneboxes_per_post = 1;

      const [editor] = await setupRichEditor(assert, `a\n\n${OTHER_URL}\n\nb`);
      const { view } = editor;

      moveCursorTo(view, lastParagraphStart(view.state.doc));
      await settled();
      assert.dom(".onebox-wrapper").hasText("No title");

      const tr = view.state.tr.insertText(URL, 1, 2);
      tr.setSelection(TextSelection.atEnd(tr.doc));
      view.dispatch(tr);
      await settled();

      assert.dom(".onebox-wrapper").exists({ count: 1 });
      assert.dom(".onebox-wrapper").includesText("An interesting article");
      assert.dom(`a[href="${OTHER_URL}"]`).hasText(OTHER_URL);
      assert.strictEqual(editor.value, `${URL}\n\n${OTHER_URL}\n\nb`);
    });

    test("links that never cook to a onebox do not take a slot", async function (assert) {
      this.siteSettings.max_oneboxes_per_post = 1;

      const [editor] = await setupRichEditor(
        assert,
        `# http://www.example.com\n\nfoo@example.com\n\n${URL}\n\nb`
      );

      moveCursorTo(editor.view, lastParagraphStart(editor.view.state.doc));
      await settled();

      assert.dom(".onebox-wrapper").exists({ count: 1 });
      assert.dom(".onebox-wrapper").includesText("An interesting article");
    });

    test("keeps marks when demoting an inline onebox", async function (assert) {
      this.siteSettings.max_oneboxes_per_post = 0;

      const [editor] = await setupRichEditor(assert, "see x here");
      const { view } = editor;
      const { schema } = view.state;

      view.dispatch(
        view.state.tr.replaceWith(5, 6, [
          schema.nodes.onebox_inline.create(
            { url: URL, title: "Title" },
            null,
            [schema.marks.strong.create()]
          ),
        ])
      );
      await settled();

      assert.dom("a.inline-onebox").doesNotExist();
      assert.strictEqual(editor.value, `see **${URL}** here`);
    });

    test("show preview past max_oneboxes_per_post keeps the link and shows a toast", async function (assert) {
      this.siteSettings.max_oneboxes_per_post = 0;
      const toasts = this.owner.lookup("service:toasts");

      const [editor] = await setupRichEditor(assert, `a\n\n<${URL}>`, {
        withMenus: true,
      });
      moveCursorTo(editor.view, lastParagraphStart(editor.view.state.doc) + 5);
      await settled();

      await click(".composer-link-toolbar__show-preview");

      assert.dom(".onebox-wrapper").doesNotExist();
      assert.strictEqual(editor.value, `a\n\n<${URL}>`);
      assert.strictEqual(toasts.activeToasts.length, 1);
    });

    test("renders an inline onebox when the cursor moves while it loads", async function (assert) {
      const { promise: gate, resolve: release } = Promise.withResolvers();
      pretender.get("/inline-onebox", async (request) => {
        await gate;
        return [
          200,
          { "Content-Type": "application/json" },
          {
            "inline-oneboxes": request.queryParams.urls.map((url) => ({
              url,
              title: "Loaded title",
            })),
          },
        ];
      });

      const url = "http://www.example.com/loads-slowly.html";
      const [editor] = await setupRichEditor(assert, "see x here\n\nb");
      const { view } = editor;

      const tr = view.state.tr.insertText(url, 5, 6);
      tr.setSelection(TextSelection.atEnd(tr.doc));
      view.dispatch(tr);
      await waitForOneboxScan();

      moveCursorTo(view, 2);
      await waitForOneboxScan();

      release();
      await settled();

      assert.dom("a.inline-onebox").hasText("Loaded title");
    });

    test("saves an inline onebox URL unescaped", async function (assert) {
      const url = "http://www.example.com/~user/has-title.html";
      const [editor] = await setupRichEditor(assert, "see x here");
      const { view } = editor;

      view.dispatch(
        view.state.tr.replaceWith(
          5,
          6,
          view.state.schema.nodes.onebox_inline.create({ url, title: "Title" })
        )
      );
      await settled();

      assert.strictEqual(editor.value, `see ${url} here`);
    });

    test("saves the bracket after a bare link unescaped", async function (assert) {
      pretender.get("/inline-onebox", () => [
        200,
        { "Content-Type": "application/json" },
        { "inline-oneboxes": [] },
      ]);

      const [editor] = await setupRichEditor(assert, `see [${OTHER_URL}] here`);

      assert.strictEqual(editor.value, `see \\[${OTHER_URL}] here`);
    });

    test("ignores nested editor states", async function (assert) {
      const [editor] = await setupRichEditor(assert, `> ${URL}\n>\n> b`);
      const { view } = editor;

      const inner = EditorState.create({
        doc: view.state.doc.firstChild,
        plugins: view.state.plugins,
      });
      const tr = inner.tr.insertText("c", inner.doc.content.size - 1);
      tr.setSelection(TextSelection.atEnd(tr.doc));
      const { state } = inner.applyTransaction(tr);

      assert.strictEqual(oneboxPluginKey.getState(state).find().length, 0);
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
        `${URL} \n\nb`,
        "leaves the markdown the user typed alone"
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
        `${URL}\nasd`,
        "leaves the markdown the user typed alone"
      );
      assert.false(
        view.state.selection instanceof NodeSelection,
        "the cursor lands after the onebox, not selecting the block"
      );
    });
  }
);
