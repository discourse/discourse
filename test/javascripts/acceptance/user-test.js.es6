import { acceptance } from "helpers/qunit-helpers";

acceptance("User", {loggedIn: true});

QUnit.test("Invites", assert => {
  visit("/u/eviltrout/invited/pending");
  andThen(() => {
    assert.ok($('body.user-invites-page').length, "has the body class");
  });
});

QUnit.test("Messages", assert => {
  visit("/u/eviltrout/messages");
  andThen(() => {
    assert.ok($('body.user-messages-page').length, "has the body class");
  });
});

QUnit.test("Notifications", assert => {
  visit("/u/eviltrout/notifications");
  andThen(() => {
    assert.ok($('body.user-notifications-page').length, "has the body class");
  });
});

QUnit.test("Root URL - Viewing Self", assert => {
  visit("/u/eviltrout");
  andThen(() => {
    assert.ok($('body.user-activity-page').length, "has the body class");
    assert.equal(currentPath(), 'user.userActivity.index', "it defaults to activity");
    assert.ok(exists('.container.viewing-self'), "has the viewing-self class");
  });
});