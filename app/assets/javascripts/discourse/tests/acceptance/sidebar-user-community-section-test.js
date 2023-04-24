import I18n from "I18n";
import { skip, test } from "qunit";
import {
  click,
  currentRouteName,
  currentURL,
  visit,
} from "@ember/test-helpers";
import {
  acceptance,
  count,
  exists,
  loggedInUser,
  publishToMessageBus,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import topicFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { cloneJSON } from "discourse-common/lib/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import { NotificationLevels } from "discourse/lib/notification-levels";

acceptance("Sidebar - Logged on user - Community Section", function (needs) {
  needs.user({
    tracked_tags: ["tag1"],
    watched_tags: ["tag2"],
    watching_first_post_tags: ["tag3"],
    sidebar_sections: [
      {
        id: 111,
        title: "Community",
        links: [
          {
            id: 329,
            name: "Everything",
            value: "/latest",
            icon: "layer-group",
            external: false,
            segment: "primary",
          },
          {
            id: 330,
            name: "Users",
            value: "/u",
            icon: "users",
            external: false,
            segment: "secondary",
          },
          {
            id: 331,
            name: "Info",
            value: "/about",
            icon: "info-circle",
            external: false,
            segment: "secondary",
          },
          {
            id: 332,
            name: "Faq",
            value: "/faq",
            icon: "question-circle",
            external: false,
            segment: "secondary",
          },
          {
            id: 333,
            name: "My Posts",
            value: "/my/activity",
            icon: "user",
            external: false,
            segment: "primary",
          },
          {
            id: 334,
            name: "Review",
            value: "/review",
            icon: "flag",
            external: false,
            segment: "secondary",
          },
          {
            id: 335,
            name: "Admin",
            value: "/admin",
            icon: "wrench",
            external: false,
            segment: "primary",
          },
          {
            id: 336,
            name: "Groups",
            value: "/g",
            icon: "user-friends",
            external: false,
            segment: "secondary",
          },
          {
            id: 337,
            name: "Badges",
            value: "/badges",
            icon: "certificate",
            external: false,
            segment: "secondary",
          },
        ],
        slug: "community",
        public: true,
        system: true,
      },
    ],
  });

  needs.settings({
    navigation_menu: "sidebar",
  });

  needs.pretender((server, helper) => {
    server.get("/new.json", () => {
      return helper.response(cloneJSON(topicFixtures["/latest.json"]));
    });

    server.get("/unread.json", () => {
      return helper.response(cloneJSON(topicFixtures["/latest.json"]));
    });

    server.get("/top.json", () => {
      return helper.response(cloneJSON(topicFixtures["/latest.json"]));
    });
  });

  test("clicking on section header button", async function (assert) {
    await visit("/");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-header-button"
    );

    assert.ok(exists("#reply-control"), "it opens the composer");
  });

  test("clicking on section header button while viewing a category", async function (assert) {
    await visit("/c/bug");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-header-button"
    );

    assert.ok(exists("#reply-control"), "it opens the composer");

    assert.strictEqual(
      query(".category-input .selected-name .category-name").textContent,
      "bug",
      "the current category is prefilled in the composer input"
    );
  });

  test("clicking on section header link", async function (assert) {
    await visit("/t/280");

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-content"
      ),
      "shows content section"
    );

    assert.strictEqual(
      query(
        ".sidebar-section[data-section-name='community'] .sidebar-section-header"
      ).title,
      I18n.t("sidebar.toggle_section"),
      "caret has the right title"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-header"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-content"
      ),
      "hides the content of the section"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-header"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-content"
      ),
      "shows content section"
    );
  });

  // TODO(tgxworld): Flaky probably due to assertions running before event listener callbacks have completed.
  skip("clicking on more... link", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content"
      ),
      "additional section links are displayed"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content"
      ),
      "additional section links are hidden"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    await click("#main-outlet");

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content"
      ),
      "additional section links are hidden when clicking outside"
    );
  });

  test("clicking on everything link", async function (assert) {
    await visit("/t/280");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
    );

    assert.strictEqual(
      currentURL(),
      "/latest",
      "it should transition to the latest page"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      ),
      "the everything link is marked as active"
    );
  });

  test("clicking on everything link - sidebar_list_destination set to unread/new and no unread or new topics", async function (assert) {
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
    });

    await visit("/t/280");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
    );
    assert.strictEqual(
      currentURL(),
      "/latest",
      "it should transition to the latest page"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      ),
      "the everything link is marked as active"
    );
  });

  test("clicking on everything link - sidebar_list_destination set to unread/new with new topics", async function (assert) {
    const topicTrackingState = this.container.lookup(
      "service:topic-tracking-state"
    );
    topicTrackingState.states.set("t112", {
      last_read_post_number: null,
      id: 112,
      notification_level: NotificationLevels.TRACKING,
      category_id: 2,
      created_in_new_period: true,
    });
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
    });
    await visit("/t/280");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
    );

    assert.strictEqual(
      currentURL(),
      "/new",
      "it should transition to the new page"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      ),
      "the everything link is marked as active"
    );
  });

  test("clicking on everything link - sidebar_list_destination set to unread/new with new and unread topics", async function (assert) {
    const topicTrackingState = this.container.lookup(
      "service:topic-tracking-state"
    );
    topicTrackingState.states.set("t112", {
      last_read_post_number: null,
      id: 112,
      notification_level: NotificationLevels.TRACKING,
      category_id: 2,
      created_in_new_period: true,
    });
    topicTrackingState.states.set("t113", {
      last_read_post_number: 1,
      highest_post_number: 2,
      id: 113,
      notification_level: NotificationLevels.TRACKING,
      category_id: 2,
      created_in_new_period: true,
    });
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
    });
    await visit("/t/280");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
    );

    assert.strictEqual(
      currentURL(),
      "/unread",
      "it should transition to the unread page"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      ),
      "the everything link is marked as active"
    );
  });

  test("clicking on users link", async function (assert) {
    await visit("/t/280");

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users']"
      ),
      "users link is not displayed in sidebar when it is not the active route"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users']"
    );

    assert.strictEqual(
      currentURL(),
      "/u?order=likes_received",
      "it should transition to the users url"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users'].active"
      ),
      "the users link is marked as active"
    );

    assert.strictEqual(
      query(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
      ).textContent.trim(),
      I18n.t("sidebar.more"),
      "displays the right count as users link is currently active"
    );

    await visit("/u");

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users'].active"
      ),
      "users link is displayed in sidebar when it is the active route"
    );
  });

  test("users section link is not shown when enable_user_directory site setting is disabled", async function (assert) {
    this.siteSettings.enable_user_directory = false;

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users']"
      ),
      "users section link is not displayed in sidebar"
    );
  });

  test("clicking on badges link", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='badges']"
    );

    assert.strictEqual(
      currentURL(),
      "/badges",
      "it should transition to the badges url"
    );
  });

  test("badges section link is not shown when badges has been disabled", async function (assert) {
    this.siteSettings.enable_badges = false;

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='badges']"
      ),
      "badges section link is not shown in sidebar"
    );
  });

  test("clicking on groups link", async function (assert) {
    await visit("/t/280");

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='groups']"
      ),
      "groups link is not displayed in sidebar when it is not the active route"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='groups']"
    );

    assert.strictEqual(
      currentURL(),
      "/g",
      "it should transition to the groups url"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='groups'].active"
      ),
      "the groups link is marked as active"
    );

    assert.strictEqual(
      query(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
      ).textContent.trim(),
      I18n.t("sidebar.more"),
      "displays the right count as groups link is currently active"
    );

    await visit("/g");

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='groups'].active"
      ),
      "groups link is displayed in sidebar when it is the active route"
    );
  });

  test("groups section link is not shown when enable_group_directory site setting has been disabled", async function (assert) {
    this.siteSettings.enable_group_directory = false;

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='groups']"
      ),
      "groups section link is not shown in sidebar"
    );
  });

  test("navigating to about from sidebar", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='about']"
    );

    assert.strictEqual(
      currentURL(),
      "/about",
      "navigates to about route correctly"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='about'].active"
      ),
      "about section link link is displayed in the main section and marked as active"
    );
  });

  test("navigating to FAQ from sidebar", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='faq']"
    );

    assert.strictEqual(
      currentURL(),
      "/faq",
      "navigates to faq route correctly"
    );
  });

  test("navigating to custom FAQ URL from sidebar", async function (assert) {
    this.siteSettings.faq_url = "http://some.faq.url";

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.strictEqual(
      query(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='faq']"
      ).href,
      "http://some.faq.url/",
      "href attribute is set to custom FAQ URL on the section link"
    );
  });

  test("navigating to admin from sidebar", async function (assert) {
    await visit("/");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='admin']"
    );

    assert.strictEqual(currentRouteName(), "admin.dashboard.general");
  });

  test("admin section link is not shown to non-staff users", async function (assert) {
    updateCurrentUser({ admin: false, moderator: false });

    await visit("/");

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='admin']"
      )
    );
  });

  test("clicking on my posts link", async function (assert) {
    await visit("/t/280");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts']"
    );

    assert.strictEqual(
      currentURL(),
      `/u/${loggedInUser().username}/activity`,
      "it should transition to the user's activity url"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts'].active"
      ),
      "the my posts link is marked as active"
    );

    await visit(`/u/${loggedInUser().username}/activity/drafts`);

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts'].active"
      ),
      "the my posts link is not marked as active when user has no drafts and visiting the user activity drafts URL"
    );
  });

  test("clicking on my posts link when user has a draft", async function (assert) {
    await visit("/t/280");

    await publishToMessageBus(`/user-drafts/${loggedInUser().id}`, {
      draft_count: 1,
    });

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts']"
    );

    assert.strictEqual(
      currentURL(),
      `/u/${loggedInUser().username}/activity/drafts`,
      "it transitions to the user's activity drafts url"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts'].active"
      ),
      "the my posts link is marked as active"
    );

    await visit(`/u/${loggedInUser().username}/activity`);

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts'].active"
      ),
      "the my posts link is marked as active"
    );
  });

  test("my posts title changes when drafts are present", async function (assert) {
    await visit("/");

    assert.strictEqual(
      query(".sidebar-section-link[data-link-name='my-posts']").title,
      I18n.t("sidebar.sections.community.links.my_posts.title"),
      "displays the default title when no drafts are present"
    );

    await publishToMessageBus(`/user-drafts/${loggedInUser().id}`, {
      draft_count: 1,
    });

    assert.strictEqual(
      query(".sidebar-section-link[data-link-name='my-posts']").title,
      I18n.t("sidebar.sections.community.links.my_posts.title_drafts"),
      "displays the draft title when drafts are present"
    );
  });

  test("my posts changes its text when drafts are present and new new view experiment is enabled", async function (assert) {
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
      new_new_view_enabled: true,
    });
    await visit("/");

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='my-posts']"
      ).textContent.trim(),
      I18n.t("sidebar.sections.community.links.my_posts.content"),
      "displays the default text when no drafts are present"
    );

    await publishToMessageBus(`/user-drafts/${loggedInUser().id}`, {
      draft_count: 1,
    });

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='my-posts'] .sidebar-section-link-content-text"
      ).textContent.trim(),
      I18n.t("sidebar.sections.community.links.my_posts.content_drafts"),
      "displays the text that's appropriate for when drafts are present"
    );
    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='my-posts'] .sidebar-section-link-content-badge"
      ).textContent.trim(),
      "1",
      "displays the draft count with no text"
    );
  });

  test("visiting top route", async function (assert) {
    await visit("/top");

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      ),
      "the everything link is marked as active"
    );
  });

  test("visiting unread route", async function (assert) {
    await visit("/unread");

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      ),
      "the everything link is marked as active"
    );
  });

  test("visiting new route", async function (assert) {
    await visit("/new");

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      ),
      "the everything link is marked as active"
    );
  });

  test("show suffix indicator for unread and new content on everything link", async function (assert) {
    updateCurrentUser({
      sidebar_list_destination: "default",
    });

    this.container.lookup("service:topic-tracking-state").loadStates([
      {
        topic_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_at: "2022-05-11T03:09:31.959Z",
        category_id: 1,
        notification_level: null,
        created_in_new_period: true,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 2,
        highest_post_number: 12,
        last_read_post_number: 11,
        created_at: "2020-02-09T09:40:02.672Z",
        category_id: 2,
        notification_level: 2,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
    ]);

    await visit("/");

    assert.ok(
      exists(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-suffix"
      ),
      "shows suffix indicator for unread posts on everything link"
    );

    // simulate reading topic 2
    await publishToMessageBus("/unread", {
      topic_id: 2,
      message_type: "read",
      payload: {
        last_read_post_number: 12,
        highest_post_number: 12,
        notification_level: 2,
      },
    });

    assert.ok(
      exists(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-suffix"
      ),
      "shows suffix indicator for new topics on categories link"
    );

    // simulate reading topic 1
    await publishToMessageBus("/unread", {
      topic_id: 1,
      message_type: "read",
      payload: {
        last_read_post_number: 1,
        highest_post_number: 1,
        notification_level: 2,
      },
    });

    assert.ok(
      !exists(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-suffix"
      ),
      "it removes the suffix indicator when all topics are read"
    );
  });

  test("new and unread count for everything link", async function (assert) {
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
    });

    this.container.lookup("service:topic-tracking-state").loadStates([
      {
        topic_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_at: "2022-05-11T03:09:31.959Z",
        category_id: 1,
        notification_level: null,
        created_in_new_period: true,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 2,
        highest_post_number: 12,
        last_read_post_number: 11,
        created_at: "2020-02-09T09:40:02.672Z",
        category_id: 2,
        notification_level: 2,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 3,
        highest_post_number: 15,
        last_read_post_number: 14,
        created_at: "2021-06-14T12:41:02.477Z",
        category_id: 3,
        notification_level: 2,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 4,
        highest_post_number: 17,
        last_read_post_number: 16,
        created_at: "2020-10-31T03:41:42.257Z",
        category_id: 4,
        notification_level: 2,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
    ]);

    await visit("/");

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-content-badge"
      ).textContent.trim(),
      "3 unread",
      "it displays the right unread count"
    );

    // simulate reading topic 2
    await publishToMessageBus("/unread", {
      topic_id: 2,
      message_type: "read",
      payload: {
        last_read_post_number: 12,
        highest_post_number: 12,
        notification_level: 2,
      },
    });

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-content-badge"
      ).textContent.trim(),
      "2 unread",
      "it updates the unread count"
    );

    // simulate reading topic 3
    await publishToMessageBus("/unread", {
      topic_id: 3,
      message_type: "read",
      payload: {
        last_read_post_number: 15,
        highest_post_number: 15,
        notification_level: 2,
      },
    });

    // simulate reading topic 4
    await publishToMessageBus("/unread", {
      topic_id: 4,
      message_type: "read",
      payload: {
        last_read_post_number: 17,
        highest_post_number: 17,
        notification_level: 2,
      },
    });

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-content-badge"
      ).textContent.trim(),
      "1 new",
      "it displays the new count once there are no unread topics"
    );

    await publishToMessageBus("/unread", {
      topic_id: 1,
      message_type: "read",
      payload: {
        last_read_post_number: 1,
        highest_post_number: 1,
        notification_level: 2,
      },
    });

    assert.ok(
      !exists(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-content-badge"
      ),
      "it removes new count once there are no new topics"
    );
  });

  test("review link is not shown when user cannot review", async function (assert) {
    updateCurrentUser({ can_review: false, reviewable_count: 0 });

    await visit("/");

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review']"
      ),
      "review link is not shown"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review']"
      ),
      "review link is not shown"
    );
  });

  test("review link when user can review", async function (assert) {
    updateCurrentUser({
      can_review: true,
      reviewable_count: 0,
    });

    await visit("/reivew");

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review'].active"
      ),
      "review link is shown as active when visiting the review route even if there are no pending reviewables"
    );

    await visit("/");

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review']"
      ),
      "review link is not shown as part of the main section links"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content .sidebar-section-link[data-link-name='review']"
      ),
      "review link is displayed in the more drawer"
    );

    await publishToMessageBus("/reviewable_counts", {
      reviewable_count: 34,
    });

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review']"
      ),
      "review link is shown as part of the main section links"
    );

    assert.strictEqual(
      query(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review'] .sidebar-section-link-content-badge"
      ).textContent.trim(),
      "34 pending",
      "displays the pending reviewable count"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content .sidebar-section-link[data-link-name='review']"
      ),
      "review link is not displayed in the more drawer"
    );
  });

  test("adding section link via plugin API with Object", async function (assert) {
    withPluginApi("1.2.0", (api) => {
      api.addCommunitySectionLink({
        name: "unread",
        route: "discovery.unread",
        text: "unread topics",
        title: "List of unread topics",
      });
    });

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='unread']"
      ).textContent.trim(),
      "unread topics",
      "displays the right text for the link"
    );

    assert.strictEqual(
      query(".sidebar-section-link[data-link-name='unread']").title,
      "List of unread topics",
      "displays the right title for the link"
    );

    await click(".sidebar-section-link[data-link-name='unread']");

    assert.strictEqual(currentURL(), "/unread", "links to the right URL");
  });

  test("adding section link via plugin API with callback function", async function (assert) {
    let teardownCalled = false;

    withPluginApi("1.2.0", (api) => {
      api.addCommunitySectionLink((baseSectionLink) => {
        return class CustomSectionLink extends baseSectionLink {
          get name() {
            return "user-summary";
          }

          get route() {
            return "user.summary";
          }

          get model() {
            return this.currentUser;
          }

          get title() {
            return `${this.currentUser.username} summary`;
          }

          get text() {
            return "my summary";
          }

          get teardown() {
            teardownCalled = true;
          }
        };
      });
    });

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    await click(".sidebar-section-link[data-link-name='user-summary']");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/summary",
      "links to the right URL"
    );

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='user-summary']"
      ).textContent.trim(),
      "my summary",
      "displays the right text for the link"
    );

    assert.strictEqual(
      query(".sidebar-section-link[data-link-name='user-summary']").title,
      "eviltrout summary",
      "displays the right title for the link"
    );

    await click(".btn-sidebar-toggle");

    assert.ok(teardownCalled, "section link teardown callback was called");
  });
});

acceptance(
  "Sidebar - Logged on user - Community Section - New new view experiment enabled",
  function (needs) {
    needs.user({
      new_new_view_enabled: true,
      sidebar_sections: [
        {
          id: 111,
          title: "Community",
          links: [
            {
              id: 329,
              name: "Everything",
              value: "/latest",
              icon: "layer-group",
              external: false,
              segment: "primary",
            },
            {
              id: 330,
              name: "Users",
              value: "/u",
              icon: "users",
              external: false,
              segment: "secondary",
            },
            {
              id: 331,
              name: "Info",
              value: "/u",
              icon: "info-circle",
              external: false,
              segment: "secondary",
            },
            {
              id: 332,
              name: "Faq",
              value: "/u",
              icon: "question-circle",
              external: false,
              segment: "secondary",
            },
            {
              id: 333,
              name: "My Posts",
              value: "/my/activity",
              icon: "user",
              external: false,
              segment: "primary",
            },
            {
              id: 334,
              name: "Review",
              value: "/review",
              icon: "flag",
              external: false,
              segment: "secondary",
            },
            {
              id: 335,
              name: "Admin",
              value: "/admin",
              icon: "wrench",
              external: false,
              segment: "primary",
            },
            {
              id: 336,
              name: "Groups",
              value: "/g",
              icon: "user-friends",
              external: false,
              segment: "secondary",
            },
            {
              id: 337,
              name: "Badges",
              value: "/badges",
              icon: "certificate",
              external: false,
              segment: "secondary",
            },
          ],
          slug: "community",
          public: true,
          system: true,
        },
      ],
    });

    needs.settings({
      navigation_menu: "sidebar",
    });

    test("count shown next to the everything link", async function (assert) {
      this.container.lookup("service:topic-tracking-state").loadStates([
        {
          topic_id: 1,
          highest_post_number: 1,
          last_read_post_number: null,
          created_at: "2022-05-11T03:09:31.959Z",
          category_id: 1,
          notification_level: null,
          created_in_new_period: true,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
        {
          topic_id: 2,
          highest_post_number: 12,
          last_read_post_number: 11,
          created_at: "2020-02-09T09:40:02.672Z",
          category_id: 2,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
        {
          topic_id: 3,
          highest_post_number: 12,
          last_read_post_number: 12,
          created_at: "2020-02-09T09:40:02.672Z",
          category_id: 2,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
      ]);

      await visit("/");

      assert.strictEqual(
        query(
          ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'] .sidebar-section-link-content-badge"
        ).textContent.trim(),
        "2",
        "count is 2 because there's 1 unread topic and 1 new topic"
      );
    });

    test("everything link href", async function (assert) {
      this.container.lookup("service:topic-tracking-state").loadStates([
        {
          topic_id: 1,
          highest_post_number: 1,
          last_read_post_number: null,
          created_at: "2022-05-11T03:09:31.959Z",
          category_id: 1,
          notification_level: null,
          created_in_new_period: true,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
        {
          topic_id: 2,
          highest_post_number: 12,
          last_read_post_number: 11,
          created_at: "2020-02-09T09:40:02.672Z",
          category_id: 2,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
      ]);

      await visit("/");

      assert.true(
        query(
          ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
        ).href.endsWith("/new"),
        "links to /new because there are 1 new and 1 unread topics"
      );

      await publishToMessageBus("/unread", {
        topic_id: 1,
        message_type: "read",
        payload: {
          last_read_post_number: 3,
          highest_post_number: 3,
        },
      });

      assert.true(
        query(
          ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
        ).href.endsWith("/new"),
        "links to /new because there is 1 unread topic"
      );

      await publishToMessageBus("/unread", {
        topic_id: 2,
        message_type: "read",
        payload: {
          last_read_post_number: 12,
          highest_post_number: 12,
        },
      });

      assert.true(
        query(
          ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
        ).href.endsWith("/latest"),
        "links to /latest because there are no unread or new topics"
      );

      await publishToMessageBus("/unread", {
        topic_id: 1,
        message_type: "read",
        payload: {
          last_read_post_number: null,
          highest_post_number: 34,
        },
      });

      assert.true(
        query(
          ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
        ).href.endsWith("/new"),
        "links to /new because there is 1 new topic"
      );
    });
  }
);
