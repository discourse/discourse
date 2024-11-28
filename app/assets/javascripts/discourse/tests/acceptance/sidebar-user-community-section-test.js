import {
  click,
  currentRouteName,
  currentURL,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { withPluginApi } from "discourse/lib/plugin-api";
import topicFixtures from "discourse/tests/fixtures/discovery-fixtures";
import {
  acceptance,
  loggedInUser,
  publishToMessageBus,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

acceptance("Sidebar - Logged on user - Community Section", function (needs) {
  needs.user({
    tracked_tags: ["tag1"],
    watched_tags: ["tag2"],
    watching_first_post_tags: ["tag3"],
    admin: false,
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

  test("clicking on more... link", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content"
      )
      .exists("additional section links are displayed");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary[aria-expanded='true']"
      )
      .exists(
        "aria-expanded toggles to true when additional links are displayed"
      );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content"
      )
      .doesNotExist("additional section links are hidden");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    await click("#main-outlet");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content"
      )
      .doesNotExist(
        "additional section links are hidden when clicking outside"
      );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary[aria-expanded='false']"
      )
      .exists(
        "aria-expanded toggles to false when additional links are hidden"
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
      "should transition to the latest page"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      )
      .exists("the everything link is marked as active");
  });

  test("clicking on everything link - sidebar_link_to_filtered_list set to true and no unread or new topics", async function (assert) {
    updateCurrentUser({
      user_option: {
        sidebar_link_to_filtered_list: true,
      },
    });

    await visit("/t/280");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
    );
    assert.strictEqual(
      currentURL(),
      "/latest",
      "should transition to the latest page"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      )
      .exists("the everything link is marked as active");
  });

  test("clicking on everything link - sidebar_link_to_filtered_list set to true with new topics", async function (assert) {
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
      user_option: {
        sidebar_link_to_filtered_list: true,
      },
    });
    await visit("/t/280");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
    );

    assert.strictEqual(
      currentURL(),
      "/new",
      "should transition to the new page"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      )
      .exists("the everything link is marked as active");
  });

  test("clicking on everything link - sidebar_link_to_filtered_list set to true with new and unread topics", async function (assert) {
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
      user_option: {
        sidebar_link_to_filtered_list: true,
      },
    });
    await visit("/t/280");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything']"
    );

    assert.strictEqual(
      currentURL(),
      "/unread",
      "should transition to the unread page"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      )
      .exists("the everything link is marked as active");
  });

  test("clicking on users link", async function (assert) {
    await visit("/t/280");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users']"
      )
      .doesNotExist(
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
      "should transition to the users url"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users'].active"
      )
      .exists("the users link is marked as active");

    assert.strictEqual(
      query(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary .sidebar-section-link-content-text"
      ).textContent.trim(),
      i18n("sidebar.more"),
      "displays the right count as users link is currently active"
    );

    await visit("/u");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users'].active"
      )
      .exists("users link is displayed in sidebar when it is the active route");
  });

  test("users section link is not shown when enable_user_directory site setting is disabled", async function (assert) {
    this.siteSettings.enable_user_directory = false;

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users']"
      )
      .doesNotExist("users section link is not displayed in sidebar");
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
      "should transition to the badges url"
    );
  });

  test("badges section link is not shown when badges has been disabled", async function (assert) {
    this.siteSettings.enable_badges = false;

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='badges']"
      )
      .doesNotExist("badges section link is not shown in sidebar");
  });

  test("clicking on groups link", async function (assert) {
    await visit("/t/280");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='groups']"
      )
      .doesNotExist(
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
      "should transition to the groups url"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='groups'].active"
      )
      .exists("the groups link is marked as active");

    assert.strictEqual(
      query(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary .sidebar-section-link-content-text"
      ).textContent.trim(),
      i18n("sidebar.more"),
      "displays the right count as groups link is currently active"
    );

    await visit("/g");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='groups'].active"
      )
      .exists(
        "groups link is displayed in sidebar when it is the active route"
      );
  });

  test("groups section link is not shown when enable_group_directory site setting has been disabled", async function (assert) {
    this.siteSettings.enable_group_directory = false;

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='groups']"
      )
      .doesNotExist("groups section link is not shown in sidebar");
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

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='about'].active"
      )
      .exists(
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

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='faq']"
      )
      .hasAttribute(
        "href",
        "http://some.faq.url",
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

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='admin']"
      )
      .doesNotExist();
  });

  test("clicking on my posts link", async function (assert) {
    await visit("/t/280");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts']"
    );

    assert.strictEqual(
      currentURL(),
      `/u/${loggedInUser().username}/activity`,
      "should transition to the user's activity url"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts'].active"
      )
      .exists("the my posts link is marked as active");

    await visit(`/u/${loggedInUser().username}/activity/drafts`);

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts'].active"
      )
      .doesNotExist(
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
      "transitions to the user's activity drafts url"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts'].active"
      )
      .exists("the my posts link is marked as active");

    await visit(`/u/${loggedInUser().username}/activity`);

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-posts'].active"
      )
      .exists("the my posts link is marked as active");
  });

  test("my posts title changes when drafts are present", async function (assert) {
    await visit("/");

    assert
      .dom(".sidebar-section-link[data-link-name='my-posts']")
      .hasAttribute(
        "title",
        i18n("sidebar.sections.community.links.my_posts.title"),
        "displays the default title when no drafts are present"
      );

    await publishToMessageBus(`/user-drafts/${loggedInUser().id}`, {
      draft_count: 1,
    });

    assert
      .dom(".sidebar-section-link[data-link-name='my-posts']")
      .hasAttribute(
        "title",
        i18n("sidebar.sections.community.links.my_posts.title_drafts"),
        "displays the draft title when drafts are present"
      );
  });

  test("my posts changes its text when drafts are present and new new view experiment is enabled", async function (assert) {
    updateCurrentUser({
      user_option: {
        sidebar_show_count_of_new_items: true,
      },
      new_new_view_enabled: true,
    });
    await visit("/");

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='my-posts']"
      ).textContent.trim(),
      i18n("sidebar.sections.community.links.my_posts.content"),
      "displays the default text when no drafts are present"
    );

    await publishToMessageBus(`/user-drafts/${loggedInUser().id}`, {
      draft_count: 1,
    });

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='my-posts'] .sidebar-section-link-content-text"
      ).textContent.trim(),
      i18n("sidebar.sections.community.links.my_posts.content_drafts"),
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

  test("the invite section link is not visible to people who cannot invite to the forum", async function (assert) {
    updateCurrentUser({ can_invite_to_forum: false });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='invite']"
      )
      .doesNotExist("invite section link is not visible");
  });

  test("clicking the invite section link opens the invite modal and doesn't change the route", async function (assert) {
    updateCurrentUser({ can_invite_to_forum: true });

    await visit("/");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='invite']"
    );

    assert.dom(".create-invite-modal").exists("invite modal is open");
    assert.strictEqual(currentURL(), "/", "route doesn't change");
  });

  test("visiting top route", async function (assert) {
    await visit("/top");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      )
      .exists("the everything link is marked as active");
  });

  test("visiting unread route", async function (assert) {
    await visit("/unread");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      )
      .exists("the everything link is marked as active");
  });

  test("visiting new route", async function (assert) {
    await visit("/new");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='everything'].active"
      )
      .exists("the everything link is marked as active");
  });

  test("show suffix indicator for unread and new content on everything link", async function (assert) {
    updateCurrentUser({
      user_option: {
        sidebar_show_count_of_new_items: false,
      },
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

    assert
      .dom(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-suffix"
      )
      .exists("shows suffix indicator for unread posts on everything link");

    const topicTrackingState = this.container.lookup(
      "service:topic-tracking-state"
    );

    const initialCallbackCount = Object.keys(
      topicTrackingState.stateChangeCallbacks
    ).length;

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

    assert
      .dom(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-suffix"
      )
      .exists("shows suffix indicator for new topics on categories link");

    assert.strictEqual(
      Object.keys(topicTrackingState.stateChangeCallbacks).length,
      initialCallbackCount,
      "does not add a new topic tracking state callback when the topic is read"
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

    assert
      .dom(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-suffix"
      )
      .doesNotExist("removes the suffix indicator when all topics are read");
  });

  test("new and unread count for everything link", async function (assert) {
    updateCurrentUser({
      user_option: {
        sidebar_show_count_of_new_items: true,
      },
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
      "displays the right unread count"
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
      "updates the unread count"
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
      "displays the new count once there are no unread topics"
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

    assert
      .dom(
        ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-content-badge"
      )
      .doesNotExist("removes new count once there are no new topics");
  });

  test("review link is not shown when user cannot review", async function (assert) {
    updateCurrentUser({ can_review: false, reviewable_count: 0 });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review']"
      )
      .doesNotExist("review link is not shown");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review']"
      )
      .doesNotExist("review link is not shown");
  });

  test("review link when user can review", async function (assert) {
    updateCurrentUser({
      can_review: true,
      reviewable_count: 0,
    });

    await visit("/review");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review'].active"
      )
      .exists(
        "review link is shown as active when visiting the review route even if there are no pending reviewables"
      );

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review']"
      )
      .doesNotExist(
        "review link is not shown as part of the main section links"
      );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content .sidebar-section-link[data-link-name='review']"
      )
      .exists("review link is displayed in the more drawer");

    await publishToMessageBus(`/reviewable_counts/${loggedInUser().id}`, {
      reviewable_count: 34,
    });

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='review']"
      )
      .exists("review link is shown as part of the main section links");

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

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content .sidebar-section-link[data-link-name='review']"
      )
      .doesNotExist("review link is not displayed in the more drawer");
  });

  test("adding section link via plugin API with Object", async function (assert) {
    withPluginApi("1.2.0", (api) => {
      api.addCommunitySectionLink({
        name: "unread",
        route: "discovery.unread",
        text: "unread topics",
        title: "List of unread topics",
        icon: "wrench",
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

    assert
      .dom(".sidebar-section-link[data-link-name='unread']")
      .hasAttribute(
        "title",
        "List of unread topics",
        "displays the right title for the link"
      );

    assert
      .dom(
        ".sidebar-section-link[data-link-name='unread'] .sidebar-section-link-prefix.icon .d-icon-wrench"
      )
      .exists("displays the wrench icon for the link");

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

    assert
      .dom(".sidebar-section-link[data-link-name='user-summary']")
      .hasAttribute(
        "title",
        "eviltrout summary",
        "displays the right title for the link"
      );

    assert
      .dom(
        ".sidebar-section-link[data-link-name='user-summary'] .sidebar-section-link-prefix.icon .d-icon-link"
      )
      .exists("displays the link icon for the link");

    await click(".btn-sidebar-toggle");

    assert.true(teardownCalled, "section link teardown callback was called");
  });
});

acceptance(
  "Sidebar - Logged on user - Community Section - New new view experiment enabled",
  function (needs) {
    needs.user({
      new_new_view_enabled: true,
    });

    needs.settings({
      navigation_menu: "sidebar",
    });

    test("count is shown next to the everything link when sidebar_show_count_of_new_items is true", async function (assert) {
      updateCurrentUser({
        user_option: {
          sidebar_show_count_of_new_items: true,
        },
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
          ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-content-badge"
        ).textContent.trim(),
        "2",
        "count is 2 because there's 1 unread topic and 1 new topic"
      );
    });

    test("dot is shown next to the everything link when sidebar_show_count_of_new_items is false", async function (assert) {
      updateCurrentUser({
        user_option: {
          sidebar_show_count_of_new_items: false,
        },
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

      assert
        .dom(
          ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-suffix.icon.unread"
        )
        .exists(
          "everything link has a dot because there are unread or new topics"
        );

      await publishToMessageBus("/unread", {
        topic_id: 1,
        message_type: "read",
        payload: {
          last_read_post_number: 1,
          highest_post_number: 1,
        },
      });

      assert
        .dom(
          ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-suffix.icon.unread"
        )
        .exists(
          "everything link has a dot because there are unread or new topics"
        );

      await publishToMessageBus("/unread", {
        topic_id: 2,
        message_type: "read",
        payload: {
          last_read_post_number: 12,
          highest_post_number: 12,
        },
      });

      assert
        .dom(
          ".sidebar-section-link[data-link-name='everything'] .sidebar-section-link-suffix.icon.unread"
        )
        .doesNotExist(
          "everything link no longer has a dot because there are no more unread or new topics"
        );
    });

    test("everything link's href is the new topics list when sidebar_link_to_filtered_list is true", async function (assert) {
      updateCurrentUser({
        user_option: {
          sidebar_link_to_filtered_list: true,
        },
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

      assert
        .dom(".sidebar-section-link[data-link-name='everything']")
        .hasAttribute(
          "href",
          "/new",

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

      assert
        .dom(".sidebar-section-link[data-link-name='everything']")
        .hasAttribute(
          "href",
          "/new",
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

      assert
        .dom(".sidebar-section-link[data-link-name='everything']")
        .hasAttribute(
          "href",
          "/latest",
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

      assert
        .dom(".sidebar-section-link[data-link-name='everything']")
        .hasAttribute(
          "href",
          "/new",
          "links to /new because there is 1 new topic"
        );
    });

    test("everything link's href is always the latest topics list when sidebar_link_to_filtered_list is false", async function (assert) {
      updateCurrentUser({
        user_option: {
          sidebar_link_to_filtered_list: false,
        },
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
      ]);

      await visit("/");

      assert
        .dom(".sidebar-section-link[data-link-name='everything']")
        .hasAttribute("href", "/latest", "everything link href is /latest");
    });
  }
);
