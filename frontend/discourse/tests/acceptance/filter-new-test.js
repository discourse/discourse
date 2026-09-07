import { click, currentURL, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Filter unified New", function (needs) {
  needs.user({ unified_new_enabled: true });
  needs.pretender((server, helper) => {
    server.get("/filter.json", () =>
      helper.response({
        topic_list: {
          can_create_topic: true,
          topics: [],
          filter_option_info: [],
          filter_new_topic_ids: [90001, 90002],
        },
      })
    );
  });

  test("navigates All, New and subsets while preserving the filter", async function (assert) {
    await visit("/filter?q=category%3Abug%20status%3Aopen");
    const tracking = this.container.lookup("service:topic-tracking-state");
    tracking.states.clear();
    tracking.loadStates([
      {
        topic_id: 90001,
        category_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_in_new_period: true,
      },
      {
        topic_id: 90002,
        category_id: 1,
        last_read_post_number: 1,
        highest_post_number: 2,
        notification_level: 2,
      },
      {
        topic_id: 90003,
        category_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_in_new_period: true,
      },
    ]);
    await settled();
    assert
      .dom('[data-filter-view="all"]')
      .hasClass("active", "All is initially active");
    assert
      .dom('[data-filter-view="new"]')
      .hasText(
        "New (2)",
        "counts matching states beyond the empty loaded page"
      );
    assert
      .dom(".topics-replies-toggle")
      .doesNotExist("subsets are hidden in All");

    await click('[data-filter-view="new"]');
    assert.strictEqual(
      new URL(currentURL(), "https://example.com").searchParams.get("q"),
      "category:bug status:open in:new",
      "New preserves the base query"
    );
    assert
      .dom(".topics-replies-toggle.--all")
      .hasAttribute("aria-pressed", "true", "New All is selected");
    assert
      .dom(".topics-replies-toggle.--topics")
      .hasText("Topics (1)", "shows scoped new count");
    assert
      .dom(".topics-replies-toggle.--replies")
      .hasText("Replies (1)", "shows scoped unread count");

    await click(".topics-replies-toggle.--replies");
    assert.strictEqual(
      new URL(currentURL(), "https://example.com").searchParams.get("q"),
      "category:bug status:open in:new-replies",
      "Replies replaces the selector"
    );
    assert
      .dom(".topics-replies-toggle.--replies")
      .hasClass("active", "Replies is selected even for an empty list");
    await click('[data-filter-view="all"]');
    assert.strictEqual(
      new URL(currentURL(), "https://example.com").searchParams.get("q"),
      "category:bug status:open",
      "All removes only the selector"
    );
  });

  test("recognizes a direct subset URL", async function (assert) {
    await visit("/filter?q=status%3Aopen%20in%3Anew-topics");
    assert.dom('[data-filter-view="new"]').hasClass("active", "New is active");
    assert
      .dom(".topics-replies-toggle.--topics")
      .hasClass("active", "Topics is active");
  });
});

acceptance("Filter unified New disabled", function (needs) {
  needs.user({ unified_new_enabled: false });
  needs.pretender((server, helper) => {
    server.get("/filter.json", () =>
      helper.response({ topic_list: { topics: [] } })
    );
  });

  test("keeps the existing filter UI", async function (assert) {
    await visit("/filter?q=in%3Anew");
    assert
      .dom(".filter-new-navigation")
      .doesNotExist("navigation is gated by the user flag");
  });
});
