import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
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
        assert.ok(exists(".faq-priority"));
        assert.ok(!exists(".faq-link"));
      },
    });

    componentTest("prioritize faq - user has read", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.siteSettings.faq_url = "http://example.com/faq";
        this.currentUser.set("read_faq", true);
      },

      test(assert) {
        assert.ok(!exists(".faq-priority"));
        assert.ok(exists(".faq-link"));
      },
    });

    componentTest("staff menu - not staff", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.currentUser.set("staff", false);
      },

      test(assert) {
        assert.ok(!exists(".admin-link"));
      },
    });

    componentTest("staff menu - moderator", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.currentUser.set("moderator", true);
        this.currentUser.set("can_review", true);
      },

      test(assert) {
        assert.ok(exists(".admin-link"));
        assert.ok(exists(".review"));
        assert.ok(!exists(".settings-link"));
      },
    });

    componentTest("staff menu - admin", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.currentUser.setProperties({ admin: true });
      },

      test(assert) {
        assert.ok(exists(".settings-link"));
      },
    });

    componentTest("logged in links", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      test(assert) {
        assert.ok(exists(".new-topics-link"));
        assert.ok(exists(".unread-topics-link"));
      },
    });

    componentTest("general links", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,
      anonymous: true,

      test(assert) {
        assert.ok(!exists("li[class='']"));
        assert.ok(exists(".latest-topics-link"));
        assert.ok(!exists(".new-topics-link"));
        assert.ok(!exists(".unread-topics-link"));
        assert.ok(exists(".top-topics-link"));
        assert.ok(exists(".badge-link"));
        assert.ok(exists(".category-link"));
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
        assert.equal(count(".category-link"), 8);
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
        assert.equal(count(".category-link"), 8);
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
                c.topicTrackingState.modifyState(123 + i, {
                  category_id: c.id,
                  last_read_post_number: 1,
                  highest_post_number: 2,
                  notification_level: NotificationLevels.TRACKING,
                  unread_not_too_old: true,
                });
              }
            } else {
              unreadCategoryIds.splice(0, 0, c.id);
              for (let i = 0; i < 10; i++) {
                c.topicTrackingState.modifyState(321 + i, {
                  category_id: c.id,
                  last_read_post_number: null,
                  created_in_new_period: true,
                });
              }
              return false;
            }
          }
          return true;
        });
        this.currentUser.set("top_category_ids", topCategoryIds);
      },

      test(assert) {
        assert.equal(
          count(".category-link"),
          maxCategoriesToDisplay,
          "categories displayed limited by header_dropdown_category_count"
        );

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
            .map(
              (id) =>
                categoriesByCount.find((category) => category.id === id).name
            )
            .join(""),
          "top categories are in the correct order"
        );
      },
    });

    componentTest("badges link - disabled", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.siteSettings.enable_badges = false;
      },

      test(assert) {
        assert.ok(!exists(".badge-link"));
      },
    });

    componentTest("badges link", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      test(assert) {
        assert.ok(exists(".badge-link"));
      },
    });

    componentTest("user directory link", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      test(assert) {
        assert.ok(exists(".user-directory-link"));
      },
    });

    componentTest("user directory link - disabled", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      beforeEach() {
        this.siteSettings.enable_user_directory = false;
      },

      test(assert) {
        assert.ok(!exists(".user-directory-link"));
      },
    });

    componentTest("general links", {
      template: hbs`{{mount-widget widget="hamburger-menu"}}`,

      test(assert) {
        assert.ok(exists(".about-link"));
        assert.ok(exists(".keyboard-shortcuts-link"));
      },
    });
  }
);
