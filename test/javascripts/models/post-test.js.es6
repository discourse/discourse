QUnit.module("Discourse.Post");

var buildPost = function(args) {
  return Discourse.Post.create(
    _.merge(
      {
        id: 1,
        can_delete: true,
        version: 1
      },
      args || {}
    )
  );
};

QUnit.test("defaults", assert => {
  var post = Discourse.Post.create({ id: 1 });
  assert.blank(post.get("deleted_at"), "it has no deleted_at by default");
  assert.blank(post.get("deleted_by"), "there is no deleted_by by default");
});

QUnit.test("new_user", assert => {
  var post = Discourse.Post.create({ trust_level: 0 });
  assert.ok(post.get("new_user"), "post is from a new user");

  post.set("trust_level", 1);
  assert.ok(!post.get("new_user"), "post is no longer from a new user");
});

QUnit.test("firstPost", assert => {
  var post = Discourse.Post.create({ post_number: 1 });
  assert.ok(post.get("firstPost"), "it's the first post");

  post.set("post_number", 10);
  assert.ok(!post.get("firstPost"), "post is no longer the first post");
});

QUnit.test("updateFromPost", assert => {
  var post = Discourse.Post.create({
    post_number: 1,
    raw: "hello world"
  });

  post.updateFromPost(
    Discourse.Post.create({
      raw: "different raw",
      wat: function() {
        return 123;
      }
    })
  );

  assert.equal(post.get("raw"), "different raw", "raw field updated");
});

QUnit.test("destroy by staff", assert => {
  var user = Discourse.User.create({ username: "staff", staff: true }),
    post = buildPost({ user: user });

  post.destroy(user);

  assert.present(post.get("deleted_at"), "it has a `deleted_at` field.");
  assert.equal(
    post.get("deleted_by"),
    user,
    "it has the user in the `deleted_by` field"
  );

  post.recover();
  assert.blank(
    post.get("deleted_at"),
    "it clears `deleted_at` when recovering"
  );
  assert.blank(
    post.get("deleted_by"),
    "it clears `deleted_by` when recovering"
  );
});

QUnit.test("destroy by non-staff", assert => {
  var originalCooked = "this is the original cooked value",
    user = Discourse.User.create({ username: "evil trout" }),
    post = buildPost({ user: user, cooked: originalCooked });

  return post.destroy(user).then(() => {
    assert.ok(
      !post.get("can_delete"),
      "the post can't be deleted again in this session"
    );
    assert.ok(
      post.get("cooked") !== originalCooked,
      "the cooked content changed"
    );
    assert.equal(post.get("version"), 2, "the version number increased");
  });
});
