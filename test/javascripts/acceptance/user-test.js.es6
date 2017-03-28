import { acceptance } from "helpers/qunit-helpers";

acceptance("User", {loggedIn: true});

test("Invites", () => {
  visit("/u/eviltrout/invited/pending");
  andThen(() => {
    ok($('body.user-invites-page').length, "has the body class");
  });
});

test("Messages", () => {
  visit("/u/eviltrout/messages");
  andThen(() => {
    ok($('body.user-messages-page').length, "has the body class");
  });
});

test("Notifications", () => {
  visit("/u/eviltrout/notifications");
  andThen(() => {
    ok($('body.user-notifications-page').length, "has the body class");
  });
});

test("Root URL - Viewing Self", () => {
  visit("/u/eviltrout");
  andThen(() => {
    ok($('body.user-activity-page').length, "has the body class");
    equal(currentPath(), 'user.userActivity.index', "it defaults to activity");
    ok(exists('.container.viewing-self'), "has the viewing-self class");
  });
});
