import { settled } from "@ember/test-helpers";
import { setLocalCache } from "pretty-text/oneboxer-cache";
import {
  closeHistory,
  redo,
  redoDepth,
  undo,
  undoDepth,
} from "prosemirror-history";
import { NodeSelection, TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import { buildEngine } from "discourse/static/markdown-it";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";

// Mocked by create-pretender for both /inline-onebox and /onebox.
const URL = "http://www.example.com/has-title.html";
const TOP_LEVEL_URL = "http://www.example.com";
const ONEBOX_HTML =
  '<aside class="onebox"><article class="onebox-body"><h3><a href="http://www.example.com">Example</a></h3></article></aside>';

function lastParagraphStart(doc) {
  let pos = null;
  doc.descendants((node, nodePos) => {
    if (node.type.name === "paragraph") {
      pos = nodePos + 1;
    }
  });
  return pos;
}

async function undoAll(view) {
  for (let i = 0; i < 5 && undoDepth(view.state) > 0; i++) {
    undo(view.state, view.dispatch);
    await settled();
  }
}

function posOfText(doc, text) {
  let pos = null;
  doc.descendants((node, nodePos) => {
    if (node.isText && node.text === text) {
      pos = nodePos;
    }
  });
  return pos;
}

// With pretender in manual-resolution mode, waits for the next /onebox request
// to fire, releases its response, and lets the resulting render dispatch.
async function resolveOneboxRequest() {
  let ref;
  for (let i = 0; i < 200 && !ref; i++) {
    ref = pretender.requestReferences?.find((reference) =>
      reference.request.url.includes("/onebox")
    );
    if (!ref) {
      await new Promise((resolve) => setTimeout(resolve, 5));
    }
  }
  pretender.resolve(ref.request);
  await new Promise((resolve) => setTimeout(resolve, 0));
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

    test("undo reaches back past a typed URL's onebox", async function (assert) {
      pretender.get("/onebox", () => [
        200,
        { "Content-Type": "text/html" },
        ONEBOX_HTML,
      ]);

      const [editor] = await setupRichEditor(assert, "x");
      const { view } = editor;
      const original = editor.value;

      view.dispatch(view.state.tr.insertText(`${TOP_LEVEL_URL} `, 1, 2));
      await settled();
      view.dispatch(view.state.tr.split(view.state.selection.from));
      await settled();
      assert.dom(".onebox-wrapper").exists("the URL becomes a full onebox");

      await undoAll(view);

      assert.dom(".onebox-wrapper").doesNotExist("undo removes the onebox");
      assert.strictEqual(editor.value, original, "undo restores the document");
    });

    // The cursor lands away from a dropped link, so the scan must stay held
    // through other plugins' appended reactions to the undo.
    test("undo reaches back past a dropped link's onebox", async function (assert) {
      pretender.get("/onebox", () => [
        200,
        { "Content-Type": "text/html" },
        ONEBOX_HTML,
      ]);

      const [editor] = await setupRichEditor(assert, "aaaaa\n\nx");
      const { view } = editor;
      const { schema } = view.state;
      const original = editor.value;

      const linkMark = schema.marks.link.create({
        href: TOP_LEVEL_URL,
        markup: "linkify",
      });
      const lastStart = lastParagraphStart(view.state.doc);
      const tr = view.state.tr
        .replaceWith(
          lastStart,
          lastStart + 1,
          schema.text(TOP_LEVEL_URL, [linkMark])
        )
        .delete(1, 3);
      tr.setSelection(TextSelection.create(tr.doc, 1));
      view.dispatch(tr);
      await settled();
      assert.dom(".onebox-wrapper").exists("the dropped link becomes a onebox");

      await undoAll(view);

      assert.dom(".onebox-wrapper").doesNotExist("undo removes the onebox");
      assert.strictEqual(editor.value, original, "undo restores the document");
    });

    test("a render arriving after an undo preserves the redo stack", async function (assert) {
      pretender.get("/onebox", () => [
        200,
        { "Content-Type": "text/html" },
        ONEBOX_HTML,
      ]);

      const [editor] = await setupRichEditor(assert, "x");
      const { view } = editor;

      view.dispatch(view.state.tr.insertText(`${TOP_LEVEL_URL} `, 1, 2));
      await settled();

      view.dispatch(
        closeHistory(view.state.tr.split(view.state.selection.from))
      );
      view.dispatch(closeHistory(view.state.tr.insertText("abc")));

      undo(view.state, view.dispatch);
      assert.strictEqual(redoDepth(view.state), 1, "the undo is redoable");

      await settled();
      assert.dom(".onebox-wrapper").exists("the late render still shows");
      assert.strictEqual(
        redoDepth(view.state),
        1,
        "the late render does not wipe the redo stack"
      );

      redo(view.state, view.dispatch);
      await settled();
      assert.true(
        view.state.doc.textContent.includes("abc"),
        "redo restores the undone edit"
      );
    });

    test("a pending render leaves an undone onebox's link alone", async function (assert) {
      let manual = false;
      pretender.get(
        "/onebox",
        () => [200, { "Content-Type": "text/html" }, ONEBOX_HTML],
        () => manual
      );

      const [editor] = await setupRichEditor(assert, "x\n\nyyy\n\nzzz");
      const { view } = editor;
      const { schema } = view.state;
      manual = true;

      const linkText = (url) =>
        schema.text(url, [
          schema.marks.link.create({ href: url, markup: "linkify" }),
        ]);

      // Drop link A on the first line, with the cursor away on the last line.
      const trA = view.state.tr.replaceWith(1, 2, linkText(TOP_LEVEL_URL));
      trA.setSelection(TextSelection.create(trA.doc, trA.doc.content.size - 1));
      view.dispatch(trA);

      // Drop link B on the second line — its fetch queues behind A's.
      const posB = posOfText(view.state.doc, "yyy");
      const trB = view.state.tr.replaceWith(
        posB,
        posB + 3,
        linkText(`${TOP_LEVEL_URL}/b`)
      );
      trB.setSelection(TextSelection.create(trB.doc, trB.doc.content.size - 1));
      view.dispatch(closeHistory(trB));

      await resolveOneboxRequest();
      assert.dom(".onebox-wrapper").exists({ count: 1 }, "A renders first");

      // Undo A's render while B's fetch is still in flight.
      undo(view.state, view.dispatch);
      assert.dom(".onebox-wrapper").doesNotExist("undo restores A's link");

      await resolveOneboxRequest();
      await settled();

      assert
        .dom(".onebox-wrapper")
        .exists({ count: 1 }, "B's preview still renders");
      assert.strictEqual(
        view.state.doc.firstChild.textContent,
        TOP_LEVEL_URL,
        "A stays the link undo restored"
      );
      assert.strictEqual(redoDepth(view.state), 1, "the undo stays redoable");
    });

    test("opening content with a onebox URL leaves nothing extra to undo", async function (assert) {
      pretender.get("/onebox", () => [
        200,
        { "Content-Type": "text/html" },
        ONEBOX_HTML,
      ]);

      const markdown = `hello\n\n${TOP_LEVEL_URL}\n\nworld`;
      const [editor] = await setupRichEditor(assert, markdown);
      const { view } = editor;

      assert.dom(".onebox-wrapper").exists("the URL renders as a onebox");
      assert.strictEqual(
        undoDepth(view.state),
        1,
        "only the helper's own serialization nudge is undoable — not the render"
      );

      await undoAll(view);

      assert.dom(".onebox-wrapper").exists("undo does not degrade the preview");
      assert.strictEqual(editor.value, markdown, "the value is unchanged");
    });
  }
);
