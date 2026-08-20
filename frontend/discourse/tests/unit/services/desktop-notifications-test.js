import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Service | desktop-notifications", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    logIn(this.owner);
    this.service = this.owner.lookup("service:desktop-notifications");
    this.owner.lookup(
      "service:site-settings"
    ).enable_desktop_push_notifications = true;
  });

  hooks.afterEach(function () {
    this.service.rearmConsentPrompt();
  });

  function unusablePushManager() {
    return {
      getSubscription: () => Promise.resolve(null),
      subscribe: () => Promise.reject(new Error("no push service")),
    };
  }

  function stubUnusablePushService() {
    sinon
      .stub(navigator.serviceWorker, "ready")
      .get(() => Promise.resolve({ pushManager: unusablePushManager() }));
  }

  test("asks for permission before touching the service worker", async function (assert) {
    // the request has to happen inside the click's user activation; awaiting the
    // service worker first expires it and the prompt is refused
    sinon.stub(Notification, "permission").get(() => "default");
    let readyAwaited = false;
    sinon.stub(navigator.serviceWorker, "ready").get(() => {
      readyAwaited = true;
      return Promise.resolve({ pushManager: unusablePushManager() });
    });
    const requested = sinon
      .stub(Notification, "requestPermission")
      .callsFake((callback) => Promise.resolve(callback?.("denied")));

    const enabled = await this.service.enable();

    assert.false(enabled);
    assert.true(requested.called, "permission is requested");
    assert.false(
      readyAwaited,
      "it gives up before awaiting the service worker, so the gesture is never spent"
    );
  });

  test("clears the intent and re-arms the consent prompt when the subscription is lost", async function (assert) {
    const { setSubscriptionIntent } =
      await import("discourse/lib/push-notifications");
    setSubscriptionIntent(
      this.owner.lookup("service:current-user"),
      "subscribed"
    );
    this.service.pushIntent = "subscribed";
    this.service.dismissConsentPrompt();

    sinon.stub(Notification, "permission").get(() => "default");
    sinon
      .stub(navigator.serviceWorker, "ready")
      .get(() => Promise.resolve({ pushManager: unusablePushManager() }));

    const result = await this.service.reconcilePushSubscription();

    assert.strictEqual(result, "lost");
    assert.strictEqual(
      this.service.pushIntent,
      null,
      "the service stops reporting push as enabled"
    );
    assert.false(
      this.service.consentPromptDismissed,
      "the consent prompt is re-armed so the user can opt back in"
    );
  });

  test("stops reporting push as enabled when a restore could not be confirmed", async function (assert) {
    const { setSubscriptionIntent } =
      await import("discourse/lib/push-notifications");
    setSubscriptionIntent(
      this.owner.lookup("service:current-user"),
      "subscribed"
    );
    this.service.pushIntent = "subscribed";

    assert.true(
      this.service.isEnabledPush,
      "before reconciling, intent stands"
    );

    sinon.stub(Notification, "permission").get(() => "granted");
    sinon
      .stub(navigator.serviceWorker, "ready")
      .get(() => Promise.resolve({ pushManager: unusablePushManager() }));

    const result = await this.service.reconcilePushSubscription();

    assert.strictEqual(result, null, "the failure is transient");
    assert.strictEqual(
      this.service.pushIntent,
      "subscribed",
      "the intent is kept so the next boot retries"
    );
    assert.false(
      this.service.isEnabledPush,
      "but the UI must not claim push is working"
    );
    assert.false(this.service.isSubscribed);
  });

  test("push can still be switched off after an unconfirmed restore", async function (assert) {
    const { getSubscriptionIntent, setSubscriptionIntent } =
      await import("discourse/lib/push-notifications");
    const user = this.owner.lookup("service:current-user");
    setSubscriptionIntent(user, "subscribed");
    this.service.pushIntent = "subscribed";
    this.service.pushSubscriptionConfirmed = false;

    sinon
      .stub(navigator.serviceWorker, "ready")
      .get(() => Promise.resolve({ pushManager: unusablePushManager() }));

    await this.service.disable();

    assert.strictEqual(
      getSubscriptionIntent(user),
      "off",
      "turning it off follows the stored intent, not the unconfirmed state"
    );
    assert.false(this.service.isEnabledPush);
  });

  test("the consent prompt dismissal is recorded against the current user", async function (assert) {
    const { keyValueStore } = await import("discourse/lib/push-notifications");
    const userId = this.owner.lookup("service:current-user").id;

    this.service.dismissConsentPrompt();

    assert.true(this.service.consentPromptDismissed);
    assert.strictEqual(
      keyValueStore.getItem(`dismissed-prompt-${userId}`),
      "dismissed",
      "the dismissal is stored under this user's key, not a shared one"
    );

    this.service.rearmConsentPrompt();

    assert.false(this.service.consentPromptDismissed);
    assert.strictEqual(
      keyValueStore.getItem(`dismissed-prompt-${userId}`),
      undefined
    );
  });

  test("does not enable anything when permission is refused", async function (assert) {
    sinon.stub(Notification, "permission").get(() => "default");
    sinon
      .stub(Notification, "requestPermission")
      .callsFake((callback) => Promise.resolve(callback?.("denied")));

    const enabled = await this.service.enable();

    assert.false(enabled);
    assert.false(this.service.isEnabledBrowser);
    assert.false(this.service.isEnabledPush);
  });

  test("a rejected permission request resolves instead of hanging", async function (assert) {
    // the request is only made when permission is still undecided
    sinon.stub(Notification, "permission").get(() => "default");
    sinon
      .stub(Notification, "requestPermission")
      .callsFake(() => Promise.reject(new Error("NotAllowedError")));

    const enabled = await this.service.enable();

    assert.false(enabled, "enable() settles rather than blocking the caller");
  });

  test("reports failure without silently switching transport when push cannot subscribe", async function (assert) {
    stubUnusablePushService();
    sinon.stub(Notification, "permission").get(() => "granted");

    assert.true(this.service.isPushNotificationsPreferred);

    const enabled = await this.service.enable();

    assert.false(enabled, "the failure is reported to the caller");
    assert.false(
      this.service.isEnabledBrowser,
      "it does not quietly enable a transport the UI is not describing"
    );
    assert.false(this.service.isEnabledPush);
    assert.false(
      this.service.isSubscribed,
      "isSubscribed agrees with the reported failure"
    );
  });
});
