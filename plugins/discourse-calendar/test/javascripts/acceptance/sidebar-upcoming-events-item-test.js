import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Calendar - hamburger action shown", function (needs) {
  needs.user();

  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    sidebar_show_upcoming_events: true,
  });

  test("upcoming events hamburger action shown", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='upcoming-events']"
      )
      .exists();
  });
});

acceptance("Discourse Calendar - hamburger action hidden", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    sidebar_show_upcoming_events: false,
    navigation_menu: "legacy",
  });

  test("upcoming events hamburger action hidden", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown");
    assert.dom(".widget-link[title='Upcoming events']").doesNotExist();
  });
});

acceptance("Discourse Calendar - sidebar link shown", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    sidebar_show_upcoming_events: true,
    navigation_menu: "sidebar",
  });

  test("upcoming events sidebar section link shown", async function (assert) {
    await visit("/");
    await click(".sidebar-more-section-links-details-summary");
    assert
      .dom(".sidebar-section-link[data-link-name='upcoming-events']")
      .exists();
  });
});

acceptance("Discourse Calendar - sidebar link hidden", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    sidebar_show_upcoming_events: false,
    navigation_menu: "sidebar",
  });

  test("upcoming events sidebar section link hidden", async function (assert) {
    await visit("/");
    await click(".sidebar-more-section-links-details-summary");
    assert
      .dom(".sidebar-section-link[data-link-name='upcoming-events']")
      .doesNotExist();
  });
});
