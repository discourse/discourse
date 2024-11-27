import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Model | post", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
  });

  test("defaults", function (assert) {
    const post = this.store.createRecord("post", { id: 1 });
    assert.blank(post.deleted_at, "it has no deleted_at by default");
    assert.blank(post.deleted_by, "there is no deleted_by by default");
  });

  test("new_user", function (assert) {
    const post = this.store.createRecord("post", { trust_level: 0 });
    assert.ok(post.new_user, "post is from a new user");

    post.set("trust_level", 1);
    assert.ok(!post.new_user, "post is no longer from a new user");
  });

  test("firstPost", function (assert) {
    const post = this.store.createRecord("post", { post_number: 1 });
    assert.ok(post.firstPost, "it's the first post");

    post.set("post_number", 10);
    assert.ok(!post.firstPost, "post is no longer the first post");
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

    assert.strictEqual(post.raw, "different raw", "raw field updated");
  });

  test("destroy by staff", async function (assert) {
    const user = this.store.createRecord("user", {
      username: "staff",
      moderator: true,
    });
    const post = this.store.createRecord("post", {
      id: 1,
      can_delete: true,
      version: 1,
      user,
    });

    await post.destroy(user);

    assert.present(post.deleted_at, "it has a `deleted_at` field.");
    assert.strictEqual(
      post.deleted_by,
      user,
      "it has the user in the `deleted_by` field"
    );

    await post.recover();

    assert.blank(post.deleted_at, "it clears `deleted_at` when recovering");
    assert.blank(post.deleted_by, "it clears `deleted_by` when recovering");
  });

  test("destroy by non-staff", async function (assert) {
    const originalCooked = "this is the original cooked value";
    const user = this.store.createRecord("user", { username: "evil trout" });
    const post = this.store.createRecord("post", {
      id: 1,
      can_delete: true,
      version: 1,
      user,
      cooked: originalCooked,
    });

    await post.destroy(user);

    assert.ok(
      !post.can_delete,
      "the post can't be deleted again in this session"
    );
    assert.ok(post.cooked !== originalCooked, "the cooked content changed");
    assert.strictEqual(post.version, 2, "the version number increased");
  });

  test("likeAction", function (assert) {
    const post = this.store.createRecord("post", {
      id: 1173,
    });

    post.likeAction = { count: 1 };
    assert.deepEqual(post.likeAction, { count: 1 }, "likeAction set");

    // creating a new record with the same id should reset the likeAction in the original post because instance
    // is cached and the information required to properly generate the field is not available in the new JSON data
    this.store.createRecord("post", {
      id: 1173,
    });

    assert.ok(post.likeAction === null, "likeAction was reset to null");
  });
});
