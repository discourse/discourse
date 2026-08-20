import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  getSubscriptionIntent,
  keyValueStore,
  reconcileSubscription,
  setSubscriptionIntent,
  userSubscriptionKey,
} from "discourse/lib/push-notifications";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";

module("Unit | Lib | push-notifications", function (hooks) {
  setupTest(hooks);

  const user = { get: (key) => (key === "id" ? 42 : undefined) };

  hooks.afterEach(function () {
    keyValueStore.remove(userSubscriptionKey(user));
  });

  test("getSubscriptionIntent returns the stored intent", function (assert) {
    setSubscriptionIntent(user, "subscribed");
    assert.strictEqual(getSubscriptionIntent(user), "subscribed");

    setSubscriptionIntent(user, "off");
    assert.strictEqual(getSubscriptionIntent(user), "off");
  });

  test("getSubscriptionIntent returns null when nothing is stored", function (assert) {
    assert.strictEqual(getSubscriptionIntent(user), null);
  });

  test("getSubscriptionIntent maps the legacy explicit-disable value to off", function (assert) {
    keyValueStore.setItem(userSubscriptionKey(user), "false");
    assert.strictEqual(getSubscriptionIntent(user), "off");
  });

  test("getSubscriptionIntent treats the legacy empty value as unknown", function (assert) {
    keyValueStore.setItem(userSubscriptionKey(user), "");
    assert.strictEqual(
      getSubscriptionIntent(user),
      null,
      "older builds stamped an empty value for every unsubscribed user, so it carries no signal"
    );
  });

  test("setSubscriptionIntent with null clears the stored value", function (assert) {
    setSubscriptionIntent(user, "subscribed");
    setSubscriptionIntent(user, null);
    assert.strictEqual(
      keyValueStore.getItem(userSubscriptionKey(user)),
      undefined
    );
  });
});

module(
  "Unit | Lib | push-notifications | reconcileSubscription",
  function (hooks) {
    setupTest(hooks);

    const user = { get: (key) => (key === "id" ? 42 : undefined) };
    const applicationServerKey = "1|2|3";

    let pushManager;
    let subscribeRequests;
    let unsubscribeRequests;

    hooks.beforeEach(function () {
      subscribeRequests = [];
      unsubscribeRequests = [];
      pretender.post("/push_notifications/subscribe", (request) => {
        subscribeRequests.push(parsePostData(request.requestBody));
        return response({ success: "OK" });
      });
      pretender.post("/push_notifications/unsubscribe", (request) => {
        unsubscribeRequests.push(parsePostData(request.requestBody));
        return response({ success: "OK" });
      });

      pushManager = {
        subscription: null,
        subscribeCalls: 0,
        platformUnsubscribeCalls: 0,
        getSubscription() {
          return Promise.resolve(this.subscription);
        },
        subscribe() {
          this.subscribeCalls++;
          this.subscription = { toJSON: () => ({ endpoint: "restored" }) };
          return Promise.resolve(this.subscription);
        },
      };

      sinon
        .stub(navigator.serviceWorker, "ready")
        .get(() => Promise.resolve({ pushManager }));
    });

    hooks.afterEach(function () {
      keyValueStore.remove(userSubscriptionKey(user));
    });

    test("restores a subscription the platform dropped while permission is granted", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "granted");

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, "subscribed");
      assert.strictEqual(pushManager.subscribeCalls, 1, "it resubscribes");
      assert.strictEqual(getSubscriptionIntent(user), "subscribed");

      await settled();
      assert.deepEqual(
        subscribeRequests,
        [
          {
            subscription: { endpoint: "restored" },
            send_confirmation: "false",
          },
        ],
        "the restored subscription is sent to the server without a confirmation push"
      );
    });

    test("reports the subscription lost when permission is no longer granted", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "default");

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, "lost");
      assert.strictEqual(
        pushManager.subscribeCalls,
        0,
        "it cannot resubscribe"
      );
      assert.strictEqual(
        getSubscriptionIntent(user),
        null,
        "the stale intent is cleared so the consent prompt can return"
      );
    });

    test("leaves an explicit opt-out alone", async function (assert) {
      setSubscriptionIntent(user, "off");
      sinon.stub(Notification, "permission").get(() => "granted");

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, null);
      assert.strictEqual(pushManager.subscribeCalls, 0);
      assert.strictEqual(getSubscriptionIntent(user), "off");
    });

    test("never adopts an existing subscription when the intent is unknown", async function (assert) {
      pushManager.subscription = { toJSON: () => ({ endpoint: "other-user" }) };
      sinon.stub(Notification, "permission").get(() => "granted");

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, null);
      assert.strictEqual(
        getSubscriptionIntent(user),
        null,
        "a live subscription may belong to another user of the same browser"
      );
      await settled();
      assert.deepEqual(subscribeRequests, [], "nothing is sent to the server");
    });

    test("does not resubscribe when push is not the preferred transport", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "granted");

      const result = await reconcileSubscription(user, {
        resubscribe: false,
        applicationServerKey,
      });

      assert.strictEqual(
        result,
        null,
        "no restore is attempted, so none is claimed either way"
      );
      assert.strictEqual(pushManager.subscribeCalls, 0);
      assert.strictEqual(
        getSubscriptionIntent(user),
        "subscribed",
        "the intent survives"
      );
    });

    test("resyncs the server when the device already has a subscription", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "granted");
      pushManager.subscription = { toJSON: () => ({ endpoint: "existing" }) };

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, "subscribed");
      assert.strictEqual(
        pushManager.subscribeCalls,
        0,
        "an existing subscription is not replaced"
      );

      await settled();
      assert.deepEqual(subscribeRequests, [
        { subscription: { endpoint: "existing" }, send_confirmation: "false" },
      ]);
    });

    test("does not claim success when the server never received the subscription", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "granted");
      pretender.post("/push_notifications/subscribe", () => response(500, {}));

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(
        result,
        null,
        "a subscription the server does not know about cannot receive pushes, so the caller must not silence the fallback"
      );
      assert.strictEqual(
        getSubscriptionIntent(user),
        "subscribed",
        "the intent survives for the next boot to retry"
      );
    });

    test("treats a revoked permission grant as a loss even when the subscription survived", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "default");
      pushManager.subscription = {
        toJSON: () => ({ endpoint: "undisplayable" }),
      };

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(
        result,
        "lost",
        "a subscription the browser will not display is not a working one"
      );
      assert.strictEqual(getSubscriptionIntent(user), null);

      await settled();
      assert.deepEqual(
        subscribeRequests,
        [],
        "nothing is resynced as subscribed"
      );
    });

    test("keeps the intent when a restore fails for a transient reason", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "granted");
      pushManager.subscribe = () => Promise.reject(new Error("offline"));

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, null, "nothing is concluded");
      assert.strictEqual(
        getSubscriptionIntent(user),
        "subscribed",
        "a network failure is not turned into an opt-out"
      );
    });

    test("keeps the intent when the key needed to resubscribe is missing", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "granted");

      const result = await reconcileSubscription(user, { resubscribe: true });

      assert.strictEqual(result, null);
      assert.strictEqual(getSubscriptionIntent(user), "subscribed");
    });

    test("retries retiring the server subscription when the user turned push off", async function (assert) {
      setSubscriptionIntent(user, "off");
      pushManager.subscription = {
        toJSON: () => ({ endpoint: "left-behind" }),
      };

      const result = await reconcileSubscription(user, { resubscribe: true });

      assert.strictEqual(result, null);
      assert.deepEqual(
        unsubscribeRequests,
        [{ subscription: { endpoint: "left-behind" } }],
        "a teardown that failed earlier is retried so delivery actually stops"
      );
      assert.strictEqual(
        getSubscriptionIntent(user),
        "off",
        "the opt-out is preserved"
      );
      assert.strictEqual(
        pushManager.platformUnsubscribeCalls,
        0,
        "the platform subscription is left alone, it may belong to another account"
      );
    });
  }
);
