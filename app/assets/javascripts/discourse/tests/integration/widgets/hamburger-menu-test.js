import {
  moduleForWidget,
  widgetTest,
} from "discourse/tests/helpers/widget-test";
import { NotificationLevels } from "discourse/lib/notification-levels";

moduleForWidget("hamburger-menu");

const topCategoryIds = [2, 3, 1];
let mutedCategoryIds = [];
let unreadCategoryIds = [];
let categoriesByCount = [];

widgetTest("prioritize faq", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.siteSettings.faq_url = "http://example.com/faq";
    this.currentUser.set("read_faq", false);
  },

  test(assert) {
    assert.ok(find(".faq-priority").length);
    assert.ok(!find(".faq-link").length);
  },
});

widgetTest("prioritize faq - user has read", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.siteSettings.faq_url = "http://example.com/faq";
    this.currentUser.set("read_faq", true);
  },

  test(assert) {
    assert.ok(!find(".faq-priority").length);
    assert.ok(find(".faq-link").length);
  },
});

widgetTest("staff menu - not staff", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.currentUser.set("staff", false);
  },

  test(assert) {
    assert.ok(!find(".admin-link").length);
  },
});

widgetTest("staff menu - moderator", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.currentUser.set("moderator", true);
  },

  test(assert) {
    assert.ok(find(".admin-link").length);
    assert.ok(find(".review").length);
    assert.ok(!find(".settings-link").length);
  },
});

widgetTest("staff menu - admin", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.currentUser.setProperties({ admin: true });
  },

  test(assert) {
    assert.ok(find(".settings-link").length);
  },
});

widgetTest("logged in links", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  test(assert) {
    assert.ok(find(".new-topics-link").length);
    assert.ok(find(".unread-topics-link").length);
  },
});

widgetTest("general links", {
  template: '{{mount-widget widget="hamburger-menu"}}',
  anonymous: true,

  test(assert) {
    assert.ok(find("li[class='']").length === 0);
    assert.ok(find(".latest-topics-link").length);
    assert.ok(!find(".new-topics-link").length);
    assert.ok(!find(".unread-topics-link").length);
    assert.ok(find(".top-topics-link").length);
    assert.ok(find(".badge-link").length);
    assert.ok(find(".category-link").length > 0);
  },
});

let maxCategoriesToDisplay;

widgetTest("top categories - anonymous", {
  template: '{{mount-widget widget="hamburger-menu"}}',
  anonymous: true,

  beforeEach() {
    this.siteSettings.header_dropdown_category_count = 8;
  },

  test(assert) {
    assert.equal(find(".category-link").length, 8);
    assert.equal(
      find(".category-link .category-name").text(),
      this.site
        .get("categoriesByCount")
        .slice(0, 8)
        .map((c) => c.name)
        .join("")
    );
  },
});

widgetTest("top categories - allow_uncategorized_topics", {
  template: '{{mount-widget widget="hamburger-menu"}}',
  anonymous: true,

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = false;
    this.siteSettings.header_dropdown_category_count = 8;
  },

  test(assert) {
    assert.equal(find(".category-link").length, 8);
    assert.equal(
      find(".category-link .category-name").text(),
      this.site
        .get("categoriesByCount")
        .filter((c) => c.name !== "uncategorized")
        .slice(0, 8)
        .map((c) => c.name)
        .join("")
    );
  },
});

widgetTest("top categories", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.siteSettings.header_dropdown_category_count = 8;
    maxCategoriesToDisplay = this.siteSettings.header_dropdown_category_count;
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
    assert.equal(find(".category-link").length, maxCategoriesToDisplay);

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
      find(".category-link .category-name").text(),
      ids.map((i) => categoriesByCount.find((c) => c.id === i).name).join("")
    );
  },
});

widgetTest("badges link - disabled", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.siteSettings.enable_badges = false;
  },

  test(assert) {
    assert.ok(!find(".badge-link").length);
  },
});

widgetTest("badges link", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  test(assert) {
    assert.ok(find(".badge-link").length);
  },
});

widgetTest("user directory link", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  test(assert) {
    assert.ok(find(".user-directory-link").length);
  },
});

widgetTest("user directory link - disabled", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.siteSettings.enable_user_directory = false;
  },

  test(assert) {
    assert.ok(!find(".user-directory-link").length);
  },
});

widgetTest("general links", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  test(assert) {
    assert.ok(find(".about-link").length);
    assert.ok(find(".keyboard-shortcuts-link").length);
  },
});
