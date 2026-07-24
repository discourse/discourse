import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

class HeaderStub extends Service {
  clearCount = 0;

  clearTopic() {
    this.clearCount++;
  }
}

function completedTransition() {
  return {
    followRedirects() {
      return Promise.resolve();
    },
  };
}

async function waitForTransitionCleanup() {
  await Promise.resolve();
  await Promise.resolve();
}

function setCurrentRouteName(route, currentRouteName) {
  sinon.stub(route.router, "currentRouteName").value(currentRouteName);
}

module("Unit | Route | topic header cleanup", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.owner.unregister("service:header");
    this.owner.register("service:header", HeaderStub);
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("topic route does not clear header topic info when transitioning between topic routes", async function (assert) {
    const route = this.owner.lookup("route:topic.from-params");
    const header = this.owner.lookup("service:header");

    setCurrentRouteName(route, "topic.fromParamsNear");
    route.controllerFor = () => ({
      set() {},
    });

    route.willTransition(completedTransition());
    await waitForTransitionCleanup();

    assert.strictEqual(
      header.clearCount,
      0,
      "topic info remains registered for topic route transitions"
    );
  });

  test("topic route clears header topic info when transitioning away from topic routes", async function (assert) {
    const route = this.owner.lookup("route:topic.from-params");
    const header = this.owner.lookup("service:header");

    setCurrentRouteName(route, "discovery.latest");
    route.controllerFor = () => ({
      set() {},
    });

    route.willTransition(completedTransition());
    await waitForTransitionCleanup();

    assert.strictEqual(
      header.clearCount,
      1,
      "topic info is cleared outside topic routes"
    );
  });
});
