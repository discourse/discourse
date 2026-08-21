import { settled, waitUntil } from "@ember/test-helpers";
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
    this.controller.rootWindowStart = 0;
    this.controller.rootWindowPages = [];
    this.controller.rootPageSize = 20;
    this.controller.pinnedRootCount = 0;
    this.controller.page = 0;
    this.controller.hasMoreRoots = false;
    this.controller.rootCount = null;
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
    this.controller.rootCount = 0;
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
    assert.strictEqual(
      this.controller.rootCount,
      1,
      "increments the initial count when the root becomes reachable"
    );
  });

  test("live roots preserve an offscreen active window", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const postId = 2_002;
    const visibleNode = {
      post: buildPost(this.store, topic, 8_000, 82),
      children: [],
      _renderKey: 8_000,
    };

    this.controller.setProperties({
      topic,
      rootNodes: [visibleNode],
      rootWindowStart: 80,
      rootCount: 100,
      page: 4,
      sort: "new",
      effectiveSort: "new",
    });

    pretender.get(`/posts/${postId}.json`, () =>
      response({
        id: postId,
        post_number: 102,
        topic_id: topic.id,
        user_id: this.currentUser.id,
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
      125
    );
    await settled();

    assert.deepEqual(
      this.controller.rootNodes.map((node) => node.post.id),
      [visibleNode.post.id],
      "does not inject a distant new root into the current page"
    );
    assert.strictEqual(
      this.controller.rootWindowStart,
      81,
      "shifts the current roots by the inserted logical prefix"
    );
    assert.strictEqual(this.controller.rootCount, 101);
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

  test("deleting a regular post does not expose the activity log", function (assert) {
    const topic = buildTopic(this.store, 724);
    const post = buildPost(this.store, topic, 2001, 2);

    this.controller.topic = topic;
    this.controller.postRegistry.set(post.post_number, post);

    this.controller._onMessage(
      { type: "deleted", id: post.id, user_id: this.currentUser.id },
      null,
      123
    );

    assert.false(
      Boolean(this.controller.topic.has_activity_log),
      "keeps the activity link hidden"
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

  test("root pagination uses the effective sort", async function (assert) {
    const topic = buildTopic(this.store, 724);
    let requestedSort;

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, (request) => {
      requestedSort = request.queryParams.sort;
      return response({ roots: [], page: 1, has_more_roots: false });
    });

    this.controller.setProperties({
      topic,
      page: 0,
      hasMoreRoots: true,
      sort: "hot",
      effectiveSort: "top",
    });

    await this.controller.loadMoreRoots();

    assert.strictEqual(
      requestedSort,
      "top",
      "continues the ordering selected by the initial response"
    );
    assert.strictEqual(
      this.controller.sort,
      "hot",
      "keeps the requested sort selected"
    );
  });

  test("root pagination keeps a bounded three-page window", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const requestedPages = [];

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, (request) => {
      const page = Number(request.queryParams.page);
      requestedPages.push(page);
      return response({
        roots: [...Array(20)].map((_, offset) => ({
          id: 8_000 + page * 20 + offset,
          post_number: 2 + page * 20 + offset,
          children: [],
        })),
        page,
        root_page_size: 20,
        has_more_roots: page < 4,
      });
    });

    this.controller.setProperties({
      topic,
      page: 0,
      hasMoreRoots: true,
      sort: "top",
      effectiveSort: "top",
      rootCount: 100,
      rootNodes: [...Array(20)].map((_, offset) => ({
        post: buildPost(this.store, topic, 8_000 + offset, 2 + offset),
        children: [],
        _renderKey: 8_000 + offset,
      })),
    });

    await this.controller.loadMoreRoots();
    await this.controller.loadMoreRoots();
    await this.controller.loadMoreRoots();

    assert.deepEqual(requestedPages, [1, 2, 3]);
    assert.strictEqual(
      this.controller.rootNodes.length,
      60,
      "renders no more than three server pages"
    );
    assert.strictEqual(this.controller.rootWindowStart, 20);
    assert.true(this.controller.hasPreviousRoots);
  });

  test("a live root keeps the whole rendered window", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const postId = 7_777;

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, (request) => {
      const page = Number(request.queryParams.page);
      return response({
        roots: [...Array(20)].map((_, offset) => ({
          id: 6_000 + page * 20 + offset,
          post_number: 2 + page * 20 + offset,
          children: [],
        })),
        page,
        root_page_size: 20,
        has_more_roots: page < 4,
      });
    });
    pretender.get(`/posts/${postId}.json`, () =>
      response({
        id: postId,
        post_number: 500,
        topic_id: topic.id,
        user_id: this.currentUser.id,
        actions_summary: [],
        direct_reply_count: 0,
        total_descendant_count: 0,
        reply_to_post_number: null,
        children: [],
      })
    );

    this.controller.setProperties({
      topic,
      page: 0,
      hasMoreRoots: true,
      sort: "new",
      effectiveSort: "new",
      rootCount: 100,
      rootNodes: [...Array(20)].map((_, offset) => ({
        post: buildPost(this.store, topic, 6_000 + offset, 2 + offset),
        children: [],
        _renderKey: 6_000 + offset,
      })),
    });

    await this.controller.loadMoreRoots();
    await this.controller.loadMoreRoots();
    assert.strictEqual(this.controller.rootNodes.length, 60);

    this.controller._onMessage(
      { type: "created", id: postId, user_id: this.currentUser.id },
      null,
      125
    );
    await settled();

    assert.strictEqual(
      this.controller.rootNodes.length,
      61,
      "does not discard rendered roots to make room"
    );
    assert.strictEqual(
      this.controller.rootNodes[0].post.id,
      postId,
      "places the new root at the top"
    );
    assert.strictEqual(this.controller.rootWindowStart, 0);
    assert.strictEqual(this.controller.rootCount, 101);

    await this.controller.loadMoreRoots();

    assert.strictEqual(
      this.controller.rootNodes.length,
      60,
      "keeps paging from the window the live root joined"
    );
  });

  test("a live root shows up under a score-based sort", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const postId = 8_888;

    pretender.get(`/posts/${postId}.json`, () =>
      response({
        id: postId,
        post_number: 40,
        topic_id: topic.id,
        user_id: this.currentUser.id,
        actions_summary: [],
        direct_reply_count: 0,
        total_descendant_count: 0,
        reply_to_post_number: null,
        children: [],
      })
    );

    this.controller.setProperties({
      topic,
      sort: "top",
      effectiveSort: "top",
      rootCount: 3,
      rootNodes: [
        {
          post: buildPost(this.store, topic, 2_001, 2),
          children: [],
          _renderKey: 2_001,
        },
      ],
    });

    this.controller._onMessage(
      { type: "created", id: postId, user_id: this.currentUser.id },
      null,
      125
    );
    await settled();

    assert.deepEqual(
      this.controller.rootNodes.map((node) => node.post.id),
      [postId, 2_001],
      "shows the root the server would place by score, rather than dropping it"
    );
  });

  test("live roots keep the window's global index honest", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const postId = 6_500;
    let liveRootInserted = false;

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, (request) => {
      const page = Number(request.queryParams.page);
      const first = page * 20 - (liveRootInserted ? 1 : 0);
      return response({
        roots: [...Array(20)].map((_, offset) => ({
          id: 3_000 + first + offset,
          post_number: 2 + first + offset,
          children: [],
        })),
        page,
        root_page_size: 20,
        has_more_roots: true,
      });
    });
    pretender.get(`/posts/${postId}.json`, () =>
      response({
        id: postId,
        post_number: 900,
        topic_id: topic.id,
        user_id: this.currentUser.id,
        actions_summary: [],
        direct_reply_count: 0,
        total_descendant_count: 0,
        reply_to_post_number: null,
        children: [],
      })
    );

    this.controller.setProperties({
      topic,
      page: 0,
      hasMoreRoots: true,
      sort: "new",
      effectiveSort: "new",
      rootCount: 100,
      rootNodes: [...Array(20)].map((_, offset) => ({
        post: buildPost(this.store, topic, 3_000 + offset, 2 + offset),
        children: [],
        _renderKey: 3_000 + offset,
      })),
    });

    // Pages fetched before the live root arrives.
    await this.controller.loadMoreRoots();
    await this.controller.loadMoreRoots();

    liveRootInserted = true;
    this.controller._onMessage(
      { type: "created", id: postId, user_id: this.currentUser.id },
      null,
      125
    );
    await settled();
    assert.strictEqual(this.controller.rootWindowStart, 0);

    // Sliding the window drops page zero, so the remaining pages carry the
    // offset the inserted root pushed them by.
    await this.controller.loadMoreRoots();

    assert.strictEqual(
      this.controller.rootWindowStart,
      21,
      "counts the live root ahead of the pages it displaced"
    );
    assert.strictEqual(
      this.controller.rootNodes.length,
      59,
      "removes the boundary root repeated by the shifted server page"
    );

    await this.controller.loadMoreRoots();
    await this.controller.loadMoreRoots();

    assert.strictEqual(
      this.controller.rootWindowStart,
      61,
      "advances past the leading duplicate when that page reaches the window edge"
    );
    assert.strictEqual(
      this.controller.rootNodes[0].post.id,
      3_060,
      "the global start describes the first retained root"
    );
  });

  test("a live batch larger than the window's headroom is not dropped", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const postId = 7_100;

    pretender.get(`/posts/${postId}.json`, () =>
      response({
        id: postId,
        post_number: 900,
        topic_id: topic.id,
        user_id: this.currentUser.id,
        actions_summary: [],
        direct_reply_count: 0,
        total_descendant_count: 0,
        reply_to_post_number: null,
        children: [],
      })
    );

    // rootPageSize 2 makes the window headroom 8 nodes, which the window
    // already fills.
    this.controller.setProperties({
      topic,
      page: 0,
      rootPageSize: 2,
      hasMoreRoots: true,
      sort: "new",
      effectiveSort: "new",
      rootCount: 100,
      rootNodes: [...Array(8)].map((_, offset) => ({
        post: buildPost(this.store, topic, 5_500 + offset, 2 + offset),
        children: [],
        _renderKey: 5_500 + offset,
      })),
      rootWindowPages: [
        {
          page: 0,
          nodeCount: 8,
          hasMoreRoots: true,
          rootPageSize: 2,
          absoluteStart: 0,
        },
      ],
    });

    this.controller._onMessage(
      { type: "created", id: postId, user_id: this.currentUser.id },
      null,
      125
    );
    await settled();

    assert.strictEqual(
      this.controller.rootNodes[0].post.id,
      postId,
      "shows the arriving root instead of discarding the batch"
    );
    assert.strictEqual(
      this.controller.rootNodes.length,
      8,
      "trims the far end of the window to stay bounded"
    );
    assert.true(
      this.controller.hasMoreRoots,
      "records that trimming left roots beyond the window"
    );
  });

  test("overlapping root pages render each post once", async function (assert) {
    const topic = buildTopic(this.store, 724);

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, (request) => {
      const page = Number(request.queryParams.page);
      // A root added between fetches shifts every later offset, so the page
      // repeats the last root of the page before it.
      const first = page * 20 - (page > 0 ? 1 : 0);
      return response({
        roots: [...Array(20)].map((_, offset) => ({
          id: 5_000 + first + offset,
          post_number: 2 + first + offset,
          children: [],
        })),
        page,
        root_page_size: 20,
        has_more_roots: true,
      });
    });

    this.controller.setProperties({
      topic,
      page: 0,
      hasMoreRoots: true,
      sort: "top",
      effectiveSort: "top",
      rootCount: 100,
      rootNodes: [...Array(20)].map((_, offset) => ({
        post: buildPost(this.store, topic, 5_000 + offset, 2 + offset),
        children: [],
        _renderKey: 5_000 + offset,
      })),
    });

    await this.controller.loadMoreRoots();

    const ids = this.controller.rootNodes.map((node) => node.post.id);
    assert.strictEqual(
      new Set(ids).size,
      ids.length,
      "renders no post twice, which would break the keyed list"
    );
    assert.strictEqual(ids.length, 39, "drops the repeated root");
  });

  test("jumpToRoot falls back to the window when the total is unknown", async function (assert) {
    const topic = buildTopic(this.store, 724);
    let requested = false;

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, () => {
      requested = true;
      return response({ roots: [], page: 1, has_more_roots: false });
    });

    this.controller.setProperties({
      topic,
      page: 0,
      hasMoreRoots: true,
      sort: "top",
      effectiveSort: "top",
      rootCount: null,
      rootPageSize: 20,
      rootNodes: [...Array(20)].map((_, offset) => ({
        post: buildPost(this.store, topic, 4_000 + offset, 2 + offset),
        children: [],
        _renderKey: 4_000 + offset,
      })),
    });

    const result = await this.controller.jumpToRoot(19);
    await settled();

    assert.deepEqual(
      result,
      { index: 19, reached: true },
      "reaches a loaded root instead of clamping to the first one"
    );
    assert.false(
      requested,
      "needs no request for a root already in the window"
    );
  });

  test("root pages are cached sparsely and can be loaded backward", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const requestedPages = [];

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, (request) => {
      const page = Number(request.queryParams.page);
      requestedPages.push(page);
      return response({
        roots: [...Array(20)].map((_, offset) => ({
          id: 9_000 + page * 20 + offset,
          post_number: 2 + page * 20 + offset,
          children: [],
        })),
        page,
        root_page_size: 20,
        has_more_roots: page < 4,
      });
    });

    this.controller.setProperties({
      topic,
      page: 0,
      hasMoreRoots: true,
      sort: "top",
      effectiveSort: "top",
      rootCount: 100,
      rootNodes: [
        {
          post: buildPost(this.store, topic, 8_999, 2),
          children: [],
          _renderKey: 8_999,
        },
      ],
    });

    await this.controller.jumpToRoot(80);
    await this.controller.loadPreviousRoots();
    await this.controller.jumpToRoot(0);
    await this.controller.jumpToRoot(80);

    assert.deepEqual(
      requestedPages,
      [4, 3],
      "reuses both the initial page and a previously fetched target page"
    );
    assert.strictEqual(this.controller.rootWindowStart, 80);
    assert.strictEqual(this.controller.rootNodes.length, 20);
  });

  test("a restored multi-page window keeps its page boundaries", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const requestedPages = [];

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, (request) => {
      const page = Number(request.queryParams.page);
      requestedPages.push(page);
      return response({
        roots: [...Array(20)].map((_, offset) => ({
          id: 10_000 + page * 20 + offset,
          post_number: 2 + page * 20 + offset,
          children: [],
        })),
        page,
        root_page_size: 20,
        has_more_roots: true,
      });
    });

    this.controller.setProperties({
      topic,
      page: 2,
      hasMoreRoots: true,
      sort: "top",
      effectiveSort: "top",
      rootCount: 200,
      rootWindowStart: 0,
      rootWindowPages: [0, 1, 2].map((page) => ({
        page,
        nodeCount: 20,
        hasMoreRoots: true,
        rootPageSize: 20,
      })),
      rootNodes: [...Array(60)].map((_, offset) => ({
        post: buildPost(this.store, topic, 10_000 + offset, 2 + offset),
        children: [],
        _renderKey: 10_000 + offset,
      })),
    });

    await this.controller.loadMoreRoots();

    assert.deepEqual(requestedPages, [3], "loads only the adjacent page");
    assert.strictEqual(
      this.controller.rootNodes.length,
      60,
      "keeps the restored window bounded to three pages"
    );
    assert.strictEqual(
      this.controller.rootWindowStart,
      20,
      "advances the global window by one page"
    );
    assert.strictEqual(
      this.controller.rootNodes[0].post.id,
      10_020,
      "drops the first restored page instead of relabeling it"
    );
  });

  test("jumpToRoot fetches the target page directly", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const requestedPages = [];

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, (request) => {
      requestedPages.push(request.queryParams.page);
      return response({
        roots: [...Array(20)].map((_, offset) => ({
          id: 12_000 + offset,
          post_number: 9_982 + offset,
          children: [],
        })),
        page: 499,
        root_page_size: 20,
        has_more_roots: false,
      });
    });

    this.controller.setProperties({
      topic,
      page: 0,
      hasMoreRoots: true,
      sort: "top",
      effectiveSort: "top",
      rootCount: 10_000,
      rootPageSize: 20,
      rootWindowStart: 0,
      rootNodes: [
        {
          post: buildPost(this.store, topic, 3001, 2),
          children: [],
          _renderKey: 3001,
        },
      ],
    });

    const result = await this.controller.jumpToRoot(9_999);
    await settled();

    assert.deepEqual(
      requestedPages,
      ["499"],
      "requests only the page containing the target"
    );
    assert.strictEqual(
      this.controller.rootNodes.length,
      20,
      "keeps only the fetched page in the active window"
    );
    assert.strictEqual(
      this.controller.rootWindowStart,
      9_980,
      "records the absolute index of the active window"
    );
    assert.deepEqual(
      result,
      { index: 9_999, reached: true },
      "reaches the target without intermediate pages"
    );
  });

  test("jumpToRoot reuses the active window", async function (assert) {
    const topic = buildTopic(this.store, 724);
    let requests = 0;

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, () => {
      requests++;
      return response({ roots: [] });
    });

    this.controller.setProperties({
      topic,
      rootCount: 100,
      rootWindowStart: 40,
      rootNodes: [...Array(20)].map((_, offset) => ({
        post: buildPost(this.store, topic, 5_000 + offset, 42 + offset),
        children: [],
        _renderKey: 5_000 + offset,
      })),
    });

    const result = await this.controller.jumpToRoot(55);

    assert.strictEqual(requests, 0, "does not refetch a loaded root");
    assert.deepEqual(result, { index: 55, reached: true });
  });

  test("jumpToRoot ignores a superseded page response", async function (assert) {
    const topic = buildTopic(this.store, 724);
    let releaseFirstRequest;

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, async (request) => {
      const page = Number(request.queryParams.page);
      if (page === 1) {
        await new Promise((resolve) => (releaseFirstRequest = resolve));
      }

      return response({
        roots: [{ id: 6_000 + page, post_number: 22 + page * 20 }],
        page,
        root_page_size: 20,
        has_more_roots: true,
      });
    });

    this.controller.setProperties({
      topic,
      sort: "top",
      effectiveSort: "top",
      rootCount: 100,
      rootNodes: [
        {
          post: buildPost(this.store, topic, 5_999, 2),
          children: [],
          _renderKey: 5_999,
        },
      ],
    });

    const firstJump = this.controller.jumpToRoot(20);
    await waitUntil(() => releaseFirstRequest);
    const secondResult = await this.controller.jumpToRoot(40);
    releaseFirstRequest();
    const firstResult = await firstJump;

    assert.deepEqual(secondResult, { index: 40, reached: true });
    assert.strictEqual(firstResult, null, "marks the old jump as superseded");
    assert.strictEqual(
      this.controller.rootWindowStart,
      40,
      "keeps the newest active window"
    );
    assert.strictEqual(
      this.controller.rootNodes[0].post.id,
      6_002,
      "does not replace it with the stale response"
    );
  });

  test("jumpToRoot reports the retained position after a request failure", async function (assert) {
    const topic = buildTopic(this.store, 724);

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, () =>
      response(500, { errors: ["Network error"] })
    );

    this.controller.setProperties({
      topic,
      sort: "top",
      effectiveSort: "top",
      rootCount: 100,
      rootNodes: [
        {
          post: buildPost(this.store, topic, 7_000, 2),
          children: [],
          _renderKey: 7_000,
        },
      ],
    });

    const result = await this.controller.jumpToRoot(80);

    assert.deepEqual(result, { index: 0, reached: false });
    assert.false(this.controller.loadingMore, "clears the busy state");
  });

  test("jumpToRoot accounts for pinned roots when selecting a page", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const requestedPages = [];

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, (request) => {
      const page = Number(request.queryParams.page);
      requestedPages.push(page);
      return response({
        roots: [...Array(20)].map((_, offset) => ({
          id: 4_000 + offset,
          post_number: 23 + offset,
          children: [],
        })),
        page,
        root_page_size: 20,
        has_more_roots: false,
      });
    });

    this.controller.setProperties({
      topic,
      page: 0,
      hasMoreRoots: true,
      sort: "top",
      effectiveSort: "top",
      rootCount: 42,
      rootPageSize: 20,
      pinnedPostIds: [3_999],
      pinnedRootCount: 1,
      rootNodes: [
        {
          post: buildPost(this.store, topic, 3_999, 2),
          children: [],
          _renderKey: 3_999,
        },
      ],
    });

    const result = await this.controller.jumpToRoot(21);

    assert.deepEqual(
      requestedPages,
      [1],
      "subtracts the pinned prefix before calculating the page"
    );
    assert.strictEqual(
      this.controller.rootWindowStart,
      21,
      "places the second server page after the pinned prefix"
    );
    assert.deepEqual(
      result,
      { index: 21, reached: true },
      "maps the first root in the page to its absolute index"
    );
  });

  test("pinning reloads page zero and resets the logical window", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const pinnedPost = buildPost(this.store, topic, 4_500, 82);
    let requestedPage;

    pretender.put(`/n/${topic.slug}/${topic.id}/pin.json`, () =>
      response({ pinned_post_ids: [pinnedPost.id] })
    );
    pretender.get(`/n/${topic.slug}/${topic.id}.json`, (request) => {
      requestedPage = request.queryParams.page;
      return response({
        roots: [
          { id: pinnedPost.id, post_number: 82, children: [] },
          { id: 4_001, post_number: 2, children: [] },
        ],
        pinned_post_ids: [pinnedPost.id],
        root_count: 100,
        root_page_size: 20,
        page: 0,
        has_more_roots: true,
      });
    });

    this.controller.setProperties({
      topic,
      sort: "top",
      effectiveSort: "top",
      rootCount: 100,
      rootWindowStart: 80,
      page: 4,
      rootNodes: [
        {
          post: pinnedPost,
          children: [],
          _renderKey: pinnedPost.id,
        },
      ],
    });

    await this.controller.togglePinPost(pinnedPost);

    assert.strictEqual(requestedPage, "0", "resolves the new ordering once");
    assert.strictEqual(this.controller.rootWindowStart, 0);
    assert.strictEqual(this.controller.pinnedRootCount, 1);
    assert.deepEqual(
      this.controller.rootNodes.map((node) => node.post.id),
      [pinnedPost.id, 4_001]
    );
  });

  test("jumpToRoot stops when loading makes no progress", async function (assert) {
    const topic = buildTopic(this.store, 724);
    let requests = 0;

    pretender.get(`/n/${topic.slug}/${topic.id}.json`, () => {
      requests++;
      return response({ roots: [], page: 1, has_more_roots: true });
    });

    this.controller.setProperties({
      topic,
      page: 0,
      hasMoreRoots: true,
      sort: "top",
      effectiveSort: "top",
      rootCount: 100,
      rootPageSize: 20,
      rootNodes: [
        {
          post: buildPost(this.store, topic, 3001, 2),
          children: [],
          _renderKey: 3001,
        },
      ],
    });

    const result = await this.controller.jumpToRoot(50);
    await settled();

    assert.strictEqual(requests, 1, "bails out instead of looping forever");
    assert.deepEqual(
      result,
      { index: 0, reached: false },
      "reports the root that remains reachable"
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

  test("acted event refreshes actionByName so the flag modal stays in sync", async function (assert) {
    const topic = buildTopic(this.store, 724);
    const postId = 3001;

    const post = this.store.createRecord("post", {
      id: postId,
      post_number: 2,
      topic,
      actions_summary: [
        { id: 3, can_act: true }, // off_topic
        { id: 4, can_act: true }, // inappropriate
        { id: 6, can_act: true }, // notify_user
        { id: 7, can_act: true }, // notify_moderators
        { id: 8, can_act: true }, // spam
      ],
    });
    post.topic = topic;

    this.controller.topic = topic;
    this.controller.subscribe();
    this.controller.postRegistry.set(post.post_number, post);

    pretender.get(`/posts/${postId}.json`, () =>
      response({
        id: postId,
        post_number: 2,
        topic_id: topic.id,
        actions_summary: [{ id: 6, acted: true, count: 1 }],
      })
    );

    this.controller._onMessage(
      { type: "acted", id: postId, updated_at: "2026-01-02T00:00:00.000Z" },
      null,
      200
    );
    await settled();

    assert.strictEqual(
      typeof post.actions_summary[0].act,
      "function",
      "rebuilds actions_summary as ActionSummary instances so postActionFor().act() works"
    );

    assert.strictEqual(
      post.actionByName.spam,
      undefined,
      "refreshes actionByName so flagsAvailable no longer offers types the server dropped"
    );
    assert.strictEqual(
      post.actionByName.off_topic,
      undefined,
      "clears every trimmed flag type, not just notify_user"
    );
    assert.true(
      post.actionByName.notify_user.acted,
      "reflects the newly-recorded flag on actionByName"
    );
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

  test("cache snapshots preserve the effective sort", function (assert) {
    const topic = buildTopic(this.store, 726);
    const cacheKey = this.nestedViewCache.buildKey(topic.id, { sort: "hot" });

    this.controller.setProperties({
      topic,
      sort: "hot",
      effectiveSort: "top",
      rootPageSize: 25,
      rootWindowStart: 50,
      rootWindowPages: [
        {
          page: 2,
          nodeCount: 20,
          hasMoreRoots: true,
          rootPageSize: 25,
        },
      ],
      pinnedRootCount: 2,
    });
    this.controller.saveToCache();

    assert.strictEqual(
      this.nestedViewCache.get(cacheKey).modelData.effectiveSort,
      "top",
      "restored pagination continues using the original effective sort"
    );
    assert.propContains(this.nestedViewCache.get(cacheKey).modelData, {
      rootPageSize: 25,
      rootWindowStart: 50,
      rootWindowPages: [
        {
          page: 2,
          nodeCount: 20,
          hasMoreRoots: true,
          rootPageSize: 25,
        },
      ],
      pinnedRootCount: 2,
    });
  });
});
