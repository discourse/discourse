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

  test("temporarily replaces the formatting bar with link controls on narrow screens", async function (assert) {
    this.owner.lookup("service:chat-formatting-bar").shown = true;
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
    const { view } = this.owner.lookup("service:chat-thread-composer").editor;
    view.dispatch(
      view.state.tr.setSelection(
        view.state.selection.constructor.create(view.state.doc, 3)
      )
    );
    await settled();

    assert
      .dom(".chat-composer__contextual-toolbar .composer-link-toolbar__edit")
      .exists("link editing is available on narrow screens");
    assert
      .dom(".chat-composer__formatting-bar")
      .doesNotExist("contextual controls take precedence");
    await click(
      ".chat-composer__contextual-toolbar .composer-link-toolbar__unlink"
    );

    assert
      .dom(".chat-composer__input a")
      .doesNotExist("unlink removes the mark");
    assert
      .dom(".chat-composer__contextual-toolbar")
      .doesNotExist("the contextual controls close when the link is removed");
    assert
      .dom(".chat-composer__formatting-bar")
      .exists("the preferred formatting bar is restored");
    assert.strictEqual(
      this.draft.message,
      "example after",
      "the draft retains the link text"
    );
  });
});
