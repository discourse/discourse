import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { currentRouteName, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("User Anonymous", function () {
  test("Root URL", async function (assert) {
    await visit("/u/eviltrout");

    assert.ok(
      document.body.classList.contains("user-summary-page"),
      "has the body class"
    );
    assert.strictEqual(
      currentRouteName(),
      "user.summary",
      "it defaults to summary"
    );
  });

  test("Filters", async function (assert) {
    await visit("/u/eviltrout/activity");
    assert.ok(
      document.body.classList.contains("user-activity-page"),
      "has the body class"
    );
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

    assert.ok(
      document.body.classList.contains("user-badges-page"),
      "has the body class"
    );
    assert.ok(exists(".badge-group-list .badge-card"), "shows a badge");
  });

  test("Restricted Routes", async function (assert) {
    await visit("/u/eviltrout/preferences");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/activity",
      "it redirects from preferences"
    );
  });
});
