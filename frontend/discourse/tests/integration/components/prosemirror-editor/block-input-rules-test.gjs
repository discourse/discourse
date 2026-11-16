import { array } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { EditorState, TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import ProsemirrorEditor from "discourse/static/prosemirror/components/prosemirror-editor";
import emoji from "discourse/static/prosemirror/extensions/emoji";
import table from "discourse/static/prosemirror/extensions/table";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | prosemirror-editor - block input rules",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      const handleSetup = (textManipulation) => {
        this.view = textManipulation.view;
      };

      await render(
        <template>
          <ProsemirrorEditor
            @extensions={{array emoji}}
            @onSetup={{handleSetup}}
          />
        </template>
      );

      // types `markup` after `intro` and a line break; its last character is
      // typed through the input rules, as a keystroke would be
      this.typeAfterBreak = (
        markup,
        leaf = this.view.state.schema.nodes.hard_break.create()
      ) => {
        const { view } = this;
        view.dispatch(
          view.state.tr
            .insertText("intro")
            .replaceSelectionWith(leaf)
            .insertText(markup.slice(0, -1))
        );
        const { from } = view.state.selection;
        const handled = view.someProp("handleTextInput", (f) =>
          f(view, from, from, markup.slice(-1))
        );
        if (!handled) {
          view.dispatch(view.state.tr.insertText(markup.slice(-1)));
        }
      };
    });

    for (const [markup, selector] of [
      ["- ", "ul li"],
      ["1. ", "ol li"],
      ["> ", "blockquote"],
      ["```", "pre"],
      ["# ", "h1"],
    ]) {
      test(`"${markup}" after a line break starts a new block`, async function (assert) {
        this.typeAfterBreak(markup);

        assert.dom(`.ProseMirror ${selector}`).exists("the block starts");
        assert
          .dom(".ProseMirror > p:first-child")
          .hasText(
            "intro",
            "the text before the break stays its own paragraph"
          );
        assert
          .dom(
            ".ProseMirror > p:first-child br:not(.ProseMirror-trailingBreak)"
          )
          .doesNotExist("the line break is gone");
      });
    }

    test("markup after other inline nodes stays text", async function (assert) {
      this.typeAfterBreak(
        "- ",
        this.view.state.schema.nodes.emoji.create({ code: "smile" })
      );

      assert.dom(".ProseMirror ul").doesNotExist("no list");
      assert.dom(".ProseMirror img.emoji").exists("the emoji stays");
    });
  }
);

module(
  "Integration | Component | prosemirror-editor - block input rules in context",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      const handleSetup = (textManipulation) => {
        this.view = textManipulation.view;
      };

      await render(
        <template>
          <ProsemirrorEditor
            @extensions={{array table}}
            @onSetup={{handleSetup}}
          />
        </template>
      );

      this.schema = this.view.state.schema;

      this.setDoc = (doc, findCursor) => {
        let state = EditorState.create({
          doc,
          plugins: this.view.state.plugins,
        });
        const pos = findCursor?.(state.doc) ?? TextSelection.atEnd(doc).from;
        state = state.apply(
          state.tr.setSelection(TextSelection.create(state.doc, pos))
        );
        this.view.updateState(state);
      };

      // each character goes through the input rules, as keystrokes would
      this.type = (text) => {
        const { view } = this;
        for (const char of text) {
          const { from, to } = view.state.selection;
          const handled = view.someProp("handleTextInput", (f) =>
            f(view, from, to, char)
          );
          if (!handled) {
            view.dispatch(view.state.tr.insertText(char));
          }
        }
      };
    });

    for (const [markup, list] of [
      ["2. ", "ordered_list"],
      ["- ", "bullet_list"],
    ]) {
      test(`"${markup}" right after a list continues it`, async function (assert) {
        const { schema } = this;
        this.setDoc(
          schema.node("doc", null, [
            schema.nodes[list].create(null, [
              schema.nodes.list_item.create(null, [
                schema.nodes.paragraph.create(null, [schema.text("a")]),
              ]),
            ]),
            schema.nodes.paragraph.create(),
          ])
        );

        this.type(markup);

        const { doc } = this.view.state;
        assert.strictEqual(doc.childCount, 1, "one list");
        assert.strictEqual(doc.firstChild.childCount, 2, "with two items");
      });
    }

    for (const [markup, afterBreak] of [
      ["# ", false],
      ["```", false],
      ["    ", false],
      ["# ", true],
    ]) {
      const where = afterBreak ? "after a line break in" : "in";
      test(`"${markup}" stays text ${where} a table cell`, async function (assert) {
        const { schema } = this;
        this.setDoc(
          schema.node("doc", null, [
            schema.nodes.table.create(null, [
              schema.nodes.table_head.create(null, [
                schema.nodes.table_row.create(null, [
                  schema.nodes.table_header_cell.create(null, [
                    schema.text("h"),
                  ]),
                ]),
              ]),
              schema.nodes.table_body.create(null, [
                schema.nodes.table_row.create(null, [
                  schema.nodes.table_cell.create(),
                ]),
              ]),
            ]),
            schema.nodes.paragraph.create(),
          ]),
          (doc) => {
            let cellPos;
            doc.descendants((node, pos) => {
              if (node.type === schema.nodes.table_cell) {
                cellPos = pos + 1;
              }
            });
            return cellPos;
          }
        );

        if (afterBreak) {
          this.view.dispatch(
            this.view.state.tr
              .insertText("x")
              .replaceSelectionWith(schema.nodes.hard_break.create())
          );
        }
        this.type(markup);

        const cells = [];
        this.view.state.doc.descendants((node) => {
          if (node.type === schema.nodes.table_cell) {
            cells.push(node.textContent);
          }
        });
        assert.deepEqual(
          cells,
          [afterBreak ? `x${markup}` : markup],
          "the cell keeps the typed text"
        );
      });
    }
  }
);
