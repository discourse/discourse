import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";
import {
  MAX_DISPLAYED_EMOJIS,
  MAX_TRACKED_EMOJIS,
  SKIN_TONE_STORE_KEY,
  STORE_NAMESPACE,
  USER_EMOJIS_STORE_KEY,
} from "discourse/services/emoji-store";

module("Unit | Service | emoji-store", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.emojiStore = getOwner(this).lookup("service:emoji-store");
  });

  hooks.afterEach(function () {
    this.emojiStore.reset();
  });

  test(".favoritesForContext", function (assert) {
    assert.deepEqual(this.emojiStore.favoritesForContext("topic"), [
      "+1",
      "heart",
      "tada",
    ]);
  });

  test(".trackEmojiForContext", function (assert) {
    this.emojiStore.trackEmojiForContext("grinning", "topic");
    const storedEmojis = new KeyValueStore(STORE_NAMESPACE).getObject(
      `topic_${USER_EMOJIS_STORE_KEY}`
    );

    assert.deepEqual(this.emojiStore.favoritesForContext("topic"), [
      "grinning",
      "+1",
      "heart",
      "tada",
    ]);
    assert.deepEqual(
      storedEmojis,
      ["grinning", "+1", "heart", "tada"],
      "it persists the tracked emojis"
    );
  });

  test("limits the maximum number of tracked emojis", function (assert) {
    let trackedEmojis;
    Array.from({ length: 45 }).forEach(() => {
      trackedEmojis = this.emojiStore.trackEmojiForContext("grinning", "topic");
    });

    assert.strictEqual(trackedEmojis.length, MAX_TRACKED_EMOJIS);
  });

  test("limits the maximum number of favorites emojis", function (assert) {
    Array.from({ length: 25 }).forEach((_, i) => {
      this.emojiStore.trackEmojiForContext(`emoji_${i}`, "topic");
    });

    assert.strictEqual(
      this.emojiStore.favoritesForContext("topic").length,
      MAX_DISPLAYED_EMOJIS
    );
  });

  test("support for multiple contexts", function (assert) {
    this.emojiStore.trackEmojiForContext("grinning", "topic");

    assert.deepEqual(this.emojiStore.favoritesForContext("topic"), [
      "grinning",
      "+1",
      "heart",
      "tada",
    ]);

    this.emojiStore.trackEmojiForContext("cat", "chat");

    assert.deepEqual(this.emojiStore.favoritesForContext("chat"), [
      "cat",
      "+1",
      "heart",
      "tada",
    ]);
  });

  test(".resetContext", function (assert) {
    this.emojiStore.trackEmojiForContext("grinning", "topic");

    this.emojiStore.resetContext("topic");

    assert.deepEqual(this.emojiStore.favoritesForContext("topic"), [
      "+1",
      "heart",
      "tada",
    ]);
  });

  test(".diversity", function (assert) {
    assert.deepEqual(this.emojiStore.diversity, 1);
  });

  test(".diversity=", function (assert) {
    this.emojiStore.diversity = 2;
    const storedDiversity = new KeyValueStore(STORE_NAMESPACE).getObject(
      SKIN_TONE_STORE_KEY
    );

    assert.deepEqual(this.emojiStore.diversity, 2);
    assert.deepEqual(storedDiversity, 2, "it persists the diversity value");
  });

  test("sort emojis by frequency", function (assert) {
    this.emojiStore.trackEmojiForContext("cat", "topic");
    this.emojiStore.trackEmojiForContext("cat", "topic");
    this.emojiStore.trackEmojiForContext("cat", "topic");
    this.emojiStore.trackEmojiForContext("dog", "topic");
    this.emojiStore.trackEmojiForContext("dog", "topic");

    assert.deepEqual(this.emojiStore.favoritesForContext("topic"), [
      "cat",
      "dog",
      "+1",
      "heart",
      "tada",
    ]);
  });
});
