import { destroy } from "@ember/destroyable";
import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  clearDesktopNotificationHandlers,
  init,
  onNotification,
  registerDesktopNotificationHandler,
} from "discourse/lib/desktop-notifications";
import KeyValueStore from "discourse/lib/key-value-store";
import User from "discourse/models/user";

module("Unit | Utility | desktop-notifications", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.sandbox = sinon.createSandbox();
    this.owners = [];
    this.notifications = [];
    this.user = { isInDoNotDisturb: () => false };
    this.appEvents = { trigger: this.sandbox.spy() };
    this.data = {
      translated_title: "Notification",
      excerpt: "A reply",
      topic_id: 123,
      post_url: "/t/example/123",
    };

    const notifications = this.notifications;
    this.Notification = class extends EventTarget {
      static permission = "default";
      static requestPermission = sinon.stub();

      close = sinon.spy(() => this.dispatchEvent(new Event("close")));

      constructor() {
        super();
        notifications.push(this);
      }
    };
    this.sandbox.stub(window, "Notification").value(this.Notification);
    this.sandbox.stub(User, "current").returns(this.user);
    this.sandbox.stub(KeyValueStore.prototype, "getItem").returns(null);
    this.sandbox.stub(KeyValueStore.prototype, "setItem");
    clearDesktopNotificationHandlers();

    this.startOwner = () => {
      const owner = {};
      this.owners.push(owner);
      init({ clientId: "notification-test" }, { owner });
      window.dispatchEvent(new Event("focus"));
      return owner;
    };
  });

  hooks.afterEach(function () {
    run(() => this.owners.forEach((owner) => destroy(owner)));
    clearDesktopNotificationHandlers();
    this.sandbox.restore();
  });

  for (const permission of ["granted", "denied"]) {
    test(`ignores ${permission} permission after the requesting owner is destroyed`, async function (assert) {
      const firstOwner = this.startOwner();
      const pending = onNotification(
        this.data,
        this.siteSettings,
        this.user,
        this.appEvents,
        { owner: firstOwner }
      );
      assert.true(this.Notification.requestPermission.calledOnce);

      run(() => destroy(firstOwner));
      const secondOwner = this.startOwner();
      const handler = this.sandbox.spy();
      registerDesktopNotificationHandler(handler, { owner: secondOwner });
      this.Notification.requestPermission.firstCall.args[0](permission);
      await pending;

      assert.strictEqual(this.notifications.length, 0);
      assert.false(handler.called);
      assert.false(this.appEvents.trigger.called);
    });
  }

  test("closes an existing notification when its owner is destroyed", async function (assert) {
    this.Notification.permission = "granted";
    const owner = this.startOwner();
    await onNotification(
      this.data,
      this.siteSettings,
      this.user,
      this.appEvents,
      { owner }
    );
    assert.strictEqual(this.notifications.length, 1);
    const notification = this.notifications[0];

    run(() => destroy(owner));

    assert.true(notification.close.calledOnce);
    assert.false(this.appEvents.trigger.called);
  });
});
