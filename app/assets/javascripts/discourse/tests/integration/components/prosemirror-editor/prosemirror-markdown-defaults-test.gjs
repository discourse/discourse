import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ProsemirrorEditor from "discourse/static/prosemirror/components/prosemirror-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import sinon from "sinon";

module(
  "Integration | Component | prosemirror-editor - prosemirror-markdown defaults",
  function (hooks) {
    setupRenderingTest(hooks);

    test("parses/edits/serializes paragraphs with text", async function (assert) {
      const value = "Hello";
      const onChangeMock = sinon.spy();
      await render(<template>
        <ProsemirrorEditor @value={{value}} @change={{onChangeMock}} />
      </template>);

      assert.dom(".ProseMirror").hasText("Hello");

      await fillIn(".ProseMirror", " world!");

      assert.true(
        onChangeMock.calledWith("Hello world!"),
        "onChange is called with the new value"
      );
    });

    // nodes:
    // blockquote
    // horizontal_rule
    // heading (level 1-6)
    // code_block
    // ordered_list (order, tight)
    // bullet_list (tight)
    // list_item
    // image (src, alt, title)
    // hard_break

    //marks:
    // em
    // strong
    // link (href, title)
    // code
  }
);
