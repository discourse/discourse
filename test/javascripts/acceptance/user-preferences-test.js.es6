import { acceptance } from "helpers/qunit-helpers";
acceptance("User Preferences", { loggedIn: true });

test("update some fields", () => {
  visit("/users/eviltrout/preferences");

  andThen(() => {
    equal(currentURL(), '/users/eviltrout/preferences', "it doesn't redirect");
    ok(exists('.user-preferences'), 'it shows the preferences');
  });

  fillIn("#edit-location", "Westeros");

  click('.save-user');
  ok(!exists('.saved-user'), "it hasn't been saved yet");
  andThen(() => {
    ok(exists('.saved-user'), 'it displays the saved message');
  });
});
