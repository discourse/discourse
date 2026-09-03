import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { pushNotificationConfirmationStore } from "discourse/lib/push-notifications";

module("Unit | Route | application", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    pushNotificationConfirmationStore.remove("active");
  });

  test("logout clears the server confirmation for the current account", async function (assert) {
    const store = this.owner.lookup("service:store");
    const currentUser = store.createRecord("user", {
      id: 42,
      username: "current-user",
    });
    sinon.stub(currentUser, "destroySession").resolves({ redirect_url: "/" });
    this.owner.unregister("service:current-user");
    this.owner.register("service:current-user", currentUser, {
      instantiate: false,
    });
    sinon.stub(navigator.serviceWorker, "getRegistration").resolves({
      pushManager: {
        getSubscription: () =>
          Promise.resolve({
            toJSON: () => ({ endpoint: "current" }),
          }),
      },
    });
    pushNotificationConfirmationStore.setObject({
      key: "active",
      value: { userId: 42, endpoint: "current" },
    });

    await this.owner.lookup("route:application").logout();

    assert.strictEqual(
      pushNotificationConfirmationStore.getObject("active"),
      undefined,
      "a later login cannot trust a row the logout request retired"
    );
  });
});
