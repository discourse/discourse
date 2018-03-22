import { acceptance, logIn } from "helpers/qunit-helpers";

acceptance("Group Members");

QUnit.test("Viewing Members as anon user", assert => {
  visit("/groups/discourse");

  andThen(() => {
    assert.ok(count('.avatar-flair .fa-adjust') === 1, "it displays the group's avatar flair");
    assert.ok(count('.group-members tr') > 0, "it lists group members");

    assert.ok(
      count('.group-member-dropdown') === 0,
      'it does not allow anon user to manage group members'
    );

    assert.equal(
      find('.group-username-filter').attr('placeholder'),
      I18n.t('groups.members.filter_placeholder'),
      'it should display the right filter placehodler'
    );
  });
});

QUnit.test("Viewing Members as an admin user", assert => {
  logIn();
  Discourse.reset();

  visit("/groups/discourse");

  andThen(() => {
    assert.ok(
      count('.group-member-dropdown') > 0,
      'it allows admin user to manage group members'
    );

    assert.equal(
      find('.group-username-filter').attr('placeholder'),
      I18n.t('groups.members.filter_placeholder_admin'),
      'it should display the right filter placehodler'
    );
  });
});
