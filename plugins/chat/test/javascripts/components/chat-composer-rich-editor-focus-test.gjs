import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import loadRichEditor from "discourse/lib/load-rich-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import RichEditorInteractor from "discourse/plugins/chat/discourse/lib/rich-editor-interactor";

module(
  "Integration | Component | chat composer - rich editor focus requests",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a key typed while the editor loads is added to the draft", async function (assert) {
      const ProsemirrorEditor = await loadRichEditor();
      const owner = getOwner(this);
      const composer = owner.lookup("service:chat-channel-composer");
      let value = "saved draft";

      composer.awaitEditor();
      composer.focus({ addText: "x" });

      const onChange = (event) => (value = event.target.value);
      const onSetup = (textManipulation) => {
        const interactor = new RichEditorInteractor(owner, textManipulation);
        composer.registerEditor(interactor);
        return () => composer.unregisterEditor(interactor);
      };

      await render(
        <template>
          <ProsemirrorEditor
            @change={{onChange}}
            @onSetup={{onSetup}}
            @value="saved draft"
          />
        </template>
      );

      assert.strictEqual(value, "saved draftx", "the key follows the draft");
    });
  }
);
