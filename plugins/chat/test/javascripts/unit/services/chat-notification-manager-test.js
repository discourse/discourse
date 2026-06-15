import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  clearDesktopNotificationHandlers,
  registerDesktopNotificationHandler,
} from "discourse/lib/desktop-notifications";

module("Unit | Service | chat-notification-manager", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.subject = getOwner(this).lookup("service:chat-notification-manager");
    this.session = getOwner(this).lookup("service:session");
    this.chat = getOwner(this).lookup("service:chat");

    this.handledMessages = [];
    registerDesktopNotificationHandler((data) =>
      this.handledMessages.push(data)
    );

    this.chat.activeChannel = { id: 1 };
  });

  hooks.afterEach(function () {
    clearDesktopNotificationHandlers();
    sinon.restore();
  });

  test("suppresses the desktop notification when the window is focused on the active channel", async function (assert) {
    this.session.hasFocus = true;
    sinon.stub(document, "hasFocus").returns(true);

    await this.subject.onMessage({ channel_id: 1 });

    assert.strictEqual(
      this.handledMessages.length,
      0,
      "does not show a desktop notification"
    );
  });

  test("shows the desktop notification when the window lacks input focus", async function (assert) {
    // The tab is still visible but the window is in the background
    this.session.hasFocus = true;
    sinon.stub(document, "hasFocus").returns(false);

    await this.subject.onMessage({ channel_id: 1 });

    assert.strictEqual(
      this.handledMessages.length,
      1,
      "shows a desktop notification"
    );
  });

  test("shows the desktop notification for a non-active channel even when focused", async function (assert) {
    this.session.hasFocus = true;
    sinon.stub(document, "hasFocus").returns(true);

    await this.subject.onMessage({ channel_id: 2 });

    assert.strictEqual(
      this.handledMessages.length,
      1,
      "shows a desktop notification"
    );
  });
});
