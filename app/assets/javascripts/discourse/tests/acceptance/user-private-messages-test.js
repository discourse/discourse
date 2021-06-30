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

    test("viewing messages", async function (assert) {
      await visit("/u/eviltrout/messages");

      assert.equal(count(".topic-list-item"), 1, "displays the topic list");

      assert.ok(
        !exists(".user-messages-inboxes-drop"),
        "does not display inboxes dropdown"
      );

      assert.ok(
        !exists(".user-messages-tags-drop"),
        "does not display tags dropdown"
      );

      assert.ok(
        !exists(".group-notifications-button"),
        "displays the group notifications button"
      );
    });
  }
);

acceptance("User Private Messages - with PM tagging enabled", function (needs) {
  needs.user();

  needs.site({
    can_tag_pms: true,
  });

  needs.pretender((server, helper) => {
    server.get("/tags/personal_messages/:username", () => {
      return helper.response({
        tags: [
          { id: "tag1", text: "tag1", count: 1 },
          { id: "tag2", text: "tag2", count: 2 },
        ],
      });
    });

    server.get("/topics/private-messages-all/:username.json", (request) => {
      let topicList;

      if (request.queryParams?.tag) {
        topicList = {
          topics: [
            { id: 1, posters: [] },
            { id: 2, posters: [] },
          ],
        };
      } else {
        topicList = {
          topics: [
            { id: 1, posters: [] },
            { id: 2, posters: [] },
            { id: 3, posters: [] },
          ],
        };
      }

      return helper.response({ topic_list: topicList });
    });
  });

  test("viewing messages", async function (assert) {
    await visit("/u/charlie/messages");

    assert.equal(count(".topic-list-item"), 3, "displays the right topic list");

    assert.ok(exists(".user-messages-tags-drop"), "displays tags dropdown");

    await selectKit(".user-messages-tags-drop").expand();
    await selectKit(".user-messages-tags-drop").selectRowByValue("tag1");

    assert.equal(count(".topic-list-item"), 2, "displays the right topic list");
  });
});

acceptance(
  "User Private Messages - user with group messages",
  function (needs) {
    needs.user();

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
        !exists(".user-messages-tags-drop"),
        "does not display tags dropdown"
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
    });
  }
);
