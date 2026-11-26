import { click, render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatComposerPendingThread from "discourse/plugins/chat/discourse/components/chat/composer/pending-thread";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

module("Component | ChatComposer | ContextualToolbar", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_composer_picker_and_rich_chat = true;
    this.currentUser.set(
      "user_option.composition_mode",
      USER_OPTION_COMPOSITION_MODES.rich
    );
    sinon
      .stub(this.owner.lookup("service:capabilities"), "viewport")
      .value({ sm: false });
    this.channel = new ChatFabricators(this.owner).channel();
    this.draft = ChatMessage.createDraftMessage(this.channel, {
      user: this.currentUser,
      message: "[example](https://example.com) after",
    });
    this.pane = { sending: false };
    this.site.hashtag_configurations = { "chat-composer": [] };
  });

  test("offers link controls on narrow screens and removes the link", async function (assert) {
    await render(
      <template>
        <ChatComposerPendingThread
          @channel={{this.channel}}
          @draft={{this.draft}}
          @pane={{this.pane}}
        />
      </template>
    );
    await waitFor(".chat-composer__input.ProseMirror");
    const { view } = this.owner.lookup("service:chat-thread-composer").editor
      .textManipulation;
    view.dispatch(
      view.state.tr.setSelection(
        view.state.selection.constructor.create(view.state.doc, 3)
      )
    );
    await settled();

    assert
      .dom(".chat-composer__contextual-toolbar .composer-link-toolbar__edit")
      .exists("link editing is available without a formatting bar");
    await click(
      ".chat-composer__contextual-toolbar .composer-link-toolbar__unlink"
    );

    assert
      .dom(".chat-composer__input a")
      .doesNotExist("unlink removes the mark");
    assert
      .dom(".chat-composer__contextual-toolbar")
      .doesNotExist("the contextual controls close when the link is removed");
    assert.strictEqual(
      this.draft.message,
      "example after",
      "the draft retains the link text"
    );
  });
});
