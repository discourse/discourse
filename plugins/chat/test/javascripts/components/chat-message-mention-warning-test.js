import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | Chat::Message::MentionWarning",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`
      <Chat::Message::MentionWarning @message={{this.message}} />
    `;

    test("without memberships", async function (assert) {
      this.message = fabricators.message();
      this.message.mentionWarning = fabricators.messageMentionWarning(
        this.message,
        {
          without_membership: [fabricators.user()].map((u) => {
            return { username: u.username, id: u.id };
          }),
        }
      );

      await render(template);

      assert
        .dom(".chat-message-mention-warning__text.-without-membership")
        .exists();
    });

    test("cannot see channel", async function (assert) {
      this.message = fabricators.message();
      this.message.mentionWarning = fabricators.messageMentionWarning(
        this.message,
        {
          cannot_see: [fabricators.user()].map((u) => {
            return { username: u.username, id: u.id };
          }),
        }
      );

      await render(template);

      assert.dom(".chat-message-mention-warning__text.-cannot-see").exists();
    });

    test("cannot see channel", async function (assert) {
      this.message = fabricators.message();
      this.message.mentionWarning = fabricators.messageMentionWarning(
        this.message,
        {
          cannot_see: [fabricators.user()].map((u) => {
            return { username: u.username, id: u.id };
          }),
        }
      );

      await render(template);

      assert.dom(".chat-message-mention-warning__text.-cannot-see").exists();
    });

    test("too many groups", async function (assert) {
      this.message = fabricators.message();
      this.message.mentionWarning = fabricators.messageMentionWarning(
        this.message,
        {
          groups_with_too_many_members: [fabricators.group()].mapBy("name"),
        }
      );

      await render(template);

      assert
        .dom(
          ".chat-message-mention-warning__text.-groups-with-too-many-members"
        )
        .exists();
    });

    test("groups with mentions disabled", async function (assert) {
      this.message = fabricators.message();
      this.message.mentionWarning = fabricators.messageMentionWarning(
        this.message,
        {
          group_mentions_disabled: [fabricators.group()].mapBy("name"),
        }
      );

      await render(template);

      assert
        .dom(
          ".chat-message-mention-warning__text.-groups-with-mentions-disabled"
        )
        .exists();
    });

    test("displays a warning when global mentions are disabled", async function (assert) {
      this.message = fabricators.message();
      this.message.mentionWarning = fabricators.messageMentionWarning(
        this.message,
        {
          global_mentions_disabled: true,
        }
      );

      await render(template);

      assert
        .dom(".chat-message-mention-warning__text.-global-mentions-disabled")
        .exists();
    });
  }
);
