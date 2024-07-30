import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Model | pending-post", function (hooks) {
  setupTest(hooks);

  test("Properties", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category = store.createRecord("category", { id: 2 });
    const post = store.createRecord("pending-post", {
      id: 1,
      topic_url: "topic-url",
      username: "USERNAME",
      category_id: 2,
    });

    // pending-post initializer performs async operations
    await settled();

    assert.strictEqual(
      post.postUrl,
      "topic-url",
      "topic_url is aliased to postUrl"
    );
    assert.false(post.truncated, "truncated is always false");
    assert.strictEqual(
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

  test("it cooks raw_text", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const post = store.createRecord("pending-post", {
      raw_text: "**bold text**",
    });

    // pending-post initializer performs async operations
    await settled();

    assert.strictEqual(
      post.expandedExcerpt.toString(),
      "<p><strong>bold text</strong></p>"
    );
  });
});
