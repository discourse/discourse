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

    test("falls back to round-trip for unknown markup", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applySurround(sel, "<big>", "</big>", "big_text");

      const md = getMarkdown(state).trim();
      assert.strictEqual(md, "<big>hello world</big>");
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

      const md = getMarkdown(state).trim();
      const hasBullet = md.includes("* ") || md.includes("- ");
      assert.true(hasBullet, "should contain bullet list marker");
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

      assert.true(
        getMarkdown(state).trim().includes("1."),
        "should contain ordered list marker"
      );
    });

    test("applies blockquote via parser detection", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(sel, "> ", "blockquote_text");

      assert.true(
        getMarkdown(state).trim().includes(">"),
        "should contain blockquote marker"
      );
    });

    test("toggles bullet list off", async function (assert) {
      const state = await setupEditor();
      setContent(state, "* hello world");
      placeCursor(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(sel, "* ", "list_item");

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
      assert.true(md.includes("1."), "should be an ordered list");
      const hasBullet = md.includes("* ") || md.includes("- ");
      assert.false(hasBullet, "should not have bullet markers");
    });

    test("falls back to markdown round-trip for unrecognized list head", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);

      const sel = state.textManipulation.getSelected();
      state.textManipulation.applyList(sel, "? ", "list_item");

      const md = getMarkdown(state).trim();
      assert.strictEqual(md, "? hello world");
    });
  }
);
