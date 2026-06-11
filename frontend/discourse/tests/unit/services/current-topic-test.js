import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  registerTopicLifecycleCallback,
  resetTopicLifecycleCallbacks,
} from "discourse/lib/topic-lifecycle-callbacks";

module("Unit | Service | current-topic", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    getOwner(this).lookup("service:current-topic").leave();
    resetTopicLifecycleCallbacks();
  });

  test("tracks the active topic and runs lifecycle callbacks", function (assert) {
    const service = getOwner(this).lookup("service:current-topic");
    const topic = { id: 1 };
    const controller = { name: "nested" };
    const topicController = { name: "topic" };
    const route = { name: "nested-route" };

    registerTopicLifecycleCallback((context) => {
      assert.strictEqual(context.topic, topic);
      assert.strictEqual(context.controller, controller);
      assert.strictEqual(context.topicController, topicController);
      assert.strictEqual(context.route, route);
      assert.strictEqual(context.routeName, "nested");
      assert.notStrictEqual(context.appEvents, undefined, "includes appEvents");
      assert.notStrictEqual(
        context.messageBus,
        undefined,
        "includes messageBus"
      );

      return () => assert.step("cleanup");
    });

    service.enter({
      topic,
      controller,
      topicController,
      route,
      routeName: "nested",
    });

    assert.strictEqual(service.topic, topic, "stores the current topic");
    assert.strictEqual(
      service.topicController,
      topicController,
      "stores the compatibility topic controller"
    );

    service.leave(topic);
    assert.verifySteps(["cleanup"]);
  });

  test("cleans up previous topic lifecycle before re-entering", function (assert) {
    const service = getOwner(this).lookup("service:current-topic");
    const firstTopic = { id: 1 };
    const secondTopic = { id: 2 };

    registerTopicLifecycleCallback(({ topic }) => {
      assert.step(`enter ${topic.id}`);
      return () => assert.step(`cleanup ${topic.id}`);
    });

    service.enter({ topic: firstTopic, controller: {} });
    service.enter({ topic: secondTopic, controller: {} });
    service.leave(secondTopic);

    assert.verifySteps(["enter 1", "cleanup 1", "enter 2", "cleanup 2"]);
  });

  test("runs all cleanups and clears state when a cleanup throws", function (assert) {
    const service = getOwner(this).lookup("service:current-topic");
    const topic = { id: 1 };

    registerTopicLifecycleCallback(() => {
      return () => {
        assert.step("cleanup one");
        throw new Error("cleanup failed");
      };
    });
    registerTopicLifecycleCallback(() => {
      return () => assert.step("cleanup two");
    });

    service.enter({ topic, controller: {} });

    assert.throws(
      () => service.leave(topic),
      /cleanup failed/,
      "rethrows cleanup failures in tests"
    );
    assert.verifySteps(["cleanup two", "cleanup one"]);
    assert.strictEqual(service.topic, null, "clears the topic state");
  });

  test("cleans up partial lifecycle callbacks when entering fails", function (assert) {
    const service = getOwner(this).lookup("service:current-topic");
    const topic = { id: 1 };

    registerTopicLifecycleCallback(() => {
      return () => assert.step("cleanup successful callback");
    });
    registerTopicLifecycleCallback(() => {
      throw new Error("enter failed");
    });

    assert.throws(
      () => service.enter({ topic, controller: {} }),
      /enter failed/,
      "rethrows callback failures in tests"
    );
    assert.verifySteps(["cleanup successful callback"]);
    assert.strictEqual(service.topic, null, "clears the topic state");
  });

  test("does not clear a different active topic", function (assert) {
    const service = getOwner(this).lookup("service:current-topic");
    const topic = { id: 1 };

    service.enter({ topic, controller: {} });
    service.leave({ id: 2 });

    assert.strictEqual(service.topic, topic, "keeps the active topic");
  });
});
