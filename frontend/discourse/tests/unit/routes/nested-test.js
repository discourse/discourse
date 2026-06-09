import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  hydrateNestedModelData,
  NESTED_VIEW_CACHE_FORMAT_VERSION,
} from "discourse/lib/nested-view-cache-snapshot";
import PreloadStore from "discourse/lib/preload-store";

module("Unit | Route | nested", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    sinon.restore();
    PreloadStore.reset();
  });

  test("contributes topic title tokens", function (assert) {
    const route = this.owner.lookup("route:nested");
    const category = EmberObject.create({
      name: "Support",
      isUncategorizedCategory: false,
    });
    const topic = EmberObject.create({
      title: "Nested topic title",
      category,
    });
    const tokens = [];

    route.siteSettings.topic_page_title_includes_category = true;
    route.currentModel = { topic };

    route._collectTitleTokens(tokens);

    assert.deepEqual(
      tokens,
      ["Nested topic title", "Support"],
      "the nested route contributes the same title tokens as the topic route"
    );
  });

  test("tears down the active nested topic before loading a different topic", function (assert) {
    const route = this.owner.lookup("route:nested");
    const controller = this.owner.lookup("controller:nested");
    controller.topic = { id: 509 };

    const saveToCache = sinon.stub(route, "_saveToCache");
    const unsubscribe = sinon.stub(controller, "unsubscribe");
    const stopScreenTrack = sinon.stub(route.screenTrack, "stop");

    route._teardownCurrentTopic(724);

    assert.true(
      saveToCache.calledOnceWith(controller),
      "stores the current topic state before replacing it"
    );
    assert.true(unsubscribe.calledOnce, "unsubscribes from the old topic");
    assert.true(stopScreenTrack.calledOnce, "stops old topic screen tracking");
  });

  test("keeps the active nested topic subscribed when the topic id is unchanged", function (assert) {
    const route = this.owner.lookup("route:nested");
    const controller = this.owner.lookup("controller:nested");
    controller.topic = { id: 509 };

    const saveToCache = sinon.stub(route, "_saveToCache");
    const unsubscribe = sinon.stub(controller, "unsubscribe");
    const stopScreenTrack = sinon.stub(route.screenTrack, "stop");

    route._teardownCurrentTopic("509");

    assert.false(saveToCache.called, "does not cache in-topic refreshes");
    assert.false(unsubscribe.called, "keeps the active subscription");
    assert.false(stopScreenTrack.called, "keeps screen tracking active");
  });

  test("passes route-family context into the cache traversal check", async function (assert) {
    const route = this.owner.lookup("route:nested");
    const cachedModel = { topic: { id: 42 } };

    sinon.stub(route.historyStore, "isPoppedState").get(() => false);
    sinon.stub(route.nestedViewCache, "buildKey").returns("cache-key");
    const consumeTraversal = sinon
      .stub(route.nestedViewCache, "consumeTraversal")
      .returns(true);
    const cachedEntry = { modelData: { topic: { id: 42 } } };
    sinon.stub(route.nestedViewCache, "get").returns(cachedEntry);
    sinon
      .stub(route, "_hydrateCachedEntry")
      .returns({ modelData: cachedModel });

    const model = await route.model(
      { topic_id: 42, slug: "nested-topic" },
      { from: { name: "discovery.latest" } }
    );

    assert.true(
      consumeTraversal.calledOnceWith({
        allowLocalSignal: false,
        isPoppedState: false,
      }),
      "normal navigations from outside nested cannot inherit stale popstate signals"
    );
    assert.strictEqual(model, cachedModel, "returns the cache service result");
  });

  test("allows cache traversal signals within the nested route family", async function (assert) {
    const route = this.owner.lookup("route:nested");
    const cachedModel = { topic: { id: 42 } };

    sinon.stub(route.historyStore, "isPoppedState").get(() => false);
    sinon.stub(route.nestedViewCache, "buildKey").returns("cache-key");
    const consumeTraversal = sinon
      .stub(route.nestedViewCache, "consumeTraversal")
      .returns(true);
    const cachedEntry = { modelData: { topic: { id: 42 } } };
    sinon.stub(route.nestedViewCache, "get").returns(cachedEntry);
    sinon
      .stub(route, "_hydrateCachedEntry")
      .returns({ modelData: cachedModel });

    const model = await route.model(
      { topic_id: 42, slug: "nested-topic" },
      { from: { name: "nestedPost" } }
    );

    assert.true(
      consumeTraversal.calledOnceWith({
        allowLocalSignal: true,
        isPoppedState: false,
      }),
      "browser traversal between nested routes can restore from cache"
    );
    assert.strictEqual(model, cachedModel, "returns the cache service result");
  });

  test("allows history-store popped transitions from outside nested", async function (assert) {
    const route = this.owner.lookup("route:nested");
    const cachedModel = { topic: { id: 42 } };

    sinon.stub(route.historyStore, "isPoppedState").get(() => true);
    sinon.stub(route.nestedViewCache, "buildKey").returns("cache-key");
    const consumeTraversal = sinon
      .stub(route.nestedViewCache, "consumeTraversal")
      .returns(true);
    const cachedEntry = { modelData: { topic: { id: 42 } } };
    sinon.stub(route.nestedViewCache, "get").returns(cachedEntry);
    sinon
      .stub(route, "_hydrateCachedEntry")
      .returns({ modelData: cachedModel });

    const model = await route.model(
      { topic_id: 42, slug: "nested-topic" },
      { from: { name: "discovery.latest" } }
    );

    assert.true(
      consumeTraversal.calledOnceWith({
        allowLocalSignal: false,
        isPoppedState: true,
      }),
      "browser forward/back from the topic list can restore from cache"
    );
    assert.strictEqual(model, cachedModel, "returns the cache service result");
  });

  test("hydrates cached snapshots into fresh records", function (assert) {
    const route = this.owner.lookup("route:nested");
    const cached = {
      formatVersion: NESTED_VIEW_CACHE_FORMAT_VERSION,
      modelData: {
        topic: {
          id: 42,
          slug: "nested-topic",
          title: "Nested topic",
          details: { can_create_post: true },
        },
        opPost: { id: 1, post_number: 1, cooked: "<p>op</p>" },
        rootNodes: [
          {
            post: { id: 2, post_number: 2, cooked: "<p>root</p>" },
            children: [],
            _renderKey: 2,
          },
        ],
        page: 0,
        hasMoreRoots: false,
        sort: "top",
        pinnedPostIds: [],
        postNumber: null,
        contextMode: false,
        initialFocusedPath: [],
        newRootPostIds: [],
      },
      expansionState: [[2, { expanded: false, collapsed: true }]],
      fetchedChildrenCache: [
        [
          2,
          {
            childNodes: [
              {
                post: { id: 3, post_number: 3, cooked: "<p>child</p>" },
                children: [],
                _renderKey: 3,
              },
            ],
            page: 0,
            hasMore: false,
            fetchedFromServer: true,
          },
        ],
      ],
      scrollAnchor: { postNumber: 2, offsetFromTop: 40 },
    };

    const restored = route._hydrateCachedEntry(cached);
    const restoredTopic = restored.modelData.topic;
    const restoredRootPost = restored.modelData.rootNodes[0].post;
    const restoredChildPost =
      restored.fetchedChildrenCache.get(2).childNodes[0].post;

    assert.notStrictEqual(
      restoredTopic,
      cached.modelData.topic,
      "creates a fresh topic record"
    );
    assert.true(restoredTopic.is_nested_view, "marks restored topic as nested");
    assert.strictEqual(
      restoredRootPost.topic,
      restoredTopic,
      "wires restored root posts to the fresh topic"
    );
    assert.strictEqual(
      restoredChildPost.topic,
      restoredTopic,
      "wires restored cached children to the fresh topic"
    );
    assert.deepEqual(
      restored.expansionState.get(2),
      { expanded: false, collapsed: true },
      "restores expansion state"
    );
    assert.deepEqual(
      restored.scrollAnchor,
      cached.scrollAnchor,
      "restores scroll anchor"
    );
  });

  test("hydrates cached snapshots without reusing stale store records", function (assert) {
    const route = this.owner.lookup("route:nested");
    const stalePost = route.store.createRecord("post", {
      id: 2,
      post_number: 2,
      deleted_post_placeholder: true,
    });
    const snapshot = {
      topic: {
        id: 42,
        slug: "nested-topic",
        title: "Nested topic",
        details: { can_create_post: true },
      },
      opPost: { id: 1, post_number: 1, cooked: "<p>op</p>" },
      rootNodes: [
        {
          post: {
            id: 2,
            post_number: 2,
            cooked: "<p>restored root</p>",
            created_at: "2026-06-08T17:00:00.000Z",
          },
          children: [],
          _renderKey: 2,
        },
      ],
    };

    const restored = hydrateNestedModelData(route.store, snapshot);
    const restoredPost = restored.rootNodes[0].post;

    assert.notStrictEqual(
      restoredPost,
      stalePost,
      "creates a fresh post instead of reusing the store identity map"
    );
    assert.strictEqual(
      restoredPost.deleted_post_placeholder,
      undefined,
      "does not inherit placeholder state from a stale post record"
    );
    assert.strictEqual(
      restoredPost.created_at,
      "2026-06-08T17:00:00.000Z",
      "keeps the snapshot timestamp for relative date rendering"
    );
  });

  test("ignores and removes unversioned cache entries", async function (assert) {
    const route = this.owner.lookup("route:nested");

    sinon.stub(route.historyStore, "isPoppedState").get(() => true);
    sinon.stub(route.nestedViewCache, "buildKey").returns("cache-key");
    route.nestedViewCache.save("cache-key", {
      modelData: {
        topic: route.store.createRecord("topic", {
          id: 42,
          slug: "stale-topic",
          title: "Stale topic",
        }),
        rootNodes: [],
      },
    });
    const remove = sinon.spy(route.nestedViewCache, "remove");

    PreloadStore.store("nested_topic_42", {
      topic: {
        id: 42,
        slug: "nested-topic",
        title: "Fresh topic",
        details: { can_create_post: true },
      },
      op_post: { id: 1, post_number: 1, cooked: "<p>op</p>" },
      roots: [],
      page: 0,
      has_more_roots: false,
      sort: "top",
      pinned_post_ids: [],
    });

    const model = await route.model(
      { topic_id: 42, slug: "nested-topic" },
      { from: { name: "discovery.latest" } }
    );

    assert.true(
      remove.calledOnceWith("cache-key"),
      "removes the incompatible cache entry"
    );
    assert.strictEqual(
      model.topic.title,
      "Fresh topic",
      "falls back to the preloaded fresh topic payload"
    );
  });

  test("selected-post route actions open modals through the topic route", function (assert) {
    const nestedRoute = this.owner.lookup("route:nested");
    const topicRoute = this.owner.lookup("route:topic");
    const topicController = this.owner.lookup("controller:topic");
    const modal = this.owner.lookup("service:modal");
    const actions = nestedRoute.actions || nestedRoute._actions;
    const topic = { id: 42, url: "/t/nested-topic/42" };
    const posts = [
      { id: 10, username: "sam" },
      { id: 20, username: "sam" },
      { id: 30, username: "different" },
    ];

    modal.shown = [];
    modal.show = (component, options) => {
      modal.shown.push({ component, options });
    };

    topicRoute.currentModel = topic;
    topicController.setProperties({
      model: {
        postStream: {
          isMegaTopic: false,
          posts,
          stream: posts.map((post) => post.id),
        },
      },
      multiSelect: true,
    });
    topicController.selectedPostIds = [10, 20, 30];

    actions.moveToTopic.call(nestedRoute);

    topicController.selectedPostIds = [10, 20];
    actions.changeOwner.call(nestedRoute);

    const moveModel = modal.shown[0].options.model;
    assert.strictEqual(moveModel.topic, topic, "move modal receives the topic");
    assert.deepEqual(
      moveModel.selectedPostIds,
      [10, 20, 30],
      "move modal receives selected ids"
    );
    assert.deepEqual(
      moveModel.selectedPosts,
      posts,
      "move modal receives selected post records"
    );
    assert.false(
      moveModel.selectedAllPosts,
      "nested move never treats loaded nested posts as the whole topic"
    );

    const changeOwnerModel = modal.shown[1].options.model;
    assert.strictEqual(
      changeOwnerModel.topic,
      topic,
      "change-owner modal receives the topic"
    );
    assert.deepEqual(
      changeOwnerModel.selectedPostIds,
      [10, 20],
      "change-owner modal receives selected ids"
    );
    assert.strictEqual(
      changeOwnerModel.selectedPostsUsername,
      "sam",
      "change-owner modal receives the selected posts username"
    );
  });

  test("setupController clears stale topic bulk selection", function (assert) {
    const nestedRoute = this.owner.lookup("route:nested");
    const nestedController = this.owner.lookup("controller:nested");
    const topicController = this.owner.lookup("controller:topic");
    const store = this.owner.lookup("service:store");
    const staleTopic = store.createRecord("topic", { id: 41 });
    const topic = store.createRecord("topic", {
      id: 42,
      slug: "nested-topic",
    });
    const opPost = store.createRecord("post", {
      id: 1,
      post_number: 1,
      topic,
    });

    nestedRoute.header.enterTopic = () => {};
    nestedRoute.screenTrack.start = () => {};
    nestedController.subscribe = () => {};
    topicController.setProperties({
      model: staleTopic,
      multiSelect: true,
    });
    topicController.selectedPostIds = [10, 20];

    nestedRoute.setupController(nestedController, {
      topic,
      opPost,
      contextMode: true,
    });

    assert.strictEqual(
      topicController.model,
      topic,
      "hydrates the topic controller with the new nested topic"
    );
    assert.false(topicController.multiSelect, "clears stale multi-select mode");
    assert.deepEqual(
      topicController.selectedPostIds,
      [],
      "clears stale selected post ids"
    );
  });

  test("deactivate clears topic bulk selection", function (assert) {
    const nestedRoute = this.owner.lookup("route:nested");
    const topicController = this.owner.lookup("controller:topic");
    let unsubscribed = false;

    nestedRoute.controller = {
      topic: null,
      unsubscribe() {
        unsubscribed = true;
      },
    };
    nestedRoute.screenTrack.stop = () => {};
    topicController.set("multiSelect", true);
    topicController.selectedPostIds = [10, 20];

    nestedRoute.deactivate();

    assert.true(unsubscribed, "preserves nested controller deactivation");
    assert.false(topicController.multiSelect, "clears stale multi-select mode");
    assert.deepEqual(
      topicController.selectedPostIds,
      [],
      "clears stale selected post ids"
    );
  });

  test("deactivate clears stale nested topic before a later entry", function (assert) {
    const nestedRoute = this.owner.lookup("route:nested");
    const nestedController = this.owner.lookup("controller:nested");
    const saveToCache = sinon.stub(nestedRoute, "_saveToCache");
    const unsubscribe = sinon.stub(nestedController, "unsubscribe");
    const stopScreenTrack = sinon.stub(nestedRoute.screenTrack, "stop");

    nestedRoute.controller = nestedController;
    nestedController.topic = { id: 509 };

    nestedRoute.deactivate();

    assert.true(
      saveToCache.calledOnceWith(nestedController),
      "stores the active nested topic before leaving"
    );
    assert.true(unsubscribe.calledOnce, "unsubscribes from the active topic");
    assert.true(stopScreenTrack.calledOnce, "stops screen tracking");
    assert.strictEqual(
      nestedController.topic,
      null,
      "clears the inactive topic reference"
    );

    saveToCache.resetHistory();
    unsubscribe.resetHistory();
    stopScreenTrack.resetHistory();

    nestedRoute._teardownCurrentTopic(724);

    assert.false(
      saveToCache.called,
      "does not overwrite cache from a non-nested page"
    );
    assert.false(
      unsubscribe.called,
      "does not unsubscribe an already inactive nested topic"
    );
    assert.false(
      stopScreenTrack.called,
      "does not stop screen tracking a second time"
    );
  });
});
