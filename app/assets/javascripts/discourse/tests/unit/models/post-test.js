import { module, test } from "qunit";
import Post from "discourse/models/post";
import User from "discourse/models/user";
import { deepMerge } from "discourse-common/lib/object";

function buildPost(args) {
  return Post.create(
    deepMerge(
      {
        id: 1,
        can_delete: true,
        version: 1,
      },
      args || {}
    )
  );
}

module("Unit | Model | post", function () {
  test("defaults", function (assert) {
    let post = Post.create({ id: 1 });
    assert.blank(post.get("deleted_at"), "it has no deleted_at by default");
    assert.blank(post.get("deleted_by"), "there is no deleted_by by default");
  });

  test("new_user", function (assert) {
    let post = Post.create({ trust_level: 0 });
    assert.ok(post.get("new_user"), "post is from a new user");

    post.set("trust_level", 1);
    assert.ok(!post.get("new_user"), "post is no longer from a new user");
  });

  test("firstPost", function (assert) {
    let post = Post.create({ post_number: 1 });
    assert.ok(post.get("firstPost"), "it's the first post");

    post.set("post_number", 10);
    assert.ok(!post.get("firstPost"), "post is no longer the first post");
  });

  test("updateFromPost", function (assert) {
    let post = Post.create({
      post_number: 1,
      raw: "hello world",
    });

    post.updateFromPost(
      Post.create({
        raw: "different raw",
        wat: function () {
          return 123;
        },
      })
    );

    assert.strictEqual(post.get("raw"), "different raw", "raw field updated");
  });

  test("destroy by staff", async function (assert) {
    let user = User.create({ username: "staff", moderator: true });
    let post = buildPost({ user });

    await post.destroy(user);

    assert.present(post.get("deleted_at"), "it has a `deleted_at` field.");
    assert.strictEqual(
      post.get("deleted_by"),
      user,
      "it has the user in the `deleted_by` field"
    );

    await post.recover();

    assert.blank(
      post.get("deleted_at"),
      "it clears `deleted_at` when recovering"
    );
    assert.blank(
      post.get("deleted_by"),
      "it clears `deleted_by` when recovering"
    );
  });

  test("destroy by non-staff", async function (assert) {
    const originalCooked = "this is the original cooked value";
    const user = User.create({ username: "evil trout" });
    const post = buildPost({ user, cooked: originalCooked });

    await post.destroy(user);

    assert.ok(
      !post.get("can_delete"),
      "the post can't be deleted again in this session"
    );
    assert.ok(
      post.get("cooked") !== originalCooked,
      "the cooked content changed"
    );
    assert.strictEqual(post.get("version"), 2, "the version number increased");
  });
});
