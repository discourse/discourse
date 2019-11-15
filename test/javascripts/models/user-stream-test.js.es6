import UserAction from "discourse/models/user-action";
import User from "discourse/models/user";

QUnit.module("model: UserStream");

QUnit.test("basics", assert => {
  var user = User.create({ id: 1, username: "eviltrout" });
  var stream = user.get("stream");
  assert.present(stream, "a user has a stream by default");
  assert.equal(stream.get("user"), user, "the stream points back to the user");

  assert.equal(stream.get("itemsLoaded"), 0, "no items are loaded by default");
  assert.blank(stream.get("content"), "no content by default");
  assert.blank(stream.get("filter"), "no filter by default");

  assert.ok(!stream.get("loaded"), "the stream is not loaded by default");
});

QUnit.test("filterParam", assert => {
  var user = User.create({ id: 1, username: "eviltrout" });
  var stream = user.get("stream");

  // defaults to posts/topics
  assert.equal(stream.get("filterParam"), "4,5");

  stream.set("filter", UserAction.TYPES.likes_given);
  assert.equal(stream.get("filterParam"), UserAction.TYPES.likes_given);

  stream.set("filter", UserAction.TYPES.replies);
  assert.equal(stream.get("filterParam"), "6,9");
});
