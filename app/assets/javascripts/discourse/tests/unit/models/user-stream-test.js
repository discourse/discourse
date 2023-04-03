import { module, test } from "qunit";
import User from "discourse/models/user";
import UserAction from "discourse/models/user-action";
import { setupTest } from "ember-qunit";

module("Unit | Model | user-stream", function (hooks) {
  setupTest(hooks);

  test("basics", function (assert) {
    const user = User.create({ id: 1, username: "eviltrout" });
    const stream = user.stream;
    assert.present(stream, "a user has a stream by default");
    assert.strictEqual(stream.user, user, "the stream points back to the user");

    assert.strictEqual(stream.itemsLoaded, 0, "no items are loaded by default");
    assert.blank(stream.content, "no content by default");
    assert.blank(stream.filter, "no filter by default");

    assert.ok(!stream.loaded, "the stream is not loaded by default");
  });

  test("filterParam", function (assert) {
    const user = User.create({ id: 1, username: "eviltrout" });
    const stream = user.stream;

    // defaults to posts/topics
    assert.strictEqual(stream.filterParam, "4,5");

    stream.set("filter", UserAction.TYPES.topics);
    assert.strictEqual(stream.filterParam, 4);

    stream.set("filter", UserAction.TYPES.likes_given);
    assert.strictEqual(stream.filterParam, UserAction.TYPES.likes_given);

    stream.set("filter", UserAction.TYPES.replies);
    assert.strictEqual(stream.filterParam, "6,9");
  });
});
