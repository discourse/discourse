import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import fabricators from "../helpers/fabricators";
import { CHATABLE_TYPES } from "discourse/plugins/chat/discourse/models/chat-channel";
import { module } from "qunit";

module("Discourse Chat | Component | chat-channel-title", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("category channel", {
    template: hbs`{{chat-channel-title channel=channel}}`,

    beforeEach() {
      this.set(
        "channel",
        fabricators.chatChannel({
          chatable_type: CHATABLE_TYPES.categoryChannel,
        })
      );
    },

    async test(assert) {
      assert.equal(
        query(".chat-channel-title__category-badge").getAttribute("style"),
        `color: #${this.channel.chatable.color}`
      );
      assert.equal(
        query(".chat-channel-title__name").innerText,
        this.channel.title
      );
    },
  });

  componentTest("category channel - escapes title", {
    template: hbs`{{chat-channel-title channel=channel}}`,

    beforeEach() {
      this.set(
        "channel",
        fabricators.chatChannel({
          chatable_type: CHATABLE_TYPES.categoryChannel,
          title: "<div class='xss'>evil</div>",
        })
      );
    },

    async test(assert) {
      assert.notOk(exists(".xss"));
    },
  });

  componentTest("category channel - read restricted", {
    template: hbs`{{chat-channel-title channel=channel}}`,

    beforeEach() {
      this.set(
        "channel",
        fabricators.chatChannel({
          chatable_type: CHATABLE_TYPES.categoryChannel,
          chatable: { read_restricted: true },
        })
      );
    },

    async test(assert) {
      assert.ok(exists(".d-icon-lock"));
    },
  });

  componentTest("category channel - not read restricted", {
    template: hbs`{{chat-channel-title channel=channel}}`,

    beforeEach() {
      this.set(
        "channel",
        fabricators.chatChannel({
          chatable_type: CHATABLE_TYPES.categoryChannel,
          chatable: { read_restricted: false },
        })
      );
    },

    async test(assert) {
      assert.notOk(exists(".d-icon-lock"));
    },
  });

  componentTest("direct message channel - one user", {
    template: hbs`{{chat-channel-title channel=channel}}`,

    beforeEach() {
      this.set("channel", fabricators.directMessageChatChannel());
    },

    async test(assert) {
      const user = this.channel.chatable.users[0];

      assert.ok(
        exists(`.chat-user-avatar-container .avatar[title="${user.username}"]`)
      );

      assert.equal(
        query(".chat-channel-title__name").innerText.trim(),
        user.username
      );
    },
  });

  componentTest("direct message channel - multiple users", {
    template: hbs`{{chat-channel-title channel=channel}}`,

    beforeEach() {
      const channel = fabricators.directMessageChatChannel();

      channel.chatable.users.push({
        id: 2,
        username: "joffrey",
        name: null,
        avatar_template: "/letter_avatar_proxy/v3/letter/t/31188e/{size}.png",
      });

      this.set("channel", channel);
    },

    async test(assert) {
      const users = this.channel.chatable.users;

      assert.equal(
        parseInt(
          query(".chat-channel-title__users-count").innerText.trim(),
          10
        ),
        users.length
      );

      assert.equal(
        query(".chat-channel-title__name").innerText.trim(),
        users.mapBy("username").join(", ")
      );
    },
  });

  componentTest("unreadIndicator", {
    template: hbs`{{chat-channel-title channel=channel unreadIndicator=unreadIndicator}}`,

    beforeEach() {
      const channel = fabricators.chatChannel({
        chatable_type: CHATABLE_TYPES.directMessageChannel,
      });

      const state = {};
      state[channel.id] = {
        unread_count: 1,
      };
      this.currentUser.set("chat_channel_tracking_state", state);

      this.set("channel", channel);
    },

    async test(assert) {
      this.set("unreadIndicator", true);

      assert.ok(exists(".chat-channel-unread-indicator"));

      this.set("unreadIndicator", false);

      assert.notOk(exists(".chat-channel-unread-indicator"));
    },
  });
});
