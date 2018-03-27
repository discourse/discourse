import { acceptance, logIn } from "helpers/qunit-helpers";

acceptance("Managing Group Profile");

QUnit.test("Editing group", assert => {
  logIn();
  Discourse.reset();

  visit("/groups/discourse/manage/profile");

  andThen(() => {
    assert.ok(find('.group-flair-inputs').length === 1, 'it should display avatar flair inputs');
    assert.ok(find('.group-form-bio').length === 1, 'it should display group bio input');
    assert.ok(find('.group-form-name').length === 1, 'it should display group name input');
    assert.ok(find('.group-form-full-name').length === 1, 'it should display group full name input');

    assert.ok(
      find('.group-form-public-admission').length === 1,
      'it should display group public admission input'
    );

    assert.ok(
      find('.group-form-public-exit').length === 1,
      'it should display group public exit input'
    );

    assert.ok(
      find('.group-form-allow-membership-requests').length === 1,
      'it should display group allow_membership_request input'
    );

    assert.ok(
      find('.group-form-allow-membership-requests[disabled]').length === 1,
      'it should disable group allow_membership_request input'
    );
  });

  click('.group-form-public-admission');
  click('.group-form-allow-membership-requests');

  andThen(() => {
    assert.ok(
      find('.group-form-public-admission[disabled]').length === 1,
      'it should disable group public admission input'
    );

    assert.ok(
      find('.group-form-public-exit[disabled]').length === 0,
      'it should not disable group public exit input'
    );

    assert.equal(
      find('.group-form-membership-request-template').length, 1,
      'it should display the membership request template field'
    );
  });
});

QUnit.test("Editing group as an anonymous user", assert => {
  visit("/groups/discourse/manage/profile");

  andThen(() => {
    assert.ok(count('.group-members tr') > 0, "it should redirect to members page for an anonymous user");
  });
});
