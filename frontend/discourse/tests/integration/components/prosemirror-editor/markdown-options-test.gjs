import { array, hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ProsemirrorEditor from "discourse/static/prosemirror/components/prosemirror-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// chat's rules: no heading, hr or html
const RULES = ["list", "backticks", "fence", "emphasis", "link", "newline"];

module(
  "Integration | Component | prosemirror-editor - markdown options",
  function (hooks) {
    setupRenderingTest(hooks);

    test("keeps markup the host doesn't cook as text", async function (assert) {
      let textManipulation;
      const handleSetup = (value) => {
        textManipulation = value;
      };

      await render(
        <template>
          <ProsemirrorEditor
            @markdownOptions={{hash markdownItRules=RULES}}
            @onSetup={{handleSetup}}
            @value="# title\n\n---\n\n<b>raw</b> **bold**"
          />
        </template>
      );

      assert.dom(".ProseMirror h1").doesNotExist("no heading");
      assert.dom(".ProseMirror hr").doesNotExist("no rule");
      assert.dom(".ProseMirror b").doesNotExist("no inline html");
      assert.dom(".ProseMirror strong").exists("emphasis still cooks");

      textManipulation.insertText("# typed");
      assert.dom(".ProseMirror h1").doesNotExist("the heading rule is off");
      assert.false(
        "heading" in textManipulation.view.state.schema.nodes,
        "the schema has no heading node"
      );
    });

    test("leaves out extensions whose feature the host doesn't cook", async function (assert) {
      await render(
        <template>
          <ProsemirrorEditor
            @markdownOptions={{hash featuresOverride=(array "emoji")}}
            @value=":smile: @sam"
          />
        </template>
      );

      assert.dom(".ProseMirror img.emoji").exists("emoji stays enabled");
      assert.dom(".ProseMirror a.mention").doesNotExist("mention is left out");
    });
  }
);
