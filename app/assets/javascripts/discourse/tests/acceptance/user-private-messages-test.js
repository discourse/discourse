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
    needs.user();

    needs.site({
      can_tag_pms: true,
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
