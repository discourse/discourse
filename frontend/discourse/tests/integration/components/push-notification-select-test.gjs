import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PushNotificationSelect from "discourse/components/push-notification-select";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

class StubDesktopNotifications extends Service {
  @tracked isNotSupported = false;
  @tracked isDeniedPermission = false;
  @tracked isSubscribed = false;

  enable() {
    this.isSubscribed = true;
  }

  disable() {
    this.isSubscribed = false;
  }
}

module("Integration | Component | push-notification-select", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register(
      "service:desktop-notifications",
      StubDesktopNotifications
    );
    this.desktopNotifications = this.owner.lookup(
      "service:desktop-notifications"
    );
    this.siteSettings.chat_enabled = true;
    this.model = EmberObject.create({
      user_option: EmberObject.create({
        push_notification_level: "all",
        chat_enabled: true,
      }),
      save() {
        return Promise.resolve();
      },
    });
  });

  test("shows 'Nothing' while not subscribed", async function (assert) {
    await render(
      <template><PushNotificationSelect @model={{this.model}} /></template>
    );

    assert.strictEqual(
      selectKit(".push-notification-select").header().value(),
      "none"
    );
  });

  test("reflects the stored level while subscribed", async function (assert) {
    this.desktopNotifications.isSubscribed = true;
    this.model.user_option.set("push_notification_level", "chat_only");

    await render(
      <template><PushNotificationSelect @model={{this.model}} /></template>
    );

    assert.strictEqual(
      selectKit(".push-notification-select").header().value(),
      "chat_only"
    );
  });

  test("hides the chat option when chat is disabled for the user", async function (assert) {
    this.model.user_option.set("chat_enabled", false);

    await render(
      <template><PushNotificationSelect @model={{this.model}} /></template>
    );

    await selectKit(".push-notification-select").expand();

    assert.deepEqual(
      selectKit(".push-notification-select")
        .displayedContent()
        .map((r) => r.id),
      ["none", "all"]
    );
  });

  test("selecting 'Nothing' unsubscribes", async function (assert) {
    this.desktopNotifications.isSubscribed = true;

    await render(
      <template><PushNotificationSelect @model={{this.model}} /></template>
    );

    await selectKit(".push-notification-select").expand();
    await selectKit(".push-notification-select").selectRowByValue("none");

    assert.false(this.desktopNotifications.isSubscribed);
  });

  test("selecting a level subscribes and stores it", async function (assert) {
    await render(
      <template><PushNotificationSelect @model={{this.model}} /></template>
    );

    await selectKit(".push-notification-select").expand();
    await selectKit(".push-notification-select").selectRowByValue("chat_only");

    assert.true(this.desktopNotifications.isSubscribed);
    assert.strictEqual(
      this.model.user_option.push_notification_level,
      "chat_only"
    );
  });
});
