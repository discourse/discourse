import { acceptance } from "helpers/qunit-helpers";

acceptance("Groups");

QUnit.test("Browsing Groups", async assert => {
  await visit("/groups?username=eviltrout");

  assert.equal(count(".groups-table-row"), 1, "it displays user's groups");

  await visit("/groups");

  assert.equal(count(".groups-table-row"), 2, "it displays visible groups");
  assert.equal(
    find(".group-index-join").length,
    1,
    "it shows button to join group"
  );
  assert.equal(
    find(".group-index-request").length,
    1,
    "it shows button to request for group membership"
  );

  await click(".group-index-join");

  assert.ok(exists(".modal.login-modal"), "it shows the login modal");

  await click(".login-modal .close");

  assert.ok(invisible(".modal.login-modal"), "it closes the login modal");

  await click(".group-index-request");

  assert.ok(exists(".modal.login-modal"), "it shows the login modal");

  await click("a[href='/groups/discourse/members']");

  assert.equal(
    find(".group-info-name")
      .text()
      .trim(),
    "Awesome Team",
    "it displays the group page"
  );

  await click(".group-index-join");

  assert.ok(exists(".modal.login-modal"), "it shows the login modal");
});
