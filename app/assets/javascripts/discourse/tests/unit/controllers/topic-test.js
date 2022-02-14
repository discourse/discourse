import EmberObject from "@ember/object";
import { Placeholder } from "discourse/lib/posts-with-placeholders";
import { Promise } from "rsvp";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { next } from "@ember/runloop";
import pretender from "discourse/tests/helpers/create-pretender";
import { settled } from "@ember/test-helpers";
import { test } from "qunit";

function topicWithStream(streamDetails) {
  let topic = Topic.create();
  topic.get("postStream").setProperties(streamDetails);
  return topic;
}

discourseModule("Unit | Controller | topic", function (hooks) {
  hooks.beforeEach(function () {
    this.registry.injection("controller", "appEvents", "service:app-events");
  });

  hooks.afterEach(function () {
    this.registry.unregister("current-user:main");
    let topic = this.container.lookup("controller:topic");
    topic.setProperties({
      selectedPostIds: [],
      selectedPostUsername: null,
      currentUser: null,
    });
  });

  test("editTopic", function (assert) {
    const model = Topic.create();
    const controller = this.getController("topic", { model });
    assert.notOk(
      controller.get("editingTopic"),
      "we are not editing by default"
    );

    controller.set("model.details.can_edit", false);
    controller.send("editTopic");

    assert.notOk(
      controller.get("editingTopic"),
      "calling editTopic doesn't enable editing unless the user can edit"
    );

    controller.set("model.details.can_edit", true);
    controller.send("editTopic");

    assert.ok(
      controller.get("editingTopic"),
      "calling editTopic enables editing if the user can edit"
    );
    assert.strictEqual(controller.get("buffered.title"), model.get("title"));
    assert.strictEqual(
      controller.get("buffered.category_id"),
      model.get("category_id")
    );

    controller.send("cancelEditingTopic");

    assert.notOk(
      controller.get("editingTopic"),
      "cancelling edit mode reverts the property value"
    );
  });

  test("deleteTopic", function (assert) {
    const model = Topic.create();
    let destroyed = false;
    let modalDisplayed = false;
    model.destroy = () => {
      destroyed = true;
      return Promise.resolve();
    };
    const controller = this.getController("topic", {
      model,
      siteSettings: {
        min_topic_views_for_delete_confirm: 5,
      },
      deleteTopicModal: () => {
        modalDisplayed = true;
      },
    });

    model.set("views", 10000);
    controller.send("deleteTopic");
    assert.notOk(destroyed, "don't destroy popular topic");
    assert.ok(modalDisplayed, "display confirmation modal for popular topic");

    model.set("views", 3);
    controller.send("deleteTopic");
    assert.ok(destroyed, "destroy not popular topic");
  });

  test("toggleMultiSelect", async function (assert) {
    const model = Topic.create();
    const controller = this.getController("topic", { model });

    assert.notOk(
      controller.get("multiSelect"),
      "multi selection mode is disabled by default"
    );

    controller.get("selectedPostIds").pushObject(1);
    assert.strictEqual(controller.get("selectedPostIds.length"), 1);

    controller.send("toggleMultiSelect");
    await settled();

    assert.ok(
      controller.get("multiSelect"),
      "calling 'toggleMultiSelect' once enables multi selection mode"
    );
    assert.strictEqual(
      controller.get("selectedPostIds.length"),
      0,
      "toggling 'multiSelect' clears 'selectedPostIds'"
    );

    controller.get("selectedPostIds").pushObject(2);
    assert.strictEqual(controller.get("selectedPostIds.length"), 1);

    controller.send("toggleMultiSelect");
    await settled();

    assert.notOk(
      controller.get("multiSelect"),
      "calling 'toggleMultiSelect' twice disables multi selection mode"
    );
    assert.strictEqual(
      controller.get("selectedPostIds.length"),
      0,
      "toggling 'multiSelect' clears 'selectedPostIds'"
    );
  });

  test("selectedPosts", function (assert) {
    let model = topicWithStream({ posts: [{ id: 1 }, { id: 2 }, { id: 3 }] });
    const controller = this.getController("topic", { model });

    controller.set("selectedPostIds", [1, 2, 42]);

    assert.strictEqual(
      controller.get("selectedPosts.length"),
      2,
      "selectedPosts only contains already loaded posts"
    );
    assert.notOk(
      controller.get("selectedPosts").some((p) => p === undefined),
      "selectedPosts only contains valid post objects"
    );
  });

  test("selectedAllPosts", function (assert) {
    let model = topicWithStream({ stream: [1, 2, 3] });
    const controller = this.getController("topic", { model });

    controller.set("selectedPostIds", [1, 2]);

    assert.notOk(
      controller.get("selectedAllPosts"),
      "not all posts are selected"
    );

    controller.get("selectedPostIds").pushObject(3);

    assert.ok(controller.get("selectedAllPosts"), "all posts are selected");

    controller.get("selectedPostIds").pushObject(42);

    assert.ok(
      controller.get("selectedAllPosts"),
      "all posts (including filtered posts) are selected"
    );

    model.setProperties({
      "postStream.isMegaTopic": true,
      posts_count: 1,
    });

    assert.ok(
      controller.get("selectedAllPosts"),
      "it uses the topic's post count for megatopics"
    );
  });

  test("selectedPostsUsername", function (assert) {
    let model = topicWithStream({
      posts: [
        { id: 1, username: "gary" },
        { id: 2, username: "gary" },
        { id: 3, username: "lili" },
      ],
      stream: [1, 2, 3],
    });
    const controller = this.getController("topic", { model });
    const selectedPostIds = controller.get("selectedPostIds");

    assert.strictEqual(
      controller.get("selectedPostsUsername"),
      undefined,
      "no username when no selected posts"
    );

    selectedPostIds.pushObject(1);

    assert.strictEqual(
      controller.get("selectedPostsUsername"),
      "gary",
      "username of the selected posts"
    );

    selectedPostIds.pushObject(2);

    assert.strictEqual(
      controller.get("selectedPostsUsername"),
      "gary",
      "username of all the selected posts when same user"
    );

    selectedPostIds.pushObject(3);

    assert.strictEqual(
      controller.get("selectedPostsUsername"),
      undefined,
      "no username when more than 1 user"
    );

    selectedPostIds.replace(2, 1, [42]);

    assert.strictEqual(
      controller.get("selectedPostsUsername"),
      undefined,
      "no username when not already loaded posts are selected"
    );
  });

  test("showSelectedPostsAtBottom", function (assert) {
    const site = EmberObject.create({ mobileView: false });
    const model = Topic.create({ posts_count: 3 });
    const controller = this.getController("topic", { model, site });

    assert.notOk(
      controller.get("showSelectedPostsAtBottom"),
      "false on desktop"
    );

    site.set("mobileView", true);

    assert.notOk(
      controller.get("showSelectedPostsAtBottom"),
      "requires at least 3 posts on mobile"
    );

    model.set("posts_count", 4);

    assert.ok(
      controller.get("showSelectedPostsAtBottom"),
      "true when mobile and more than 3 posts"
    );
  });

  test("canDeleteSelected", function (assert) {
    const currentUser = User.create({ admin: false });
    this.registry.register("current-user:main", currentUser, {
      instantiate: false,
    });
    this.registry.injection("controller", "currentUser", "current-user:main");
    let model = topicWithStream({
      posts: [
        { id: 1, can_delete: false },
        { id: 2, can_delete: true },
        { id: 3, can_delete: true },
      ],
      stream: [1, 2, 3],
    });
    const controller = this.getController("topic", {
      model,
      currentUser,
    });
    const selectedPostIds = controller.get("selectedPostIds");

    assert.notOk(
      controller.get("canDeleteSelected"),
      "false when no posts are selected"
    );

    selectedPostIds.pushObject(1);

    assert.notOk(
      controller.get("canDeleteSelected"),
      "false when can't delete one of the selected posts"
    );

    selectedPostIds.replace(0, 1, [2, 3]);

    assert.ok(
      controller.get("canDeleteSelected"),
      "true when all selected posts can be deleted"
    );

    selectedPostIds.pushObject(1);

    assert.notOk(
      controller.get("canDeleteSelected"),
      "false when all posts are selected and user is staff"
    );

    currentUser.set("admin", true);

    assert.ok(
      controller.get("canDeleteSelected"),
      "true when all posts are selected and user is staff"
    );
  });

  test("Can split/merge topic", function (assert) {
    let model = topicWithStream({
      posts: [
        { id: 1, post_number: 1, post_type: 1 },
        { id: 2, post_number: 2, post_type: 4 },
        { id: 3, post_number: 3, post_type: 1 },
      ],
      stream: [1, 2, 3],
    });
    model.set("details.can_move_posts", false);
    const controller = this.getController("topic", { model });
    const selectedPostIds = controller.get("selectedPostIds");

    assert.notOk(
      controller.get("canMergeTopic"),
      "can't merge topic when no posts are selected"
    );

    selectedPostIds.pushObject(1);

    assert.notOk(
      controller.get("canMergeTopic"),
      "can't merge topic when can't move posts"
    );

    model.set("details.can_move_posts", true);

    assert.ok(controller.get("canMergeTopic"), "can merge topic");

    selectedPostIds.removeObject(1);
    selectedPostIds.pushObject(2);

    assert.ok(
      controller.get("canMergeTopic"),
      "can merge topic when 1st post is not a regular post"
    );

    selectedPostIds.pushObject(3);

    assert.ok(
      controller.get("canMergeTopic"),
      "can merge topic when all posts are selected"
    );
  });

  test("canChangeOwner", function (assert) {
    const currentUser = User.create({ admin: false });
    this.registry.register("current-user:main", currentUser, {
      instantiate: false,
    });
    this.registry.injection("controller", "currentUser", "current-user:main");

    let model = topicWithStream({
      posts: [
        { id: 1, username: "gary" },
        { id: 2, username: "lili" },
      ],
      stream: [1, 2],
    });
    model.set("currentUser", { admin: false });
    const controller = this.getController("topic", {
      model,
      currentUser,
    });
    const selectedPostIds = controller.get("selectedPostIds");

    assert.notOk(
      controller.get("canChangeOwner"),
      "false when no posts are selected"
    );

    selectedPostIds.pushObject(1);

    assert.notOk(controller.get("canChangeOwner"), "false when not admin");

    currentUser.set("admin", true);

    assert.ok(
      controller.get("canChangeOwner"),
      "true when admin and one post is selected"
    );

    selectedPostIds.pushObject(2);

    assert.notOk(
      controller.get("canChangeOwner"),
      "false when admin but more than 1 user"
    );
  });

  test("canMergePosts", function (assert) {
    let model = topicWithStream({
      posts: [
        { id: 1, username: "gary", can_delete: true },
        { id: 2, username: "lili", can_delete: true },
        { id: 3, username: "gary", can_delete: false },
        { id: 4, username: "gary", can_delete: true },
      ],
      stream: [1, 2, 3],
    });
    const controller = this.getController("topic", {
      model,
    });
    const selectedPostIds = controller.get("selectedPostIds");

    assert.notOk(
      controller.get("canMergePosts"),
      "false when no posts are selected"
    );

    selectedPostIds.pushObject(1);

    assert.notOk(
      controller.get("canMergePosts"),
      "false when only one post is selected"
    );

    selectedPostIds.pushObject(2);

    assert.notOk(
      controller.get("canMergePosts"),
      "false when selected posts are from different users"
    );

    selectedPostIds.replace(1, 1, [3]);

    assert.notOk(
      controller.get("canMergePosts"),
      "false when selected posts can't be deleted"
    );

    selectedPostIds.replace(1, 1, [4]);

    assert.ok(
      controller.get("canMergePosts"),
      "true when all selected posts are deletable and by the same user"
    );
  });

  test("Select/deselect all", function (assert) {
    let model = topicWithStream({ stream: [1, 2, 3] });
    const controller = this.getController("topic", { model });

    assert.strictEqual(
      controller.get("selectedPostsCount"),
      0,
      "no posts selected by default"
    );

    controller.send("selectAll");

    assert.strictEqual(
      controller.get("selectedPostsCount"),
      3,
      "calling 'selectAll' selects all posts"
    );

    controller.send("deselectAll");

    assert.strictEqual(
      controller.get("selectedPostsCount"),
      0,
      "calling 'deselectAll' deselects all posts"
    );
  });

  test("togglePostSelection", function (assert) {
    const controller = this.getController("topic");
    const selectedPostIds = controller.get("selectedPostIds");

    assert.strictEqual(
      selectedPostIds[0],
      undefined,
      "no posts selected by default"
    );

    controller.send("togglePostSelection", { id: 1 });

    assert.strictEqual(
      selectedPostIds[0],
      1,
      "adds the selected post id if not already selected"
    );

    controller.send("togglePostSelection", { id: 1 });

    assert.strictEqual(
      selectedPostIds[0],
      undefined,
      "removes the selected post id if already selected"
    );
  });

  test("selectBelow", function (assert) {
    const site = EmberObject.create({
      post_types: { small_action: 3, whisper: 4 },
    });
    let model = topicWithStream({
      stream: [1, 2, 3, 4, 5, 6, 7, 8],
      posts: [
        { id: 5, cooked: "whisper post", post_type: 4 },
        { id: 6, cooked: "a small action", post_type: 3 },
        { id: 7, cooked: "", post_type: 4 },
      ],
    });
    const controller = this.getController("topic", { site, model });
    let selectedPostIds = controller.get("selectedPostIds");

    assert.strictEqual(
      selectedPostIds[0],
      undefined,
      "no posts selected by default"
    );

    controller.send("selectBelow", { id: 3 });

    assert.strictEqual(selectedPostIds[0], 3, "selected post #3");
    assert.strictEqual(
      selectedPostIds[1],
      4,
      "also selected 1st post below post #3"
    );
    assert.strictEqual(
      selectedPostIds[2],
      5,
      "also selected 2nd post below post #3"
    );
    assert.strictEqual(
      selectedPostIds[3],
      8,
      "also selected 3rd post below post #3"
    );
  });

  test("topVisibleChanged", function (assert) {
    let model = topicWithStream({
      posts: [{ id: 1 }],
    });
    const controller = this.getController("topic", { model });
    const placeholder = new Placeholder("post-placeholder");

    assert.strictEqual(
      controller.send("topVisibleChanged", {
        post: placeholder,
      }),
      undefined,
      "it should work with a post-placeholder"
    );
  });

  test("deletePost - no modal is shown if post does not have replies", function (assert) {
    pretender.get("/posts/2/reply-ids.json", () => {
      return [200, { "Content-Type": "application/json" }, []];
    });

    let destroyed;
    const post = EmberObject.create({
      id: 2,
      post_number: 2,
      can_delete: true,
      reply_count: 3,
      destroy: () => {
        destroyed = true;
        return Promise.resolve();
      },
    });

    const currentUser = EmberObject.create({ moderator: true });
    let model = topicWithStream({
      stream: [2, 3, 4],
      posts: [post, { id: 3 }, { id: 4 }],
    });
    const controller = this.getController("topic", { model, currentUser });

    const done = assert.async();
    controller.send("deletePost", post);

    next(() => {
      assert.ok(destroyed, "post was destroyed");
      done();
    });
  });
});
