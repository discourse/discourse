import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import Site from "discourse/models/site";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Calendar - Disable sorting headers", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    disable_resorting_on_categories_enabled: true,
  });

  test("visiting a category page", async function (assert) {
    const site = Site.current();
    site.categories[15].custom_fields = { disable_topic_resorting: true };

    await visit("/c/bug");
    assert.dom(".topic-list").exists("The list of topics was rendered");
    assert
      .dom(".topic-list .topic-list-data")
      .exists("The headers were rendered");
    assert
      .dom(".topic-list")
      .doesNotHaveClass("sortable", "The headers are not sortable");
  });
});
