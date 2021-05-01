import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { NotificationLevels } from "discourse/lib/notification-levels";
import hbs from "htmlbars-inline-precompile";

const topCategoryIds = [2, 3, 1];
let mutedCategoryIds = [];
let unreadCategoryIds = [];
let categoriesByCount = [];

discourseModule(
  "Integration | Component | Widget | hamburger-menu",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("prioritize faq", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.siteSettings.faq_url = "http://example.com/faq";
        this.currentUser.set("read_faq", false);
      },

      test(assert) {
        assert.ok(queryAll(".faq-priority").length);
        assert.ok(!queryAll(".faq-link").length);
      },
    });

    componentTest("prioritize faq - user has read", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.siteSettings.faq_url = "http://example.com/faq";
        this.currentUser.set("read_faq", true);
      },

      test(assert) {
        assert.ok(!queryAll(".faq-priority").length);
        assert.ok(queryAll(".faq-link").length);
      },
    });

    componentTest("staff menu - not staff", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.currentUser.set("staff", false);
      },

      test(assert) {
        assert.ok(!queryAll(".admin-link").length);
      },
    });

    componentTest("staff menu - moderator", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.currentUser.set("moderator", true);
        this.currentUser.set("can_review", true);
      },

      test(assert) {
        assert.ok(queryAll(".admin-link").length);
        assert.ok(queryAll(".review").length);
        assert.ok(!queryAll(".settings-link").length);
      },
    });

    componentTest("staff menu - admin", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.currentUser.setProperties({ admin: true });
      },

      test(assert) {
        assert.ok(queryAll(".settings-link").length);
      },
    });

    componentTest("logged in links", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      test(assert) {
        assert.ok(queryAll(".new-topics-link").length);
        assert.ok(queryAll(".unread-topics-link").length);
      },
    });

    componentTest("general links", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,
      anonymous: true,

      test(assert) {
        assert.ok(queryAll("li[class='']").length === 0);
        assert.ok(queryAll(".latest-topics-link").length);
        assert.ok(!queryAll(".new-topics-link").length);
        assert.ok(!queryAll(".unread-topics-link").length);
        assert.ok(queryAll(".top-topics-link").length);
        assert.ok(queryAll(".badge-link").length);
        assert.ok(queryAll(".category-link").length > 0);
      },
    });

    let maxCategoriesToDisplay;

    componentTest("top categories - anonymous", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,
      anonymous: true,

      beforeEach() {
        this.siteSettings.header_dropdown_category_count = 8;
      },

      test(assert) {
        assert.equal(queryAll(".category-link").length, 8);
        assert.equal(
          queryAll(".category-link .category-name").text(),
          this.site
            .get("categoriesByCount")
            .slice(0, 8)
            .map((c) => c.name)
            .join("")
        );
      },
    });

    componentTest("top categories - allow_uncategorized_topics", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,
      anonymous: true,

      beforeEach() {
        this.siteSettings.allow_uncategorized_topics = false;
        this.siteSettings.header_dropdown_category_count = 8;
      },

      test(assert) {
        assert.equal(queryAll(".category-link").length, 8);
        assert.equal(
          queryAll(".category-link .category-name").text(),
          this.site
            .get("categoriesByCount")
            .filter((c) => c.name !== "uncategorized")
            .slice(0, 8)
            .map((c) => c.name)
            .join("")
        );
      },
    });

    componentTest("top categories", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.siteSettings.header_dropdown_category_count = 8;
        maxCategoriesToDisplay = this.siteSettings
          .header_dropdown_category_count;
        categoriesByCount = this.site.get("categoriesByCount").slice();
        categoriesByCount.every((c) => {
          if (!topCategoryIds.includes(c.id)) {
            if (mutedCategoryIds.length === 0) {
              mutedCategoryIds.push(c.id);
              c.set("notification_level", NotificationLevels.MUTED);
            } else if (unreadCategoryIds.length === 0) {
              unreadCategoryIds.push(c.id);
              for (let i = 0; i < 5; i++) {
                c.topicTrackingState.states["t123" + i] = {
                  category_id: c.id,
                  last_read_post_number: 1,
                  highest_post_number: 2,
                  notification_level: NotificationLevels.TRACKING,
                };
              }
            } else {
              unreadCategoryIds.splice(0, 0, c.id);
              for (let i = 0; i < 10; i++) {
                c.topicTrackingState.states["t321" + i] = {
                  category_id: c.id,
                  last_read_post_number: null,
                };
              }
              return false;
            }
          }
          return true;
        });
        this.currentUser.set("top_category_ids", topCategoryIds);
      },

      test(assert) {
        assert.equal(queryAll(".category-link").length, maxCategoriesToDisplay);

        categoriesByCount = categoriesByCount.filter(
          (c) => !mutedCategoryIds.includes(c.id)
        );
        let ids = [
          ...unreadCategoryIds,
          ...topCategoryIds,
          ...categoriesByCount.map((c) => c.id),
        ]
          .uniq()
          .slice(0, maxCategoriesToDisplay);

        assert.equal(
          queryAll(".category-link .category-name").text(),
          ids
            .map((i) => categoriesByCount.find((c) => c.id === i).name)
            .join("")
        );
      },
    });

    componentTest("badges link - disabled", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.siteSettings.enable_badges = false;
      },

      test(assert) {
        assert.ok(!queryAll(".badge-link").length);
      },
    });

    componentTest("badges link", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      test(assert) {
        assert.ok(queryAll(".badge-link").length);
      },
    });

    componentTest("user directory link", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      test(assert) {
        assert.ok(queryAll(".user-directory-link").length);
      },
    });

    componentTest("user directory link - disabled", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.siteSettings.enable_user_directory = false;
      },

      test(assert) {
        assert.ok(!queryAll(".user-directory-link").length);
      },
    });

    componentTest("general links", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      test(assert) {
        assert.ok(queryAll(".about-link").length);
        assert.ok(queryAll(".keyboard-shortcuts-link").length);
      },
    });
  }
);
