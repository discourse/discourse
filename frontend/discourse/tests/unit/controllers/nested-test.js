import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { NESTED_VIEW_CACHE_FORMAT_VERSION } from "discourse/lib/nested-view-cache-snapshot";
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
    this.controller.context = null;
    this.controller.contextMode = false;
    this.controller.rootNodes = [];
    this.controller.newRootPostIds = [];
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

  test("context view ignores live root replies", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const contextRoot = buildPost(this.store, topic, 1001, 2);
    const ownPostId = 2001;
    const otherPostId = 2002;

    this.controller.topic = topic;
    this.controller.contextMode = true;
    this.controller.rootNodes = [{ post: contextRoot, children: [] }];
    this.controller.newRootPostIds = [];

    pretender.get(`/posts/${ownPostId}.json`, () =>
      response({
        id: ownPostId,
        post_number: 3,
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
    pretender.get(`/posts/${otherPostId}.json`, () =>
      response({
        id: otherPostId,
        post_number: 4,
        topic_id: topic.id,
        user_id: 999,
        username: "other-user",
        avatar_template: "/letter_avatar_proxy/v4/letter/o/25/48.png",
        cooked: "<p>Other root reply</p>",
        created_at: "2026-01-01T00:00:00.000Z",
        actions_summary: [],
        direct_reply_count: 0,
        total_descendant_count: 0,
        reply_to_post_number: null,
        children: [],
      })
    );

    this.controller._onMessage(
      { type: "created", id: ownPostId, user_id: this.currentUser.id },
      null,
      123
    );
    this.controller._onMessage(
      { type: "created", id: otherPostId, user_id: 999 },
      null,
      124
    );
    await settled();

    assert.deepEqual(
      this.controller.rootNodes.map((node) => node.post.id),
      [contextRoot.id],
      "keeps the context branch isolated from new root replies"
    );
    assert.deepEqual(
      this.controller.newRootPostIds,
      [],
      "does not show the new root replies banner in context mode"
    );
    assert.strictEqual(
      this.controller.newRootPostCount,
      0,
      "reports no visible new root replies in context mode"
    );
  });

  test("context view ignores queued new root replies", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const contextRoot = buildPost(this.store, topic, 1001, 2);

    this.controller.topic = topic;
    this.controller.contextMode = true;
    this.controller.rootNodes = [{ post: contextRoot, children: [] }];
    this.controller.newRootPostIds = [2001];

    assert.strictEqual(
      this.controller.newRootPostCount,
      0,
      "hides queued root replies while rendering context"
    );

    await this.controller.loadNewRoots();

    assert.deepEqual(
      this.controller.newRootPostIds,
      [],
      "clears stale queued roots without loading them"
    );
    assert.deepEqual(
      this.controller.rootNodes.map((node) => node.post.id),
      [contextRoot.id],
      "keeps the context branch unchanged"
    );
  });

  test("deletePost delegates first post deletion to the topic controller", function (assert) {
    const topic = buildTopic(this.store, 724);
    const op = buildPost(this.store, topic, 1001, 1);
    const topicController = this.owner.lookup("controller:topic");
    const opts = { force_destroy: true };
    let destroyArgs;

    topic.destroy = (deletedBy, passedOpts) => {
      destroyArgs = { deletedBy, passedOpts };
    };
    topicController.set("model", topic);

    this.controller.deletePost(op, opts);

    assert.deepEqual(
      destroyArgs,
      { deletedBy: this.currentUser, passedOpts: opts },
      "uses the topic delete path for the OP"
    );
  });

  test("context view still dispatches live child replies", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const childPostId = 2001;
    let childCreatedEvent;
    const captureChildCreated = (event) => {
      childCreatedEvent = event;
    };

    this.controller.topic = topic;
    this.controller.contextMode = true;
    this.appEvents.on(
      "nested-replies:child-created",
      this,
      captureChildCreated
    );

    pretender.get(`/posts/${childPostId}.json`, () =>
      response({
        id: childPostId,
        post_number: 3,
        topic_id: topic.id,
        user_id: this.currentUser.id,
        username: this.currentUser.username,
        avatar_template: this.currentUser.avatar_template,
        cooked: "<p>Child reply</p>",
        created_at: "2026-01-01T00:00:00.000Z",
        actions_summary: [],
        direct_reply_count: 0,
        total_descendant_count: 0,
        reply_to_post_number: 2,
        children: [],
      })
    );

    try {
      this.controller._onMessage(
        { type: "created", id: childPostId, user_id: this.currentUser.id },
        null,
        123
      );
      await settled();

      assert.strictEqual(
        childCreatedEvent?.topicId,
        topic.id,
        "dispatches the update for the current topic"
      );
      assert.strictEqual(
        childCreatedEvent?.parentPostNumber,
        2,
        "targets the parent post"
      );
      assert.strictEqual(
        childCreatedEvent?.post.id,
        childPostId,
        "passes the fetched child post"
      );
      assert.true(childCreatedEvent?.isOwnPost, "marks own replies");
    } finally {
      this.appEvents.off(
        "nested-replies:child-created",
        this,
        captureChildCreated
      );
    }
  });

  test("scroll position persistence avoids full cache snapshots", function (assert) {
    const topic = buildTopic(this.store, 725);
    const anchor = { postNumber: 2, offsetFromTop: 80, scrollY: 1600 };
    const cacheKey = this.nestedViewCache.buildKey(topic.id, { sort: "top" });

    this.controller.topic = topic;
    this.controller.sort = "top";
    sessionStorage.removeItem(`nested-view-scroll:${cacheKey}`);

    this.controller.saveScrollPosition(anchor);

    assert.strictEqual(
      this.nestedViewCache.get(cacheKey),
      null,
      "does not snapshot the full nested model for scroll-only updates"
    );
    assert.deepEqual(
      JSON.parse(sessionStorage.getItem(`nested-view-scroll:${cacheKey}`)),
      anchor,
      "keeps the scroll anchor available for restoration"
    );
  });

  test("focused post cache entries include the mobile focused path", function (assert) {
    const topic = buildTopic(this.store, 724);
    const focusedPost = buildPost(this.store, topic, 2001, 2);
    const focusedPath = [{ post: focusedPost, children: [] }];

    this.controller.topic = topic;
    this.controller.sort = "top";
    this.controller.context = 0;
    this.controller.rootNodes = focusedPath;

    this.controller.setFocusedPostNumber(2, focusedPath);
    this.controller.saveToCache({ postNumber: 2, offsetFromTop: 80 });

    const cached = this.nestedViewCache.get(
      this.nestedViewCache.buildKey(topic.id, {
        sort: "top",
        post_number: 2,
        context: 0,
      })
    );

    assert.strictEqual(
      cached.formatVersion,
      NESTED_VIEW_CACHE_FORMAT_VERSION,
      "stores the current cache snapshot format"
    );
    assert.deepEqual(
      cached.modelData.initialFocusedPath.map((node) => node.post.post_number),
      [2],
      "keeps enough focused-path data to restore the mobile drill-down URL"
    );
    assert.notStrictEqual(
      cached.modelData.initialFocusedPath[0].post,
      focusedPost,
      "stores a post snapshot instead of the live post record"
    );
    assert.notStrictEqual(
      cached.modelData.topic,
      topic,
      "stores a topic snapshot instead of the live topic record"
    );
    assert.strictEqual(
      cached.modelData.postNumber,
      2,
      "stores the post URL cache entry under the focused post number"
    );
    assert.strictEqual(cached.modelData.context, 0, "preserves context depth");
  });
});
