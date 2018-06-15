import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";

acceptance("Managing Group Interaction Settings", {
  loggedIn: true,
  settings: {
    email_in: true
  }
});

QUnit.test("As an admin", assert => {
  visit("/groups/discourse/manage/interaction");

  andThen(() => {
    assert.equal(
      find(".groups-form-visibility-level").length,
      1,
      "it should display visibility level selector"
    );

    assert.equal(
      find(".groups-form-mentionable-level").length,
      1,
      "it should display mentionable level selector"
    );

    assert.equal(
      find(".groups-form-messageable-level").length,
      1,
      "it should display messageable level selector"
    );

    assert.equal(
      find(".groups-form-incoming-email").length,
      1,
      "it should display incoming email input"
    );

    assert.equal(
      find(".groups-form-default-notification-level").length,
      1,
      "it should display default notification level input"
    );
  });
});

QUnit.test("As a group owner", assert => {
  replaceCurrentUser({ admin: false, staff: false });
  visit("/groups/discourse/manage/interaction");

  andThen(() => {
    assert.equal(
      find(".groups-form-visibility-level").length,
      0,
      "it should display visibility level selector"
    );

    assert.equal(
      find(".groups-form-mentionable-level").length,
      1,
      "it should display mentionable level selector"
    );

    assert.equal(
      find(".groups-form-messageable-level").length,
      1,
      "it should display messageable level selector"
    );

    assert.equal(
      find(".groups-form-incoming-email").length,
      0,
      "it should not display incoming email input"
    );

    assert.equal(
      find(".groups-form-default-notification-level").length,
      1,
      "it should display default notification level input"
    );
  });
});
