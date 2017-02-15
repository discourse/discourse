import { acceptance, logIn } from "helpers/qunit-helpers";

acceptance("Groups");

test("Browsing Groups", () => {
  visit("/groups");

  andThen(() => {
    equal(count('.groups-table-row'), 2, 'it displays visible groups');
    equal(find('.group-index-join').length, 1, 'it shows button to join group');
    equal(find('.group-index-request').length, 1, 'it shows button to request for group membership');
  });

  click('.group-index-join');

  andThen(() => {
    ok(exists('.modal.login-modal'), 'it shows the login modal');
  });

  click('.login-modal .close');

  andThen(() => {
    ok(invisible('.modal.login-modal'), 'it closes the login modal');
  });

  click('.group-index-request');

  andThen(() => {
    ok(exists('.modal.login-modal'), 'it shows the login modal');
  });

  click("a[href='/groups/discourse/members']");

  andThen(() => {
    equal(find('.group-info-name').text().trim(), 'Awesome Team', "it displays the group page");
  });

  click('.group-index-join');

  andThen(() => {
    ok(exists('.modal.login-modal'), 'it shows the login modal');
  });
});

test("Viewing Group", () => {
  visit("/groups/discourse");

  andThen(() => {
    ok(count('.avatar-flair .fa-adjust') === 1, "it displays the group's avatar flair");
    ok(count('.group-members tr') > 0, "it lists group members");
  });

  click(".nav-pills li a[title='Activity']");

  andThen(() => {
    ok(count('.user-stream .item') > 0, "it lists stream items");
  });

  click(".group-activity-nav li a[href='/groups/discourse/activity/topics']");

  andThen(() => {
    ok(count('.user-stream .item') > 0, "it lists stream items");
  });

  click(".group-activity-nav li a[href='/groups/discourse/activity/mentions']");

  andThen(() => {
    ok(count('.user-stream .item') > 0, "it lists stream items");
  });

  andThen(() => {
    equal(
      find(".group-activity li a[href='/groups/discourse/activity/messages']").length,
      0,
      'it should not show messages tab if user is not a group user or admin'
    );
    ok(find(".nav-pills li a[title='Edit Group']").length === 0, 'it should not show messages tab if user is not admin');
    ok(find(".nav-pills li a[title='Logs']").length === 0, 'it should not show Logs tab if user is not admin');
    ok(count('.user-stream .item') > 0, "it lists stream items");
  });
});

test("Admin Viewing Group", () => {
  logIn();
  Discourse.reset();

  visit("/groups/discourse");

  andThen(() => {
    ok(find(".nav-pills li a[title='Edit Group']").length === 1, 'it should show edit group tab if user is admin');
    ok(find(".nav-pills li a[title='Logs']").length === 1, 'it should show Logs tab if user is admin');

    equal(find('.group-info-name').text(), 'Awesome Team', 'it should display the group name');
  });

  click(".nav-pills li a[title='Activity']");

  andThen(() => {
    equal(
      find(".group-activity li a[href='/groups/discourse/activity/messages']").length,
      1,
      'it should show messages tab if user is admin'
    );
  });
});
