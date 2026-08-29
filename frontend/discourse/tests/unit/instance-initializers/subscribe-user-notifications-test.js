import { module, test } from "qunit";
import sinon from "sinon";
import { SubscribeUserNotificationsInit } from "discourse/instance-initializers/subscribe-user-notifications";
import {
  context,
  getPushTransport,
  setPushTransport,
} from "discourse/lib/desktop-notifications";
import KeyValueStore from "discourse/lib/key-value-store";

module(
  "Unit | Instance Initializer | subscribe-user-notifications",
  function (hooks) {
    const keyValueStore = new KeyValueStore(context);
    const currentUser = { get: (key) => (key === "id" ? 42 : undefined) };

    hooks.afterEach(function () {
      keyValueStore.remove("notifications-disabled");
      // module-level state: leaving it set would silence other suites
      setPushTransport(null);
    });

    function build(result, { pushIntent = "subscribed" } = {}) {
      const desktopNotifications = {
        isGrantedPermission: true,
        pushIntent,
        reconcilePushSubscription: sinon.stub().resolves(result),
        setIsEnabledBrowser: sinon.spy(),
      };

      return {
        capabilities: { isMobileDevice: false },
        currentUser,
        desktopNotifications,
        messageBus: { unsubscribe: sinon.spy() },
      };
    }

    function reconcile(instance) {
      return SubscribeUserNotificationsInit.prototype.reconcileTransports.call(
        instance
      );
    }

    test("suppresses in-tab notifications for the session once push delivers", async function (assert) {
      const instance = build("subscribed");

      await reconcile(instance);

      assert.strictEqual(getPushTransport(), "delivering");
      assert.false(
        instance.messageBus.unsubscribe.called,
        "the alert channel stays subscribed, so clearing the session flag is all it takes to get the fallback back"
      );
      assert.strictEqual(
        keyValueStore.getItem("notifications-disabled"),
        undefined,
        "and suppression is not persisted, so the next boot decides afresh"
      );
    });

    test("treats an unconfirmed subscription as delivering", async function (assert) {
      const instance = build("unconfirmed");

      await reconcile(instance);

      assert.strictEqual(
        getPushTransport(),
        "delivering",
        "the device still has the subscription the server knows, so an in-tab fallback would double every notification"
      );
      assert.false(
        instance.desktopNotifications.setIsEnabledBrowser.called,
        "and nothing persistent is written over the user's own choice"
      );
      assert.strictEqual(
        keyValueStore.getItem("notifications-disabled"),
        undefined
      );
    });

    test("falls back to in-tab notifications for the session when push is not delivering", async function (assert) {
      const instance = build(null);

      await reconcile(instance);

      assert.strictEqual(
        getPushTransport(),
        "fallback",
        "in-tab alerts stand in past the suppression older builds persisted"
      );
      assert.false(
        instance.desktopNotifications.setIsEnabledBrowser.called,
        "without permanently overwriting the stored browser-notification preference"
      );
      assert.strictEqual(
        keyValueStore.getItem("notifications-disabled"),
        undefined
      );
    });

    test("leaves the stored preference in charge when push was never wanted", async function (assert) {
      setPushTransport("delivering");
      const instance = build(null, { pushIntent: null });

      await reconcile(instance);

      assert.strictEqual(getPushTransport(), null);
      assert.false(instance.desktopNotifications.setIsEnabledBrowser.called);
    });
  }
);
