import { module, test } from "qunit";
import PendingPost from "discourse/models/pending-post";
import createStore from "discourse/tests/helpers/create-store";
import { run } from "@ember/runloop";

module("Unit | Model | pending-post", function () {
  test("Properties", function (assert) {
    const store = createStore();
    const category = store.createRecord("category", { id: 2 });
    const post = PendingPost.create({
      id: 1,
      topic_url: "topic-url",
      username: "USERNAME",
      category_id: 2,
    });
    assert.equal(post.postUrl, "topic-url", "topic_url is aliased to postUrl");
    assert.equal(post.truncated, false, "truncated is always false");
    assert.equal(
      post.userUrl,
      "/u/username",
      "it returns user URL from the username"
    );
    assert.strictEqual(
      post.category,
      category,
      "it returns the proper category object based on category_id"
    );
  });
  test("it cooks raw_text", function (assert) {
    const post = run(() => PendingPost.create({ raw_text: "**bold text**" }));
    assert.equal(
      post.expandedExcerpt.string,
      "<p><strong>bold text</strong></p>"
    );
  });
});
