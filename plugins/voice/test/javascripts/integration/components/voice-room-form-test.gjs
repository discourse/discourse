import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import VoiceRoomForm from "discourse/plugins/voice/discourse/components/voice-room-form";

class ChatApiStub extends Service {
  channels() {
    return {
      items: [{ id: 6, title: "Team Meeting", threadingEnabled: true }],
      async load() {},
    };
  }
}

module("Integration | Component | voice-room-form", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.chat_enabled = true;
    this.siteSettings.voice_chat_enabled = true;
    this.siteSettings.voice_video_enabled = false;

    this.owner.unregister("service:chat-api");
    this.owner.register("service:chat-api", ChatApiStub);
  });

  test("shows the chat settings for a room that already has a chat channel linked", async function (assert) {
    this.room = {
      name: "Team Meeting",
      description: "",
      public: true,
      room_type: "open",
      max_participants: null,
      video_enabled: true,
      chat_channel_id: 6,
      chat_idle_minutes: 2,
    };

    await render(<template><VoiceRoomForm @room={{this.room}} /></template>);

    assert.dom('select[name="chat_channel_id"]').hasValue("6");
    assert
      .dom('input[name="chat_idle_minutes"]')
      .exists("the idle-minutes field is shown once a channel is linked");
  });

  test("can clear a linked chat channel back to none", async function (assert) {
    this.room = {
      name: "Team Meeting",
      description: "",
      public: true,
      room_type: "open",
      max_participants: null,
      video_enabled: true,
      chat_channel_id: 6,
      chat_idle_minutes: 2,
    };

    await render(<template><VoiceRoomForm @room={{this.room}} /></template>);
    assert.dom('input[name="chat_idle_minutes"]').exists();

    await formKit().field("chat_channel_id").select("__NONE__");

    assert.dom('select[name="chat_channel_id"]').hasValue("__NONE__");
    assert
      .dom('input[name="chat_idle_minutes"]')
      .doesNotExist("idle-minutes field hides once the channel is cleared");
  });

  test("shows the media server toggle only when per-room LiveKit is available", async function (assert) {
    this.room = {
      name: "Town hall",
      description: "",
      public: true,
      room_type: "open",
      max_participants: null,
      video_enabled: true,
      livekit_enabled: false,
      chat_channel_id: null,
      chat_idle_minutes: 15,
    };

    this.owner
      .lookup("service:site")
      .set("voice_livekit_per_room_available", true);
    await render(<template><VoiceRoomForm @room={{this.room}} /></template>);
    assert.dom('[data-name="livekit_enabled"]').exists();

    this.owner
      .lookup("service:site")
      .set("voice_livekit_per_room_available", false);
    await render(<template><VoiceRoomForm @room={{this.room}} /></template>);
    assert.dom('[data-name="livekit_enabled"]').doesNotExist();
  });

  test("hides the chat settings when no chat channel is linked", async function (assert) {
    this.room = {
      name: "Chill",
      description: "",
      public: true,
      room_type: "open",
      max_participants: null,
      video_enabled: true,
      chat_channel_id: null,
      chat_idle_minutes: 15,
    };

    await render(<template><VoiceRoomForm @room={{this.room}} /></template>);

    assert.dom('input[name="chat_idle_minutes"]').doesNotExist();
  });
});
