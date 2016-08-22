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
    equal(currentPath(), 'user.userActivity.index', "it defaults to activity");
  });
});

test("Filters", () => {
  visit("/users/eviltrout/activity");
  hasStream();

  visit("/users/eviltrout/activity/topics");
  hasTopicList();

  visit("/users/eviltrout/activity/replies");
  hasStream();
});

test("Restricted Routes", () => {
  visit("/users/eviltrout/preferences");

  andThen(() => {
    equal(currentURL(), '/users/eviltrout/activity', "it redirects from preferences");
  });
});
