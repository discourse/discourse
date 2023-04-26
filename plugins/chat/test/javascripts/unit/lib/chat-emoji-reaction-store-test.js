import { module, test } from "qunit";
import { getOwner } from "discourse-common/lib/get-owner";

module("Discourse Chat | Unit | chat-emoji-reaction-store", function (hooks) {
  hooks.beforeEach(function () {
    this.siteSettings = getOwner(this).lookup("service:site-settings");
    this.chatEmojiReactionStore = getOwner(this).lookup(
      "service:chat-emoji-reaction-store"
    );

    this.chatEmojiReactionStore.siteSettings = this.siteSettings;
    this.chatEmojiReactionStore.reset();
  });

  hooks.afterEach(function () {
    this.chatEmojiReactionStore.reset();
  });

  test("defaults", function (assert) {
    assert.deepEqual(
      this.chatEmojiReactionStore.favorites,
      this.siteSettings.default_emoji_reactions.split("|").filter((val) => val)
    );
  });

  test("diversity", function (assert) {
    assert.strictEqual(this.chatEmojiReactionStore.diversity, 1);

    this.chatEmojiReactionStore.diversity = 2;

    assert.strictEqual(this.chatEmojiReactionStore.diversity, 2);
  });

  test("#favorites with defaults", function (assert) {
    this.siteSettings.default_emoji_reactions = "smile|heart|tada";

    assert.deepEqual(this.chatEmojiReactionStore.favorites, [
      "smile",
      "heart",
      "tada",
    ]);
  });

  test("#favorites", function (assert) {
    this.chatEmojiReactionStore.storedFavorites = ["grinning"];

    assert.deepEqual(this.chatEmojiReactionStore.favorites, ["grinning"]);
  });

  test("#favorites when tracking multiple times the same emoji", function (assert) {
    this.chatEmojiReactionStore.storedFavorites = [
      "grinning",
      "yum",
      "not_yum",
      "yum",
    ];

    assert.deepEqual(
      this.chatEmojiReactionStore.favorites,
      ["yum", "grinning", "not_yum"],
      "it favors count over order"
    );
  });

  test("#favorites when reaching displayed limit", function (assert) {
    this.chatEmojiReactionStore.storedFavorites = [];
    [...Array(this.chatEmojiReactionStore.MAX_TRACKED_EMOJIS)].forEach(
      (_, index) => {
        this.chatEmojiReactionStore.track("yum" + index);
      }
    );
    this.chatEmojiReactionStore.track("grinning");

    assert.strictEqual(
      this.chatEmojiReactionStore.favorites.length,
      this.chatEmojiReactionStore.MAX_DISPLAYED_EMOJIS,
      "it enforces the max length"
    );
  });

  test("#storedFavorites", function (assert) {
    this.chatEmojiReactionStore.storedFavorites = [];
    this.chatEmojiReactionStore.track("yum");

    assert.deepEqual(
      this.chatEmojiReactionStore.storedFavorites,
      ["yum"].concat(this.siteSettings.default_emoji_reactions.split("|"))
    );
  });

  test("#storedFavorites when tracking different emojis", function (assert) {
    this.chatEmojiReactionStore.storedFavorites = [];
    this.chatEmojiReactionStore.track("yum");
    this.chatEmojiReactionStore.track("not_yum");
    this.chatEmojiReactionStore.track("yum");
    this.chatEmojiReactionStore.track("grinning");

    assert.deepEqual(
      this.chatEmojiReactionStore.storedFavorites,
      ["grinning", "yum", "not_yum", "yum"].concat(
        this.siteSettings.default_emoji_reactions.split("|")
      ),
      "it ensures last in is first"
    );
  });

  test("#storedFavorites when tracking an emoji after reaching the limit", function (assert) {
    this.chatEmojiReactionStore.storedFavorites = [];
    [...Array(this.chatEmojiReactionStore.MAX_TRACKED_EMOJIS)].forEach(() => {
      this.chatEmojiReactionStore.track("yum");
    });
    this.chatEmojiReactionStore.track("grinning");

    assert.strictEqual(
      this.chatEmojiReactionStore.storedFavorites.length,
      this.chatEmojiReactionStore.MAX_TRACKED_EMOJIS,
      "it enforces the max length"
    );
    assert.strictEqual(
      this.chatEmojiReactionStore.storedFavorites.firstObject,
      "grinning",
      "it correctly stores the last tracked emoji"
    );
  });
});
