import { acceptance, logIn } from "helpers/qunit-helpers";

acceptance("Groups");

QUnit.test("Browsing Groups", assert => {
  visit("/groups");

  andThen(() => {
    assert.equal(count('.groups-table-row'), 2, 'it displays visible groups');
    assert.equal(find('.group-index-join').length, 1, 'it shows button to join group');
    assert.equal(find('.group-index-request').length, 1, 'it shows button to request for group membership');
  });

  click('.group-index-join');

  andThen(() => {
    assert.ok(exists('.modal.login-modal'), 'it shows the login modal');
  });

  click('.login-modal .close');

  andThen(() => {
    assert.ok(invisible('.modal.login-modal'), 'it closes the login modal');
  });

  click('.group-index-request');

  andThen(() => {
    assert.ok(exists('.modal.login-modal'), 'it shows the login modal');
  });

  click("a[href='/groups/discourse/members']");

  andThen(() => {
    assert.equal(find('.group-info-name').text().trim(), 'Awesome Team', "it displays the group page");
  });

  click('.group-index-join');

  andThen(() => {
    assert.ok(exists('.modal.login-modal'), 'it shows the login modal');
  });
});

QUnit.test("Anonymous Viewing Group", assert => {
  visit("/groups/discourse");

  andThen(() => {
    assert.ok(count('.avatar-flair .fa-adjust') === 1, "it displays the group's avatar flair");
    assert.ok(count('.group-members tr') > 0, "it lists group members");
    assert.ok(count('.group-message-button') === 0, 'it does not show group message button');
  });

  click(".nav-pills li a[title='Activity']");

  andThen(() => {
    assert.ok(count('.group-post') > 0, "it lists stream items");
  });

  click(".group-activity-nav li a[href='/groups/discourse/activity/topics']");

  andThen(() => {
    assert.ok(count('.group-post') > 0, "it lists stream items");
  });

  click(".group-activity-nav li a[href='/groups/discourse/activity/mentions']");

  andThen(() => {
    assert.ok(count('.group-post') > 0, "it lists stream items");
  });

  andThen(() => {
    assert.equal(
      find(".group-activity li a[href='/groups/discourse/activity/messages']").length,
      0,
      'it should not show messages tab if user is not a group user or admin'
    );
    assert.ok(find(".nav-pills li a[title='Edit Group']").length === 0, 'it should not show messages tab if user is not admin');
    assert.ok(find(".nav-pills li a[title='Logs']").length === 0, 'it should not show Logs tab if user is not admin');
    assert.ok(count('.group-post') > 0, "it lists stream items");
  });
});

QUnit.test("User Viewing Group", assert => {
  logIn();
  Discourse.reset();

  visit("/groups");
  click('.group-index-request');

  server.post('/groups/Macdonald/request_membership', () => { // eslint-disable-line no-undef
    return [
      200,
      { "Content-Type": "application/json" },
      { relative_url: '/t/internationalization-localization/280' }
    ];
  });

  andThen(() => {
    assert.equal(find('.modal-header').text().trim(), I18n.t(
      'groups.membership_request.title', { group_name: 'Macdonald' }
    ));

    assert.equal(find('.request-group-membership-form textarea').val(), 'Please add me');
  });

  click('.modal-footer .btn-primary');

  andThen(() => {
    assert.equal(
      find('.fancy-title').text().trim(),
      "Internationalization / localization"
    );
  });

  visit("/groups/discourse");

  click('.group-message-button');

  andThen(() => {
    assert.ok(count('#reply-control') === 1, 'it opens the composer');
    assert.equal(find('.ac-wrap .item').text(), 'discourse', 'it prefills the group name');
  });
});

QUnit.test("Admin Viewing Group", assert => {
  logIn();
  Discourse.reset();

  visit("/groups/discourse");

  andThen(() => {
    assert.ok(find(".nav-pills li a[title='Edit Group']").length === 1, 'it should show edit group tab if user is admin');
    assert.ok(find(".nav-pills li a[title='Logs']").length === 1, 'it should show Logs tab if user is admin');
    assert.equal(count('.group-message-button'), 1, 'it displays show group message button');
    assert.equal(find('.group-info-name').text(), 'Awesome Team', 'it should display the group name');
  });

  click(".nav-pills li a[title='Activity']");

  andThen(() => {
    assert.equal(
      find(".group-activity li a[href='/groups/discourse/activity/messages']").length,
      1,
      'it should show messages tab if user is admin'
    );
  });
});
