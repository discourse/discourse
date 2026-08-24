import { module, test } from "qunit";
import sinon from "sinon";
import { SubscribeUserNotificationsInit } from "discourse/instance-initializers/subscribe-user-notifications";
import { context } from "discourse/lib/desktop-notifications";
import KeyValueStore from "discourse/lib/key-value-store";

module(
  "Unit | Instance Initializer | subscribe-user-notifications",
  function (hooks) {
    const keyValueStore = new KeyValueStore(context);
    const currentUser = { get: (key) => (key === "id" ? 42 : undefined) };

    hooks.afterEach(function () {
      keyValueStore.remove("notifications-disabled");
    });

    test("uses session-local push suppression and restores the browser fallback on a later failure", async function (assert) {
      const messageBus = { unsubscribe: sinon.spy() };
      const desktopNotifications = {
        isGrantedPermission: true,
        pushIntent: "subscribed",
        reconcilePushSubscription: sinon.stub().resolves("subscribed"),
        setIsEnabledBrowser(value) {
          keyValueStore.setItem(
            "notifications-disabled",
            value ? "enabled" : "disabled"
          );
        },
      };
      const instance = {
        capabilities: { isMobileDevice: false },
        currentUser,
        desktopNotifications,
        messageBus,
      };

      keyValueStore.setItem("notifications-disabled", "disabled");
      await SubscribeUserNotificationsInit.prototype.reconcileTransports.call(
        instance
      );

      assert.true(
        messageBus.unsubscribe.calledWith("/notification-alert/42"),
        "successful push only removes the MessageBus alert for this session"
      );
      assert.strictEqual(
        keyValueStore.getItem("notifications-disabled"),
        "disabled",
        "it does not persist transport suppression"
      );

      desktopNotifications.reconcilePushSubscription.resolves(null);
      await SubscribeUserNotificationsInit.prototype.reconcileTransports.call(
        instance
      );

      assert.strictEqual(
        keyValueStore.getItem("notifications-disabled"),
        "enabled",
        "a later failed recovery clears suppression left by older builds"
      );
    });
  }
);
