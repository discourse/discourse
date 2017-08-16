import { acceptance, logIn } from "helpers/qunit-helpers";

acceptance("Editing Group");

QUnit.test("Editing group", assert => {
  logIn();
  Discourse.reset();

  visit("/groups/discourse/edit");

  andThen(() => {
    assert.ok(find('.group-flair-inputs').length === 1, 'it should display avatar flair inputs');
    assert.ok(find('.group-edit-bio').length === 1, 'it should display group bio input');
    assert.ok(find('.group-edit-full-name').length === 1, 'it should display group full name input');

    assert.ok(
      find('.group-edit-public-admission').length === 1,
      'it should display group public admission input'
    );

    assert.ok(
      find('.group-edit-public-exit').length === 1,
      'it should display group public exit input'
    );

    assert.ok(find('.group-edit-allow-membership-requests').length === 1, 'it should display group allow_membership_requets input');
    assert.ok(find('.group-members-input .item').length === 7, 'it should display group members');
    assert.ok(find('.group-members-input-selector').length === 1, 'it should display input to add group members');
    assert.ok(find('.group-members-input-selector .add[disabled]').length === 1, 'add members button should be disabled');

    assert.ok(
      find('.group-edit-allow-membership-requests[disabled]').length === 1,
      'it should disable group allow_membership_request input'
    );
  });

  click('.group-edit-public-admission');
  click('.group-edit-allow-membership-requests');

  andThen(() => {
    assert.ok(
      find('.group-edit-public-admission[disabled]').length === 1,
      'it should disable group public admission input'
    );

    assert.equal(
      find('.group-edit-membership-request-template').length, 1,
      'it should display the membership request template field'
    );
  });
});

QUnit.test("Editing group as an anonymous user", assert => {
  visit("/groups/discourse/edit");

  andThen(() => {
    assert.ok(count('.group-members tr') > 0, "it should redirect to members page for an anonymous user");
  });
});
