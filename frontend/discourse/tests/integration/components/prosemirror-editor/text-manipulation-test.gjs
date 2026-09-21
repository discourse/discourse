import { tracked } from "@glimmer/tracking";
import { render, settled, waitFor } from "@ember/test-helpers";
import { closeHistory, undo } from "prosemirror-history";
import { TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import ProsemirrorEditor from "discourse/static/prosemirror/components/prosemirror-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

async function setupEditor() {
  const state = new (class {
    @tracked value = "";
    textManipulation = null;
  })();

  const handleSetup = (tm) => {
    state.textManipulation = tm;
  };

  await render(
    <template>
      <ProsemirrorEditor @onSetup={{handleSetup}} @value={{state.value}} />
    </template>
  );

  await waitFor(".ProseMirror");
  await settled();

  return state;
}

function setContent(state, markdown) {
  const { view, convertFromMarkdown } = state.textManipulation;
  const doc = convertFromMarkdown(markdown);
  view.dispatch(
    view.state.tr.replaceWith(0, view.state.doc.content.size, doc.content)
  );
}

function selectAll(state) {
  const { view } = state.textManipulation;
  const { doc } = view.state;

  const from = TextSelection.atStart(doc).from;
  const to = TextSelection.atEnd(doc).to;
  view.dispatch(
    view.state.tr.setSelection(TextSelection.create(doc, from, to))
  );
}

function placeCursor(state) {
  const { view } = state.textManipulation;
  const pos = TextSelection.atStart(view.state.doc).from;
  view.dispatch(
    view.state.tr.setSelection(TextSelection.create(view.state.doc, pos))
  );
}

function countNodes(state, typeName) {
  let count = 0;
  state.textManipulation.view.state.doc.descendants((node) => {
    if (node.type.name === typeName) {
      count++;
    }
  });
  return count;
}

function getMarkdown(state) {
  const { view, convertToMarkdown } = state.textManipulation;
  return convertToMarkdown(view.state.doc);
}

module(
  "Integration | Component | ProsemirrorEditor | Text manipulation | applySurround",
  function (hooks) {
    setupRenderingTest(hooks);

    test("toggles bold mark via parser detection", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applySurround(sel, "**", "**", "bold_text");

      assert.strictEqual(getMarkdown(state).trim(), "**hello world**");
    });

    test("toggles strikethrough (extension mark) via parser detection", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applySurround(
        sel,
        "~~",
        "~~",
        "strikethrough_text"
      );

      assert.strictEqual(getMarkdown(state).trim(), "~~hello world~~");
    });

    test("preserves combined marks in the fallback", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      state.textManipulation.applySurroundSelection("**_", "_**", "bold_text");

      assert
        .dom(".ProseMirror strong em, .ProseMirror em strong")
        .hasText("hello world", "both marks are applied");
    });

    test("preserves formatting inside a block wrapper", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      state.textManipulation.applySurroundSelection("> **", "**", "bold_text");

      assert
        .dom(".ProseMirror blockquote strong")
        .hasText("hello world", "the quote retains its bold formatting");
      assert.strictEqual(
        getMarkdown(state).trim(),
        "> **hello world**",
        "both formatting layers survive serialization"
      );
      assert
        .dom(".ProseMirror > blockquote:first-child")
        .exists("the replaced paragraph is not left behind");
    });

    test("preserves literal content inside a block wrapper", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      state.textManipulation.applySurroundSelection(
        "> prefix ",
        " suffix",
        "blockquote_text"
      );

      assert
        .dom(".ProseMirror blockquote")
        .hasText(
          "prefix hello world suffix",
          "the wrapper retains its prefix and suffix"
        );
    });

    test("preserves nested block wrappers", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      state.textManipulation.applySurroundSelection(
        "> > ",
        "",
        "blockquote_text"
      );

      assert
        .dom(".ProseMirror blockquote blockquote")
        .hasText("hello world", "both quote levels are retained");
    });

    test("uses the inline variant of block-capable markup inside a paragraph", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      const { view } = state.textManipulation;
      view.dispatch(
        view.state.tr.setSelection(TextSelection.create(view.state.doc, 7, 12))
      );

      state.textManipulation.applySurroundSelection(
        "[wrap=note]",
        "[/wrap]",
        "wrap_text"
      );

      assert.strictEqual(countNodes(state, "wrap_inline"), 1);
      assert.strictEqual(countNodes(state, "wrap_block"), 0);
      assert.dom(".ProseMirror p").hasText("hello world");
    });

    test("uses the block variant of block-capable markup for a whole paragraph", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      state.textManipulation.applySurroundSelection(
        "[wrap=note]",
        "[/wrap]",
        "wrap_text"
      );

      assert.strictEqual(countNodes(state, "wrap_block"), 1);
      assert.strictEqual(countNodes(state, "wrap_inline"), 0);
      assert.dom(".ProseMirror p").hasText("hello world");
    });

    test("inserts an inline placeholder when the cursor is at the end of a paragraph", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      const { view } = state.textManipulation;
      view.dispatch(
        view.state.tr.setSelection(TextSelection.create(view.state.doc, 12))
      );

      state.textManipulation.applySurroundSelection(
        "[wrap=note]",
        "[/wrap]",
        "wrap_text"
      );

      const { from, to } = view.state.selection;
      assert.strictEqual(
        view.state.doc.textBetween(from, to),
        "Wrap content",
        "the placeholder is selected"
      );
      assert.strictEqual(countNodes(state, "wrap_inline"), 1);
    });

    test("wraps a multi-paragraph selection as a block", async function (assert) {
      const state = await setupEditor();
      setContent(state, "first\n\nsecond");
      selectAll(state);

      state.textManipulation.applySurroundSelection(
        "[wrap=note]",
        "[/wrap]",
        "wrap_text"
      );

      assert.strictEqual(countNodes(state, "wrap_block"), 1);
      assert.strictEqual(
        state.textManipulation.view.state.doc.firstChild.childCount,
        2,
        "both paragraphs are inside the wrapper"
      );
    });

    test("keeps a blockquote around a fully selected quoted paragraph", async function (assert) {
      const state = await setupEditor();
      setContent(state, "> quoted");
      const { view } = state.textManipulation;
      view.dispatch(
        view.state.tr.setSelection(TextSelection.create(view.state.doc, 2, 8))
      );

      state.textManipulation.applySurroundSelection(
        "[wrap=note]",
        "[/wrap]",
        "wrap_text"
      );

      assert.strictEqual(countNodes(state, "blockquote"), 1);
      assert.strictEqual(countNodes(state, "wrap_block"), 1);
      assert.dom(".ProseMirror blockquote p").hasText("quoted");
    });

    test("selects the placeholder of a block inserted after a paragraph", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      const { view } = state.textManipulation;
      view.dispatch(
        view.state.tr.setSelection(TextSelection.create(view.state.doc, 12))
      );

      state.textManipulation.applySurroundSelection(
        "\n[wrap=note]\n",
        "\n[/wrap]\n",
        "wrap_text"
      );

      const { from, to } = view.state.selection;
      assert.strictEqual(view.state.doc.textBetween(from, to), "Wrap content");
      assert.strictEqual(countNodes(state, "wrap_block"), 1);
      assert
        .dom(".ProseMirror p")
        .hasText("hello world", "the paragraph is kept");
    });

    test("selects the placeholder of a block inserted before a paragraph", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      const { view } = state.textManipulation;
      view.dispatch(
        view.state.tr.setSelection(TextSelection.create(view.state.doc, 1))
      );

      state.textManipulation.applySurroundSelection(
        "\n[wrap=note]\n",
        "\n[/wrap]\n",
        "wrap_text"
      );

      const { from, to } = view.state.selection;
      assert.strictEqual(view.state.doc.textBetween(from, to), "Wrap content");
      assert.strictEqual(countNodes(state, "wrap_block"), 1);
      assert
        .dom(".ProseMirror > p")
        .hasText("hello world", "the paragraph is kept");
    });

    test("removes mark when already applied", async function (assert) {
      const state = await setupEditor();
      setContent(state, "**hello world**");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applySurround(sel, "**", "**", "bold_text");

      assert.strictEqual(getMarkdown(state).trim(), "hello world");
    });

    test("falls back to round-trip for unrecognized markup", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applySurround(sel, "<big>", "</big>", "big_text");

      assert.strictEqual(getMarkdown(state).trim(), "<big>hello world</big>");
    });

    test("toggles stored marks when nothing is selected", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      placeCursor(state);
      const { view } = state.textManipulation;

      state.textManipulation.applySurroundSelection("**", "**", "bold_text");
      view.dispatch(view.state.tr.insertText("bold "));

      assert.dom(".ProseMirror strong").hasText("bold", "typing is bold");
      assert.false(
        getMarkdown(state).includes("strong text"),
        "no placeholder is inserted"
      );

      state.textManipulation.applySurroundSelection("**", "**", "bold_text");
      view.dispatch(view.state.tr.insertText("plain "));

      assert
        .dom(".ProseMirror strong")
        .hasText("bold", "the stored mark is toggled off again");
    });

    test("inserts and selects a placeholder when nothing is selected in the fallback", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      placeCursor(state);
      const { view } = state.textManipulation;

      state.textManipulation.applySurroundSelection("**_", "_**", "bold_text");

      const { from, to } = view.state.selection;
      assert.strictEqual(
        view.state.doc.textBetween(from, to),
        "strong text",
        "the placeholder is selected"
      );
      assert
        .dom(".ProseMirror strong em, .ProseMirror em strong")
        .hasText("strong text");
    });
  }
);

module(
  "Integration | Component | ProsemirrorEditor | Text manipulation | applyList",
  function (hooks) {
    setupRenderingTest(hooks);

    test("applies bullet list via parser detection", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(sel, "* ", "list_item");

      assert.strictEqual(getMarkdown(state).trim(), "* hello world");
    });

    test("creates a list item for each selected line", async function (assert) {
      const state = await setupEditor();
      setContent(state, "first line\nsecond line");
      selectAll(state);

      state.textManipulation.applyList(
        state.textManipulation.getSelected(),
        "* ",
        "list_item"
      );

      assert
        .dom(".ProseMirror li")
        .exists({ count: 2 }, "each line becomes a separate list item");
      assert.strictEqual(
        getMarkdown(state).trim(),
        "* first line\n* second line",
        "both lines are preserved"
      );
    });

    test("switching list type is undone in one step", async function (assert) {
      const state = await setupEditor();
      setContent(state, "* first\n* second");
      const { view } = state.textManipulation;
      const list = view.state.doc.firstChild;
      const from = TextSelection.atStart(list).from + 1;
      const to = TextSelection.atEnd(list).to + 1;
      view.dispatch(
        closeHistory(
          view.state.tr.setSelection(
            TextSelection.create(view.state.doc, from, to)
          )
        )
      );

      state.textManipulation.applyList(
        state.textManipulation.getSelected(),
        "1. ",
        "list_item"
      );
      assert.strictEqual(
        getMarkdown(state).trim(),
        "1. first\n2. second",
        "switching preserves both items"
      );
      assert
        .dom(".ProseMirror ol li")
        .exists({ count: 2 }, "both items change type");
      undo(view.state, view.dispatch);
      assert.strictEqual(
        getMarkdown(state).trim(),
        "* first\n* second",
        "one undo restores the original list"
      );
    });

    test("applies ordered list with function head", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(
        sel,
        (i) => (!i ? "1. " : `${parseInt(i, 10) + 1}. `),
        "list_item"
      );

      assert.strictEqual(getMarkdown(state).trim(), "1. hello world");
    });

    test("applies blockquote via parser detection", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(sel, "> ", "blockquote_text");

      assert.strictEqual(getMarkdown(state).trim(), "> hello world");
    });

    test("toggles bullet list off", async function (assert) {
      const state = await setupEditor();
      setContent(state, "* hello world");
      placeCursor(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(sel, "* ", "list_item");

      assert.strictEqual(getMarkdown(state).trim(), "hello world");
    });

    test("toggles ordered list off", async function (assert) {
      const state = await setupEditor();
      setContent(state, "1. hello world");
      placeCursor(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(
        sel,
        (i) => (!i ? "1. " : `${parseInt(i, 10) + 1}. `),
        "list_item"
      );

      assert.strictEqual(getMarkdown(state).trim(), "hello world");
    });

    test("toggles blockquote off", async function (assert) {
      const state = await setupEditor();
      setContent(state, "> hello world");
      placeCursor(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(sel, "> ", "blockquote_text");

      assert.strictEqual(getMarkdown(state).trim(), "hello world");
    });

    test("switches from bullet list to ordered list", async function (assert) {
      const state = await setupEditor();
      setContent(state, "* hello world");
      placeCursor(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(
        sel,
        (i) => (!i ? "1. " : `${parseInt(i, 10) + 1}. `),
        "list_item"
      );

      const md = getMarkdown(state).trim();
      assert.true(md.startsWith("1."));
      assert.false(md.startsWith("* "));
    });

    test("switches from ordered list to bullet list", async function (assert) {
      const state = await setupEditor();
      setContent(state, "1. hello world");
      placeCursor(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(sel, "* ", "list_item");

      const md = getMarkdown(state).trim();
      const isBullet = md.startsWith("* ") || md.startsWith("- ");
      assert.true(isBullet);
      assert.false(md.startsWith("1."));
    });

    test("falls back to markdown round-trip for unrecognized list head", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(sel, "? ", "list_item");

      assert.strictEqual(getMarkdown(state).trim(), "? hello world");
      assert.strictEqual(
        state.textManipulation.view.state.doc.childCount,
        1,
        "the replaced paragraph is not left behind"
      );
    });

    test("passes the previous head to function heads in the fallback", async function (assert) {
      const state = await setupEditor();
      setContent(state, "first\n\nsecond");
      selectAll(state);

      state.textManipulation.applyList(
        state.textManipulation.getSelected(),
        (previous) =>
          previous === undefined
            ? "?1 "
            : `?${parseInt(previous.slice(1), 10) + 1} `,
        "list_item"
      );

      assert.strictEqual(
        getMarkdown(state).trim(),
        "?1 first\n\n?2 second",
        "each head derives from the previous one and blank lines do not advance it"
      );
    });

    test("preserves additional content in list prefixes", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      state.textManipulation.applyList(
        state.textManipulation.getSelected(),
        "* [x] ",
        "list_item"
      );

      assert
        .dom(".ProseMirror li")
        .hasText("[x] hello world", "the prefix content is retained");
    });

    test("preserves additional content in blockquote prefixes", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      state.textManipulation.applyList(
        state.textManipulation.getSelected(),
        "> prefix ",
        "blockquote_text"
      );

      assert
        .dom(".ProseMirror blockquote")
        .hasText("prefix hello world", "the prefix content is retained");
    });

    test("preserves the starting number of an ordered list", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      state.textManipulation.applyList(
        state.textManipulation.getSelected(),
        "3. ",
        "list_item"
      );

      assert
        .dom(".ProseMirror ol")
        .hasAttribute("start", "3", "the parsed starting number is retained");
    });

    test("selects the inserted placeholder rather than an earlier copy of its text", async function (assert) {
      const state = await setupEditor();
      setContent(state, "List item and more");
      const { view } = state.textManipulation;
      view.dispatch(
        view.state.tr.setSelection(TextSelection.create(view.state.doc, 19))
      );

      state.textManipulation.applyList(
        state.textManipulation.getSelected(),
        "? ",
        "list_item"
      );

      const { from, to } = view.state.selection;
      assert.strictEqual(view.state.doc.textBetween(from, to), "List item");
      assert.strictEqual(from, 21, "the new occurrence is selected");
    });

    test("handles multi-line selection in fallback path", async function (assert) {
      const state = await setupEditor();
      setContent(state, "line one\nline two");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(sel, "? ", "list_item");

      assert.strictEqual(getMarkdown(state).trim(), "? line one\n? line two");
    });
  }
);
