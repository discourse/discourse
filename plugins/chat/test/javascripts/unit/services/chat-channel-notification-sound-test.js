import { getOwner } from "@ember/application";
import { test } from "qunit";
import {
  disable,
  init,
  resetIdle,
  setLastAction,
} from "discourse/lib/desktop-notifications";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

function buildDirectMessageChannel(owner) {
  const channel = new ChatFabricators(owner).directMessageChannel();
  buildMembership(channel);
  return channel;
}
function buildCategoryMessageChannel(owner) {
  const channel = new ChatFabricators(owner).channel();
  buildMembership(channel);
  return channel;
}

function buildMembership(channel) {
  channel.currentUserMembership = {
    following: true,
    desktop_notification_level: "always",
    muted: false,
  };
  return channel;
}

acceptance(
  "Discourse Chat | Unit | Service | chat-channel-notification-sound",
  function (needs) {
    needs.hooks.beforeEach(function () {
      Object.defineProperty(this, "subject", {
        get: () =>
          this.container.lookup("service:chat-channel-notification-sound"),
      });

      Object.defineProperty(this, "site", {
        get: () => this.container.lookup("service:site"),
      });

      Object.defineProperty(this, "chat", {
        get: () => this.container.lookup("service:chat"),
      });

      updateCurrentUser({ chat_sound: "ding" });

      init(
        this.container.lookup("service:message-bus"),
        this.container.lookup("service:app-events")
      );

      setLastAction(moment().subtract(1, "hour").valueOf());
    });

    needs.user();

    test("in do not disturb", async function (assert) {
      updateCurrentUser({ do_not_disturb_until: moment().add(1, "hour") });
      const channel = buildDirectMessageChannel(getOwner(this));

      assert.deepEqual(await this.subject.play(channel), false);
    });

    test("no chat sound", async function (assert) {
      updateCurrentUser({ chat_sound: null });
      const channel = buildDirectMessageChannel(getOwner(this));

      assert.deepEqual(await this.subject.play(channel), false);
    });

    test("mobile", async function (assert) {
      const channel = buildDirectMessageChannel(getOwner(this));
      this.site.mobileView = true;

      assert.deepEqual(await this.subject.play(channel), false);
    });

    test("plays sound", async function (assert) {
      const channel = buildDirectMessageChannel(getOwner(this));

      assert.deepEqual(await this.subject.play(channel), true);
    });

    test("muted", async function (assert) {
      const channel = buildDirectMessageChannel(getOwner(this));
      channel.currentUserMembership.muted = true;

      assert.deepEqual(await this.subject.play(channel), false);
    });

    test("not following", async function (assert) {
      const channel = buildDirectMessageChannel(getOwner(this));
      channel.currentUserMembership.following = false;

      assert.deepEqual(await this.subject.play(channel), false);
    });

    test("no notification", async function (assert) {
      const channel = buildDirectMessageChannel(getOwner(this));
      channel.currentUserMembership.desktopNotificationLevel = "never";

      assert.deepEqual(await this.subject.play(channel), false);
    });

    test("currently active channel", async function (assert) {
      const channel = buildDirectMessageChannel(getOwner(this));
      this.chat.activeChannel = channel;

      assert.deepEqual(await this.subject.play(channel), false);
    });

    test("category channel", async function (assert) {
      const channel = buildCategoryMessageChannel(getOwner(this));

      assert.deepEqual(await this.subject.play(channel), false);
    });

    test("group", async function (assert) {
      const channel = buildDirectMessageChannel(getOwner(this));
      channel.chatable.group = true;

      assert.deepEqual(await this.subject.play(channel), false);
    });

    test("not idle", async function (assert) {
      const channel = buildDirectMessageChannel(getOwner(this));
      resetIdle();

      assert.deepEqual(await this.subject.play(channel), false);
    });

    test("notifications disabled", async function (assert) {
      const channel = buildDirectMessageChannel(getOwner(this));
      disable();

      assert.deepEqual(await this.subject.play(channel), false);
    });
  }
);
