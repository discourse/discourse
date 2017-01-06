import { acceptance } from "helpers/qunit-helpers";

acceptance("Editing Group", {
  loggedIn: true
});

test("Editing group", () => {
  visit("/groups/discourse/edit");

  andThen(() => {
    ok(find('.group-flair-inputs').length === 1, 'it should display avatar flair inputs');
    ok(find('.group-edit-bio').length === 1, 'it should display group bio input');
    ok(find('.group-edit-full-name').length === 1, 'it should display group full name input');
    ok(find('.group-edit-public').length === 1, 'it should display group public input');
    ok(find('.group-edit-allow-membership-requests').length === 1, 'it should display group allow_membership_requets input');
    ok(find('.group-members-input .item').length === 7, 'it should display group members');
    ok(find('.group-members-input-selector').length === 1, 'it should display input to add group members');
    ok(find('.group-members-input-selector .add[disabled]').length === 1, 'add members button should be disabled');
  });

  andThen(() => {
    ok(find('.group-edit-allow-membership-requests[disabled]').length === 1, 'it should disable group allow_membership_request input');
  });

  click('.group-edit-public');
  click('.group-edit-allow-membership-requests');

  andThen(() => {
    ok(find('.group-edit-public[disabled]').length === 1, 'it should disable group public input');
  });
});
