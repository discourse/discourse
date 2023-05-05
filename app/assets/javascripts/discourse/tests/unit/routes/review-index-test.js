import User from "discourse/models/user";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Route | review-index", function (hooks) {
  setupTest(hooks);

  test("subscribes and unsubscribes /reviewable_counts MessageBus channel when user menu not enabled", function (assert) {
    const currentUser = User.create({ redesigned_user_menu_enabled: false });
    this.owner.unregister("service:current-user");
    this.owner.register("service:current-user", currentUser, {
      instantiate: false,
    });
    this.owner.inject("route", "currentUser", "service:current-user");

    const reviewIndexRoute = this.owner.lookup("route:review-index");
    const messageBus = this.owner.lookup("service:message-bus");

    let channels = messageBus.callbacks.map((c) => c.channel);
    assert.false(channels.includes("/reviewable_counts"));
    assert.false(channels.includes("/reviewable_claimed"));

    reviewIndexRoute.activate();

    channels = messageBus.callbacks.map((c) => c.channel);
    assert.true(channels.includes("/reviewable_counts"));
    assert.true(channels.includes("/reviewable_claimed"));

    reviewIndexRoute.deactivate();

    channels = messageBus.callbacks.map((c) => c.channel);
    assert.false(channels.includes("/reviewable_counts"));
    assert.false(channels.includes("/reviewable_claimed"));
  });

  test("subscribes and unsubscribes /reviewable_counts(with id) when user menu enabled", function (assert) {
    const currentUser = User.create({
      id: "the-id",
    });
    this.owner.unregister("service:current-user");
    this.owner.register("service:current-user", currentUser, {
      instantiate: false,
    });
    this.owner.inject("route", "currentUser", "service:current-user");

    const reviewIndexRoute = this.owner.lookup("route:review-index");
    const messageBus = this.owner.lookup("service:message-bus");

    let channels = messageBus.callbacks.map((c) => c.channel);
    assert.false(channels.includes("/reviewable_counts/the-id"));
    assert.false(channels.includes("/reviewable_claimed"));

    reviewIndexRoute.activate();

    channels = messageBus.callbacks.map((c) => c.channel);
    assert.true(channels.includes("/reviewable_counts/the-id"));
    assert.true(channels.includes("/reviewable_claimed"));

    reviewIndexRoute.deactivate();

    channels = messageBus.callbacks.map((c) => c.channel);
    assert.false(channels.includes("/reviewable_counts/the-id"));
    assert.false(channels.includes("/reviewable_claimed"));
  });
});
