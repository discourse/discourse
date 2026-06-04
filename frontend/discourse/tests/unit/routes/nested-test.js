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
});
