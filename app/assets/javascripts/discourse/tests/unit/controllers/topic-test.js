import EmberObject from "@ember/object";
import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { Placeholder } from "discourse/lib/posts-with-placeholders";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

function topicWithStream(streamDetails) {
  const topic = this.store.createRecord("topic");
  topic.postStream.setProperties(streamDetails);
  return topic;
}

module("Unit | Controller | topic", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
  });

  test("editTopic", function (assert) {
    const controller = getOwner(this).lookup("controller:topic");
    const model = this.store.createRecord("topic");
    controller.setProperties({ model });
    assert.false(controller.editingTopic, "we are not editing by default");

    controller.set("model.details.can_edit", false);
    controller.editTopic();

    assert.false(
      controller.editingTopic,
      "calling editTopic doesn't enable editing unless the user can edit"
    );

    controller.set("model.details.can_edit", true);
    controller.editTopic();

    assert.true(
      controller.editingTopic,
      "calling editTopic enables editing if the user can edit"
    );
    assert.strictEqual(controller.buffered.title, model.title);
    assert.strictEqual(controller.buffered.category_id, model.category_id);

    controller.send("cancelEditingTopic");

    assert.false(
      controller.editingTopic,
      "cancelling edit mode reverts the property value"
    );
  });

  test("deleteTopic", function (assert) {
    const model = this.store.createRecord("topic");
    let destroyed = false;
    let modalDisplayed = false;
    model.destroy = async () => (destroyed = true);

    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.min_topic_views_for_delete_confirm = 5;

    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({
      model,
      deleteTopicModal: () => (modalDisplayed = true),
    });

    model.set("views", 10000);
    controller.send("deleteTopic");
    assert.false(destroyed, "don't destroy popular topic");
    assert.true(modalDisplayed, "display confirmation modal for popular topic");

    model.set("views", 3);
    controller.send("deleteTopic");
    assert.true(destroyed, "destroy not popular topic");
  });

  test("deleteTopic permanentDelete", function (assert) {
    const opts = { force_destroy: true };
    const model = this.store.createRecord("topic");
    const siteSettings = this.owner.lookup("service:site-settings");
    siteSettings.min_topic_views_for_delete_confirm = 5;

    const controller = this.owner.lookup("controller:topic");
    controller.setProperties({ model });
    model.set("views", 100);

    const stub = sinon.stub(model, "destroy");
    controller.send("deleteTopic", { force_destroy: true });

    assert.deepEqual(
      stub.getCall(0).args[1],
      opts,
      "does not show delete confirm permanently deleting, passes opts to model action"
      // permanent delete happens after first delete, no need to show modal again
    );
  });

  test("toggleMultiSelect", async function (assert) {
    const model = this.store.createRecord("topic");
    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model });

    assert.false(
      controller.multiSelect,
      "multi selection mode is disabled by default"
    );

    controller.selectedPostIds.pushObject(1);
    assert.strictEqual(controller.selectedPostIds.length, 1);

    controller.send("toggleMultiSelect");
    await settled();

    assert.true(
      controller.multiSelect,
      "calling 'toggleMultiSelect' once enables multi selection mode"
    );
    assert.strictEqual(
      controller.selectedPostIds.length,
      0,
      "toggling 'multiSelect' clears 'selectedPostIds'"
    );

    controller.selectedPostIds.pushObject(2);
    assert.strictEqual(controller.selectedPostIds.length, 1);

    controller.send("toggleMultiSelect");
    await settled();

    assert.false(
      controller.multiSelect,
      "calling 'toggleMultiSelect' twice disables multi selection mode"
    );
    assert.strictEqual(
      controller.selectedPostIds.length,
      0,
      "toggling 'multiSelect' clears 'selectedPostIds'"
    );
  });

  test("selectedPosts", function (assert) {
    const model = topicWithStream.call(this, {
      posts: [{ id: 1 }, { id: 2 }, { id: 3 }],
    });
    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model });

    controller.set("selectedPostIds", [1, 2, 42]);

    assert.strictEqual(
      controller.selectedPosts.length,
      2,
      "selectedPosts only contains already loaded posts"
    );
    assert.false(
      controller.selectedPosts.some((p) => p === undefined),
      "selectedPosts only contains valid post objects"
    );
  });

  test("selectedAllPosts", function (assert) {
    const model = topicWithStream.call(this, { stream: [1, 2, 3] });
    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model });

    controller.set("selectedPostIds", [1, 2]);
    assert.false(controller.selectedAllPosts, "not all posts are selected");

    controller.selectedPostIds.pushObject(3);
    assert.true(controller.selectedAllPosts, "all posts are selected");

    controller.selectedPostIds.pushObject(42);
    assert.true(
      controller.selectedAllPosts,
      "all posts (including filtered posts) are selected"
    );

    model.setProperties({
      "postStream.isMegaTopic": true,
      posts_count: 1,
    });
    assert.true(
      controller.selectedAllPosts,
      "uses the topic's post count for mega-topics"
    );
  });

  test("selectedPostsUsername", function (assert) {
    const model = topicWithStream.call(this, {
      posts: [
        { id: 1, username: "gary" },
        { id: 2, username: "gary" },
        { id: 3, username: "lili" },
      ],
      stream: [1, 2, 3],
    });
    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model });

    assert.strictEqual(
      controller.selectedPostsUsername,
      undefined,
      "no username when no selected posts"
    );

    controller.selectedPostIds.pushObject(1);
    assert.strictEqual(
      controller.selectedPostsUsername,
      "gary",
      "username of the selected posts"
    );

    controller.selectedPostIds.pushObject(2);
    assert.strictEqual(
      controller.selectedPostsUsername,
      "gary",
      "username of all the selected posts when same user"
    );

    controller.selectedPostIds.pushObject(3);
    assert.strictEqual(
      controller.selectedPostsUsername,
      undefined,
      "no username when more than 1 user"
    );

    controller.selectedPostIds.replace(2, 1, [42]);
    assert.strictEqual(
      controller.selectedPostsUsername,
      undefined,
      "no username when not already loaded posts are selected"
    );
  });

  test("showSelectedPostsAtBottom", function (assert) {
    const model = this.store.createRecord("topic", { posts_count: 3 });
    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model });

    assert.false(controller.showSelectedPostsAtBottom, "false on desktop");

    const site = getOwner(this).lookup("service:site");
    site.set("mobileView", true);

    assert.false(
      controller.showSelectedPostsAtBottom,
      "requires at least 3 posts on mobile"
    );

    model.set("posts_count", 4);
    assert.true(
      controller.showSelectedPostsAtBottom,
      "true when mobile and more than 3 posts"
    );
  });

  test("canDeleteSelected", function (assert) {
    const currentUser = this.store.createRecord("user", { admin: false });
    const model = topicWithStream.call(this, {
      posts: [
        { id: 1, can_delete: false },
        { id: 2, can_delete: true },
        { id: 3, can_delete: true },
      ],
      stream: [1, 2, 3],
    });

    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({
      model,
      currentUser,
    });

    assert.false(
      controller.canDeleteSelected,
      "false when no posts are selected"
    );

    controller.selectedPostIds.pushObject(1);
    assert.false(
      controller.canDeleteSelected,
      "false when can't delete one of the selected posts"
    );

    controller.selectedPostIds.replace(0, 1, [2, 3]);
    assert.true(
      controller.canDeleteSelected,
      "true when all selected posts can be deleted"
    );

    controller.selectedPostIds.pushObject(1);
    assert.false(
      controller.canDeleteSelected,
      "false when all posts are selected and user is staff"
    );

    currentUser.set("admin", true);
    assert.true(
      controller.canDeleteSelected,
      "true when all posts are selected and user is staff"
    );
  });

  test("Can split/merge topic", function (assert) {
    const model = topicWithStream.call(this, {
      posts: [
        { id: 1, post_number: 1, post_type: 1 },
        { id: 2, post_number: 2, post_type: 4 },
        { id: 3, post_number: 3, post_type: 1 },
      ],
      stream: [1, 2, 3],
    });
    model.set("details.can_move_posts", false);

    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model });

    assert.false(
      controller.canMergeTopic,
      "can't merge topic when no posts are selected"
    );

    controller.selectedPostIds.pushObject(1);

    assert.false(
      controller.canMergeTopic,
      "can't merge topic when can't move posts"
    );

    model.set("details.can_move_posts", true);

    assert.true(controller.canMergeTopic, "can merge topic");

    controller.selectedPostIds.removeObject(1);
    controller.selectedPostIds.pushObject(2);

    assert.true(
      controller.canMergeTopic,
      "can merge topic when 1st post is not a regular post"
    );

    controller.selectedPostIds.pushObject(3);

    assert.true(
      controller.canMergeTopic,
      "can merge topic when all posts are selected"
    );
  });

  test("canChangeOwner", function (assert) {
    const currentUser = this.store.createRecord("user", { admin: false });
    const model = topicWithStream.call(this, {
      posts: [
        { id: 1, username: "gary" },
        { id: 2, username: "lili" },
      ],
      stream: [1, 2],
    });
    model.set("currentUser", currentUser);

    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model, currentUser });

    assert.false(controller.canChangeOwner, "false when no posts are selected");

    controller.selectedPostIds.pushObject(1);
    assert.false(controller.canChangeOwner, "false when not admin");

    currentUser.set("admin", true);
    assert.true(
      controller.canChangeOwner,
      "true when admin and one post is selected"
    );

    controller.selectedPostIds.pushObject(2);
    assert.false(
      controller.canChangeOwner,
      "false when admin but more than 1 user"
    );
  });

  test("modCanChangeOwner", function (assert) {
    const currentUser = this.store.createRecord("user", { moderator: false });
    const model = topicWithStream.call(this, {
      posts: [
        { id: 1, username: "gary" },
        { id: 2, username: "lili" },
      ],
      stream: [1, 2],
    });
    model.set("currentUser", currentUser);

    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.moderators_change_post_ownership = true;

    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model, currentUser });

    assert.false(controller.canChangeOwner, "false when no posts are selected");

    controller.selectedPostIds.pushObject(1);
    assert.false(controller.canChangeOwner, "false when not moderator");

    currentUser.set("moderator", true);
    assert.true(
      controller.canChangeOwner,
      "true when moderator and one post is selected"
    );

    controller.selectedPostIds.pushObject(2);
    assert.false(
      controller.canChangeOwner,
      "false when moderator but more than 1 user"
    );
  });

  test("canMergePosts", function (assert) {
    const model = topicWithStream.call(this, {
      posts: [
        { id: 1, username: "gary", can_delete: true },
        { id: 2, username: "lili", can_delete: true },
        { id: 3, username: "gary", can_delete: false },
        { id: 4, username: "gary", can_delete: true },
      ],
      stream: [1, 2, 3],
    });

    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model });

    assert.false(controller.canMergePosts, "false when no posts are selected");

    controller.selectedPostIds.pushObject(1);
    assert.false(
      controller.canMergePosts,
      "false when only one post is selected"
    );

    controller.selectedPostIds.pushObject(2);
    assert.false(
      controller.canMergePosts,
      "false when selected posts are from different users"
    );

    controller.selectedPostIds.replace(1, 1, [3]);
    assert.false(
      controller.canMergePosts,
      "false when selected posts can't be deleted"
    );

    controller.selectedPostIds.replace(1, 1, [4]);
    assert.true(
      controller.canMergePosts,
      "true when all selected posts are deletable and by the same user"
    );
  });

  test("Select/deselect all", function (assert) {
    const controller = getOwner(this).lookup("controller:topic");
    const model = topicWithStream.call(this, { stream: [1, 2, 3] });
    controller.setProperties({ model });

    assert.strictEqual(
      controller.selectedPostsCount,
      0,
      "no posts selected by default"
    );

    controller.send("selectAll");
    assert.strictEqual(
      controller.selectedPostsCount,
      3,
      "calling 'selectAll' selects all posts"
    );

    controller.send("deselectAll");
    assert.strictEqual(
      controller.selectedPostsCount,
      0,
      "calling 'deselectAll' deselects all posts"
    );
  });

  test("togglePostSelection", function (assert) {
    const controller = getOwner(this).lookup("controller:topic");

    assert.strictEqual(
      controller.selectedPostIds[0],
      undefined,
      "no posts selected by default"
    );

    controller.send("togglePostSelection", { id: 1 });
    assert.strictEqual(
      controller.selectedPostIds[0],
      1,
      "adds the selected post id if not already selected"
    );

    controller.send("togglePostSelection", { id: 1 });
    assert.strictEqual(
      controller.selectedPostIds[0],
      undefined,
      "removes the selected post id if already selected"
    );
  });

  test("selectBelow", function (assert) {
    const site = getOwner(this).lookup("service:site");
    site.set("post_types", { small_action: 3, whisper: 4 });

    const model = topicWithStream.call(this, {
      stream: [1, 2, 3, 4, 5, 6, 7, 8],
      posts: [
        { id: 5, cooked: "whisper post", post_type: 4 },
        { id: 6, cooked: "a small action", post_type: 3 },
        { id: 7, cooked: "", post_type: 4 },
      ],
    });

    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model });

    assert.deepEqual(
      controller.selectedPostIds,
      [],
      "no posts selected by default"
    );

    controller.send("selectBelow", { id: 3 });
    assert.deepEqual(controller.selectedPostIds, [3, 4, 5, 8]);
  });

  test("selectReplies", async function (assert) {
    pretender.get("/posts/1/reply-ids.json", () =>
      response([{ id: 2, level: 1 }])
    );

    const model = topicWithStream.call(this, {
      posts: [{ id: 1 }, { id: 2 }],
    });

    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model });

    controller.send("selectReplies", { id: 1 });
    await settled();

    assert.strictEqual(
      controller.selectedPostsCount,
      2,
      "selects two, the post and its replies"
    );

    controller.send("togglePostSelection", { id: 1 });
    assert.strictEqual(
      controller.selectedPostsCount,
      1,
      "is selecting one only"
    );
    assert.strictEqual(
      controller.selectedPostIds[0],
      2,
      "is selecting the reply id"
    );

    controller.send("selectReplies", { id: 1 });
    await settled();

    assert.strictEqual(
      controller.selectedPostsCount,
      2,
      "is selecting two, even if reply was already selected"
    );
  });

  test("topVisibleChanged", function (assert) {
    const model = topicWithStream.call(this, {
      posts: [{ id: 1 }],
    });
    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model });
    const placeholder = new Placeholder("post-placeholder");

    assert.strictEqual(
      controller.send("topVisibleChanged", {
        post: placeholder,
      }),
      undefined,
      "works with a post-placeholder"
    );
  });

  test("deletePost - no modal is shown if post does not have replies", async function (assert) {
    pretender.get("/posts/2/reply-ids.json", () => response([]));

    let destroyed;
    const post = EmberObject.create({
      id: 2,
      post_number: 2,
      can_delete: true,
      reply_count: 3,
      destroy: async () => (destroyed = true),
    });

    const currentUser = EmberObject.create({ moderator: true });
    const model = topicWithStream.call(this, {
      stream: [2, 3, 4],
      posts: [post, { id: 3 }, { id: 4 }],
    });

    const controller = getOwner(this).lookup("controller:topic");
    controller.setProperties({ model, currentUser });

    controller.send("deletePost", post);
    await settled();

    assert.true(destroyed, "post was destroyed");
  });
});
