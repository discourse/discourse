import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Site from "discourse/models/site";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("User Preferences - Navigation Menu", function (needs) {
  needs.user();

  test("user enabling sidebar_show_count_of_new_items preference", async function (assert) {
    const categories = Site.current().categories;
    const category1 = categories[0];

    updateCurrentUser({
      sidebar_category_ids: [category1.id],
    });

    this.container.lookup("service:topic-tracking-state").loadStates([
      {
        topic_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_at: "2022-05-11T03:09:31.959Z",
        category_id: category1.id,
        notification_level: null,
        created_in_new_period: true,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
    ]);

    await visit("/u/eviltrout/preferences/navigation-menu");

    assert
      .dom(
        '.sidebar-section-link[data-link-name="everything"] .sidebar-section-link-suffix.icon.unread'
      )
      .exists("everything link has a dot before the preference is enabled");
    assert
      .dom(
        `.sidebar-section-link[data-link-name="everything"] .sidebar-section-link-content-badge`
      )
      .doesNotExist(
        "everything link doesn't have badge text before the preference is enabled"
      );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-suffix.icon.unread`
      )
      .exists("category1 has a dot before the preference is enabled");
    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-content-badge`
      )
      .doesNotExist(
        "category1 doesn't have badge text before the preference is enabled"
      );

    await click(
      ".preferences-navigation-menu-navigation .pref-show-count-new-items input"
    );
    await click(".save-changes");

    assert
      .dom(
        '.sidebar-section-link[data-link-name="everything"] .sidebar-section-link-suffix.icon.unread'
      )
      .doesNotExist(
        "everything link no longer has a dot after the preference is enabled"
      );
    assert
      .dom(
        `.sidebar-section-link[data-link-name="everything"] .sidebar-section-link-content-badge`
      )
      .hasText(
        i18n("sidebar.new_count", { count: 1 }),
        "everything link now has badge text after the preference is enabled"
      );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-suffix.icon.unread`
      )
      .doesNotExist(
        "category1 doesn't have a dot anymore after the preference is enabled"
      );
    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-content-badge`
      )
      .hasText(
        i18n("sidebar.new_count", { count: 1 }),
        "category1 now has badge text after the preference is enabled"
      );
  });

  test("user enabling sidebar_link_to_filtered_list preference", async function (assert) {
    const categories = Site.current().categories;
    const category1 = categories[0];

    updateCurrentUser({
      sidebar_category_ids: [category1.id],
    });

    this.container.lookup("service:topic-tracking-state").loadStates([
      {
        topic_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_at: "2022-05-11T03:09:31.959Z",
        category_id: category1.id,
        notification_level: null,
        created_in_new_period: true,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
    ]);

    await visit("/u/eviltrout/preferences/navigation-menu");

    assert
      .dom('.sidebar-section-link[data-link-name="everything"]')
      .hasAttribute(
        "href",
        "/latest",
        "everything link's href is the latest topics list before the preference is enabled"
      );
    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link`
      )
      .hasAttribute(
        "href",
        "/c/meta/3",
        "category1's link href is the latest topics list of the category before the preference is enabled"
      );

    await click(
      ".preferences-navigation-menu-navigation .pref-link-to-filtered-list input"
    );
    await click(".save-changes");

    assert
      .dom('.sidebar-section-link[data-link-name="everything"]')
      .hasAttribute(
        "href",
        "/new",
        "everything link's href is the new topics list after the preference is enabled"
      );
    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link`
      )
      .hasAttribute(
        "href",
        "/c/meta/3/l/new",
        "category1's link href is the new topics list of the category after the preference is enabled"
      );
  });
});
