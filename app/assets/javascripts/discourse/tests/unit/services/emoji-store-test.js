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

  test(".trackEmoji", function (assert) {
    this.emojiStore.trackEmoji("grinning");
    const storedEmojis = new KeyValueStore(STORE_NAMESPACE).getObject(
      USER_EMOJIS_STORE_KEY
    );

    assert.deepEqual(this.emojiStore.favorites, ["grinning"]);
    assert.deepEqual(
      storedEmojis,
      ["grinning"],
      "it persists the tracked emojis"
    );
  });

  test("limits the maximum number of tracked emojis", function (assert) {
    let trackedEmojis;
    Array.from({ length: 45 }).forEach(() => {
      trackedEmojis = this.emojiStore.trackEmoji("grinning");
    });

    assert.strictEqual(trackedEmojis.length, MAX_TRACKED_EMOJIS);
  });

  test("limits the maximum number of favorites emojis", function (assert) {
    Array.from({ length: 25 }).forEach((_, i) => {
      this.emojiStore.trackEmoji(`emoji_${i}`);
    });

    assert.strictEqual(this.emojiStore.favorites.length, MAX_DISPLAYED_EMOJIS);
  });

  test(".reset()", function (assert) {
    this.emojiStore.trackEmoji("grinning");

    this.emojiStore.reset();

    assert.deepEqual(this.emojiStore.favorites, []);
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

  test("favorites excludes denied emojis", function (assert) {
    const site = getOwner(this).lookup("service:site");
    site.set("denied_emojis", ["poo"]);

    this.emojiStore.trackEmoji("grinning");
    this.emojiStore.trackEmoji("poo");

    assert.deepEqual(this.emojiStore.favorites, ["grinning"]);
  });

  test("sort emojis by frequency", function (assert) {
    this.emojiStore.trackEmoji("grinning");
    this.emojiStore.trackEmoji("cat");
    this.emojiStore.trackEmoji("cat");
    this.emojiStore.trackEmoji("cat");
    this.emojiStore.trackEmoji("dog");
    this.emojiStore.trackEmoji("dog");

    assert.deepEqual(this.emojiStore.favorites, ["cat", "dog", "grinning"]);
  });
});
