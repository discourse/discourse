import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("Admin - User Index", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/groups/search.json", () => {
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
          full_name: null,
        },
      ]);
    });

    server.put("/users/sam/preferences/username", () => {
      return helper.response({ id: 2, username: "new-sam" });
    });
  });

  test("can edit username", async function (assert) {
    await visit("/admin/users/2/sam");

    assert.equal(queryAll(".display-row.username .value").text().trim(), "sam");

    // Trying cancel.
    await click(".display-row.username button");
    await fillIn(".display-row.username .value input", "new-sam");
    await click(".display-row.username a");
    assert.equal(queryAll(".display-row.username .value").text().trim(), "sam");

    // Doing edit.
    await click(".display-row.username button");
    await fillIn(".display-row.username .value input", "new-sam");
    await click(".display-row.username button");
    assert.equal(
      queryAll(".display-row.username .value").text().trim(),
      "new-sam"
    );
  });

  test("will clear unsaved groups when switching user", async function (assert) {
    await visit("/admin/users/2/sam");

    assert.equal(
      queryAll(".display-row.username .value").text().trim(),
      "sam",
      "the name should be correct"
    );

    const groupChooser = selectKit(".group-chooser");
    await groupChooser.expand();
    await groupChooser.selectRowByValue(42);
    assert.equal(groupChooser.header().value(), 42, "group should be set");

    await visit("/admin/users/1/eviltrout");

    assert.equal(
      queryAll(".display-row.username .value").text().trim(),
      "eviltrout",
      "the name should be correct"
    );

    assert.ok(
      !exists('.group-chooser span[title="Macdonald"]'),
      "group should not be set"
    );
  });
});
