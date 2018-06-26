import { acceptance } from "helpers/qunit-helpers";

acceptance("Group logs", {
  loggedIn: true,
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.get("/groups/snorlax.json", () => { // eslint-disable-line no-undef
      return response({
        group: {
          id: 41,
          automatic: false,
          name: "snorlax",
          user_count: 1,
          alias_level: 0,
          visible: true,
          automatic_membership_email_domains: "",
          automatic_membership_retroactive: false,
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
          is_group_owner: true
        }
      });
    });

    // Workaround while awaiting https://github.com/tildeio/route-recognizer/issues/53
    // prettier-ignore
    server.get("/groups/snorlax/logs.json", request => { // eslint-disable-line no-undef
      if (request.queryParams["filters[action]"]) {
        return response({
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
                avatar_template: "/images/avatar.png"
              },
              target_user: null
            }
          ],
          all_loaded: true
        });
      } else {
        return response({
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
                avatar_template: "/images/avatar.png"
              },
              target_user: null
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
                avatar_template: "/images/avatar.png"
              },
              target_user: {
                id: 1,
                username: "tgx",
                avatar_template: "/images/avatar.png"
              }
            }
          ],
          all_loaded: true
        });
      }
    });
  }
});

QUnit.test("Browsing group logs", assert => {
  visit("/groups/snorlax/manage/logs");

  andThen(() => {
    assert.ok(
      find("tr.group-manage-logs-row").length === 2,
      "it should display the right number of logs"
    );
    click(find(".group-manage-logs-row button")[0]);
  });

  andThen(() => {
    assert.ok(
      find("tr.group-manage-logs-row").length === 1,
      "it should display the right number of logs"
    );
  });
});
