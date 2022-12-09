import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { click, currentURL, settled, visit } from "@ember/test-helpers";
import { directMessageChannels } from "discourse/plugins/chat/chat-fixtures";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";
import { emojiUnescape } from "discourse/lib/text";
import User from "discourse/models/user";

acceptance("Discourse Chat - Core Sidebar", function (needs) {
  needs.user({ has_chat_enabled: true });

  needs.settings({
    chat_enabled: true,
    navigation_menu: "sidebar",
  });

  needs.pretender((server, helper) => {
    let directChannels = cloneJSON(directMessageChannels).mapBy("chat_channel");
    directChannels[0].chatable.users = [directChannels[0].chatable.users[0]];
    directChannels[0].current_user_membership.unread_count = 1;
    directChannels.push({
      chatable: {
        users: [
          {
            id: 1,
            username: "markvanlan",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/f9ae1b/{size}.png",
          },
          {
            id: 2,
            username: "sam",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/f9ae1b/{size}.png",
          },
        ],
      },
      chatable_id: 59,
      chatable_type: "DirectMessage",
      chatable_url: null,
      id: 76,
      title: "@sam",
      last_message_sent_at: "2021-06-01T11:15:00.000Z",
      current_user_membership: {
        unread_count: 0,
        muted: true,
        following: true,
      },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    });
    directChannels.push({
      chatable: {
        users: [
          {
            id: 1,
            username: "<script>markvanlan</script>",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/f9ae1b/{size}.png",
          },
          {
            id: 2,
            username: "<script>sam</script>",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/f9ae1b/{size}.png",
          },
        ],
      },
      chatable_type: "DirectMessage",
      chatable_url: null,
      id: 77,
      title: "@<script>sam</script>",
      last_message_sent_at: "2021-06-01T11:15:00.000Z",
      current_user_membership: {
        unread_count: 0,
        muted: false,
        following: true,
      },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    });

    server.get("/chat/chat_channels.json", () => {
      return helper.response({
        public_channels: [
          {
            id: 1,
            title: "dev :bug:",
            chatable_type: "Category",
            chatable: { slug: "dev", read_restricted: true },
            last_message_sent_at: "2021-11-08T21:26:05.710Z",
            current_user_membership: {
              unread_count: 0,
              unread_mentions: 0,
            },
            message_bus_last_ids: {
              new_mentions: 0,
              new_messages: 0,
            },
          },
          {
            id: 2,
            title: "general",
            chatable_type: "Category",
            chatable: { slug: "general" },
            last_message_sent_at: "2021-11-08T21:26:05.710Z",
            current_user_membership: {
              unread_count: 1,
              unread_mentions: 0,
            },
            message_bus_last_ids: {
              new_mentions: 0,
              new_messages: 0,
            },
          },
          {
            id: 3,
            title: "random",
            description: "The channel for random <script>evil</script> things",
            chatable_type: "Category",
            chatable: { slug: "random" },
            last_message_sent_at: "2021-11-08T21:26:05.710Z",
            current_user_membership: {
              muted: true,
              unread_count: 1,
              unread_mentions: 1,
            },
            message_bus_last_ids: {
              new_mentions: 0,
              new_messages: 0,
            },
          },
          {
            id: 4,
            title: "<script>evil</script>",
            chatable_type: "Category",
            chatable: { slug: "random" },
            last_message_sent_at: "2021-11-08T21:26:05.710Z",
            current_user_membership: {
              unread_count: 1,
              unread_mentions: 1,
            },
            message_bus_last_ids: {
              new_mentions: 0,
              new_messages: 0,
            },
          },
        ],
        direct_message_channels: directChannels,
        message_bus_last_ids: {
          channel_metadata: 0,
          channel_edits: 0,
          channel_status: 0,
          new_channel: 0,
          user_tracking_state: 0,
        },
      });
    });

    server.get("/chat/1/messages.json", () =>
      helper.response({
        meta: {
          can_chat: true,
          user_silenced: false,
          channel_message_bus_last_id: 0,
        },
        chat_messages: [],
      })
    );

    server.get("/u/search/users", () => {
      return helper.response({
        users: [
          {
            username: "hawk",
            id: 2,
            name: "hawk",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/41988e/{size}.png",
          },
        ],
      });
    });

    server.get("/chat/75/messages.json", () =>
      helper.response({
        meta: { can_chat: true, user_silenced: false },
        chat_messages: [],
      })
    );

    server.get("/chat/direct_messages.json", () => {
      return helper.response({
        chat_channel: {
          id: 75,
          title: "hawk",
          chatable_type: "DirectMessage",
          last_message_sent_at: "2021-07-20T08:14:16.950Z",
          chatable: {
            users: [{ username: "hawk" }],
          },
        },
      });
    });
  });

  needs.hooks.beforeEach(function () {
    withPluginApi("1.3.0", (api) => {
      api.addUsernameSelectorDecorator((username) => {
        if (username === "hawk") {
          return `<span class="on-holiday">${emojiUnescape(
            ":desert_island:"
          )}</span>`;
        }
      });
    });
  });

  test("Public channels section", async function (assert) {
    await visit("/");

    assert.strictEqual(
      query(
        ".sidebar-section-chat-channels .sidebar-section-header-text"
      ).textContent.trim(),
      I18n.t("chat.chat_channels"),
      "displays correct channels section title"
    );

    assert.ok(
      exists(
        ".sidebar-section-chat-channels .sidebar-section-link-dev-bug .sidebar-section-link-prefix svg.prefix-icon.d-icon-hashtag"
      ),
      "dev channel section link displays hash icon prefix"
    );

    assert.ok(
      exists(
        ".sidebar-section-chat-channels .sidebar-section-link-dev-bug .sidebar-section-link-prefix svg.prefix-badge.d-icon-lock"
      ),
      "dev channel section link displays lock badge for restricted channel"
    );

    assert.ok(
      exists(
        ".sidebar-section-chat-channels .sidebar-section-link-dev-bug .emoji"
      ),
      "unescapes emoji in channel title in the link"
    );

    assert.strictEqual(
      query(
        ".sidebar-section-chat-channels .sidebar-section-link-dev-bug"
      ).textContent.trim(),
      "dev",
      "dev channel section link displays channel title in the link"
    );

    assert.ok(
      query(
        ".sidebar-section-chat-channels .sidebar-section-link-dev-bug"
      ).href.endsWith("/chat/channel/1/dev-bug"),
      "dev channel section link has the right href attribute"
    );

    assert.notOk(
      exists(
        ".sidebar-section-chat-channels .sidebar-section-link-dev-bug .sidebar-section-link-suffix"
      ),
      "does not display new messages indicator"
    );

    assert.ok(
      exists(
        ".sidebar-section-chat-channels .sidebar-section-link-general .sidebar-section-link-prefix svg.prefix-icon.d-icon-hashtag"
      ),
      "general channel section link displays hash icon prefix"
    );

    assert.notOk(
      exists(
        ".sidebar-section-chat-channels .sidebar-section-link-general .sidebar-section-link-prefix svg.prefix-badge"
      ),
      "general channel section link does not display lock badge for public channel"
    );

    assert.strictEqual(
      query(
        ".sidebar-section-chat-channels .sidebar-section-link-general"
      ).textContent.trim(),
      "general",
      "general channel section link displays channel title in the link"
    );

    assert.ok(
      exists(
        ".sidebar-section-chat-channels .sidebar-section-link-general .sidebar-section-link-suffix.unread"
      ),
      "general section link has new messages indicator"
    );

    assert.ok(
      exists(
        ".sidebar-section-chat-channels .sidebar-section-link-random .sidebar-section-link-prefix svg.prefix-icon.d-icon-hashtag"
      ),
      "random channel section link displays hash icon prefix"
    );

    assert.strictEqual(
      query(
        ".sidebar-section-chat-channels .sidebar-section-link-random"
      ).textContent.trim(),
      "random",
      "random channel section link displays channel title in the link"
    );

    assert.ok(
      exists(
        ".sidebar-section-chat-channels .sidebar-section-link-random .sidebar-section-link-suffix.urgent"
      ),
      "random section link has new messages mention indicator"
    );
  });

  test("sidebar section link when direct message channel is muted by user", async function (assert) {
    await visit("/");

    assert.ok(
      exists(
        ".sidebar-section-chat-dms .sidebar-section-link-sam.sidebar-section-link--muted"
      ),
      "muted direct chat channel section link has right classname configured"
    );
  });

  test("sidebar section link when public channel is muted by user", async function (assert) {
    await visit("/");

    assert.ok(
      exists(
        ".sidebar-section-chat-channels .sidebar-section-link-random.sidebar-section-link--muted"
      ),
      "muted random chat channel section link has right classname configured"
    );
  });

  test("Direct messages section", async function (assert) {
    const chatService = this.container.lookup("service:chat");
    chatService.directMessagesLimit = 2;
    await visit("/");

    assert.strictEqual(
      query(
        ".sidebar-section-chat-dms .sidebar-section-header-text"
      ).textContent.trim(),
      I18n.t("chat.direct_messages.title"),
      "displays correct direct messages section title"
    );

    let directLinks = queryAll(
      ".sidebar-section-chat-dms a.sidebar-section-link"
    );

    assert.strictEqual(
      directLinks[0]
        .querySelector(".sidebar-section-link-prefix img")
        .classList.contains("prefix-image"),
      true,
      "displays avatar in prefix when two participants"
    );

    assert.strictEqual(
      directLinks[0].textContent.trim(),
      "hawk",
      "displays user name in a link"
    );

    assert.ok(
      directLinks[0].querySelector(
        ".sidebar-section-link-content-text .on-holiday img"
      ),
      "displays flair when user is on holiday"
    );

    assert.strictEqual(
      directLinks[0]
        .querySelector(".sidebar-section-link-suffix")
        .classList.contains("urgent"),
      true,
      "displays new messages indicator"
    );

    assert.strictEqual(
      directLinks[1]
        .querySelector("span.sidebar-section-link-prefix")
        .classList.contains("text"),
      true,
      "displays text in prefix when more than two participants"
    );

    assert.strictEqual(
      directLinks[1]
        .querySelector(".sidebar-section-link-content-text")
        .textContent.trim(),
      "eviltrout, markvanlan",
      "displays all participants name in a link"
    );

    assert.ok(
      !directLinks[1].querySelector(".sidebar-section-link-suffix"),
      "does not display new messages indicator"
    );
    User.current().chat_channel_tracking_state[76].set("unread_count", 99);
    chatService.reSortDirectMessageChannels();
    chatService.appEvents.trigger("chat:user-tracking-state-changed");
    await settled();

    directLinks = queryAll(".sidebar-section-chat-dms a.sidebar-section-link");
    assert.strictEqual(
      directLinks[0]
        .querySelector(".sidebar-section-link-content-text")
        .textContent.trim(),
      "eviltrout, markvanlan",
      "reorders private messages"
    );

    assert.equal(
      directLinks.length,
      2,
      "limits number of displayed direct messages"
    );
  });

  test("Plugin sidebar is hidden", async function (assert) {
    await visit("/chat/channel/1/dev");
    assert.notOk(exists(".full-page-chat .channels-list"));
  });

  test("Open a new direct conversation", async function (assert) {
    await visit("/");
    await click(".sidebar-section-chat-dms .sidebar-section-header-button");

    assert.ok(exists(".direct-message-creator"));
    assert.ok(exists(".chat-drawer.is-expanded"));
    assert.strictEqual(currentURL(), "/");
  });

  test("Escaped channel description used as title when present", async function (assert) {
    await visit("/");

    const randomChannel = queryAll(
      ".sidebar-section-chat-channels .sidebar-section-link-wrapper .sidebar-section-link"
    )[3];

    assert.strictEqual(
      randomChannel.title,
      "The channel for random &lt;script&gt;evil&lt;/script&gt; things"
    );
  });

  test("Escapes public channel titles", async function (assert) {
    await visit("/");

    const evilChannel = query(
      ".sidebar-section-chat-channels .sidebar-section-link-wrapper .sidebar-section-link"
    );

    assert.strictEqual(
      evilChannel.title,
      "&lt;script&gt;evil&lt;/script&gt; chat"
    );

    assert.ok(
      evilChannel.className.includes(
        "sidebar-section-link-ltscriptgtevilltscriptgt"
      )
    );

    assert.strictEqual(
      evilChannel
        .querySelector(".sidebar-section-link-content-text")
        .innerHTML.trim(),
      "&lt;script&gt;evil&lt;/script&gt;"
    );
  });

  test("Escapes dm channel titles", async function (assert) {
    await visit("/");

    const evilChannel = queryAll(
      ".sidebar-section-chat-dms .sidebar-section-link-wrapper .sidebar-section-link"
    )[3];

    assert.strictEqual(
      evilChannel.title,
      "Chat with @&lt;script&gt;sam&lt;/script&gt;"
    );

    assert.ok(
      evilChannel.className.includes(
        "sidebar-section-link-ltscriptgtsamltscriptgt"
      )
    );

    assert.strictEqual(
      evilChannel
        .querySelector(".sidebar-section-link-content-text")
        .innerHTML.trim(),
      "&amp;lt;script&amp;gt;sam&amp;lt;/script&amp;gt;"
    );
  });
});

acceptance("Discourse Chat - Plugin Sidebar", function (needs) {
  needs.user({ has_chat_enabled: true });

  needs.settings({
    chat_enabled: true,
    navigation_menu: "legacy",
  });

  needs.pretender((server, helper) => {
    server.get("/chat/chat_channels.json", () => {
      return helper.response({
        public_channels: [
          {
            id: 1,
            title: "dev :bug:",
            chatable_type: "Category",
            chatable: { slug: "dev", read_restricted: true },
            last_message_sent_at: "2021-11-08T21:26:05.710Z",
            current_user_membership: {
              unread_count: 1,
              unread_mentions: 1,
            },
            message_bus_last_ids: {
              new_mentions: 0,
              new_messages: 0,
            },
          },
          {
            id: 2,
            title: "general",
            chatable_type: "Category",
            chatable: { slug: "general" },
            last_message_sent_at: "2021-11-08T21:26:05.710Z",
            current_user_membership: {
              unread_count: 1,
              unread_mentions: 1,
            },
            message_bus_last_ids: {
              new_mentions: 0,
              new_messages: 0,
            },
          },
          {
            id: 3,
            title: "random",
            chatable_type: "Category",
            chatable: { slug: "random" },
            last_message_sent_at: "2021-11-08T21:26:05.710Z",
            current_user_membership: {
              unread_count: 1,
              unread_mentions: 1,
            },
            message_bus_last_ids: {
              new_mentions: 0,
              new_messages: 0,
            },
          },
        ],
        direct_message_channels: [],
        message_bus_last_ids: {
          channel_metadata: 0,
          channel_edits: 0,
          channel_status: 0,
          new_channel: 0,
          user_tracking_state: 0,
        },
      });
    });

    server.get("/chat/1/messages.json", () =>
      helper.response({
        meta: { can_chat: true, user_silenced: false },
        chat_messages: [],
      })
    );
  });

  test("Plugin sidebar is visible", async function (assert) {
    await visit("/chat/channel/1/dev");
    assert.ok(exists(".full-page-chat .channels-list"));
  });
});

acceptance(
  "Discourse Chat - Core Sidebar - no joinable public channels, staff",
  function (needs) {
    needs.user({ has_chat_enabled: true, has_joinable_public_channels: false });

    needs.settings({
      chat_enabled: true,
      navigation_menu: "sidebar",
    });

    needs.pretender((server, helper) => {
      server.get("/chat/chat_channels.json", () => {
        return helper.response({
          public_channels: [],
          direct_message_channels: [],
          message_bus_last_ids: {
            channel_metadata: 0,
            channel_edits: 0,
            channel_status: 0,
            new_channel: 0,
            user_tracking_state: 0,
          },
        });
      });
    });

    test("Chat channels section visibility", async function (assert) {
      await visit("/");

      assert.ok(
        exists(".sidebar-section-chat-channels"),
        "it shows the section for staff"
      );
    });
  }
);

acceptance(
  "Discourse Chat - Core Sidebar - no joinable public channels, regular user",
  function (needs) {
    needs.user({
      has_chat_enabled: true,
      has_joinable_public_channels: false,
      moderator: false,
      admin: false,
    });

    needs.settings({
      chat_enabled: true,
      navigation_menu: "sidebar",
    });

    needs.pretender((server, helper) => {
      server.get("/chat/chat_channels.json", () => {
        return helper.response({
          public_channels: [],
          direct_message_channels: [],
          message_bus_last_ids: {
            channel_metadata: 0,
            channel_edits: 0,
            channel_status: 0,
            new_channel: 0,
            user_tracking_state: 0,
          },
        });
      });
    });

    test("Chat channels section visibility", async function (assert) {
      await visit("/");

      assert.notOk(
        exists(".sidebar-section-chat-channels"),
        "it doesn’t show the section for regular user"
      );
    });
  }
);

acceptance(
  "Discourse Chat - Core Sidebar - regular user with no direct message channels who cannot send direct messages",
  function (needs) {
    needs.user({
      has_chat_enabled: true,
      moderator: false,
      admin: false,
    });

    needs.settings({
      chat_enabled: true,
      navigation_menu: "sidebar",
      direct_message_enabled_groups: "13", // trust_level_3 auto group ID;
    });

    needs.pretender((server, helper) => {
      server.get("/chat/chat_channels.json", () => {
        return helper.response({
          public_channels: [],
          direct_message_channels: [],
          message_bus_last_ids: {
            channel_metadata: 0,
            channel_edits: 0,
            channel_status: 0,
            new_channel: 0,
            user_tracking_state: 0,
          },
        });
      });
    });

    test("Direct message channels section visibility", async function (assert) {
      await visit("/");

      assert.notOk(
        exists(".sidebar-section-chat-dms"),
        "it doesn’t show the section for regular user"
      );
    });
  }
);

acceptance(
  "Discourse Chat - Core Sidebar - regular user with existing direct message channels who cannot send direct messages",
  function (needs) {
    needs.user({
      has_chat_enabled: true,
      moderator: false,
      admin: false,
    });

    needs.settings({
      chat_enabled: true,
      navigation_menu: "sidebar",
      direct_message_enabled_groups: "13", // trust_level_3 auto group ID;
    });

    needs.pretender((server, helper) => {
      let directChannels = cloneJSON(directMessageChannels).mapBy(
        "chat_channel"
      );
      server.get("/chat/chat_channels.json", () => {
        return helper.response({
          public_channels: [],
          direct_message_channels: directChannels,
          message_bus_last_ids: {
            channel_metadata: 0,
            channel_edits: 0,
            channel_status: 0,
            new_channel: 0,
            user_tracking_state: 0,
          },
        });
      });
    });

    test("Direct message channels section visibility", async function (assert) {
      await visit("/");

      assert.ok(
        exists(".sidebar-section-chat-dms"),
        "it does show the section for a regular user"
      );

      assert.notOk(
        exists(".sidebar-section-chat-dms .sidebar-section-header-button"),
        "user cannot see the create DM channel button"
      );
    });
  }
);
