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
    ok($('.nav-stacked li').length === 5, 'it should show messages tab if user is admin');
  });

  click('.group-edit-btn');

  andThen(() => {
    ok(find('.group-flair-inputs').length === 1, 'it should display avatar flair inputs');
  });
});
