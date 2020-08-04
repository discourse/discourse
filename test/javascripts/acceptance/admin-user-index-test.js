import selectKit from "helpers/select-kit-helper";
import { acceptance } from "helpers/qunit-helpers";
import pretender from "helpers/create-pretender";

acceptance("Admin - User Index", {
  loggedIn: true,
  pretend(pretenderServer, helper) {
    pretenderServer.get("/groups/search.json", () => {
      return helper.response([
        {
          id: 42,
          automatic: false,
          name: "Macdonald",
          user_count: 0,
          alias_level: 99,
          visible: true,
          automatic_membership_email_domains: "",
          primary_group: false,
          title: null,
          grant_trust_level: null,
          has_messages: false,
          flair_url: null,
          flair_bg_color: null,
          flair_color: null,
          bio_raw: null,
          bio_cooked: null,
          public_admission: false,
          allow_membership_requests: true,
          membership_request_template: "Please add me",
          full_name: null
        }
      ]);
    });
  }
});

QUnit.test("can edit username", async assert => {
  pretender.put("/users/sam/preferences/username", () => [
    200,
    {
      "Content-Type": "application/json"
    },
    { id: 2, username: "new-sam" }
  ]);

  await visit("/admin/users/2/sam");

  assert.equal(
    find(".display-row.username .value")
      .text()
      .trim(),
    "sam"
  );

  // Trying cancel.
  await click(".display-row.username button");
  await fillIn(".display-row.username .value input", "new-sam");
  await click(".display-row.username a");
  assert.equal(
    find(".display-row.username .value")
      .text()
      .trim(),
    "sam"
  );

  // Doing edit.
  await click(".display-row.username button");
  await fillIn(".display-row.username .value input", "new-sam");
  await click(".display-row.username button");
  assert.equal(
    find(".display-row.username .value")
      .text()
      .trim(),
    "new-sam"
  );
});

QUnit.test("will clear unsaved groups when switching user", async assert => {
  await visit("/admin/users/2/sam");

  assert.equal(
    find(".display-row.username .value")
      .text()
      .trim(),
    "sam",
    "the name should be correct"
  );

  const groupChooser = selectKit(".group-chooser");
  await groupChooser.expand();
  await groupChooser.selectRowByValue(42);
  assert.equal(groupChooser.header().value(), 42, "group should be set");

  await visit("/admin/users/1/eviltrout");

  assert.equal(
    find(".display-row.username .value")
      .text()
      .trim(),
    "eviltrout",
    "the name should be correct"
  );

  assert.equal(
    find('.group-chooser span[title="Macdonald"]').length,
    0,
    "group should not be set"
  );
});
