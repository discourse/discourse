import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  isPushNotificationsEnabled,
  keyValueStore,
  register,
  userSubscriptionKey,
} from "discourse/lib/push-notifications";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";

module("Unit | Lib | push-notifications | register", function (hooks) {
  setupTest(hooks);

  const user = {
    get: (key) => (key === "id" ? 42 : undefined),
    isInDoNotDisturb: () => false,
  };
  const router = { transitionTo() {} };
  const appEvents = { trigger() {} };

  hooks.beforeEach(function () {
    this.subscribeRequests = [];
    pretender.post("/push_notifications/subscribe", (request) => {
      this.subscribeRequests.push(parsePostData(request.requestBody));
      return response({ success: "OK" });
    });

    this.pushManager = {
      subscription: null,
      getSubscription: sinon.spy(function () {
        return Promise.resolve(this.subscription);
      }),
      subscribe: sinon.spy(function () {
        this.subscription = {
          toJSON: () => ({
            endpoint: "restored",
            keys: { p256dh: "p256dh", auth: "auth" },
          }),
        };
        return Promise.resolve(this.subscription);
      }),
    };

    sinon
      .stub(navigator.serviceWorker, "ready")
      .get(() => Promise.resolve({ pushManager: this.pushManager }));
    sinon
      .stub(navigator.serviceWorker, "controller")
      .get(() => ({ state: "activated" }));
    sinon.stub(Notification, "permission").get(() => "granted");
  });

  hooks.afterEach(function () {
    keyValueStore.remove(userSubscriptionKey(user));
  });

  test("restores a subscription the browser dropped", async function (assert) {
    keyValueStore.setItem(userSubscriptionKey(user), "subscribed");

    await register(user, router, appEvents, "1|2|3");
    await settled();

    assert.true(this.pushManager.subscribe.calledOnce);
    assert.deepEqual(
      Array.from(
        this.pushManager.subscribe.firstCall.args[0].applicationServerKey
      ),
      [1, 2, 3]
    );
    assert.strictEqual(
      this.subscribeRequests[0]?.subscription.endpoint,
      "restored"
    );
  });

  test("does not subscribe a user who turned push off", async function (assert) {
    keyValueStore.setItem(userSubscriptionKey(user), "false");

    await register(user, router, appEvents, "1|2|3");
    await settled();

    assert.true(this.pushManager.subscribe.notCalled);
    assert.strictEqual(this.subscribeRequests.length, 0);
  });

  test("resyncs an existing subscription without resubscribing", async function (assert) {
    keyValueStore.setItem(userSubscriptionKey(user), "subscribed");
    this.pushManager.subscription = {
      toJSON: () => ({
        endpoint: "existing",
        keys: { p256dh: "p256dh", auth: "auth" },
      }),
    };

    await register(user, router, appEvents, "1|2|3");
    await settled();

    assert.true(this.pushManager.subscribe.notCalled);
    assert.strictEqual(
      this.subscribeRequests[0]?.subscription.endpoint,
      "existing"
    );
  });

  test("reports a failed restore so alerts can fall back", async function (assert) {
    keyValueStore.setItem(userSubscriptionKey(user), "subscribed");
    this.pushManager.subscribe = sinon.stub().rejects(new Error("offline"));
    sinon.stub(console, "error");

    const registered = await register(user, router, appEvents, "1|2|3");

    assert.false(registered);
    assert.strictEqual(this.subscribeRequests.length, 0);
  });

  test("reports a restore the server did not accept", async function (assert) {
    keyValueStore.setItem(userSubscriptionKey(user), "subscribed");
    pretender.post("/push_notifications/subscribe", () => response(500, {}));
    sinon.stub(console, "error");

    const registered = await register(user, router, appEvents, "1|2|3");

    assert.false(registered);
  });

  test("treats a turned-off subscription as disabled", function (assert) {
    keyValueStore.setItem(userSubscriptionKey(user), "false");
    assert.false(isPushNotificationsEnabled(user));

    keyValueStore.setItem(userSubscriptionKey(user), "subscribed");
    assert.true(isPushNotificationsEnabled(user));
  });

  test("drops a restored subscription when push was turned off meanwhile", async function (assert) {
    keyValueStore.setItem(userSubscriptionKey(user), "subscribed");
    const restored = { unsubscribe: sinon.stub().resolves(true) };
    this.pushManager.subscribe = () => {
      keyValueStore.setItem(userSubscriptionKey(user), "false");
      return Promise.resolve(restored);
    };

    await register(user, router, appEvents, "1|2|3");
    await settled();

    assert.true(restored.unsubscribe.calledOnce);
    assert.strictEqual(this.subscribeRequests.length, 0);
    assert.strictEqual(
      keyValueStore.getItem(userSubscriptionKey(user)),
      "false"
    );
  });

  test("does not fall back when the subscription cannot be read", async function (assert) {
    keyValueStore.setItem(userSubscriptionKey(user), "subscribed");
    this.pushManager.getSubscription = sinon
      .stub()
      .rejects(new Error("storage"));
    sinon.stub(console, "error");

    const registered = await register(user, router, appEvents, "1|2|3");
    await settled();

    assert.notStrictEqual(registered, false);
    assert.true(this.pushManager.subscribe.notCalled);
    assert.strictEqual(this.subscribeRequests.length, 0);
  });
});
