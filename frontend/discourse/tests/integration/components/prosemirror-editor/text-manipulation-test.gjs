import { tracked } from "@glimmer/tracking";
import { render, settled, waitFor } from "@ember/test-helpers";
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
      <ProsemirrorEditor @value={{state.value}} @onSetup={{handleSetup}} />
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
  "Integration | Component | prosemirror-editor | text-manipulation - applySurround",
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
  "Integration | Component | prosemirror-editor | text-manipulation - applyList",
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
