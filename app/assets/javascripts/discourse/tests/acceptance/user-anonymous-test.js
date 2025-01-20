import { currentRouteName, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("User Anonymous", function () {
  test("Root URL", async function (assert) {
    await visit("/u/eviltrout");

    assert
      .dom(document.body)
      .hasClass("user-summary-page", "has the body class");
    assert.strictEqual(
      currentRouteName(),
      "user.summary",
      "it defaults to summary"
    );
  });

  test("Filters", async function (assert) {
    await visit("/u/eviltrout/activity");
    assert
      .dom(document.body)
      .hasClass("user-activity-page", "has the body class");
    assert.dom(".user-main .about").exists("has the about section");
    assert.dom(".user-stream-item").exists("has stream items");

    await visit("/u/eviltrout/activity/topics");
    assert.dom(".user-stream-item").doesNotExist("has no stream displayed");
    assert.dom(".topic-list tr").exists("has a topic list");

    await visit("/u/eviltrout/activity/replies");
    assert.dom(".user-main .about").exists("has the about section");
    assert.dom(".user-stream-item").exists("has stream items");

    assert.dom(".user-stream.filter-5").exists("stream has filter class");
  });

  test("Badges", async function (assert) {
    await visit("/u/eviltrout/badges");

    assert
      .dom(document.body)
      .hasClass("user-badges-page", "has the body class");
    assert.dom(".badge-group-list .badge-card").exists("shows a badge");
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
