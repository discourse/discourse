import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { click } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender from "discourse/tests/helpers/create-pretender";
import I18n from "I18n";
import { module } from "qunit";

module("Discourse Chat | Component | chat-channel-leave-btn", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("accepts an optional onLeaveChannel callback", {
    template: hbs`{{chat-channel-leave-btn channel=channel onLeaveChannel=onLeaveChannel}}`,

    beforeEach() {
      this.set("foo", 1);
      this.set("onLeaveChannel", () => this.set("foo", 2));
      this.set("channel", {
        id: 1,
        chatable_type: "DirectMessageChannel",
        chatable: {
          users: [{ id: 1 }],
        },
      });
    },

    async test(assert) {
      pretender.post("/chat/chat_channels/:chatChannelId/unfollow", () => {
        return [200, { current_user_membership: { following: false } }, {}];
      });
      assert.equal(this.foo, 1);

      await click(".chat-channel-leave-btn");

      assert.equal(this.foo, 2);
    },
  });

  componentTest("has a specific title for direct message channel", {
    template: hbs`{{chat-channel-leave-btn channel=channel}}`,

    beforeEach() {
      this.set("channel", { chatable_type: "DirectMessageChannel" });
    },

    async test(assert) {
      const btn = query(".chat-channel-leave-btn");

      assert.equal(btn.title, I18n.t("chat.direct_messages.leave"));
    },
  });

  componentTest("has a specific title for message channel", {
    template: hbs`{{chat-channel-leave-btn channel=channel}}`,

    beforeEach() {
      this.set("channel", { chatable_type: "Topic" });
    },

    async test(assert) {
      const btn = query(".chat-channel-leave-btn");

      assert.equal(btn.title, I18n.t("chat.leave"));
    },
  });

  componentTest("is not visible on mobile", {
    template: hbs`{{chat-channel-leave-btn channel=channel}}`,

    beforeEach() {
      this.site.mobileView = true;
      this.set("channel", { chatable_type: "Topic" });
    },

    async test(assert) {
      assert.notOk(exists(".chat-channel-leave-btn"));
    },
  });
});
