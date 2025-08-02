import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Group logs", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/groups/snorlax.json", () => {
      return helper.response({
        group: {
          id: 41,
          automatic: false,
          name: "snorlax",
          user_count: 1,
          alias_level: 0,
          visible: true,
          automatic_membership_email_domains: "",
          primary_group: true,
          title: "Team Snorlax",
          grant_trust_level: null,
          incoming_email: null,
          has_messages: false,
          flair_url: "",
          flair_bg_color: "",
          flair_color: "",
          bio_raw: "",
          bio_cooked: null,
          public: true,
          is_group_user: true,
          is_group_owner: true,
        },
      });
    });

    // Workaround while awaiting https://github.com/tildeio/route-recognizer/issues/53
    server.get("/groups/snorlax/logs.json", (request) => {
      if (request.queryParams["filters[action]"]) {
        return helper.response({
          logs: [
            {
              action: "change_group_setting",
              subject: "title",
              prev_value: null,
              new_value: "Team Snorlax",
              created_at: "2016-12-12T08:27:46.408Z",
              acting_user: {
                id: 1,
                username: "tgx",
                avatar_template: "/images/avatar.png",
              },
              target_user: null,
            },
          ],
          all_loaded: true,
        });
      } else {
        return helper.response({
          logs: [
            {
              action: "change_group_setting",
              subject: "title",
              prev_value: null,
              new_value: "Team Snorlax",
              created_at: "2016-12-12T08:27:46.408Z",
              acting_user: {
                id: 1,
                username: "tgx",
                avatar_template: "/images/avatar.png",
              },
              target_user: null,
            },
            {
              action: "add_user_to_group",
              subject: null,
              prev_value: null,
              new_value: null,
              created_at: "2016-12-12T08:27:27.725Z",
              acting_user: {
                id: 1,
                username: "tgx",
                avatar_template: "/images/avatar.png",
              },
              target_user: {
                id: 1,
                username: "tgx",
                avatar_template: "/images/avatar.png",
              },
            },
          ],
          all_loaded: true,
        });
      }
    });
  });

  test("Browsing group logs", async function (assert) {
    await visit("/g/snorlax/manage/logs");
    assert
      .dom("tr.group-manage-logs-row")
      .exists({ count: 2 }, "displays the right number of logs");

    await click(".group-manage-logs-row button");
    assert
      .dom("tr.group-manage-logs-row")
      .exists({ count: 1 }, "displays the right number of logs");
  });
});
