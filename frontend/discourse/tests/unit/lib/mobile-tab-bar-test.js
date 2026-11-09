import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { findRoute, routeWithin } from "discourse/lib/mobile-tab-bar";

module("Unit | Lib | mobile-tab-bar", function (hooks) {
  setupTest(hooks);

  test("routeWithin", function (assert) {
    assert.true(routeWithin({ name: "chat" }, "chat"), "the route itself");
    assert.true(
      routeWithin({ name: "chat.channel.index" }, "chat"),
      "a route below it"
    );
    assert.true(
      routeWithin({ name: "tag.show" }, "discovery", "tag"),
      "any of several names"
    );
    assert.false(
      routeWithin({ name: "chatter" }, "chat"),
      "not a route that only starts with the name"
    );
    assert.false(routeWithin(null, "chat"), "not a missing route");
  });

  test("findRoute", function (assert) {
    const topic = { name: "topic", attributes: { id: 1 } };
    const leaf = { name: "topic.fromParams", parent: topic };

    assert.strictEqual(findRoute(leaf, "topic"), topic, "an ancestor");
    assert.strictEqual(findRoute(topic, "topic"), topic, "the route itself");
    assert.strictEqual(findRoute(leaf, "user"), undefined, "nothing else");
  });
});
