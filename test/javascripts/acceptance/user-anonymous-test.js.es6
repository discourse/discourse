import { acceptance } from "helpers/qunit-helpers";
acceptance("User Anonymous");

function hasStream(assert) {
  andThen(() => {
    assert.ok(exists(".user-main .about"), "it has the about section");
    assert.ok(count(".user-stream .item") > 0, "it has stream items");
  });
}

function hasTopicList(assert) {
  andThen(() => {
    assert.equal(count(".user-stream .item"), 0, "has no stream displayed");
    assert.ok(count(".topic-list tr") > 0, "it has a topic list");
  });
}

QUnit.test("Root URL", assert => {
  visit("/u/eviltrout");
  andThen(() => {
    assert.ok($("body.user-summary-page").length, "has the body class");
    assert.equal(currentPath(), "user.summary", "it defaults to summary");
  });
});

QUnit.test("Filters", assert => {
  visit("/u/eviltrout/activity");
  andThen(() => {
    assert.ok($("body.user-activity-page").length, "has the body class");
  });
  hasStream(assert);

  visit("/u/eviltrout/activity/topics");
  hasTopicList(assert);

  visit("/u/eviltrout/activity/replies");
  hasStream(assert);
});

QUnit.test("Badges", assert => {
  visit("/u/eviltrout/badges");
  andThen(() => {
    assert.ok($("body.user-badges-page").length, "has the body class");
    assert.ok(exists(".user-badges-list .badge-card"), "shows a badge");
  });
});

QUnit.test("Restricted Routes", assert => {
  visit("/u/eviltrout/preferences");

  andThen(() => {
    assert.equal(
      currentURL(),
      "/u/eviltrout/activity",
      "it redirects from preferences"
    );
  });
});
