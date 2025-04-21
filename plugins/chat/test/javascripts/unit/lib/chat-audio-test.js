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

    this.currentUser.chat_sound = "ding";
    this.currentUser.user_option.has_chat_enabled = true;
    this.currentUser.user_option.chat_header_indicator_preference = "all_new";

    withPluginApi("0.12.1", async (api) => {
      this.stub = sinon.spy(api, "registerDesktopNotificationHandler");
      chatAudioInitializer.initialize(getOwner(this));

      // stub the service worker response
      sinon
        .stub(chatAudioInitializer, "canPlaySound")
        .returns(Promise.resolve(true));

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

  test("registers desktop notification handler", function (assert) {
    assert.true(this.stub.calledOnce);
  });

  test("plays chat sound", async function (assert) {
    await this.handleNotification();

    assert.true(this.playStub.calledOnce);
  });

  test("skips chat sound for user in DND mode", async function (assert) {
    this.currentUser.isInDoNotDisturb = () => true;
    await this.handleNotification();

    assert.true(this.playStub.notCalled);
  });

  test("skips chat sound for user with no chat sound set", async function (assert) {
    this.currentUser.chat_sound = null;
    await this.handleNotification();

    assert.true(this.playStub.notCalled);
  });

  test("plays a chat sound for mentions", async function (assert) {
    this.currentUser.user_option.chat_header_indicator_preference =
      "only_mentions";

    await this.handleNotification({ notification_type: 29 });

    assert.true(this.playStub.calledOnce);
  });

  test("skips chat sound for non-mentions", async function (assert) {
    this.currentUser.user_option.chat_header_indicator_preference =
      "only_mentions";

    await this.handleNotification();

    assert.true(this.playStub.notCalled);
  });

  test("plays a chat sound for DMs", async function (assert) {
    this.currentUser.user_option.chat_header_indicator_preference =
      "dm_and_mentions";

    await this.handleNotification({ is_direct_message_channel: true });

    assert.true(this.playStub.calledOnce);
  });

  test("skips chat sound for non-DM messages", async function (assert) {
    this.currentUser.user_option.chat_header_indicator_preference =
      "dm_and_mentions";

    await this.handleNotification({ is_direct_message_channel: false });

    assert.true(this.playStub.notCalled);
  });

  test("skips chat sound when service worker returns false", async function (assert) {
    chatAudioInitializer.canPlaySound.returns(Promise.resolve(false));
    await this.handleNotification();

    assert.true(this.playStub.notCalled);
  });
});
