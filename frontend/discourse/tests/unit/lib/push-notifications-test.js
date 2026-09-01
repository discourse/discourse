import { settled, waitUntil } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { helperContext } from "discourse/lib/helpers";
import KeyValueStore from "discourse/lib/key-value-store";
import {
  getSubscriptionIntent,
  keyValueStore,
  pushNotificationPreferenceStore,
  reconcileSubscription,
  setSubscriptionIntent,
  subscribe,
  unsubscribe,
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
    pushNotificationPreferenceStore.remove(userSubscriptionKey(user));
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
    assert.strictEqual(
      pushNotificationPreferenceStore.getItem(userSubscriptionKey(user)),
      "off",
      "the old opt-out is migrated to storage which survives logout"
    );
  });

  test("an explicit opt-out survives logout storage cleanup", function (assert) {
    setSubscriptionIntent(user, "off");

    new KeyValueStore("discourse_").abandonLocal();

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
          this.subscription = {
            toJSON: () => ({ endpoint: "restored" }),
            unsubscribe: () => {
              this.platformUnsubscribeCalls++;
              this.subscription = null;
              return Promise.resolve(true);
            },
          };
          return Promise.resolve(this.subscription);
        },
      };

      sinon
        .stub(navigator.serviceWorker, "ready")
        .get(() => Promise.resolve({ pushManager }));
    });

    hooks.afterEach(function () {
      keyValueStore.remove(userSubscriptionKey(user));
      pushNotificationPreferenceStore.remove(userSubscriptionKey(user));
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

    test("adopts an existing subscription when the intent is unknown", async function (assert) {
      pushManager.subscription = {
        toJSON: () => ({ endpoint: "existing" }),
        unsubscribe: () => {
          pushManager.platformUnsubscribeCalls++;
          return Promise.resolve(true);
        },
      };
      sinon.stub(Notification, "permission").get(() => "granted");

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, "subscribed");
      assert.strictEqual(
        getSubscriptionIntent(user),
        "subscribed",
        "the origin-level permission applies unless this user opted out"
      );
      await settled();
      assert.deepEqual(
        subscribeRequests,
        [
          {
            subscription: { endpoint: "existing" },
            send_confirmation: "false",
          },
        ],
        "the POST transfers the endpoint to the current account"
      );
      assert.strictEqual(
        pushManager.platformUnsubscribeCalls,
        0,
        "adoption preserves the working platform subscription"
      );
    });

    test("creates a subscription by default when permission is already granted", async function (assert) {
      sinon.stub(Notification, "permission").get(() => "granted");

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, "subscribed");
      assert.strictEqual(
        pushManager.subscribeCalls,
        1,
        "the origin-level notification grant opts the account into push"
      );
      assert.strictEqual(getSubscriptionIntent(user), "subscribed");
      assert.deepEqual(subscribeRequests, [
        { subscription: { endpoint: "restored" }, send_confirmation: "false" },
      ]);
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
      assert.strictEqual(
        pushManager.platformUnsubscribeCalls,
        0,
        "only one subscription exists per origin, so a restore this tab could not confirm must not destroy one another tab just did"
      );
    });

    test("does not suppress fallback when an existing subscription cannot be confirmed", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "granted");
      pushManager.subscription = { toJSON: () => ({ endpoint: "existing" }) };
      pretender.post("/push_notifications/subscribe", () => response(500, {}));

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(
        result,
        null,
        "only a successful server response proves push can deliver"
      );
      assert.strictEqual(
        getSubscriptionIntent(user),
        "subscribed",
        "the preference survives so reconciliation can retry"
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

    test("re-reads the intent recorded while it was awaiting the platform", async function (assert) {
      let platformUnsubscribeCalls = 0;
      const subscription = {
        toJSON: () => ({ endpoint: "just-enabled" }),
        unsubscribe: () => {
          platformUnsubscribeCalls++;
          return Promise.resolve(true);
        },
      };
      sinon.stub(Notification, "permission").get(() => "granted");
      pushManager.getSubscription = () => {
        // the consent banner's `enable()` completes while reconcile is parked
        // on this await, so the intent it read on entry is already stale
        setSubscriptionIntent(user, "subscribed");
        return Promise.resolve(subscription);
      };

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(
        platformUnsubscribeCalls,
        0,
        "a subscription the user just created must not be destroyed by a stale intent read"
      );
      assert.strictEqual(result, "subscribed");
      assert.strictEqual(getSubscriptionIntent(user), "subscribed");
    });

    test("retires a row the resync recreated after the user opted out", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "granted");
      pushManager.subscription = { toJSON: () => ({ endpoint: "existing" }) };
      pretender.post("/push_notifications/subscribe", (request) => {
        subscribeRequests.push(parsePostData(request.requestBody));
        // the user hits disable while the resync POST is in flight
        setSubscriptionIntent(user, "off");
        return response({ success: "OK" });
      });

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, null, "the opt-out stands");
      assert.strictEqual(getSubscriptionIntent(user), "off");

      await settled();
      assert.deepEqual(
        unsubscribeRequests,
        [{ subscription: { endpoint: "existing" } }],
        "the recreated row is retired; the platform subscription is already gone, so nothing else can reach it"
      );
    });

    test("retires a row a stale resync recreated after logout", async function (assert) {
      setSubscriptionIntent(user, "subscribed");
      sinon.stub(Notification, "permission").get(() => "granted");
      pushManager.subscription = { toJSON: () => ({ endpoint: "existing" }) };
      pretender.post("/push_notifications/subscribe", (request) => {
        subscribeRequests.push(parsePostData(request.requestBody));
        setSubscriptionIntent(user, null);
        return response({ success: "OK" });
      });

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(
        result,
        null,
        "the logged-out account is not restored"
      );
      assert.strictEqual(
        getSubscriptionIntent(user),
        null,
        "the stale request does not recreate local state"
      );
      assert.deepEqual(
        unsubscribeRequests,
        [{ subscription: { endpoint: "existing" } }],
        "the stale account's recreated row is retired"
      );
    });

    test("retires an adoption that completes after logout", async function (assert) {
      sinon.stub(Notification, "permission").get(() => "granted");
      pushManager.subscription = { toJSON: () => ({ endpoint: "existing" }) };
      pretender.post("/push_notifications/subscribe", (request) => {
        subscribeRequests.push(parsePostData(request.requestBody));
        setSubscriptionIntent(user, null);
        return response({ success: "OK" });
      });

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, null, "the logged-out account is not adopted");
      assert.strictEqual(getSubscriptionIntent(user), null);
      assert.deepEqual(
        unsubscribeRequests,
        [{ subscription: { endpoint: "existing" } }],
        "the stale account's row is retired"
      );
    });

    test("retries retiring the server subscription when the user turned push off", async function (assert) {
      setSubscriptionIntent(user, "off");
      pushManager.subscription = {
        toJSON: () => ({ endpoint: "left-behind" }),
        unsubscribe: () => {
          pushManager.platformUnsubscribeCalls++;
          return Promise.resolve(true);
        },
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
        1,
        "the endpoint is invalidated so it cannot retain another account's delivery"
      );
    });

    test("replays an enable that lands during opt-out cleanup", async function (assert) {
      setSubscriptionIntent(user, "off");
      pushManager.subscription = {
        toJSON: () => ({ endpoint: "re-enabled" }),
        unsubscribe: () => {
          pushManager.platformUnsubscribeCalls++;
          return Promise.resolve(true);
        },
      };
      pretender.post("/push_notifications/unsubscribe", (request) => {
        unsubscribeRequests.push(parsePostData(request.requestBody));
        setSubscriptionIntent(user, "subscribed");
        return response({ success: "OK" });
      });

      const result = await reconcileSubscription(user, {
        resubscribe: true,
        applicationServerKey,
      });

      assert.strictEqual(result, "subscribed");
      assert.strictEqual(
        pushManager.platformUnsubscribeCalls,
        0,
        "the explicit enable keeps the platform subscription"
      );
      assert.deepEqual(
        subscribeRequests,
        [
          {
            subscription: { endpoint: "re-enabled" },
            send_confirmation: "false",
          },
        ],
        "the row is recreated after the stale teardown"
      );
    });
  }
);

module(
  "Unit | Lib | push-notifications | subscribe and unsubscribe",
  function (hooks) {
    setupTest(hooks);

    const user = { get: (key) => (key === "id" ? 42 : undefined) };
    const applicationServerKey = "1|2|3";

    let pushManager;
    let subscribeRequests;
    let unsubscribeRequests;
    let platformUnsubscribeCalls;

    hooks.beforeEach(function () {
      subscribeRequests = [];
      unsubscribeRequests = [];
      platformUnsubscribeCalls = 0;

      pretender.post("/push_notifications/subscribe", (request) => {
        subscribeRequests.push(parsePostData(request.requestBody));
        return response({ success: "OK" });
      });
      pretender.post("/push_notifications/unsubscribe", (request) => {
        unsubscribeRequests.push(parsePostData(request.requestBody));
        return response({ success: "OK" });
      });

      const subscription = {
        toJSON: () => ({ endpoint: "current" }),
        // the platform reports false once it has dropped the subscription
        // itself, which is exactly when the server row is still there
        unsubscribe: () => {
          platformUnsubscribeCalls++;
          return Promise.resolve(false);
        },
      };

      pushManager = {
        subscription,
        getSubscription: () => Promise.resolve(pushManager.subscription),
        subscribe: () => Promise.resolve(subscription),
      };

      sinon
        .stub(navigator.serviceWorker, "ready")
        .get(() => Promise.resolve({ pushManager }));
    });

    hooks.afterEach(function () {
      keyValueStore.remove(userSubscriptionKey(user));
      pushNotificationPreferenceStore.remove(userSubscriptionKey(user));
    });

    test("retires the server subscription even when the platform already dropped it", async function (assert) {
      await unsubscribe(user, () => {});

      assert.deepEqual(
        unsubscribeRequests,
        [{ subscription: { endpoint: "current" } }],
        "delivery only stops once the server row is gone, so it is never conditional on the platform teardown"
      );
      assert.strictEqual(platformUnsubscribeCalls, 1);
      assert.strictEqual(getSubscriptionIntent(user), "off");
    });

    test("records the opt-out when push is no longer supported", async function (assert) {
      sinon.stub(helperContext().capabilities, "isAppWebview").value(true);

      assert.true(await unsubscribe(user, () => assert.step("disabled")));

      assert.strictEqual(getSubscriptionIntent(user), "off");
      assert.verifySteps(["disabled"]);
    });

    test("does not finish disabling until platform teardown settles", async function (assert) {
      let finishPlatformUnsubscribe;
      pushManager.subscription.unsubscribe = () => {
        platformUnsubscribeCalls++;
        return new Promise((resolve) => {
          finishPlatformUnsubscribe = resolve;
        });
      };

      const disabling = unsubscribe(user, () => assert.step("disabled"));

      await waitUntil(() => platformUnsubscribeCalls === 1);
      assert.verifySteps(
        [],
        "the callback does not report disabled while platform teardown is pending"
      );

      finishPlatformUnsubscribe(true);
      assert.true(await disabling);
      assert.verifySteps(["disabled"]);
    });

    test("reports success once the server has the subscription", async function (assert) {
      const subscribed = await subscribe(() => {}, applicationServerKey);

      assert.true(subscribed);
      assert.deepEqual(subscribeRequests, [
        {
          subscription: { endpoint: "current" },
          send_confirmation: "true",
        },
      ]);
    });

    test("does not report success when the server never recorded the subscription", async function (assert) {
      pretender.post("/push_notifications/subscribe", () => response(500, {}));

      const subscribed = await subscribe(
        () => assert.step("enabled"),
        applicationServerKey
      );

      assert.false(
        subscribed,
        "a subscription the server does not know about receives nothing"
      );
      assert.verifySteps([], "the intent is never recorded as subscribed");
    });
  }
);
