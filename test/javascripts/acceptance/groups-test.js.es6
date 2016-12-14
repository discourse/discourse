import { acceptance, logIn } from "helpers/qunit-helpers";

acceptance("Groups");

test("Browsing Groups", () => {
  visit("/groups");

  andThen(() => {
    equal(count('.groups-table-row'), 18, 'it displays visible groups');
  });

  click("a[href='/groups/discourse/members']");

  andThen(() => {
    equal(find('.group-header').text().trim(), 'Awesome Team', "it displays the group page");
  });
});

test("Viewing Group", () => {
  visit("/groups/discourse");

  andThen(() => {
    ok(count('.avatar-flair .fa-adjust') === 1, "it displays the group's avatar flair");
    ok(count('.group-members tr') > 0, "it lists group members");
  });

  visit("/groups/discourse/posts");
  andThen(() => {
    ok(count('.user-stream .item') > 0, "it lists stream items");
  });

  visit("/groups/discourse/topics");
  andThen(() => {
    ok(count('.user-stream .item') > 0, "it lists stream items");
  });

  visit("/groups/discourse/mentions");
  andThen(() => {
    ok(count('.user-stream .item') > 0, "it lists stream items");
  });

  visit("/groups/discourse/messages");
  andThen(() => {
    ok(find(".nav-stacked li a[title='Messages']").length === 0, 'it should not show messages tab if user is not admin');
    ok(find(".nav-stacked li a[title='Edit Group']").length === 0, 'it should not show messages tab if user is not admin');
    ok(find(".nav-stacked li a[title='Logs']").length === 0, 'it should not show Logs tab if user is not admin');
    ok(count('.user-stream .item') > 0, "it lists stream items");
  });
});

test("Admin Viewing Group", () => {
  logIn();
  Discourse.reset();

  visit("/groups/discourse");

  andThen(() => {
    ok(find(".nav-stacked li a[title='Messages']").length === 1, 'it should show messages tab if user is admin');
    ok(find(".nav-stacked li a[title='Edit Group']").length === 1, 'it should show edit group tab if user is admin');
    ok(find(".nav-stacked li a[title='Logs']").length === 1, 'it should show Logs tab if user is admin');
    equal(find('.group-title').text(), 'Awesome Team', 'it should display the group title');
    equal(find('.group-name').text(), '@discourse', 'it should display the group name');
  });
});
