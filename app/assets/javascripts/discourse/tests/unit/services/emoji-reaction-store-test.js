import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Discourse Chat | Unit | emoji-reaction-store", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = getOwner(this).lookup("service:site-settings");
    this.emojiReactionStore = getOwner(this).lookup(
      "service:emoji-reaction-store"
    );

    this.emojiReactionStore.siteSettings = this.siteSettings;
    this.emojiReactionStore.reset();
  });

  hooks.afterEach(function () {
    this.emojiReactionStore.reset();
  });

  test("defaults", function (assert) {
    assert.deepEqual(
      this.emojiReactionStore.favorites,
      this.siteSettings.default_emoji_reactions.split("|").filter((val) => val)
    );
  });

  test("diversity", function (assert) {
    assert.strictEqual(this.emojiReactionStore.diversity, 1);

    this.emojiReactionStore.diversity = 2;

    assert.strictEqual(this.emojiReactionStore.diversity, 2);
  });

  test("#favorites with defaults", function (assert) {
    this.siteSettings.default_emoji_reactions = "smile|heart|tada";

    assert.deepEqual(this.emojiReactionStore.favorites, [
      "smile",
      "heart",
      "tada",
    ]);
  });

  test("#favorites", function (assert) {
    this.emojiReactionStore.storedFavorites = ["grinning"];

    assert.deepEqual(this.emojiReactionStore.favorites, ["grinning"]);
  });

  test("#favorites when tracking multiple times the same emoji", function (assert) {
    this.emojiReactionStore.storedFavorites = [
      "grinning",
      "yum",
      "not_yum",
      "yum",
    ];

    assert.deepEqual(
      this.emojiReactionStore.favorites,
      ["yum", "grinning", "not_yum"],
      "it favors count over order"
    );
  });

  test("#favorites when reaching displayed limit", function (assert) {
    this.emojiReactionStore.storedFavorites = [];
    [...Array(this.emojiReactionStore.MAX_TRACKED_EMOJIS)].forEach(
      (_, index) => {
        this.emojiReactionStore.track("yum" + index);
      }
    );
    this.emojiReactionStore.track("grinning");

    assert.strictEqual(
      this.emojiReactionStore.favorites.length,
      this.emojiReactionStore.MAX_DISPLAYED_EMOJIS,
      "it enforces the max length"
    );
  });

  test("#storedFavorites", function (assert) {
    this.emojiReactionStore.storedFavorites = [];
    this.emojiReactionStore.track("yum");

    assert.deepEqual(
      this.emojiReactionStore.storedFavorites,
      ["yum"].concat(this.siteSettings.default_emoji_reactions.split("|"))
    );
  });

  test("#storedFavorites when tracking different emojis", function (assert) {
    this.emojiReactionStore.storedFavorites = [];
    this.emojiReactionStore.track("yum");
    this.emojiReactionStore.track("not_yum");
    this.emojiReactionStore.track("yum");
    this.emojiReactionStore.track("grinning");

    assert.deepEqual(
      this.emojiReactionStore.storedFavorites,
      ["grinning", "yum", "not_yum", "yum"].concat(
        this.siteSettings.default_emoji_reactions.split("|")
      ),
      "it ensures last in is first"
    );
  });

  test("#storedFavorites when tracking an emoji after reaching the limit", function (assert) {
    this.emojiReactionStore.storedFavorites = [];
    [...Array(this.emojiReactionStore.MAX_TRACKED_EMOJIS)].forEach(() => {
      this.emojiReactionStore.track("yum");
    });
    this.emojiReactionStore.track("grinning");

    assert.strictEqual(
      this.emojiReactionStore.storedFavorites.length,
      this.emojiReactionStore.MAX_TRACKED_EMOJIS,
      "it enforces the max length"
    );
    assert.strictEqual(
      this.emojiReactionStore.storedFavorites.firstObject,
      "grinning",
      "it correctly stores the last tracked emoji"
    );
  });
});
