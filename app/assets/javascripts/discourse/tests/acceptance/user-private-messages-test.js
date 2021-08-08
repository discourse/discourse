import {
  acceptance,
  count,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { PERSONAL_INBOX } from "discourse/controllers/user-private-messages";

acceptance(
  "User Private Messages - user with no group messages",
  function (needs) {
    needs.user();

    needs.site({
      can_tag_pms: true,
    });

    test("viewing messages", async function (assert) {
      await visit("/u/eviltrout/messages");

      assert.equal(count(".topic-list-item"), 1, "displays the topic list");

      assert.ok(
        !exists(".user-messages-inboxes-drop"),
        "does not display inboxes dropdown"
      );

      assert.ok(exists(".messages-nav .tags"), "displays the tags filter");

      assert.ok(
        !exists(".group-notifications-button"),
        "displays the group notifications button"
      );
    });
  }
);

acceptance(
  "User Private Messages - user with group messages",
  function (needs) {
    let fetchedNew;
    let fetchUserNew;
    let fetchedGroupNew;

    needs.user();

    needs.site({
      can_tag_pms: true,
    });

    needs.hooks.afterEach(() => {
      fetchedNew = false;
      fetchedGroupNew = false;
      fetchUserNew = false;
    });

    needs.pretender((server, helper) => {
      server.get("/topics/private-messages-all/:username.json", () => {
        return helper.response({
          topic_list: {
            topics: [
              { id: 1, posters: [] },
              { id: 2, posters: [] },
              { id: 3, posters: [] },
            ],
          },
        });
      });

      [
        "/topics/private-messages-all-new/:username.json",
        "/topics/private-messages-all-unread/:username.json",
        "/topics/private-messages-new/:username.json",
        "/topics/private-messages-unread/:username.json",
        "/topics/private-messages-group/:username/:group_name/new.json",
        "/topics/private-messages-group/:username/:group_name/unread.json",
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
              topics: topics,
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

        return helper.response({});
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

        return helper.response({});
      });
    });

    test("dismissing all unread messages", async function (assert) {
      await visit("/u/charlie/messages/unread");

      assert.equal(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");
      await click("#dismiss-read-confirm");

      assert.equal(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("dismissing personal unread messages", async function (assert) {
      await visit("/u/charlie/messages/personal/unread");

      assert.equal(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");
      await click("#dismiss-read-confirm");

      assert.equal(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("dismissing group unread messages", async function (assert) {
      await visit("/u/charlie/messages/group/awesome_group/unread");

      assert.equal(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");
      await click("#dismiss-read-confirm");

      assert.equal(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("dismissing all new messages", async function (assert) {
      await visit("/u/charlie/messages/new");

      assert.equal(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");

      assert.equal(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("dismissing personal new messages", async function (assert) {
      await visit("/u/charlie/messages/personal/new");

      assert.equal(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");

      assert.equal(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("dismissing new group messages", async function (assert) {
      await visit("/u/charlie/messages/group/awesome_group/new");

      assert.equal(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      await click(".btn.dismiss-read");

      assert.equal(
        count(".topic-list-item"),
        0,
        "displays the right topic list"
      );
    });

    test("viewing messages", async function (assert) {
      await visit("/u/charlie/messages");

      assert.equal(
        count(".topic-list-item"),
        3,
        "displays the right topic list"
      );

      assert.ok(
        exists(".user-messages-inboxes-drop"),
        "displays inboxes dropdown"
      );

      assert.ok(exists(".messages-nav .tags"), "displays the tags filter");

      await selectKit(".user-messages-inboxes-drop").expand();
      await selectKit(".user-messages-inboxes-drop").selectRowByValue(
        PERSONAL_INBOX
      );

      assert.equal(
        count(".topic-list-item"),
        1,
        "displays the right topic list"
      );

      assert.ok(
        !exists(".messages-nav .tags"),
        "does not display the tags filter"
      );

      await selectKit(".user-messages-inboxes-drop").expand();
      await selectKit(".user-messages-inboxes-drop").selectRowByValue(
        "awesome_group"
      );

      assert.equal(
        count(".topic-list-item"),
        2,
        "displays the right topic list"
      );

      assert.ok(
        exists(".group-notifications-button"),
        "displays the group notifications button"
      );

      assert.ok(
        !exists(".messages-nav .tags"),
        "does not display the tags filter"
      );
    });
  }
);
