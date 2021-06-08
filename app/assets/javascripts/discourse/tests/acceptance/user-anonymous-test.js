import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { currentRouteName, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("User Anonymous", function () {
  test("Root URL", async function (assert) {
    await visit("/u/eviltrout");
    assert.ok($("body.user-summary-page").length, "has the body class");
    assert.equal(currentRouteName(), "user.summary", "it defaults to summary");
  });

  test("Filters", async function (assert) {
    await visit("/u/eviltrout/activity");
    assert.ok($("body.user-activity-page").length, "has the body class");
    assert.ok(exists(".user-main .about"), "it has the about section");
    assert.ok(exists(".user-stream .item"), "it has stream items");

    await visit("/u/eviltrout/activity/topics");
    assert.ok(!exists(".user-stream .item"), "has no stream displayed");
    assert.ok(exists(".topic-list tr"), "it has a topic list");

    await visit("/u/eviltrout/activity/replies");
    assert.ok(exists(".user-main .about"), "it has the about section");
    assert.ok(exists(".user-stream .item"), "it has stream items");

    assert.ok(exists(".user-stream.filter-5"), "stream has filter class");
  });

  test("Badges", async function (assert) {
    await visit("/u/eviltrout/badges");
    assert.ok($("body.user-badges-page").length, "has the body class");
    assert.ok(exists(".user-badges-list .badge-card"), "shows a badge");
  });

  test("Restricted Routes", async function (assert) {
    await visit("/u/eviltrout/preferences");

    assert.equal(
      currentURL(),
      "/u/eviltrout/activity",
      "it redirects from preferences"
    );
  });
});
