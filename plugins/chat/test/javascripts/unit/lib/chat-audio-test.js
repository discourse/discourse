import { getOwner } from "@ember/owner";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import chatAudioInitializer from "discourse/plugins/chat/discourse/initializers/chat-audio";

module("Discourse Chat | Unit | chat-audio", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const chatAudioManager = getOwner(this).lookup(
      "service:chat-audio-manager"
    );

    this.chat = getOwner(this).lookup("service:chat");
    sinon.stub(this.chat, "userCanChat").value(true);

    this.siteSettings = getOwner(this).lookup("service:site-settings");
    this.siteSettings.chat_enabled = true;

    this.currentUser.user_option.has_chat_enabled = true;
    this.currentUser.user_option.chat_sound = "ding";
    this.currentUser.user_option.chat_header_indicator_preference = "all_new";

    withPluginApi("0.12.1", async (api) => {
      this.stub = sinon.spy(api, "registerDesktopNotificationHandler");
      chatAudioInitializer.initialize(getOwner(this));

      this.notificationHandler = this.stub.getCall(0).callback;
      this.playStub = sinon.stub(chatAudioManager, "play");

      this.handleNotification = (data = {}) => {
        if (!data.notification_type) {
          data.notification_type = 30;
        }
        this.notificationHandler(data, this.siteSettings, this.currentUser);
      };
    });
  });

  test("it registers desktop notification handler", function (assert) {
    assert.ok(this.stub.calledOnce);
  });

  test("it plays chat sound", function (assert) {
    this.handleNotification();

    assert.ok(this.playStub.calledOnce);
  });

  test("it skips chat sound for user in DND mode", function (assert) {
    this.currentUser.isInDoNotDisturb = () => true;
    this.handleNotification();

    assert.ok(this.playStub.notCalled);
  });

  test("it skips chat sound for user with no chat sound set", function (assert) {
    this.currentUser.user_option.chat_sound = null;
    this.handleNotification();

    assert.ok(this.playStub.notCalled);
  });

  test("it plays a chat sound for mentions", function (assert) {
    this.currentUser.user_option.chat_header_indicator_preference =
      "only_mentions";

    this.handleNotification({ notification_type: 29 });

    assert.ok(this.playStub.calledOnce);
  });

  test("it skips chat sound for non-mentions", function (assert) {
    this.currentUser.user_option.chat_header_indicator_preference =
      "only_mentions";

    this.handleNotification();

    assert.ok(this.playStub.notCalled);
  });

  test("it plays a chat sound for DMs", function (assert) {
    this.currentUser.user_option.chat_header_indicator_preference =
      "dm_and_mentions";

    this.handleNotification({ is_direct_message_channel: true });

    assert.ok(this.playStub.calledOnce);
  });

  test("it skips chat sound for non-DM messages", function (assert) {
    this.currentUser.user_option.chat_header_indicator_preference =
      "dm_and_mentions";

    this.handleNotification({ is_direct_message_channel: false });

    assert.ok(this.playStub.notCalled);
  });
});
