import User from "discourse/models/user";
import { render } from "@ember/test-helpers";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { module, test } from "qunit";

module("Discourse Chat | Component | chat-message", function (hooks) {
  setupRenderingTest(hooks);

  function generateMessageProps(messageData = {}) {
    const channel = ChatChannel.create({
      chatable_id: 1,
      chatable_type: "Category",
      id: 9,
      title: "Site",
      last_message_sent_at: "2021-11-08T21:26:05.710Z",
      current_user_membership: {
        unread_count: 0,
        muted: false,
      },
      can_delete_self: true,
      can_delete_others: true,
      can_flag: true,
      user_silenced: false,
      can_mdoerate: true,
    });
    return {
      message: ChatMessage.create(
        channel,
        Object.assign(
          {
            id: 178,
            message: "from deleted user",
            cooked: "<p>from deleted user</p>",
            excerpt: "<p>from deleted user</p>",
            created_at: "2021-07-22T08:14:16.950Z",
            flag_count: 0,
            user: User.create({ username: "someguy", id: 1424 }),
            edited: false,
          },
          messageData
        )
      ),
      channel,
      afterExpand: () => {},
      onHoverMessage: () => {},
      messageDidEnterViewport: () => {},
      messageDidLeaveViewport: () => {},
    };
  }

  const template = hbs`
    <ChatMessage
      @message={{this.message}}
      @channel={{this.channel}}
      @messageDidEnterViewport={{this.messageDidEnterViewport}}
      @messageDidLeaveViewport={{this.messageDidLeaveViewport}}
    />
  `;

  test("Message with edits", async function (assert) {
    this.setProperties(generateMessageProps({ edited: true }));
    await render(template);

    assert.true(
      exists(".chat-message-edited"),
      "has the correct edited css class"
    );
  });

  test("Deleted message", async function (assert) {
    this.setProperties(generateMessageProps({ deleted_at: moment() }));
    await render(template);

    assert.true(
      exists(".chat-message-deleted .chat-message-expand"),
      "has the correct deleted css class and expand button within"
    );
  });

  test("Hidden message", async function (assert) {
    this.setProperties(generateMessageProps({ hidden: true }));
    await render(template);

    assert.true(
      exists(".chat-message-hidden .chat-message-expand"),
      "has the correct hidden css class and expand button within"
    );
  });
});
