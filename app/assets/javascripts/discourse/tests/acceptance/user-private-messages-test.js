import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { resetCustomUserNavMessagesDropdownRows } from "discourse/controllers/user-private-messages";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  resetHighestReadCache,
  setHighestReadCache,
} from "discourse/lib/topic-list-tracker";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  count,
  publishToMessageBus,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "discourse-i18n";
import selectKit from "../helpers/select-kit-helper";

acceptance(
  "User Private Messages - user with no group messages",
  function (needs) {
    needs.user();

    needs.site({
      can_tag_pms: true,
    });

    test("viewing messages", async function (assert) {
      await visit("/u/eviltrout/messages");

      assert.strictEqual(
        count(".topic-list-item"),
        1,
        "displays the topic list"
      );

      assert
        .dom(".group-notifications-button")
        .doesNotExist("displays the group notifications button");
    });

    test("viewing messages of another user", async function (assert) {
      updateCurrentUser({ id: 5, username: "charlie" });

      await visit("/u/eviltrout/messages");

      assert
        .dom(".messages-nav li a.new")
        .doesNotExist("it does not display new filter");

      assert
        .dom(".messages-nav li a.unread")
        .doesNotExist("it does not display unread filter");
    });
  }
);

let fetchedNew;
let fetchUserNew;
let fetchedGroupNew;

function withGroupMessagesSetup(needs) {
  needs.user({
    id: 5,
    username: "charlie",
    groups: [{ id: 14, name: "awesome_group", has_messages: true }],
  });

  needs.site({
    can_tag_pms: true,
  });

  needs.hooks.afterEach(() => {
    fetchedNew = false;
    fetchedGroupNew = false;
    fetchUserNew = false;
  });

  needs.pretender((server, helper) => {
    server.get("/tags/personal_messages/:username.json", () => {
      return helper.response({ tags: [{ id: "tag1" }] });
    });

    server.get("/t/13.json", () => {
      const response = cloneJSON(fixturesByUrl["/t/12/1.json"]);
      response.suggested_group_name = "awesome_group";
      return helper.response(response);
    });

    server.get("/topics/private-messages/:username.json", () => {
      return helper.response({
        topic_list: {
          topics: [
            {
              id: 1,
              posters: [],
              notification_level: NotificationLevels.TRACKING,
              unread_posts: 1,
              last_read_post_number: 1,
              highest_post_number: 2,
            },
            {
              id: 2,
              posters: [],
            },
            {
              id: 3,
              posters: [],
            },
          ],
        },
      });
    });

    [
      "/topics/private-messages-new/:username.json",
      "/topics/private-messages-unread/:username.json",
      "/topics/private-messages-archive/:username.json",
      "/topics/private-messages-group/:username/:group_name/new.json",
      "/topics/private-messages-group/:username/:group_name/unread.json",
      "/topics/private-messages-group/:username/:group_name/archive.json",
      "/topics/private-messages-tags/:username/:tag_name",
    ].forEach((url) => {
      server.get(url, () => {
        let topics;

        if (fetchedNew || fetchedGroupNew || fetchUserNew) {
          topics = [];
        } else {
          topics = [
            { id: 1, posters: [] },
            { id: 2, posters: [] },
            { id: 3, posters: [] },
          ];
        }

        return helper.response({
          topic_list: {
            topics,
          },
        });
      });
    });

    server.get(
      "/topics/private-messages-group/:username/:group_name.json",
      () => {
        return helper.response({
          topic_list: {
            topics: [
              { id: 1, posters: [] },
              { id: 2, posters: [] },
            ],
          },
        });
      }
    );

    server.put("/topics/pm-reset-new", (request) => {
      const requestBody = request.requestBody;
      // No easy way to do this https://github.com/pretenderjs/pretender/issues/159
      if (requestBody === "inbox=group&group_name=awesome_group") {
        fetchedGroupNew = true;
      }

      if (requestBody === "inbox=user") {
        fetchUserNew = true;
      }

      if (requestBody === "inbox=all") {
        fetchedNew = true;
      }

      return helper.response({ topic_ids: [1, 2, 3] });
    });

    server.put("/topics/bulk", (request) => {
      const requestBody = request.requestBody;

      if (requestBody.includes("private_message_inbox=all")) {
        fetchedNew = true;
      }

      if (
        requestBody.includes(
          "private_message_inbox=group&group_name=awesome_group"
        )
      ) {
        fetchedGroupNew = true;
      }

      if (requestBody.includes("private_message_inbox=user")) {
        fetchUserNew = true;
      }

      return helper.response({
        topic_ids: [1, 2, 3],
      });
    });
  });
}

const publishReadToMessageBus = function (opts = {}) {
  return publishToMessageBus(
    `/private-message-topic-tracking-state/user/${opts.userId || 5}`,
    {
      topic_id: opts.topicId,
      message_type: "read",
      payload: {
        last_read_post_number: 2,
        highest_post_number: 2,
        notification_level: 2,
      },
    }
  );
};

const publishUnreadToMessageBus = function (opts = {}) {
  return publishToMessageBus(
    `/private-message-topic-tracking-state/user/${opts.userId || 5}`,
    {
      topic_id: opts.topicId,
      message_type: "unread",
      payload: {
        last_read_post_number: 1,
        highest_post_number: 2,
        notification_level: 2,
        group_ids: opts.groupIds || [],
      },
    }
  );
};

const publishNewToMessageBus = function (opts = {}) {
  return publishToMessageBus(
    `/private-message-topic-tracking-state/user/${opts.userId || 5}`,
    {
      topic_id: opts.topicId,
      message_type: "new_topic",
      payload: {
        last_read_post_number: null,
        highest_post_number: 1,
        group_ids: opts.groupIds || [],
      },
    }
  );
};

const publishGroupArchiveToMessageBus = function (opts) {
  return publishToMessageBus(
    `/private-message-topic-tracking-state/group/${opts.groupIds[0]}`,
    {
      topic_id: opts.topicId,
      message_type: "group_archive",
      payload: {
        group_ids: opts.groupIds,
        acting_user_id: opts.actingUserId,
      },
    }
  );
};

const publishGroupUnreadToMessageBus = function (opts) {
  return publishToMessageBus(
    `/private-message-topic-tracking-state/group/${opts.groupIds[0]}`,
    {
      topic_id: opts.topicId,
      message_type: "unread",
      payload: {
        last_read_post_number: 1,
        highest_post_number: 2,
        notification_level: 2,
        group_ids: opts.groupIds || [],
      },
    }
  );
};

const publishGroupNewToMessageBus = function (opts) {
  return publishToMessageBus(
    `/private-message-topic-tracking-state/group/${opts.groupIds[0]}`,
    {
      topic_id: opts.topicId,
      message_type: "new_topic",
      payload: {
        last_read_post_number: null,
        highest_post_number: 1,
        group_ids: opts.groupIds || [],
      },
    }
  );
};

acceptance("User Private Messages - sorting", function (needs) {
  withGroupMessagesSetup(needs);

  test("order by posts_count", async function (assert) {
    await visit("/u/eviltrout/messages");

    assert.dom(".topic-list-header th.posts.sortable").exists("is sortable");

    await click(".topic-list-header th.posts.sortable");

    assert.dom(".topic-list-header th.posts.sortable.sorting").exists("sorted");
  });
});

acceptance(
  "User Private Messages - user with group messages",
  function (needs) {
    withGroupMessagesSetup(needs);

    test("incoming group archive message acted by current user", async function (assert) {
      await visit("/u/charlie/messages");

      await publishGroupArchiveToMessageBus({
        groupIds: [14],
        topicId: 1,
        actingUserId: 5,
      });

      assert
        .dom(".show-mores")
        .doesNotExist(`does not display the topic incoming info`);
    });

    test("incoming group archive message on inbox and archive filter", async function (assert) {
      for (const url of [
        "/u/charlie/messages/group/awesome_group",
        "/u/charlie/messages/group/awesome_group/archive",
      ]) {
        await visit(url);

        await publishGroupArchiveToMessageBus({ groupIds: [14], topicId: 1 });

        assert
          .dom(".show-mores")
          .exists(`${url} displays the topic incoming info`);
      }

      for (const url of [
        "/u/charlie/messages",
        "/u/charlie/messages/archive",
      ]) {
        await visit(url);

        await publishGroupArchiveToMessageBus({ groupIds: [14], topicId: 1 });

        assert
          .dom(".show-mores")
          .doesNotExist(`${url} does not display the topic incoming info`);
      }
    });

    test("incoming unread and new messages on all filter", async function (assert) {
      await visit("/u/charlie/messages");

      await publishUnreadToMessageBus({ topicId: 1 });
      await publishNewToMessageBus({ topicId: 2 });

      assert.strictEqual(
        query(".user-nav__messages-new").innerText.trim(),
        I18n.t("user.messages.new_with_count", { count: 1 }),
        "displays the right count"
      );

      assert.strictEqual(
        query(".user-nav__messages-unread").innerText.trim(),
        I18n.t("user.messages.unread_with_count", { count: 1 }),
        "displays the right count"
      );
    });

    test("incoming new messages while viewing new", async function (assert) {
      await visit("/u/charlie/messages/new");

      await publishNewToMessageBus({ topicId: 1 });

      assert.strictEqual(
        query(".messages-nav .user-nav__messages-new").innerText.trim(),
        I18n.t("user.messages.new_with_count", { count: 1 }),
        "displays the right count"
      );

      assert.dom(".show-mores").exists("displays the topic incoming info");

      await publishNewToMessageBus({ topicId: 2 });

      assert.strictEqual(
        query(".messages-nav .user-nav__messages-new").innerText.trim(),
        I18n.t("user.messages.new_with_count", { count: 2 }),
        "displays the right count"
      );

      assert.dom(".show-mores").exists("displays the topic incoming info");
    });

    test("incoming unread messages while viewing unread", async function (assert) {
      await visit("/u/charlie/messages/unread");

      await publishUnreadToMessageBus();

      assert.strictEqual(
        query(".messages-nav .user-nav__messages-unread").innerText.trim(),
        I18n.t("user.messages.unread_with_count", { count: 1 }),
        "displays the right count"
      );

      assert.dom(".show-mores").exists("displays the topic incoming info");
    });

    test("incoming unread and new messages while viewing group unread", async function (assert) {
      await visit("/u/charlie/messages/group/awesome_group/unread");

      await publishUnreadToMessageBus({ groupIds: [14], topicId: 1 });
      await publishNewToMessageBus({ groupIds: [14], topicId: 2 });

      assert.strictEqual(
        query(
          ".messages-nav .user-nav__messages-group-unread"
        ).innerText.trim(),
        I18n.t("user.messages.unread_with_count", { count: 1 }),
        "displays the right count"
      );

      assert.strictEqual(
        query(".messages-nav .user-nav__messages-group-new").innerText.trim(),
        I18n.t("user.messages.new_with_count", { count: 1 }),
        "displays the right count"
      );

      assert.dom(".show-mores").exists("displays the topic incoming info");

      await visit("/u/charlie/messages/unread");

      assert.strictEqual(
        query(".messages-nav .user-nav__messages-unread").innerText.trim(),
        I18n.t("user.messages.unread"),
        "displays the right count"
      );

      assert.strictEqual(
        query(".messages-nav .user-nav__messages-new").innerText.trim(),
        I18n.t("user.messages.new"),
        "displays the right count"
      );
    });

    test("incoming messages is not tracked on non user messages route", async function (assert) {
      await visit("/u/charlie/messages");
      await visit("/t/13");

      await publishNewToMessageBus({ topicId: 1, userId: 5 });

      await visit("/u/charlie/messages");

      assert
        .dom(".show-mores")
        .doesNotExist("does not display the topic incoming info");
    });

    test("dismissing all unread messages", async function (assert) {
      await visit("/u/charlie/messages/unread");

      await publishUnreadToMessageBus({ topicId: 1, userId: 5 });
      await publishUnreadToMessageBus({ topicId: 2, userId: 5 });
      await publishUnreadToMessageBus({ topicId: 3, userId: 5 });

      assert.strictEqual(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");
      await click("#dismiss-read-confirm");

      assert.strictEqual(
        query(".user-nav__messages-unread").innerText.trim(),
        I18n.t("user.messages.unread"),
        "displays the right count"
      );

      assert.strictEqual(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("dismissing personal unread messages", async function (assert) {
      await visit("/u/charlie/messages/unread");

      assert.strictEqual(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");
      await click("#dismiss-read-confirm");

      assert.strictEqual(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("dismissing group unread messages", async function (assert) {
      await visit("/u/charlie/messages/group/awesome_group/unread");

      assert.strictEqual(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");
      await click("#dismiss-read-confirm");

      assert.strictEqual(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("dismissing new messages", async function (assert) {
      await visit("/u/charlie/messages/new");

      await publishNewToMessageBus({ topicId: 1, userId: 5 });
      await publishNewToMessageBus({ topicId: 2, userId: 5 });
      await publishNewToMessageBus({ topicId: 3, userId: 5 });

      assert.strictEqual(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");

      assert.strictEqual(
        query(".messages-nav .user-nav__messages-new").innerText.trim(),
        I18n.t("user.messages.new"),
        "displays the right count"
      );

      assert.strictEqual(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("dismissing personal new messages", async function (assert) {
      await visit("/u/charlie/messages/new");

      assert.strictEqual(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");

      assert.strictEqual(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("dismissing new group messages", async function (assert) {
      await visit("/u/charlie/messages/group/awesome_group/new");

      assert.strictEqual(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");

      assert.strictEqual(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("viewing messages when highest read cache has been set for a topic", async function (assert) {
      try {
        setHighestReadCache(1, 2);

        await visit("/u/charlie/messages");

        assert.strictEqual(
          query(".topic-post-badges").textContent.trim(),
          "",
          "does not display unread posts count badge"
        );
      } finally {
        resetHighestReadCache();
      }
    });

    test("viewing messages", async function (assert) {
      await visit("/u/charlie/messages");

      assert.strictEqual(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      assert.strictEqual(
        query(`tr[data-topic-id="1"] .topic-post-badges`).textContent.trim(),
        "1",
        "displays the right unread posts count badge"
      );

      await visit("/u/charlie/messages/group/awesome_group");

      assert.strictEqual(
        count(".topic-list-item"),
        2,
        "displays the right topic list"
      );

      assert
        .dom(".group-notifications-button")
        .exists("displays the group notifications button");
    });

    test("navigating between user messages route with dropdown", async function (assert) {
      await visit("/u/Charlie/messages");

      const messagesDropdown = selectKit(".user-nav-messages-dropdown");

      assert.strictEqual(
        messagesDropdown.header().name(),
        I18n.t("user.messages.inbox"),
        "User personal inbox is selected in dropdown"
      );

      await click(".user-nav__messages-sent");

      assert.strictEqual(
        messagesDropdown.header().name(),
        I18n.t("user.messages.inbox"),
        "User personal inbox is still selected when viewing sent messages"
      );

      await messagesDropdown.expand();
      await messagesDropdown.selectRowByName("awesome_group");

      assert.strictEqual(
        currentURL(),
        "/u/charlie/messages/group/awesome_group",
        "routes to the right URL when selecting awesome_group in the dropdown"
      );

      assert.strictEqual(
        messagesDropdown.header().name(),
        "awesome_group",
        "Group inbox is selected in dropdown"
      );

      await click(".user-nav__messages-group-new");

      assert.strictEqual(
        messagesDropdown.header().name(),
        "awesome_group",
        "Group inbox is still selected in dropdown"
      );

      await messagesDropdown.expand();
      await messagesDropdown.selectRowByName(I18n.t("user.messages.tags"));

      assert.strictEqual(
        currentURL(),
        "/u/charlie/messages/tags",
        "routes to the right URL when selecting tags in the dropdown"
      );

      assert.strictEqual(
        messagesDropdown.header().name(),
        I18n.t("user.messages.tags"),
        "All tags is selected in dropdown"
      );

      await click(".discourse-tag[data-tag-name='tag1']");

      assert.strictEqual(
        messagesDropdown.header().name(),
        I18n.t("user.messages.tags"),
        "All tags is still selected in dropdown"
      );
    });

    test("addUserMessagesNavigationDropdownRow plugin api", async function (assert) {
      try {
        withPluginApi("1.5.0", (api) => {
          api.addUserMessagesNavigationDropdownRow(
            "preferences",
            "test nav",
            "arrow-left"
          );
        });

        await visit("/u/eviltrout/messages");

        const messagesDropdown = selectKit(".user-nav-messages-dropdown");
        await messagesDropdown.expand();

        const row = messagesDropdown.rowByName("test nav");

        assert.strictEqual(row.value(), "/u/eviltrout/preferences");
        assert.ok(row.icon().classList.contains("d-icon-arrow-left"));
      } finally {
        resetCustomUserNavMessagesDropdownRows();
      }
    });
  }
);

acceptance(
  "User Private Messages - user with group messages - browse more message",
  function (needs) {
    withGroupMessagesSetup(needs);

    test("suggested messages without new or unread", async function (assert) {
      await visit("/t/12");

      assert.strictEqual(
        query(".more-topics__browse-more").innerText.trim(),
        "Want to read more? Browse other messages in personal messages.",
        "displays the right browse more message"
      );
    });

    test("suggested messages with new and unread", async function (assert) {
      await visit("/t/12");

      await publishNewToMessageBus({ userId: 5, topicId: 1 });

      assert.strictEqual(
        query(".more-topics__browse-more").innerText.trim(),
        "There is 1 new message remaining, or browse other personal messages",
        "displays the right browse more message"
      );

      await publishUnreadToMessageBus({ userId: 5, topicId: 2 });

      assert.strictEqual(
        query(".more-topics__browse-more").innerText.trim(),
        "There is 1 unread and 1 new message remaining, or browse other personal messages",
        "displays the right browse more message"
      );

      await publishReadToMessageBus({ userId: 5, topicId: 2 });

      assert.strictEqual(
        query(".more-topics__browse-more").innerText.trim(),
        "There is 1 new message remaining, or browse other personal messages",
        "displays the right browse more message"
      );
    });

    test("suggested messages for group messages without new or unread", async function (assert) {
      await visit("/t/13");

      assert.ok(
        query(".more-topics__browse-more")
          .innerText.trim()
          .match(
            /Want to read more\? Browse other messages in\s+awesome_group\./
          ),
        "displays the right browse more message"
      );
    });

    test("suggested messages for group messages with new and unread", async function (assert) {
      await visit("/t/13");

      await publishGroupNewToMessageBus({ groupIds: [14], topicId: 1 });

      assert.ok(
        query(".more-topics__browse-more")
          .innerText.trim()
          .match(
            /There is 1 new message remaining, or browse other messages in\s+awesome_group/
          ),
        "displays the right browse more message"
      );

      await publishGroupUnreadToMessageBus({ groupIds: [14], topicId: 2 });

      assert.ok(
        query(".more-topics__browse-more")
          .innerText.trim()
          .match(
            /There is 1 unread and 1 new message remaining, or browse other messages in\s+awesome_group/
          ),
        "displays the right browse more message"
      );
    });
  }
);

acceptance("User Private Messages - user with no messages", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const emptyResponse = {
      topic_list: {
        topics: [],
      },
    };

    const apiUrls = [
      "/topics/private-messages/:username.json",
      "/topics/private-messages-sent/:username.json",
      "/topics/private-messages-new/:username.json",
      "/topics/private-messages-unread/:username.json",
      "/topics/private-messages-archive/:username.json",
    ];

    apiUrls.forEach((url) => {
      server.get(url, () => {
        return helper.response(emptyResponse);
      });
    });
  });

  test("It renders the empty state panel", async function (assert) {
    await visit("/u/charlie/messages");
    assert.dom("div.empty-state").exists();

    await visit("/u/charlie/messages/sent");
    assert.dom("div.empty-state").exists();

    await visit("/u/charlie/messages/new");
    assert.dom("div.empty-state").exists();

    await visit("/u/charlie/messages/unread");
    assert.dom("div.empty-state").exists();

    await visit("/u/charlie/messages/archive");
    assert.dom("div.empty-state").exists();
  });
});

acceptance(
  "User Private Messages - composer with tags - Desktop",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      server.post("/posts", () => {
        return helper.response({
          action: "create_post",
          post: {
            id: 323,
            name: "Robin Ward",
            username: "eviltrout",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/j/b77776/{size}.png",
            created_at: "2021-10-26T11:47:54.253Z",
            cooked: "<p>Testing private messages with tags</p>",
            post_number: 1,
            post_type: 1,
            updated_at: "2021-10-26T11:47:54.253Z",
            yours: true,
            topic_id: 161,
            topic_slug: "testing-private-messages-with-tags",
            raw: "This is a test for private messages with tags",
            user_id: 29,
          },
          success: true,
        });
      });

      server.get("/t/161.json", () => {
        return helper.response(200, {});
      });

      server.get("/u/search/users", () => {
        return helper.response({
          users: [
            {
              username: "eviltrout",
              name: "Robin Ward",
              avatar_template:
                "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
            },
            {
              username: "r_ocelot",
              name: "Revolver Ocelot",
              avatar_template:
                "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
            },
          ],
        });
      });
    });

    needs.site({
      can_tag_pms: true,
      can_tag_topics: true,
    });

    test("tags are present on private messages - Desktop mode", async function (assert) {
      await visit("/u/eviltrout/messages");
      await click(".new-private-message");

      assert.dom("#reply-control .mini-tag-chooser").exists();

      await fillIn("#reply-title", "Sending a message with tags");
      await fillIn(
        "#reply-control .d-editor-input",
        "This is a message to test tags"
      );

      const users = selectKit("#reply-control .user-chooser");

      await users.expand();
      await fillIn(
        "#private-message-users-body input.filter-input",
        "eviltrout"
      );
      await users.selectRowByValue("eviltrout");

      await fillIn(
        "#private-message-users-body input.filter-input",
        "r_ocelot"
      );
      await users.selectRowByValue("r_ocelot");

      const tags = selectKit("#reply-control .mini-tag-chooser");
      await tags.expand();
      await tags.selectRowByValue("monkey");
      await tags.selectRowByValue("gazelle");

      await click("#reply-control .save-or-cancel button");

      assert.strictEqual(
        currentURL(),
        "/t/testing-private-messages-with-tags/161",
        "it creates the private message"
      );
    });
  }
);

acceptance(
  "User Private Messages - composer with tags - Mobile",
  function (needs) {
    needs.mobileView();
    needs.user();

    needs.site({
      can_tag_pms: true,
      can_tag_topics: true,
    });

    test("tags are present on private messages - Mobile mode", async function (assert) {
      await visit("/u/eviltrout/messages");
      await click(".new-private-message");
      assert.dom("#reply-control .mini-tag-chooser").exists();
    });
  }
);
