import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import { getOwner } from "discourse-common/lib/get-owner";

module("Unit | Service | emoji-store", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.emojiStore = getOwner(this).lookup("service:emoji-store");
    this.emojiStore.reset();
  });

  hooks.afterEach(function () {
    this.emojiStore.reset();
  });

  test("defaults", function (assert) {
    assert.deepEqual(this.emojiStore.favorites, []);
    assert.strictEqual(this.emojiStore.diversity, 1);
  });

  test("diversity", function (assert) {
    this.emojiStore.diversity = 2;
    assert.strictEqual(this.emojiStore.diversity, 2);
  });

  test("favorites", function (assert) {
    this.emojiStore.favorites = ["smile"];
    assert.deepEqual(this.emojiStore.favorites, ["smile"]);
  });

  test("track", function (assert) {
    this.emojiStore.track("woman:t4");
    assert.deepEqual(this.emojiStore.favorites, ["woman:t4"]);

    this.emojiStore.track("otter");
    this.emojiStore.track(":otter:");
    assert.deepEqual(this.emojiStore.favorites, ["otter", "woman:t4"]);
  });
});
