import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module("Unit | Route | nested", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    sinon.restore();
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
});
