import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Controller | nested", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser = logIn(this.owner);
    this.appEvents = this.owner.lookup("service:app-events");
    this.controller = this.owner.lookup("controller:nested");
    this.nestedViewCache = this.owner.lookup("service:nested-view-cache");
    this.store = this.owner.lookup("service:store");
  });

  hooks.afterEach(function () {
    this.controller.unsubscribe();
    this.controller.topic = null;
  });

  function buildTopic(store, id) {
    return store.createRecord("topic", {
      id,
      slug: `topic-${id}`,
    });
  }

  function buildPost(store, topic, id, postNumber) {
    const post = store.createRecord("post", {
      id,
      post_number: postNumber,
      topic,
    });
    post.topic = topic;
    return post;
  }

  test("post registry events are scoped to the current topic", function (assert) {
    const previousTopic = buildTopic(this.store, 509);
    const currentTopic = buildTopic(this.store, 724);
    const previousPost = buildPost(this.store, previousTopic, 1001, 2);
    const currentPost = buildPost(this.store, currentTopic, 2001, 2);

    this.controller.topic = currentTopic;
    this.controller.subscribe();

    this.appEvents.trigger("nested-replies:post-registered", previousPost);

    assert.false(
      this.controller.postRegistry.has(2),
      "ignores post registration from a previous topic"
    );

    this.appEvents.trigger("nested-replies:post-registered", currentPost);
    this.appEvents.trigger("nested-replies:post-unregistered", previousPost);

    assert.strictEqual(
      this.controller.postRegistry.get(2),
      currentPost,
      "does not unregister the current topic post for a stale same-number post"
    );

    this.appEvents.trigger("nested-replies:post-unregistered", currentPost);

    assert.false(
      this.controller.postRegistry.has(2),
      "unregisters the matching current topic post"
    );
  });

  test("own root message inserts a processed root node", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const postId = 2001;

    this.controller.topic = topic;
    this.controller.rootNodes = [];
    this.controller.newRootPostIds = [];

    pretender.get(`/posts/${postId}.json`, () =>
      response({
        id: postId,
        post_number: 2,
        topic_id: topic.id,
        user_id: this.currentUser.id,
        username: this.currentUser.username,
        avatar_template: this.currentUser.avatar_template,
        cooked: "<p>Own root reply</p>",
        created_at: "2026-01-01T00:00:00.000Z",
        actions_summary: [],
        direct_reply_count: 0,
        total_descendant_count: 0,
        reply_to_post_number: null,
        children: [],
      })
    );

    this.controller._onMessage(
      { type: "created", id: postId, user_id: this.currentUser.id },
      null,
      123
    );
    await settled();

    assert.strictEqual(
      this.controller.rootNodes.length,
      1,
      "inserts the own root reply immediately"
    );
    assert.strictEqual(
      this.controller.rootNodes[0].post.id,
      postId,
      "stores the fetched post"
    );
    assert.strictEqual(
      this.controller.rootNodes[0]._renderKey,
      postId,
      "preserves the processed node render key"
    );
    assert.deepEqual(
      this.controller.newRootPostIds,
      [],
      "does not queue own root replies behind the new replies banner"
    );
  });

  test("focused post cache entries include the mobile focused path", function (assert) {
    const topic = buildTopic(this.store, 724);
    const focusedPost = buildPost(this.store, topic, 2001, 2);
    const focusedPath = [{ post: focusedPost, children: [] }];

    this.controller.topic = topic;
    this.controller.sort = "top";
    this.controller.rootNodes = focusedPath;

    this.controller.setFocusedPostNumber(2, focusedPath);
    this.controller.saveToCache({ postNumber: 2, offsetFromTop: 80 });

    const cached = this.nestedViewCache.get(
      this.nestedViewCache.buildKey(topic.id, { sort: "top", post_number: 2 })
    );

    assert.strictEqual(
      cached.modelData.initialFocusedPath,
      focusedPath,
      "keeps enough focused-path state to restore the mobile drill-down URL"
    );
    assert.strictEqual(
      cached.modelData.postNumber,
      2,
      "stores the post URL cache entry under the focused post number"
    );
  });
});
