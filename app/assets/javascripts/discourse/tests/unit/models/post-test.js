import { module, test } from "qunit";
import User from "discourse/models/user";
import { getOwner } from "discourse-common/lib/get-owner";

module("Unit | Model | post", function (hooks) {
  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
  });

  test("defaults", function (assert) {
    const post = this.store.createRecord("post", { id: 1 });
    assert.blank(post.get("deleted_at"), "it has no deleted_at by default");
    assert.blank(post.get("deleted_by"), "there is no deleted_by by default");
  });

  test("new_user", function (assert) {
    const post = this.store.createRecord("post", { trust_level: 0 });
    assert.ok(post.get("new_user"), "post is from a new user");

    post.set("trust_level", 1);
    assert.ok(!post.get("new_user"), "post is no longer from a new user");
  });

  test("firstPost", function (assert) {
    const post = this.store.createRecord("post", { post_number: 1 });
    assert.ok(post.get("firstPost"), "it's the first post");

    post.set("post_number", 10);
    assert.ok(!post.get("firstPost"), "post is no longer the first post");
  });

  test("updateFromPost", function (assert) {
    const post = this.store.createRecord("post", {
      post_number: 1,
      raw: "hello world",
    });

    post.updateFromPost(
      this.store.createRecord("post", {
        raw: "different raw",
      })
    );

    assert.strictEqual(post.get("raw"), "different raw", "raw field updated");
  });

  test("destroy by staff", async function (assert) {
    const user = User.create({ username: "staff", moderator: true });
    const post = this.store.createRecord("post", {
      id: 1,
      can_delete: true,
      version: 1,
      user,
    });

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
    const post = this.store.createRecord("post", {
      id: 1,
      can_delete: true,
      version: 1,
      user,
      cooked: originalCooked,
    });

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
