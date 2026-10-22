import { array } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ProsemirrorEditor from "discourse/static/prosemirror/components/prosemirror-editor";
import emoji from "discourse/static/prosemirror/extensions/emoji";
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
