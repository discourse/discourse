import { tracked } from "@glimmer/tracking";
import { render, settled, waitFor } from "@ember/test-helpers";
import { closeHistory, undo } from "prosemirror-history";
import { TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import ProsemirrorEditor from "discourse/static/prosemirror/components/prosemirror-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

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

    test("surrounds formatted lines independently in multiline mode", async function (assert) {
      const state = await setupEditor();
      setContent(state, "**one**\n_two_");
      selectAll(state);
      state.textManipulation.applySurroundSelection(
        "<kbd>",
        "</kbd>",
        "code_text",
        { multiline: true }
      );
      assert
        .dom(".ProseMirror kbd")
        .exists({ count: 2 }, "each line has its own wrapper");
      assert
        .dom(".ProseMirror kbd strong, .ProseMirror strong kbd")
        .hasText("one", "bold survives");
      assert
        .dom(".ProseMirror kbd em, .ProseMirror em kbd")
        .hasText("two", "italic survives");
      assert.false(
        state.textManipulation.view.state.selection.empty,
        "the formatted content stays selected"
      );
    });

    test("multiline surround skips empty paragraphs", async function (assert) {
      const state = await setupEditor();
      setContent(state, "one\n\ntwo");
      const { view, schema } = state.textManipulation;
      view.dispatch(view.state.tr.insert(5, schema.nodes.paragraph.create()));
      selectAll(state);
      state.textManipulation.applySurroundSelection(
        "<kbd>",
        "</kbd>",
        "code_text",
        { multiline: true }
      );
      assert
        .dom(".ProseMirror > p")
        .exists({ count: 3 }, "the empty paragraph is preserved");
      assert
        .dom(".ProseMirror > p:nth-child(2) kbd")
        .doesNotExist("empty paragraphs are not wrapped by default");
      assert
        .dom(".ProseMirror > p:first-child kbd")
        .hasText("one", "the first paragraph is wrapped");
      assert
        .dom(".ProseMirror > p:last-child kbd")
        .hasText("two", "the last paragraph is wrapped");
    });

    test("multiline surround preserves text outside the selection and undoes in one step", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello one\ntwo world");
      const { view } = state.textManipulation;
      view.dispatch(
        closeHistory(
          view.state.tr.setSelection(
            TextSelection.create(view.state.doc, 7, 14)
          )
        )
      );
      state.textManipulation.applySurroundSelection(
        "<kbd>",
        "</kbd>",
        "code_text",
        { multiline: true }
      );
      assert
        .dom(".ProseMirror kbd:first-of-type")
        .hasText("one", "only the selected first line is wrapped");
      assert
        .dom(".ProseMirror kbd:last-of-type")
        .hasText("two", "only the selected last line is wrapped");
      undo(view.state, view.dispatch);
      assert.strictEqual(
        getMarkdown(state).trim(),
        "hello one\ntwo world",
        "one undo restores both lines"
      );
    });

    test("multiline surround preserves the containing blockquote", async function (assert) {
      const state = await setupEditor();
      setContent(state, "> one\n> two");
      selectAll(state);
      state.textManipulation.applySurroundSelection(
        "<kbd>",
        "</kbd>",
        "code_text",
        { multiline: true }
      );
      assert
        .dom(".ProseMirror blockquote kbd")
        .exists({ count: 2 }, "both lines stay inside the quote");
    });

    test("applies a multiline heading prefix across hard breaks", async function (assert) {
      const state = await setupEditor();
      setContent(state, "one\ntwo");
      selectAll(state);
      state.textManipulation.applySurroundSelection("# ", "", "heading_text", {
        multiline: true,
      });
      assert
        .dom(".ProseMirror h1")
        .exists({ count: 2 }, "each selected line becomes a heading");
      assert.strictEqual(
        getMarkdown(state).trim(),
        "# one\n\n# two",
        "both lines retain their content without literal prefixes"
      );
    });

    test("multiline heading prefixes preserve unselected boundary text", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello\nworld\nafter");
      state.textManipulation.selectText(4, 5);
      state.textManipulation.applySurroundSelection("# ", "", "heading_text", {
        multiline: true,
      });
      assert
        .dom(".ProseMirror > p:first-child")
        .hasText("hel# lo", "a prefix in the middle of a line stays literal");
      assert
        .dom(".ProseMirror h1")
        .hasText("world", "a heading includes the rest of its line");
      assert
        .dom(".ProseMirror > p:last-child")
        .hasText("after", "the following line is preserved");
      assert
        .dom(".ProseMirror br")
        .doesNotExist("block boundaries replace the original hard breaks");
    });

    test("keeps a heading prefix literal in the middle of a paragraph", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      state.textManipulation.selectText(7, 5);
      state.textManipulation.applySurroundSelection("# ", "", "heading_text", {
        multiline: false,
      });
      assert
        .dom(".ProseMirror p")
        .hasText("hello # world", "mid-line markdown remains literal");
      assert.dom(".ProseMirror h1").doesNotExist("no block is introduced");
    });

    test("honors a caller-adjusted surround selection", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);
      const selected = state.textManipulation.getSelected();
      selected.start = 7;
      selected.value = "world";
      state.textManipulation.applySurround(
        selected,
        "<small>",
        "</small>",
        "wrap_text"
      );
      assert
        .dom(".ProseMirror small")
        .hasText("world", "only the supplied range is wrapped");
      assert
        .dom(".ProseMirror p")
        .hasText("hello world", "the preceding text is retained");
    });

    test("preserves formatting and selection after an inline surround", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello **world**");
      state.textManipulation.selectText(7, 5);
      state.textManipulation.applySurroundSelection(
        "<small>",
        "</small>",
        "wrap_text",
        { multiline: false }
      );
      assert
        .dom(".ProseMirror small strong, .ProseMirror strong small")
        .hasText("world", "existing formatting is preserved");
      const { view } = state.textManipulation;
      assert.strictEqual(
        view.state.doc.textBetween(
          view.state.selection.from,
          view.state.selection.to
        ),
        "world",
        "the content remains selected"
      );
    });

    test("selects an image created from a selected URL", async function (assert) {
      const state = await setupEditor();
      setContent(state, "https://example.com/image.png");
      selectAll(state);
      state.textManipulation.applySurroundSelection(
        '<img src="',
        '" alt="">',
        "wrap_text",
        { multiline: false }
      );
      await settled();
      assert
        .dom(".ProseMirror img")
        .hasAttribute(
          "src",
          "https://example.com/image.png",
          "the selected URL becomes an image"
        );
      assert.strictEqual(
        state.textManipulation.view.state.selection.node?.type.name,
        "image",
        "the image is selected"
      );
    });

    for (const [edge, markdown] of [
      ["leading", "![a](https://example.com/image.png) hello"],
      ["trailing", "hello ![a](https://example.com/image.png)"],
    ]) {
      test(`preserves a selected ${edge} image when surrounding text`, async function (assert) {
        const state = await setupEditor();
        setContent(state, markdown);
        selectAll(state);
        state.textManipulation.applySurroundSelection(
          "<small>",
          "</small>",
          "wrap_text",
          {
            multiline: false,
          }
        );
        await settled();
        const { view } = state.textManipulation;
        assert
          .dom(".ProseMirror small img")
          .exists("the image is inside the wrapper");
        const { from, to } = view.state.selection;
        assert.strictEqual(
          view.state.doc.textBetween(from, to).trim(),
          "hello",
          "the text remains selected"
        );
        view.dispatch(view.state.tr.insertText("replacement"));
        assert
          .dom(".ProseMirror img")
          .doesNotExist("replacing the selection removes the image too");
        assert
          .dom(".ProseMirror")
          .hasText(
            "replacement",
            "typing replaces the complete selected content"
          );
      });
    }

    test("keeps an unselected image outside a restored heading selection", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world ![a](https://example.com/image.png)");
      state.textManipulation.selectText(1, 5);
      state.textManipulation.applySurroundSelection("# ", "", "heading_text", {
        multiline: false,
      });
      await settled();
      const { view } = state.textManipulation;
      const { from, to } = view.state.selection;
      assert
        .dom(".ProseMirror h1")
        .hasText("hello world", "the complete line becomes a heading");
      assert.strictEqual(
        view.state.doc.textBetween(from, to),
        "hello",
        "only the original text is selected"
      );
      view.dispatch(view.state.tr.insertText("replacement"));
      assert
        .dom(".ProseMirror h1 img")
        .exists("the unselected image is preserved");
      assert
        .dom(".ProseMirror h1")
        .hasText("replacement world", "the unselected text is preserved");
    });

    test("restores a partial image and text selection after applying a heading", async function (assert) {
      const state = await setupEditor();
      setContent(state, "![a](https://example.com/image.png) hello world");
      state.textManipulation.selectText(1, 7);
      state.textManipulation.applySurroundSelection("# ", "", "heading_text", {
        multiline: false,
      });
      await settled();
      const { view } = state.textManipulation;
      view.dispatch(view.state.tr.insertText("replacement"));
      assert
        .dom(".ProseMirror img")
        .doesNotExist("the selected image is replaced");
      assert
        .dom(".ProseMirror h1")
        .hasText(
          "replacement world",
          "the unselected suffix remains outside the selection"
        );
    });

    test("trims leading whitespace in toolbar selections", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      state.textManipulation.selectText(6, 6);
      const selected = state.textManipulation.getSelected(true);
      state.textManipulation.applySurround(
        selected,
        "<small>",
        "</small>",
        "wrap_text"
      );
      assert
        .dom(".ProseMirror small")
        .hasText("world", "leading whitespace stays outside the wrapper");
      assert.strictEqual(
        selected.start,
        7,
        "the selection starts after whitespace"
      );
    });

    test("selects the rendered content of a structured placeholder", async function (assert) {
      const state = await setupEditor();
      const translations = I18n.translations[I18n.locale].js.composer;
      const original = translations.wrap_text;
      translations.wrap_text = "日本語<rp>(</rp><rt>にほんご</rt><rp>)</rp>";
      try {
        state.textManipulation.applySurroundSelection(
          "<ruby>",
          "</ruby>",
          "wrap_text",
          { multiline: false }
        );
        assert
          .dom(".ProseMirror ruby rt")
          .hasText("にほんご", "the annotation is rendered");
        const { view } = state.textManipulation;
        assert.strictEqual(
          view.state.doc.textBetween(
            view.state.selection.from,
            view.state.selection.to
          ),
          "日本語(にほんご)",
          "the complete parsed placeholder is selected"
        );
      } finally {
        translations.wrap_text = original;
      }
    });

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

    test("honors inline mode for a custom prefix across paragraphs", async function (assert) {
      const state = await setupEditor();
      setContent(state, "one\n\ntwo");
      selectAll(state);
      state.textManipulation.applyList(
        state.textManipulation.getSelected(),
        "? ",
        "list_item",
        { multiline: false }
      );
      assert.strictEqual(
        getMarkdown(state).trim(),
        "? one\n\ntwo",
        "the prefix is applied once"
      );
    });

    test("honors a caller-adjusted list selection", async function (assert) {
      const state = await setupEditor();
      setContent(state, "hello world");
      selectAll(state);
      const selected = state.textManipulation.getSelected();
      selected.start = 7;
      state.textManipulation.applyList(selected, "? ", "list_item");
      assert
        .dom(".ProseMirror p")
        .hasText("hello ? world", "only the supplied range is prefixed");
    });

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
      const { view } = state.textManipulation;
      assert.strictEqual(
        view.state.doc.textBetween(
          view.state.selection.from,
          view.state.selection.to,
          "\n",
          "\n"
        ),
        "? line one\n? line two",
        "all prefixed lines remain selected"
      );
    });
  }
);
