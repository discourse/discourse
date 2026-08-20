import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import NotificationConsentBanner from "discourse/components/notification-consent-banner";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

class StubDesktopNotifications extends Service {
  @tracked isNotSupported = false;
  @tracked isEnabled = false;
  @tracked consentPromptDismissed = false;
  @tracked canRestorePushWithoutPrompt = false;
  @tracked enableCalls = 0;
  @tracked dismissCalls = 0;

  enable() {
    this.enableCalls++;
  }

  dismissConsentPrompt() {
    this.dismissCalls++;
    this.consentPromptDismissed = true;
  }
}

module("Integration | Component | NotificationConsentBanner", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register(
      "service:desktop-notifications",
      StubDesktopNotifications
    );
    sinon.stub(this.owner.lookup("service:capabilities"), "isPwa").value(true);
    this.desktopNotifications = this.owner.lookup(
      "service:desktop-notifications"
    );
    this.siteSettings.push_notifications_prompt = true;
  });

  function stubPermission(value) {
    sinon.stub(Notification, "permission").get(() => value);
  }

  test("prompts for consent when permission has not been decided", async function (assert) {
    stubPermission("default");

    await render(<template><NotificationConsentBanner /></template>);

    assert.dom(".consent_banner").exists();
  });

  test("prompts when a lost subscription can be restored without a permission prompt", async function (assert) {
    stubPermission("granted");
    this.desktopNotifications.canRestorePushWithoutPrompt = true;

    await render(<template><NotificationConsentBanner /></template>);

    assert.dom(".consent_banner").exists("the banner offers to re-enable");
  });

  test("stays hidden while permission is granted and nothing was lost", async function (assert) {
    stubPermission("granted");

    await render(<template><NotificationConsentBanner /></template>);

    assert.dom(".consent_banner").doesNotExist();
  });

  test("stays hidden once permission has been denied", async function (assert) {
    stubPermission("denied");
    this.desktopNotifications.canRestorePushWithoutPrompt = true;

    await render(<template><NotificationConsentBanner /></template>);

    assert.dom(".consent_banner").doesNotExist();
  });

  test("stays hidden once the prompt has been dismissed", async function (assert) {
    stubPermission("default");
    this.desktopNotifications.consentPromptDismissed = true;

    await render(<template><NotificationConsentBanner /></template>);

    assert.dom(".consent_banner").doesNotExist();
  });

  test("stays hidden while notifications are already enabled", async function (assert) {
    stubPermission("default");
    this.desktopNotifications.isEnabled = true;

    await render(<template><NotificationConsentBanner /></template>);

    assert.dom(".consent_banner").doesNotExist();
  });

  test("dismissing hides the banner and records the dismissal", async function (assert) {
    stubPermission("default");

    await render(<template><NotificationConsentBanner /></template>);
    await click(".consent_banner .btn-transparent.close");

    assert.dom(".consent_banner").doesNotExist();
    assert.true(this.desktopNotifications.consentPromptDismissed);
  });

  test("enabling notifications delegates to the service without recording a dismissal", async function (assert) {
    stubPermission("default");

    await render(<template><NotificationConsentBanner /></template>);
    await click(".consent_banner .btn-link");

    assert.strictEqual(this.desktopNotifications.enableCalls, 1);
    assert.strictEqual(
      this.desktopNotifications.dismissCalls,
      0,
      "turning notifications on must not latch the prompt off, so a failed enable can re-show it"
    );
  });
});
