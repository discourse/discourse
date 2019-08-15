QUnit.module("lib:emojis-store", {
  afterEach() {
    const store = Discourse.__container__.lookup("service:emojis-store");
    store.reset();
  }
});

QUnit.test("defaults", assert => {
  const store = Discourse.__container__.lookup("service:emojis-store");
  assert.deepEqual(store.favorites, []);
  assert.equal(store.diversity, 1);
});

QUnit.test("diversity", assert => {
  const store = Discourse.__container__.lookup("service:emojis-store");
  store.diversity = 2;
  assert.equal(store.diversity, 2);
});

QUnit.test("favorites", assert => {
  const store = Discourse.__container__.lookup("service:emojis-store");
  store.favorites = ["smile"];
  assert.deepEqual(store.favorites, ["smile"]);
});

QUnit.test("track", assert => {
  const store = Discourse.__container__.lookup("service:emojis-store");
  store.track("woman:t4");
  assert.deepEqual(store.favorites, ["woman:t4"]);
  store.track("otter");
  store.track(":otter:");
  assert.deepEqual(store.favorites, ["otter", "woman:t4"]);
});
