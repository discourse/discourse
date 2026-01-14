import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  logIn,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Unit | chat-message-interactor", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    logIn(getOwner(this));
    const message = new ChatFabricators(getOwner(this)).message();
    this.messageInteractor = new ChatMessageInteractor(getOwner(this), message);
    this.emojiStore = getOwner(this).lookup("service:emoji-store");
    this.siteSettings = getOwner(this).lookup("service:site-settings");
  });

  test("emojiReactions with no option uses site default", function (assert) {
    assert.deepEqual(
      this.messageInteractor.emojiReactions.map((r) => r.emoji),
      ["+1", "heart", "tada"]
    );
  });

  test("emojiReactions empty when no frequent or site defaults", function (assert) {
    this.siteSettings.default_emoji_reactions = "";

    assert.deepEqual(this.messageInteractor.emojiReactions, []);
  });

  test("emojiReactions with user option frequent falls back to site defaults", function (assert) {
    updateCurrentUser({
      user_option: {
        chat_quick_reaction_type: "frequent",
      },
    });

    assert.deepEqual(
      this.messageInteractor.emojiReactions.map((r) => r.emoji),
      ["+1", "heart", "tada"]
    );
  });

  test("emojiReactions with diversity set applies to site defaults", function (assert) {
    updateCurrentUser({
      user_option: {
        chat_quick_reaction_type: "frequent",
      },
    });

    this.emojiStore.diversity = 2;

    assert.deepEqual(
      this.messageInteractor.emojiReactions.map((r) => r.emoji),
      ["+1:t2", "heart", "tada"]
    );
  });

  test("emojiReactions with top 3 frequent", function (assert) {
    this.emojiStore.trackEmojiForContext("eyes", "chat");
    this.emojiStore.trackEmojiForContext("camera", "chat");
    this.emojiStore.trackEmojiForContext("butterfly", "chat");
    this.emojiStore.trackEmojiForContext("butterfly", "chat");
    this.emojiStore.trackEmojiForContext("laptop", "chat");

    assert.deepEqual(
      this.messageInteractor.emojiReactions.map((r) => r.emoji),
      ["butterfly", "laptop", "camera"]
    );
  });

  test("emojiReactions with 1 frequent falls back to system", function (assert) {
    this.emojiStore.trackEmojiForContext("butterfly", "chat");

    assert.deepEqual(
      this.messageInteractor.emojiReactions.map((r) => r.emoji),
      ["butterfly", "+1", "heart"]
    );
  });

  test("emojiReactions uses custom user option", function (assert) {
    updateCurrentUser({
      user_option: {
        chat_quick_reaction_type: "custom",
        chat_quick_reactions_custom: "grin|fearful|angry",
      },
    });

    assert.deepEqual(
      this.messageInteractor.emojiReactions.map((r) => r.emoji),
      ["grin", "fearful", "angry"]
    );
  });

  test("emojiReactions does not use custom if set to frequent", function (assert) {
    updateCurrentUser({
      user_option: {
        chat_quick_reaction_type: "frequent",
        chat_quick_reactions_custom: "grin|fearful|angry",
      },
    });

    assert.deepEqual(
      this.messageInteractor.emojiReactions.map((r) => r.emoji),
      ["+1", "heart", "tada"]
    );
  });

  test("emojiReactions avoids duplicates from frequent and site", function (assert) {
    this.emojiStore.trackEmojiForContext("+1", "chat");

    assert.deepEqual(
      this.messageInteractor.emojiReactions.map((r) => r.emoji),
      ["+1", "heart", "tada"]
    );
  });

  test("emojiReactions avoids duplicates from custom + frequent + site", function (assert) {
    updateCurrentUser({
      user_option: {
        chat_quick_reaction_type: "custom",
        chat_quick_reactions_custom: "+1|+1|+1",
      },
    });
    this.emojiStore.trackEmojiForContext("+1", "chat");
    this.emojiStore.trackEmojiForContext("butterfly", "chat");

    assert.deepEqual(
      this.messageInteractor.emojiReactions.map((r) => r.emoji),
      ["+1", "butterfly", "heart"]
    );
  });
});
