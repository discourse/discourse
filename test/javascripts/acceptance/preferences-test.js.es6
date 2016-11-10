import { acceptance } from "helpers/qunit-helpers";
acceptance("User Preferences", { loggedIn: true });

test("update some fields", () => {
  visit("/users/eviltrout/preferences");

  andThen(() => {
    ok($('body.user-preferences-page').length, "has the body class");
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

test("username", () => {
  visit("/users/eviltrout/preferences/username");
  andThen(() => {
    ok(exists("#change_username"), "it has the input element");
  });
});

test("about me", () => {
  visit("/users/eviltrout/preferences/about-me");
  andThen(() => {
    ok(exists(".raw-bio"), "it has the input element");
  });
});

test("email", () => {
  visit("/users/eviltrout/preferences/email");
  andThen(() => {
    ok(exists("#change_email"), "it has the input element");
  });
});
