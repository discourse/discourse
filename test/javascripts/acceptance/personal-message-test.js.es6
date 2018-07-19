import { acceptance } from "helpers/qunit-helpers";

acceptance("Personal Message", {
  loggedIn: true
});

QUnit.test("footer edit button", async assert => {
  await visit("/t/pm-for-testing/12");

  assert.ok(
    !exists(".edit-message"),
    "does not show edit first post button on footer by default"
  );
});

acceptance("Personal Message Tagging", {
  loggedIn: true,
  site: { can_tag_pms: true }
});

QUnit.test("show footer edit button", async assert => {
  await visit("/t/pm-for-testing/12");

  assert.ok(
    exists(".edit-message"),
    "shows edit first post button on footer when PM tagging is enabled"
  );
});
