import EmojisStore from "discourse/lib/emojis-store";

QUnit.module("lib:emojis-store", {
  beforeEach() {
    EmojisStore.reset();
  }
});

QUnit.test("defaults", assert => {
  const store = new EmojisStore();
  assert.deepEqual(store.favorites, []);
  assert.equal(store.diversity, 1);
});

QUnit.test("diversity", assert => {
  const store = new EmojisStore();
  store.diversity = 2;
  assert.equal(store.diversity, 2);
});

QUnit.test("favorites", assert => {
  const store = new EmojisStore();
  store.favorites = ["smile"];
  assert.deepEqual(store.favorites, ["smile"]);
});

QUnit.test("track", assert => {
  const store = new EmojisStore();
  store.track("woman:t4");
  assert.deepEqual(store.favorites, ["woman:t4"]);
  store.track("otter");
  store.track(":otter:");
  assert.deepEqual(store.favorites, ["otter", "woman:t4"]);
});
