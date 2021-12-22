import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

discourseModule("Unit | Utility | emoji-emojiStore", function (hooks) {
  hooks.beforeEach(function () {
    this.emojiStore = this.container.lookup("service:emoji-store");
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

  test("evented", function (assert) {
    let newFavorites;
    this.emojiStore.on("favorites-changed", (favorites) => {
      newFavorites = favorites;
    });
    this.emojiStore.track("otter");

    assert.deepEqual(newFavorites, ["otter"]);
  });
});
