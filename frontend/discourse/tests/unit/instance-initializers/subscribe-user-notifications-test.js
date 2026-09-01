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
        isPushNotificationsPreferred: true,
        pushIntent,
        reconcilePushSubscription: sinon.stub().resolves(result),
        setIsEnabledBrowser: sinon.spy(),
      };

      return {
        capabilities: { isMobileDevice: false },
        currentUser: { ...currentUser, isInDoNotDisturb: () => false },
        siteSettings: {},
        appEvents: { trigger: sinon.spy() },
        desktopNotifications,
        messageBus: { unsubscribe: sinon.spy() },
        reconcileTransports:
          SubscribeUserNotificationsInit.prototype.reconcileTransports,
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

    test("a desktop alert retries push after reconciliation fails", async function (assert) {
      const clock = sinon.useFakeTimers();
      const instance = build(null);
      const { reconcilePushSubscription } = instance.desktopNotifications;
      reconcilePushSubscription.onSecondCall().resolves("subscribed");
      const onAlert = Object.getOwnPropertyDescriptor(
        SubscribeUserNotificationsInit.prototype,
        "onAlert"
      ).get.call(instance);

      try {
        await reconcile(instance);
        setPushTransport("delivering");
        onAlert({});
        assert.strictEqual(
          reconcilePushSubscription.callCount,
          1,
          "an alert during the cooldown does not retry"
        );

        clock.tick(60_001);
        onAlert({});
        await instance.pushReconciliation;
      } finally {
        clock.restore();
      }

      assert.strictEqual(
        reconcilePushSubscription.callCount,
        2,
        "a transient failure is retried without waiting for a reload"
      );
      assert.strictEqual(
        getPushTransport(),
        "delivering",
        "successful retry suppresses the in-tab fallback"
      );
    });

    test("assumes push delivers while reconciliation is still in flight", async function (assert) {
      let finishReconciliation;
      const instance = build(null);
      instance.desktopNotifications.reconcilePushSubscription = () =>
        new Promise((resolve) => (finishReconciliation = resolve));

      const pending = reconcile(instance);

      assert.strictEqual(
        getPushTransport(),
        "delivering",
        "a notification arriving during the boot round trip would be shown twice"
      );

      finishReconciliation("subscribed");
      await pending;

      assert.strictEqual(getPushTransport(), "delivering");
    });

    test("a completed enable overrides an older reconciliation verdict", async function (assert) {
      let finishReconciliation;
      const instance = build(null, { pushIntent: null });
      instance.desktopNotifications.reconcilePushSubscription = () =>
        new Promise((resolve) => (finishReconciliation = resolve));

      const pending = reconcile(instance);
      instance.desktopNotifications.pushIntent = "subscribed";
      setPushTransport("delivering");
      finishReconciliation(null);
      await pending;

      assert.strictEqual(
        getPushTransport(),
        "delivering",
        "the stale fallback cannot overrule the explicit enable"
      );
    });

    test("a completed disable overrides an older reconciliation verdict", async function (assert) {
      let finishReconciliation;
      const instance = build(null);
      instance.desktopNotifications.reconcilePushSubscription = () =>
        new Promise((resolve) => (finishReconciliation = resolve));

      const pending = reconcile(instance);
      instance.desktopNotifications.pushIntent = "off";
      setPushTransport(null);
      finishReconciliation("subscribed");
      await pending;

      assert.strictEqual(
        getPushTransport(),
        null,
        "the stale delivery verdict cannot overrule the explicit opt-out"
      );
    });

    test("leaves an explicit opt-out in charge", async function (assert) {
      setPushTransport("delivering");
      const instance = build(null, { pushIntent: "off" });

      await reconcile(instance);

      assert.strictEqual(getPushTransport(), null);
      assert.false(instance.desktopNotifications.setIsEnabledBrowser.called);
    });
  }
);
