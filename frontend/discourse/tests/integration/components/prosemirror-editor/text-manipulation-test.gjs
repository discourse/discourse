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

    test("preserves link attributes detected from markup", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      state.textManipulation.applySurroundSelection(
        "[",
        "](https://example.com)",
        "link_text"
      );

      assert
        .dom(".ProseMirror a")
        .hasAttribute(
          "href",
          "https://example.com",
          "the detected link keeps its destination"
        );
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

    test("inserts placeholder text when nothing is selected", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      placeCursor(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applySurround(sel, "**", "**", "bold_text");

      const md = getMarkdown(state).trim();
      assert.true(md.includes("**strong text**"));
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
