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
    ok($('.action-list li').length === 4, 'it should not show messages tab');
    ok(count('.user-stream .item') > 0, "it lists stream items");
  });
});

test("Messages tab", () => {
  logIn();
  Discourse.reset();

  visit("/groups/discourse");

  andThen(() => {
    ok($('.action-list li').length === 5, 'it should show messages tab if user is admin');
  });
});
