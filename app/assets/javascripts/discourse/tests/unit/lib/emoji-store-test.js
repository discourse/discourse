import { discourseModule } from "discourse/tests/helpers/qunit-helpers";

discourseModule("lib:emoji-emojiStore", {
  beforeEach() {
    this.emojiStore = this.container.lookup("service:emoji-store");
    this.emojiStore.reset();
  },
  afterEach() {
    this.emojiStore.reset();
  },
});

QUnit.test("defaults", function (assert) {
  assert.deepEqual(this.emojiStore.favorites, []);
  assert.equal(this.emojiStore.diversity, 1);
});

QUnit.test("diversity", function (assert) {
  this.emojiStore.diversity = 2;
  assert.equal(this.emojiStore.diversity, 2);
});

QUnit.test("favorites", function (assert) {
  this.emojiStore.favorites = ["smile"];
  assert.deepEqual(this.emojiStore.favorites, ["smile"]);
});

QUnit.test("track", function (assert) {
  this.emojiStore.track("woman:t4");
  assert.deepEqual(this.emojiStore.favorites, ["woman:t4"]);
  this.emojiStore.track("otter");
  this.emojiStore.track(":otter:");
  assert.deepEqual(this.emojiStore.favorites, ["otter", "woman:t4"]);
});
