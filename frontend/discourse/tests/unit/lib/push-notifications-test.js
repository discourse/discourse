import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  canSubscribeToPushNotifications,
  isPushNotificationsSupported,
  subscribe,
} from "discourse/lib/push-notifications";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Utility | push-notifications", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.capabilities = getOwner(this).lookup("service:capabilities");
  });

  test("canSubscribeToPushNotifications returns true when all required browser APIs are present", function (assert) {
    sinon.stub(this.capabilities, "isAppWebview").get(() => false);

    assert.true(canSubscribeToPushNotifications());
  });

  test("canSubscribeToPushNotifications returns false when inside an app webview", function (assert) {
    sinon.stub(this.capabilities, "isAppWebview").get(() => true);

    assert.false(canSubscribeToPushNotifications());
  });

  test("canSubscribeToPushNotifications does not require an active service worker controller", function (assert) {
    sinon.stub(this.capabilities, "isAppWebview").get(() => false);
    sinon.stub(navigator.serviceWorker, "controller").get(() => null);

    assert.true(canSubscribeToPushNotifications());
  });

  test("isPushNotificationsSupported returns false when no service worker is controlling the page", function (assert) {
    sinon.stub(this.capabilities, "isAppWebview").get(() => false);
    sinon.stub(navigator.serviceWorker, "controller").get(() => null);

    assert.false(isPushNotificationsSupported());
  });

  test("isPushNotificationsSupported returns false when controller is not yet activated", function (assert) {
    sinon.stub(this.capabilities, "isAppWebview").get(() => false);
    sinon
      .stub(navigator.serviceWorker, "controller")
      .get(() => ({ state: "activating" }));

    assert.false(isPushNotificationsSupported());
  });

  test("isPushNotificationsSupported returns true when an activated controller is present", function (assert) {
    sinon.stub(this.capabilities, "isAppWebview").get(() => false);
    sinon
      .stub(navigator.serviceWorker, "controller")
      .get(() => ({ state: "activated" }));

    assert.true(isPushNotificationsSupported());
  });

  test("subscribe proceeds even when the service worker does not control the page yet", async function (assert) {
    sinon.stub(this.capabilities, "isAppWebview").get(() => false);
    sinon.stub(navigator.serviceWorker, "controller").get(() => null);

    const fakeSubscription = {
      toJSON: () => ({ endpoint: "https://example.com/push" }),
    };
    const fakeRegistration = {
      pushManager: {
        subscribe: sinon.stub().resolves(fakeSubscription),
      },
    };
    sinon
      .stub(navigator.serviceWorker, "ready")
      .get(() => Promise.resolve(fakeRegistration));

    pretender.post("/push_notifications/subscribe", () => response({}));

    const callback = sinon.stub();
    await subscribe(callback, "1|2|3");

    assert.true(
      fakeRegistration.pushManager.subscribe.calledOnce,
      "pushManager.subscribe was called despite no controller"
    );
    assert.true(callback.calledOnce, "success callback was invoked");
  });
});
