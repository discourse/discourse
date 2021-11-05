import { module, test } from "qunit";
import User from "discourse/models/user";
import UserAction from "discourse/models/user-action";

module("Unit | Model | user-stream", function () {
  test("basics", function (assert) {
    let user = User.create({ id: 1, username: "eviltrout" });
    let stream = user.get("stream");
    assert.present(stream, "a user has a stream by default");
    assert.strictEqual(
      stream.get("user"),
      user,
      "the stream points back to the user"
    );

    assert.strictEqual(
      stream.get("itemsLoaded"),
      0,
      "no items are loaded by default"
    );
    assert.blank(stream.get("content"), "no content by default");
    assert.blank(stream.get("filter"), "no filter by default");

    assert.ok(!stream.get("loaded"), "the stream is not loaded by default");
  });

  test("filterParam", function (assert) {
    let user = User.create({ id: 1, username: "eviltrout" });
    let stream = user.get("stream");

    // defaults to posts/topics
    assert.strictEqual(stream.get("filterParam"), "4,5");

    stream.set("filter", UserAction.TYPES.topics);
    assert.strictEqual(stream.get("filterParam"), 4);

    stream.set("filter", UserAction.TYPES.likes_given);
    assert.strictEqual(stream.get("filterParam"), UserAction.TYPES.likes_given);

    stream.set("filter", UserAction.TYPES.replies);
    assert.strictEqual(stream.get("filterParam"), "6,9");
  });
});
