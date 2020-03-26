import { acceptance } from "helpers/qunit-helpers";
import { parsePostData } from "helpers/create-pretender";

let requests = [];

acceptance("Group Requests", {
  loggedIn: true,
  pretend(server, helper) {
    server.get("/groups/Macdonald.json", () => {
      return helper.response({
        group: {
          id: 42,
          automatic: false,
          name: "Macdonald",
          user_count: 1,
          mentionable_level: 0,
          messageable_level: 0,
          visibility_level: 0,
          automatic_membership_email_domains: "",
          automatic_membership_retroactive: false,
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
          messageable: false
        },
        extras: {
          visible_group_names: ["discourse", "Macdonald"]
        }
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
            requested_at: "2019-01-31T12:00:00.000Z"
          },
          {
            id: 20,
            username: "eviltrout2",
            name: "Robin Ward",
            avatar_template:
              "/user_avatar/meta.discourse.org/eviltrout/{size}/5275_2.png",
            reason: "Please accept another membership request.",
            requested_at: "2019-01-31T14:00:00.000Z"
          }
        ],
        meta: { total: 2, limit: 50, offset: 0 }
      });
    });

    server.put("/groups/42/handle_membership_request.json", request => {
      const body = parsePostData(request.requestBody);
      requests.push([body["user_id"], body["accept"]]);
      return helper.success();
    });
  }
});

QUnit.test("Group Requests", async assert => {
  await visit("/groups/Macdonald/requests");

  assert.equal(find(".group-members tr").length, 2);
  assert.equal(
    find(".group-members tr:first-child td:nth-child(1)")
      .text()
      .trim()
      .replace(/\s+/g, " "),
    "eviltrout Robin Ward"
  );
  assert.equal(
    find(".group-members tr:first-child td:nth-child(3)")
      .text()
      .trim(),
    "Please accept my membership request."
  );
  assert.equal(
    find(".group-members tr:first-child .btn-primary")
      .text()
      .trim(),
    "Accept"
  );
  assert.equal(
    find(".group-members tr:first-child .btn-danger")
      .text()
      .trim(),
    "Deny"
  );

  await click(".group-members tr:first-child .btn-primary");
  assert.ok(
    find(".group-members tr:first-child td:nth-child(4)")
      .text()
      .trim()
      .indexOf("accepted") === 0
  );
  assert.deepEqual(requests, [["19", "true"]]);

  await click(".group-members tr:last-child .btn-danger");
  assert.equal(
    find(".group-members tr:last-child td:nth-child(4)")
      .text()
      .trim(),
    "denied"
  );
  assert.deepEqual(requests, [
    ["19", "true"],
    ["20", undefined]
  ]);
});
