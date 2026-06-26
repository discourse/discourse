import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import ChatChannel from "discourse/plugins/chat/discourse/components/chat-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Component | ChatChannel | screen reader announcements",
  function (hooks) {
    setupRenderingTest(hooks);

    const channelId = 1;

    hooks.beforeEach(function () {
      // Keep announcements in the live region so we can assert on them.
      disableClearA11yAnnouncementsInTests();

      pretender.get(`/chat/api/channels/1/messages`, () =>
        response({ messages: [], meta: { can_delete_self: true } })
      );
      pretender.get(`/chat/api/me/channels`, () =>
        response({ direct_message_channels: [], public_channels: [] })
      );

      this.currentUser = getOwner(this).lookup("service:current-user");
      this.currentUser.id = 1;
      this.currentUser.set("user_option", { chat_announce_new_messages: true });

      this.channel = new ChatFabricators(getOwner(this)).channel({
        id: channelId,
        currentUserMembership: { following: true },
        meta: { can_join_chat_channel: false },
      });
    });

    hooks.afterEach(function () {
      enableClearA11yAnnouncementsInTests();
    });

    function publishSentMessage(overrides = {}) {
      return publishToMessageBus(`/chat/${channelId}`, {
        type: "sent",
        chat_message: {
          id: 2138,
          message: "Hello there",
          cooked: "<p>Hello there</p>",
          excerpt: "Hello there",
          created_at: "2023-05-18T16:07:59.588Z",
          available_flags: [],
          chat_channel_id: channelId,
          user: { id: 2, username: "otheruser" },
          uploads: [],
          ...overrides,
        },
      });
    }

    test("announces incoming messages from other users", async function (assert) {
      await render(
        <template>
          <ChatChannel @channel={{this.channel}} />
          <A11yLiveRegions />
        </template>
      );

      await publishSentMessage();

      assert
        .dom("#a11y-announcements-polite")
        .hasText("otheruser: Hello there");
    });

    test("does not announce the current user's own messages", async function (assert) {
      await render(
        <template>
          <ChatChannel @channel={{this.channel}} />
          <A11yLiveRegions />
        </template>
      );

      await publishSentMessage({
        user: { id: this.currentUser.id, username: this.currentUser.username },
      });

      assert.dom("#a11y-announcements-polite").hasNoText();
    });

    test("does not announce messages from ignored users", async function (assert) {
      this.currentUser.ignored_users = ["otheruser"];

      await render(
        <template>
          <ChatChannel @channel={{this.channel}} />
          <A11yLiveRegions />
        </template>
      );

      await publishSentMessage();

      assert.dom("#a11y-announcements-polite").hasNoText();
    });

    test("does not announce hidden messages", async function (assert) {
      await render(
        <template>
          <ChatChannel @channel={{this.channel}} />
          <A11yLiveRegions />
        </template>
      );

      await publishSentMessage({ hidden: true });

      assert.dom("#a11y-announcements-polite").hasNoText();
    });

    test("announces an image-only message as an image", async function (assert) {
      await render(
        <template>
          <ChatChannel @channel={{this.channel}} />
          <A11yLiveRegions />
        </template>
      );

      await publishSentMessage({
        message: "",
        excerpt: "photo.png",
        uploads: [{ id: 1, original_filename: "photo.png" }],
      });

      assert
        .dom("#a11y-announcements-polite")
        .hasText("otheruser sent an image");
    });

    test("announces a non-image upload as an attachment", async function (assert) {
      await render(
        <template>
          <ChatChannel @channel={{this.channel}} />
          <A11yLiveRegions />
        </template>
      );

      await publishSentMessage({
        message: "",
        excerpt: "report.pdf",
        uploads: [{ id: 1, original_filename: "report.pdf" }],
      });

      assert
        .dom("#a11y-announcements-polite")
        .hasText("otheruser sent an attachment");
    });

    test("announces a caption together with its image", async function (assert) {
      await render(
        <template>
          <ChatChannel @channel={{this.channel}} />
          <A11yLiveRegions />
        </template>
      );

      await publishSentMessage({
        message: "Look at this",
        excerpt: "Look at this",
        uploads: [{ id: 1, original_filename: "photo.png" }],
      });

      assert
        .dom("#a11y-announcements-polite")
        .hasText("otheruser: Look at this (with an image)");
    });

    test("does not announce when the user has opted out", async function (assert) {
      this.currentUser.set("user_option", {
        chat_announce_new_messages: false,
      });

      await render(
        <template>
          <ChatChannel @channel={{this.channel}} />
          <A11yLiveRegions />
        </template>
      );

      await publishSentMessage();

      assert.dom("#a11y-announcements-polite").hasNoText();
    });

    test("coalesces a burst of messages into a single summary", async function (assert) {
      await render(
        <template>
          <ChatChannel @channel={{this.channel}} />
          <A11yLiveRegions />
        </template>
      );

      const first = publishSentMessage({ id: 10, message: "First" });
      const second = publishSentMessage({ id: 11, message: "Second" });
      await Promise.all([first, second]);

      assert.dom("#a11y-announcements-polite").hasText("2 new messages");
    });
  }
);
