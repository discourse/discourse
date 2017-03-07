import { acceptance } from "helpers/qunit-helpers";
acceptance("User Anonymous");

export function hasStream() {
  andThen(() => {
    ok(exists('.user-main .about'), 'it has the about section');
    ok(count('.user-stream .item') > 0, 'it has stream items');
  });
}

function hasTopicList() {
  andThen(() => {
    equal(count('.user-stream .item'), 0, "has no stream displayed");
    ok(count('.topic-list tr') > 0, 'it has a topic list');
  });
}

test("Root URL", () => {
  visit("/users/eviltrout");
  andThen(() => {
    equal(currentPath(), 'user.summary', "it defaults to summary");
  });
});

test("Filters", () => {
  visit("/users/eviltrout/activity");
  andThen(() => {
    ok($('body.user-activity-page').length, "has the body class");
  });
  hasStream();

  visit("/users/eviltrout/activity/topics");
  hasTopicList();

  visit("/users/eviltrout/activity/replies");
  hasStream();
});

test("Badges", () => {
  visit("/users/eviltrout/badges");
  andThen(() => {
    ok($('body.user-badges-page').length, "has the body class");
    ok(exists(".user-badges-list .badge-card"), "shows a badge");
  });
});

test("Restricted Routes", () => {
  visit("/users/eviltrout/preferences");

  andThen(() => {
    equal(currentURL(), '/users/eviltrout/activity', "it redirects from preferences");
  });
});
