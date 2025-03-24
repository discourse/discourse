import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Route | review-index", function (hooks) {
  setupTest(hooks);

  test("subscribes and unsubscribes /reviewable_counts(with id) when user menu enabled", function (assert) {
    const store = this.owner.lookup("service:store");
    const currentUser = store.createRecord("user", { id: 654 });
    this.owner.unregister("service:current-user");
    this.owner.register("service:current-user", currentUser, {
      instantiate: false,
    });

    const reviewIndexRoute = this.owner.lookup("route:review-index");
    const messageBus = this.owner.lookup("service:message-bus");

    let channels = messageBus.callbacks.map((c) => c.channel);
    assert.false(channels.includes("/reviewable_counts/654"));

    reviewIndexRoute.activate();

    channels = messageBus.callbacks.map((c) => c.channel);
    assert.true(channels.includes("/reviewable_counts/654"));

    reviewIndexRoute.deactivate();

    channels = messageBus.callbacks.map((c) => c.channel);
    assert.false(channels.includes("/reviewable_counts/654"));
  });
});
