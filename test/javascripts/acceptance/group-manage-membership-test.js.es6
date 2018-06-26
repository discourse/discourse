import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";

acceptance("Managing Group Membership", {
  loggedIn: true
});

QUnit.test("As an admin", assert => {
  visit("/groups/discourse/manage/membership");

  andThen(() => {
    assert.ok(
      find('label[for="automatic_membership"]').length === 1,
      "it should display automatic membership label"
    );

    assert.ok(
      find(".groups-form-automatic-membership-retroactive").length === 1,
      "it should display automatic membership retroactive checkbox"
    );

    assert.ok(
      find(".groups-form-primary-group").length === 1,
      "it should display set as primary group checkbox"
    );

    assert.ok(
      find(".groups-form-grant-trust-level").length === 1,
      "it should display grant trust level selector"
    );

    assert.ok(
      find(".group-form-public-admission").length === 1,
      "it should display group public admission input"
    );

    assert.ok(
      find(".group-form-public-exit").length === 1,
      "it should display group public exit input"
    );

    assert.ok(
      find(".group-form-allow-membership-requests").length === 1,
      "it should display group allow_membership_request input"
    );

    assert.ok(
      find(".group-form-allow-membership-requests[disabled]").length === 1,
      "it should disable group allow_membership_request input"
    );
  });

  click(".group-form-public-admission");
  click(".group-form-allow-membership-requests");

  andThen(() => {
    assert.ok(
      find(".group-form-public-admission[disabled]").length === 1,
      "it should disable group public admission input"
    );

    assert.ok(
      find(".group-form-public-exit[disabled]").length === 0,
      "it should not disable group public exit input"
    );

    assert.equal(
      find(".group-form-membership-request-template").length,
      1,
      "it should display the membership request template field"
    );
  });
});

QUnit.test("As a group owner", assert => {
  replaceCurrentUser({ staff: false, admin: false });

  visit("/groups/discourse/manage/membership");

  andThen(() => {
    assert.ok(
      find('label[for="automatic_membership"]').length === 0,
      "it should not display automatic membership label"
    );

    assert.ok(
      find(".groups-form-automatic-membership-retroactive").length === 0,
      "it should not display automatic membership retroactive checkbox"
    );

    assert.ok(
      find(".groups-form-primary-group").length === 0,
      "it should not display set as primary group checkbox"
    );

    assert.ok(
      find(".groups-form-grant-trust-level").length === 0,
      "it should not display grant trust level selector"
    );

    assert.ok(
      find(".group-form-public-admission").length === 1,
      "it should display group public admission input"
    );

    assert.ok(
      find(".group-form-public-exit").length === 1,
      "it should display group public exit input"
    );

    assert.ok(
      find(".group-form-allow-membership-requests").length === 1,
      "it should display group allow_membership_request input"
    );

    assert.ok(
      find(".group-form-allow-membership-requests[disabled]").length === 1,
      "it should disable group allow_membership_request input"
    );
  });
});
