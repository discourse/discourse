import AppEvents from "discourse/lib/app-events";
import Topic from "discourse/models/topic";

moduleFor("controller:topic", "controller:topic", {
  needs: ["controller:composer", "controller:application"],
  beforeEach() {
    this.registry.register("app-events:main", AppEvents.create(), {
      instantiate: false
    });
    this.registry.injection("controller", "appEvents", "app-events:main");
  }
});

QUnit.test("editTopic", function(assert) {
  const model = Topic.create();
  const controller = this.subject({ model });

  assert.not(controller.get("editingTopic"), "we are not editing by default");

  controller.set("model.details.can_edit", false);
  controller.send("editTopic");

  assert.not(
    controller.get("editingTopic"),
    "calling editTopic doesn't enable editing unless the user can edit"
  );

  controller.set("model.details.can_edit", true);
  controller.send("editTopic");

  assert.ok(
    controller.get("editingTopic"),
    "calling editTopic enables editing if the user can edit"
  );
  assert.equal(controller.get("buffered.title"), model.get("title"));
  assert.equal(
    controller.get("buffered.category_id"),
    model.get("category_id")
  );

  controller.send("cancelEditingTopic");

  assert.not(
    controller.get("editingTopic"),
    "cancelling edit mode reverts the property value"
  );
});

QUnit.test("toggleMultiSelect", function(assert) {
  const model = Topic.create();
  const controller = this.subject({ model });

  assert.not(
    controller.get("multiSelect"),
    "multi selection mode is disabled by default"
  );

  controller.get("selectedPostIds").pushObject(1);
  assert.equal(controller.get("selectedPostIds.length"), 1);

  controller.send("toggleMultiSelect");

  assert.ok(
    controller.get("multiSelect"),
    "calling 'toggleMultiSelect' once enables multi selection mode"
  );
  assert.equal(
    controller.get("selectedPostIds.length"),
    0,
    "toggling 'multiSelect' clears 'selectedPostIds'"
  );

  controller.get("selectedPostIds").pushObject(2);
  assert.equal(controller.get("selectedPostIds.length"), 1);

  controller.send("toggleMultiSelect");

  assert.not(
    controller.get("multiSelect"),
    "calling 'toggleMultiSelect' twice disables multi selection mode"
  );
  assert.equal(
    controller.get("selectedPostIds.length"),
    0,
    "toggling 'multiSelect' clears 'selectedPostIds'"
  );
});

QUnit.test("selectedPosts", function(assert) {
  const postStream = { posts: [{ id: 1 }, { id: 2 }, { id: 3 }] };
  const model = Topic.create({ postStream });
  const controller = this.subject({ model });

  controller.set("selectedPostIds", [1, 2, 42]);

  assert.equal(
    controller.get("selectedPosts.length"),
    2,
    "selectedPosts only contains already loaded posts"
  );
  assert.not(
    controller.get("selectedPosts").some(p => p === undefined),
    "selectedPosts only contains valid post objects"
  );
});

QUnit.test("selectedAllPosts", function(assert) {
  const postStream = { stream: [1, 2, 3] };
  const model = Topic.create({ postStream });
  const controller = this.subject({ model });

  controller.set("selectedPostIds", [1, 2]);

  assert.not(controller.get("selectedAllPosts"), "not all posts are selected");

  controller.get("selectedPostIds").pushObject(3);

  assert.ok(controller.get("selectedAllPosts"), "all posts are selected");

  controller.get("selectedPostIds").pushObject(42);

  assert.ok(
    controller.get("selectedAllPosts"),
    "all posts (including filtered posts) are selected"
  );
});

QUnit.test("selectedPostsUsername", function(assert) {
  const postStream = {
    posts: [
      { id: 1, username: "gary" },
      { id: 2, username: "gary" },
      { id: 3, username: "lili" }
    ],
    stream: [1, 2, 3]
  };

  const model = Topic.create({ postStream });
  const controller = this.subject({ model });
  const selectedPostIds = controller.get("selectedPostIds");

  assert.equal(
    controller.get("selectedPostsUsername"),
    undefined,
    "no username when no selected posts"
  );

  selectedPostIds.pushObject(1);

  assert.equal(
    controller.get("selectedPostsUsername"),
    "gary",
    "username of the selected posts"
  );

  selectedPostIds.pushObject(2);

  assert.equal(
    controller.get("selectedPostsUsername"),
    "gary",
    "username of all the selected posts when same user"
  );

  selectedPostIds.pushObject(3);

  assert.equal(
    controller.get("selectedPostsUsername"),
    undefined,
    "no username when more than 1 user"
  );

  selectedPostIds.replace(2, 1, [42]);

  assert.equal(
    controller.get("selectedPostsUsername"),
    undefined,
    "no username when not already loaded posts are selected"
  );
});

QUnit.test("showSelectedPostsAtBottom", function(assert) {
  const site = Ember.Object.create({ mobileView: false });
  const model = Topic.create({ posts_count: 3 });
  const controller = this.subject({ model, site });

  assert.not(controller.get("showSelectedPostsAtBottom"), "false on desktop");

  site.set("mobileView", true);

  assert.not(
    controller.get("showSelectedPostsAtBottom"),
    "requires at least 3 posts on mobile"
  );

  model.set("posts_count", 4);

  assert.ok(
    controller.get("showSelectedPostsAtBottom"),
    "true when mobile and more than 3 posts"
  );
});

QUnit.test("canDeleteSelected", function(assert) {
  const postStream = {
    posts: [
      { id: 1, can_delete: false },
      { id: 2, can_delete: true },
      { id: 3, can_delete: true }
    ],
    stream: [1, 2, 3]
  };
  const currentUser = Discourse.User.create({ admin: false });
  this.registry.register("current-user:main", currentUser, {
    instantiate: false
  });
  this.registry.injection("controller", "currentUser", "current-user:main");
  const model = Topic.create({ postStream });
  const controller = this.subject({ model });
  const selectedPostIds = controller.get("selectedPostIds");

  assert.not(
    controller.get("canDeleteSelected"),
    "false when no posts are selected"
  );

  selectedPostIds.pushObject(1);

  assert.not(
    controller.get("canDeleteSelected"),
    "false when can't delete one of the selected posts"
  );

  selectedPostIds.replace(0, 1, [2, 3]);

  assert.ok(
    controller.get("canDeleteSelected"),
    "true when all selected posts can be deleted"
  );

  selectedPostIds.pushObject(1);

  assert.not(
    controller.get("canDeleteSelected"),
    "false when all posts are selected and user is staff"
  );

  currentUser.set("admin", true);

  assert.ok(
    controller.get("canDeleteSelected"),
    "true when all posts are selected and user is staff"
  );
});

QUnit.test("Can split/merge topic", function(assert) {
  const postStream = {
    posts: [
      { id: 1, post_number: 1, post_type: 1 },
      { id: 2, post_number: 2, post_type: 4 },
      { id: 3, post_number: 3, post_type: 1 }
    ],
    stream: [1, 2, 3]
  };

  const model = Topic.create({
    postStream,
    details: { can_move_posts: false }
  });
  const controller = this.subject({ model });
  const selectedPostIds = controller.get("selectedPostIds");

  assert.not(
    controller.get("canSplitTopic"),
    "can't split topic when no posts are selected"
  );
  assert.not(
    controller.get("canMergeTopic"),
    "can't merge topic when no posts are selected"
  );

  selectedPostIds.pushObject(1);

  assert.not(
    controller.get("canSplitTopic"),
    "can't split topic when can't move posts"
  );
  assert.not(
    controller.get("canMergeTopic"),
    "can't merge topic when can't move posts"
  );

  model.set("details.can_move_posts", true);

  assert.ok(controller.get("canSplitTopic"), "can split topic");
  assert.ok(controller.get("canMergeTopic"), "can merge topic");

  selectedPostIds.removeObject(1);
  selectedPostIds.pushObject(2);

  assert.not(
    controller.get("canSplitTopic"),
    "can't split topic when 1st post is not a regular post"
  );
  assert.ok(
    controller.get("canMergeTopic"),
    "can merge topic when 1st post is not a regular post"
  );

  selectedPostIds.pushObject(3);

  assert.not(
    controller.get("canSplitTopic"),
    "can't split topic when all posts are selected"
  );
  assert.ok(
    controller.get("canMergeTopic"),
    "can merge topic when all posts are selected"
  );
});

QUnit.test("canChangeOwner", function(assert) {
  const currentUser = Discourse.User.create({ admin: false });
  this.registry.register("current-user:main", currentUser, {
    instantiate: false
  });
  this.registry.injection("controller", "currentUser", "current-user:main");

  const postStream = {
    posts: [{ id: 1, username: "gary" }, { id: 2, username: "lili" }],
    stream: [1, 2]
  };

  const model = Topic.create({ postStream, currentUser: { admin: false } });
  const controller = this.subject({ model });
  const selectedPostIds = controller.get("selectedPostIds");

  assert.not(
    controller.get("canChangeOwner"),
    "false when no posts are selected"
  );

  selectedPostIds.pushObject(1);

  assert.not(controller.get("canChangeOwner"), "false when not admin");

  currentUser.set("admin", true);

  assert.ok(
    controller.get("canChangeOwner"),
    "true when admin and one post is selected"
  );

  selectedPostIds.pushObject(2);

  assert.not(
    controller.get("canChangeOwner"),
    "false when admin but more than 1 user"
  );
});

QUnit.test("canMergePosts", function(assert) {
  const postStream = {
    posts: [
      { id: 1, username: "gary", can_delete: true },
      { id: 2, username: "lili", can_delete: true },
      { id: 3, username: "gary", can_delete: false },
      { id: 4, username: "gary", can_delete: true }
    ],
    stream: [1, 2, 3]
  };

  const model = Topic.create({ postStream });
  const controller = this.subject({ model });
  const selectedPostIds = controller.get("selectedPostIds");

  assert.not(
    controller.get("canMergePosts"),
    "false when no posts are selected"
  );

  selectedPostIds.pushObject(1);

  assert.not(
    controller.get("canMergePosts"),
    "false when only one post is selected"
  );

  selectedPostIds.pushObject(2);

  assert.not(
    controller.get("canMergePosts"),
    "false when selected posts are from different users"
  );

  selectedPostIds.replace(1, 1, [3]);

  assert.not(
    controller.get("canMergePosts"),
    "false when selected posts can't be deleted"
  );

  selectedPostIds.replace(1, 1, [4]);

  assert.ok(
    controller.get("canMergePosts"),
    "true when all selected posts are deletable and by the same user"
  );
});

QUnit.test("Select/deselect all", function(assert) {
  const postStream = { stream: [1, 2, 3] };
  const model = Topic.create({ postStream });
  const controller = this.subject({ model });

  assert.equal(
    controller.get("selectedPostsCount"),
    0,
    "no posts selected by default"
  );

  controller.send("selectAll");

  assert.equal(
    controller.get("selectedPostsCount"),
    postStream.stream.length,
    "calling 'selectAll' selects all posts"
  );

  controller.send("deselectAll");

  assert.equal(
    controller.get("selectedPostsCount"),
    0,
    "calling 'deselectAll' deselects all posts"
  );
});

QUnit.test("togglePostSelection", function(assert) {
  const controller = this.subject();
  const selectedPostIds = controller.get("selectedPostIds");

  assert.equal(selectedPostIds[0], undefined, "no posts selected by default");

  controller.send("togglePostSelection", { id: 1 });

  assert.equal(
    selectedPostIds[0],
    1,
    "adds the selected post id if not already selected"
  );

  controller.send("togglePostSelection", { id: 1 });

  assert.equal(
    selectedPostIds[0],
    undefined,
    "removes the selected post id if already selected"
  );
});

// QUnit.test("selectReplies", function(assert) {
//   const controller = this.subject();
//   const selectedPostIds = controller.get("selectedPostIds");
//
//   assert.equal(selectedPostIds[0], undefined, "no posts selected by default");
//
//   controller.send("selectReplies", { id: 42 });
//
//   assert.equal(selectedPostIds[0], 42, "selected post #42");
//   assert.equal(selectedPostIds[1], 45, "selected post #45");
//   assert.equal(selectedPostIds[2], 100, "selected post #100");
// });

QUnit.test("selectBelow", function(assert) {
  const postStream = { stream: [1, 2, 3, 4, 5] };
  const model = Topic.create({ postStream });
  const controller = this.subject({ model });
  const selectedPostIds = controller.get("selectedPostIds");

  assert.equal(selectedPostIds[0], undefined, "no posts selected by default");

  controller.send("selectBelow", { id: 3 });

  assert.equal(selectedPostIds[0], 3, "selected post #3");
  assert.equal(selectedPostIds[1], 4, "also selected 1st post below post #3");
  assert.equal(selectedPostIds[2], 5, "also selected 2nd post below post #3");
});
