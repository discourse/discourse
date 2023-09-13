import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { fillIn, visit } from "@ember/test-helpers";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

acceptance("Chat | Mentions", function (needs) {
  const channelId = 1;
  const actingUser = {
    id: 1,
    username: "acting_user",
  };
  const channel = {
    id: channelId,
    chatable_id: 1,
    chatable_type: "Category",
    meta: { message_bus_last_ids: {}, can_delete_self: true },
    current_user_membership: { following: true },
    allow_channel_wide_mentions: false,
    chatable: { id: 1 },
    title: "Some title",
  };

  needs.settings({ chat_enabled: true });

  needs.user({
    ...actingUser,
    has_chat_enabled: true,
    chat_channels: {
      public_channels: [channel],
      direct_message_channels: [],
      meta: { message_bus_last_ids: {} },
      tracking: {},
    },
  });

  needs.hooks.beforeEach(function () {
    pretender.post(`/chat/drafts`, () => response({}));
    pretender.get(`/chat/api/channels/${channelId}/messages`, () =>
      response({
        messages: [],
        meta: {
          can_load_more_future: false,
        },
      })
    );
    pretender.get("/chat/api/mentions/groups.json", () =>
      response({
        unreachable: [],
        over_members_limit: [],
        invalid: ["and"],
      })
    );
  });

  test("shows warning when mention limit exceeded", async function (assert) {
    this.siteSettings.max_mentions_per_chat_message = 2;

    await visit(`/chat/c/-/${channelId}`);
    await fillIn(".chat-composer__input", `Hey @user1 @user2 @user3`);

    assert.dom(".chat-mention-warnings").exists();
  });

  test("shows warning for @here mentions when channel-wide mentions are disabled", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);
    await fillIn(".chat-composer__input", `Hey @here`);

    assert.dom(".chat-mention-warnings").exists();
  });

  test("shows warning for @all mention when channel-wide mentions are disabled", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);
    await fillIn(".chat-composer__input", `Hey @all`);

    assert.dom(".chat-mention-warnings").exists();
  });

  test("ignores duplicates when counting mentions", async function (assert) {
    this.siteSettings.max_mentions_per_chat_message = 2;

    await visit(`/chat/c/-/${channelId}`);
    const mention = `@user1`;
    await fillIn(
      ".chat-composer__input",
      `Hey ${mention} ${mention} ${mention}`
    );

    assert.dom(".chat-mention-warnings").doesNotExist();
  });

  test("doesn't consider code-blocks when counting mentions", async function (assert) {
    this.siteSettings.max_mentions_per_chat_message = 2;

    await visit(`/chat/c/-/${channelId}`);
    // since @bar is inside a code-block it shouldn't be considered a mention
    const message = `Hey @user1 @user2
    \`\`\`
      def foo
        @bar = true
      end
    \`\`\`
    `;
    await fillIn(".chat-composer__input", message);

    assert.dom(".chat-mention-warnings").doesNotExist();
  });
});
