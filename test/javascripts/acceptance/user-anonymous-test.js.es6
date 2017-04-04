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
  visit("/u/eviltrout");
  andThen(() => {
    ok($('body.user-summary-page').length, "has the body class");
    equal(currentPath(), 'user.summary', "it defaults to summary");
  });
});

test("Filters", () => {
  visit("/u/eviltrout/activity");
  andThen(() => {
    ok($('body.user-activity-page').length, "has the body class");
  });
  hasStream();

  visit("/u/eviltrout/activity/topics");
  hasTopicList();

  visit("/u/eviltrout/activity/replies");
  hasStream();
});

test("Badges", () => {
  visit("/u/eviltrout/badges");
  andThen(() => {
    ok($('body.user-badges-page').length, "has the body class");
    ok(exists(".user-badges-list .badge-card"), "shows a badge");
  });
});

test("Restricted Routes", () => {
  visit("/u/eviltrout/preferences");

  andThen(() => {
    equal(currentURL(), '/u/eviltrout/activity', "it redirects from preferences");
  });
});
