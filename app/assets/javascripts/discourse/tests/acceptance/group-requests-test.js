import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";

acceptance("Group Requests", function (needs) {
  let requests;

  needs.user();
  needs.hooks.beforeEach(() => (requests = []));

  needs.pretender((server, helper) => {
    server.get("/groups/Macdonald.json", () => {
      return helper.response({
        group: {
          id: 42,
          automatic: false,
          name: "Macdonald",
          user_count: 10,
          mentionable_level: 0,
          messageable_level: 0,
          visibility_level: 0,
          automatic_membership_email_domains: "",
          primary_group: false,
          title: "Macdonald",
          grant_trust_level: null,
          incoming_email: null,
          has_messages: false,
          flair_url: null,
          flair_bg_color: "",
          flair_color: "",
          bio_raw: null,
          bio_cooked: null,
          public_admission: false,
          public_exit: false,
          allow_membership_requests: true,
          full_name: "Macdonald",
          default_notification_level: 3,
          membership_request_template: "",
          is_group_user: true,
          is_group_owner: true,
          is_group_owner_display: true,
          can_see_members: true,
          mentionable: false,
          messageable: false,
        },
        extras: {
          visible_group_names: ["discourse", "Macdonald"],
        },
      });
    });

    server.get("/groups/Macdonald/members.json", () => {
      return helper.response({
        members: [
          {
            id: 19,
            username: "eviltrout",
            name: "Robin Ward",
            avatar_template:
              "/user_avatar/meta.discourse.org/eviltrout/{size}/5275_2.png",
            reason: "Please accept my membership request.",
            requested_at: "2019-01-31T12:00:00.000Z",
          },
          {
            id: 20,
            username: "eviltrout2",
            name: "Robin Ward",
            avatar_template:
              "/user_avatar/meta.discourse.org/eviltrout/{size}/5275_2.png",
            reason: "Please accept another membership request.",
            requested_at: "2019-01-31T14:00:00.000Z",
          },
        ],
        meta: { total: 2, limit: 50, offset: 0 },
      });
    });

    server.put("/groups/42/handle_membership_request.json", (request) => {
      const body = helper.parsePostData(request.requestBody);
      requests.push([body["user_id"], body["accept"]]);
      return helper.success();
    });
  });

  test("Group Requests", async function (assert) {
    await visit("/g/Macdonald/requests");

    assert.dom(".group-members .group-member").exists({ count: 2 });
    assert.strictEqual(
      query(".group-members .directory-table__row:first-child .user-detail")
        .innerText.trim()
        .replace(/\s+/g, " "),
      "eviltrout Robin Ward"
    );
    assert.strictEqual(
      query(
        ".group-members .directory-table__row:first-child .directory-table__cell:nth-child(3)"
      ).innerText.trim(),
      "Please accept my membership request."
    );
    assert.strictEqual(
      query(
        ".group-members .directory-table__row:first-child .btn-primary"
      ).innerText.trim(),
      "Accept"
    );
    assert.strictEqual(
      query(
        ".group-members .directory-table__row:first-child .btn-danger"
      ).innerText.trim(),
      "Deny"
    );

    await click(
      ".group-members .directory-table__row:first-child .btn-primary"
    );
    assert.ok(
      query(
        ".group-members .directory-table__row:first-child .directory-table__cell:nth-child(4)"
      )
        .innerText.trim()
        .startsWith("accepted")
    );
    assert.deepEqual(requests, [["19", "true"]]);

    await click(".group-members .directory-table__row:last-child .btn-danger");
    assert.strictEqual(
      query(
        ".group-members .directory-table__row:last-child .directory-table__cell:nth-child(4)"
      ).innerText.trim(),
      "denied"
    );
    assert.deepEqual(requests, [
      ["19", "true"],
      ["20", undefined],
    ]);
  });
});
