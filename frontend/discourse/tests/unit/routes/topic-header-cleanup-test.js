import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

class HeaderStub extends Service {
  clearCount = 0;

  clearTopic() {
    this.clearCount++;
  }
}

class RouterStub extends Service {
  currentRouteName = null;
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

module("Unit | Route | topic header cleanup", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register("service:header", HeaderStub);
    this.owner.register("service:router", RouterStub);
  });

  test("nested route does not clear header topic info when transitioning to flat topic route", async function (assert) {
    const route = this.owner.lookup("route:nested");
    const header = this.owner.lookup("service:header");
    const router = this.owner.lookup("service:router");

    router.currentRouteName = "topic.fromParams";

    route.willTransition(completedTransition());
    await waitForTransitionCleanup();

    assert.strictEqual(
      header.clearCount,
      0,
      "topic info remains registered for the flat topic route"
    );
  });

  test("flat topic route does not clear header topic info when transitioning to nested route", async function (assert) {
    const route = this.owner.lookup("route:topic.from-params");
    const header = this.owner.lookup("service:header");
    const router = this.owner.lookup("service:router");

    router.currentRouteName = "nested";
    route.controllerFor = () => ({
      set() {},
    });

    route.willTransition(completedTransition());
    await waitForTransitionCleanup();

    assert.strictEqual(
      header.clearCount,
      0,
      "topic info remains registered for the nested topic route"
    );
  });

  test("nested route clears header topic info when transitioning away from topic routes", async function (assert) {
    const route = this.owner.lookup("route:nested");
    const header = this.owner.lookup("service:header");
    const router = this.owner.lookup("service:router");

    router.currentRouteName = "discovery.latest";

    route.willTransition(completedTransition());
    await waitForTransitionCleanup();

    assert.strictEqual(
      header.clearCount,
      1,
      "topic info is cleared outside topic routes"
    );
  });
});
