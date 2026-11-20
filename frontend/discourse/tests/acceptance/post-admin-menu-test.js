import { click, currentURL, find, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Post - Admin Menu - Anonymous", function () {
  test("Enter as a anon user", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".show-more-actions");

    assert.dom("#topic").exists("the topic is rendered");
    assert
      .dom("#post_1 .post-controls .edit")
      .exists("the edit button is not rendered");
    assert
      .dom(".show-post-admin-menu")
      .doesNotExist("the wrench button is not rendered");
  });
});

acceptance("Post - Admin Menu - Authenticated", function (needs) {
  needs.user();
  test("Enter as a user with group moderator permissions", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");
    await click(".show-more-actions");
    await click(".show-post-admin-menu");

    assert
      .dom("#post_1 .post-controls .edit")
      .exists("the edit button is rendered");
    assert.dom(".add-notice").exists("the add notice button is rendered");
  });
});

acceptance("Post - Admin Menu - Staff", function (needs) {
  needs.user({ admin: true, moderator: true });

  test("viewing moderation history closes the menu", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#post_1 .show-more-actions");
    await click("#post_1 .show-post-admin-menu");

    assert.dom(".fk-d-menu").exists("the admin menu is open");
    assert.dom(".moderation-history").exists("the history link is rendered");

    const historyUrl = new URL(find(".moderation-history").href);

    await click(".moderation-history");

    const reviewUrl = new URL(currentURL(), window.location.origin);
    assert.strictEqual(
      reviewUrl.pathname,
      "/review",
      "the review page is open"
    );
    assert.strictEqual(
      reviewUrl.searchParams.get("status"),
      "all",
      "all review statuses are included"
    );
    assert.strictEqual(
      reviewUrl.searchParams.get("topic_id"),
      historyUrl.searchParams.get("topic_id"),
      "the history link's topic filter is preserved"
    );
    assert.dom(".fk-d-menu").doesNotExist("the admin menu has closed");
  });
});
