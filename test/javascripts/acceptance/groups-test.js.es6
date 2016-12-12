import { acceptance, logIn } from "helpers/qunit-helpers";

acceptance("Groups");

test("Browsing Groups", () => {
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
    ok($('.nav-stacked li').length === 4, 'it should not show messages tab');
    ok(count('.user-stream .item') > 0, "it lists stream items");
  });
});

test("Admin Browsing Groups", () => {
  logIn();
  Discourse.reset();

  visit("/groups/discourse");

  andThen(() => {
    ok(find(".nav-stacked li a[title='Messages']").length === 1, 'it should show messages tab if user is admin');
    ok(find(".nav-stacked li a[title='Logs']").length === 1, 'it should show Logs tab if user is admin');
    equal(find('.group-title').text(), 'Awesome Team', 'it should display the group title');
    equal(find('.group-name').text(), '@discourse', 'it should display the group name');
  });

  click('.group-edit-btn');

  andThen(() => {
    ok(find('.group-flair-inputs').length === 1, 'it should display avatar flair inputs');
    ok(find('.edit-group-bio').length === 1, 'it should display group bio input');
    ok(find('.edit-group-title').length === 1, 'it should display group title input');
    ok(find('.edit-group-public').length === 1, 'it should display group public input');
  });
});
