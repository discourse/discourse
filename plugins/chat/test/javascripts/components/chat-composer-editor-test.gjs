import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import Channel from "discourse/plugins/chat/discourse/components/chat/composer/channel";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

module("Component | chat-composer editor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/emojis.json", () => [200, [], {}]);
    this.channel = ChatChannel.create({
      chatable_type: "Category",
      title: "just-cats",
    });
  });

  test("renders the rich editor when the user prefers it", async function (assert) {
    this.currentUser.set(
      "user_option.composition_mode",
      USER_OPTION_COMPOSITION_MODES.rich
    );

    await render(<template><Channel @channel={{this.channel}} /></template>);

    assert.dom(".chat-composer__input.ProseMirror").exists();
    assert
      .dom(".chat-composer__input p")
      .hasAttribute("data-placeholder", "Chat in #just-cats");
    assert.dom("textarea.chat-composer__input").doesNotExist();
  });

  test("renders the markdown editor when the user prefers it", async function (assert) {
    this.currentUser.set(
      "user_option.composition_mode",
      USER_OPTION_COMPOSITION_MODES.markdown
    );

    await render(<template><Channel @channel={{this.channel}} /></template>);

    assert.dom("textarea.chat-composer__input").exists();
    assert.dom(".chat-composer__input.ProseMirror").doesNotExist();
  });

  test("switches editors and keeps the draft", async function (assert) {
    pretender.put("/u/eviltrout.json", () => response({ user: {} }));
    this.currentUser.set(
      "user_option.composition_mode",
      USER_OPTION_COMPOSITION_MODES.rich
    );
    this.channel.resetDraft(this.currentUser);
    this.channel.draft.message = "draft text";

    await render(<template><Channel @channel={{this.channel}} /></template>);

    assert.dom(".chat-composer__input.ProseMirror").hasText("draft text");

    document
      .querySelector(".chat-composer__input")
      .dispatchEvent(new KeyboardEvent("keydown", { key: "m", ctrlKey: true }));
    await settled();

    assert.dom("textarea.chat-composer__input").hasValue("draft text");
    assert.strictEqual(
      this.currentUser.user_option.composition_mode,
      USER_OPTION_COMPOSITION_MODES.markdown
    );
  });
});
