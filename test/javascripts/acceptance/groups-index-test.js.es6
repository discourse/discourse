import { acceptance } from "helpers/qunit-helpers";

acceptance("Groups");

QUnit.test("Browsing Groups", assert => {
  visit("/groups");

  andThen(() => {
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
  });

  click(".group-index-join");

  andThen(() => {
    assert.ok(exists(".modal.login-modal"), "it shows the login modal");
  });

  click(".login-modal .close");

  andThen(() => {
    assert.ok(invisible(".modal.login-modal"), "it closes the login modal");
  });

  click(".group-index-request");

  andThen(() => {
    assert.ok(exists(".modal.login-modal"), "it shows the login modal");
  });

  click("a[href='/groups/discourse/members']");

  andThen(() => {
    assert.equal(
      find(".group-info-name")
        .text()
        .trim(),
      "Awesome Team",
      "it displays the group page"
    );
  });

  click(".group-index-join");

  andThen(() => {
    assert.ok(exists(".modal.login-modal"), "it shows the login modal");
  });
});
