import { acceptance } from "helpers/qunit-helpers";
acceptance("User Anonymous");

function hasStream(assert) {
  assert.ok(exists(".user-main .about"), "it has the about section");
  assert.ok(count(".user-stream .item") > 0, "it has stream items");
}

function hasTopicList(assert) {
  assert.equal(count(".user-stream .item"), 0, "has no stream displayed");
  assert.ok(count(".topic-list tr") > 0, "it has a topic list");
}

QUnit.test("Root URL", async assert => {
  await visit("/u/eviltrout");
  assert.ok($("body.user-summary-page").length, "has the body class");
  assert.equal(currentPath(), "user.summary", "it defaults to summary");
});

QUnit.test("Filters", async assert => {
  await visit("/u/eviltrout/activity");
  assert.ok($("body.user-activity-page").length, "has the body class");
  hasStream(assert);

  await visit("/u/eviltrout/activity/topics");
  await hasTopicList(assert);

  await visit("/u/eviltrout/activity/replies");
  hasStream(assert);

  assert.ok(exists(".user-stream.filter-5"), "stream has filter class");
});

QUnit.test("Badges", async assert => {
  await visit("/u/eviltrout/badges");
  assert.ok($("body.user-badges-page").length, "has the body class");
  assert.ok(exists(".user-badges-list .badge-card"), "shows a badge");
});

QUnit.test("Restricted Routes", async assert => {
  await visit("/u/eviltrout/preferences");

  assert.equal(
    currentURL(),
    "/u/eviltrout/activity",
    "it redirects from preferences"
  );
});
