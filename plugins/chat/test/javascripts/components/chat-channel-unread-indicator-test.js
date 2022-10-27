import { set } from "@ember/object";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { CHATABLE_TYPES } from "discourse/plugins/chat/discourse/models/chat-channel";
import { module } from "qunit";

const directMessageChannel = {
  id: 1,
  chatable_type: CHATABLE_TYPES.directMessageChannel,
  chatable: {
    users: [{ id: 1 }],
  },
};

const topicChannel = {
  id: 2,
  chatable_type: CHATABLE_TYPES.topicChannel,
  chatable: {
    users: [{ id: 1 }],
  },
};

module(
  "Discourse Chat | Component | chat-channel-unread-indicator",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("has no unread", {
      template: hbs`{{chat-channel-unread-indicator channel=channel}}`,

      beforeEach() {
        set(this.currentUser, "chat_channel_tracking_state", {
          unread_count: 0,
        });
        this.set("channel", topicChannel);
      },

      async test(assert) {
        assert.notOk(exists(".chat-channel-unread-indicator"));
      },
    });

    componentTest("has unread and no mentions", {
      template: hbs`{{chat-channel-unread-indicator channel=channel}}`,

      beforeEach() {
        set(this.currentUser, "chat_channel_tracking_state", {
          [topicChannel.id]: { unread_count: 1 },
        });
        this.set("channel", topicChannel);
      },

      async test(assert) {
        assert.ok(exists(".chat-channel-unread-indicator:not(.urgent)"));
      },
    });

    componentTest("has unread and mentions", {
      template: hbs`{{chat-channel-unread-indicator channel=channel}}`,

      beforeEach() {
        set(this.currentUser, "chat_channel_tracking_state", {
          [topicChannel.id]: { unread_count: 1, unread_mentions: 1 },
        });
        this.set("channel", topicChannel);
      },

      async test(assert) {
        assert.ok(exists(".chat-channel-unread-indicator.urgent"));
      },
    });

    componentTest("direct message channel | has unread", {
      template: hbs`{{chat-channel-unread-indicator channel=channel}}`,

      beforeEach() {
        set(this.currentUser, "chat_channel_tracking_state", {
          [directMessageChannel.id]: { unread_count: 1 },
        });
        this.set("channel", directMessageChannel);
      },

      async test(assert) {
        assert.ok(exists(".chat-channel-unread-indicator.urgent"));
      },
    });
  }
);
