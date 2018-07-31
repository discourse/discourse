import { moduleForWidget, widgetTest } from "helpers/widget-test";
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
    assert.ok(this.$(".faq-priority").length);
    assert.ok(!this.$(".faq-link").length);
  }
});

widgetTest("prioritize faq - user has read", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.siteSettings.faq_url = "http://example.com/faq";
    this.currentUser.set("read_faq", true);
  },

  test(assert) {
    assert.ok(!this.$(".faq-priority").length);
    assert.ok(this.$(".faq-link").length);
  }
});

widgetTest("staff menu - not staff", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.currentUser.set("staff", false);
  },

  test(assert) {
    assert.ok(!this.$(".admin-link").length);
  }
});

widgetTest("staff menu", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.currentUser.setProperties({
      staff: true,
      site_flagged_posts_count: 3
    });
  },

  test(assert) {
    assert.ok(this.$(".admin-link").length);
    assert.ok(this.$(".flagged-posts-link").length);
    assert.equal(this.$(".flagged-posts").text(), "3");
    assert.ok(!this.$(".settings-link").length);
  }
});

widgetTest("staff menu - admin", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.currentUser.setProperties({ staff: true, admin: true });
  },

  test(assert) {
    assert.ok(this.$(".settings-link").length);
  }
});

widgetTest("queued posts", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.currentUser.setProperties({
      staff: true,
      show_queued_posts: true,
      post_queue_new_count: 5
    });
  },

  test(assert) {
    assert.ok(this.$(".queued-posts-link").length);
    assert.equal(this.$(".queued-posts").text(), "5");
  }
});

widgetTest("queued posts - disabled", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.currentUser.setProperties({ staff: true, show_queued_posts: false });
  },

  test(assert) {
    assert.ok(!this.$(".queued-posts-link").length);
  }
});

widgetTest("logged in links", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  test(assert) {
    assert.ok(this.$(".new-topics-link").length);
    assert.ok(this.$(".unread-topics-link").length);
  }
});

widgetTest("general links", {
  template: '{{mount-widget widget="hamburger-menu"}}',
  anonymous: true,

  test(assert) {
    assert.ok(this.$("li[class='']").length === 0);
    assert.ok(this.$(".latest-topics-link").length);
    assert.ok(!this.$(".new-topics-link").length);
    assert.ok(!this.$(".unread-topics-link").length);
    assert.ok(this.$(".top-topics-link").length);
    assert.ok(this.$(".badge-link").length);
    assert.ok(this.$(".category-link").length > 0);
  }
});

let maxCategoriesToDisplay;

widgetTest("top categories - anonymous", {
  template: '{{mount-widget widget="hamburger-menu"}}',
  anonymous: true,

  beforeEach() {
    this.siteSettings.header_dropdown_category_count = 8;
    maxCategoriesToDisplay = this.siteSettings.header_dropdown_category_count;
    categoriesByCount = this.site.get("categoriesByCount");
  },

  test(assert) {
    const count = categoriesByCount.length;
    const maximum =
      count <= maxCategoriesToDisplay ? count : maxCategoriesToDisplay;
    assert.equal(find(".category-link").length, maximum);
    assert.equal(
      find(".category-link .category-name").text(),
      categoriesByCount
        .slice(0, maxCategoriesToDisplay)
        .map(c => c.name)
        .join("")
    );
  }
});

widgetTest("top categories", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.siteSettings.header_dropdown_category_count = 8;
    maxCategoriesToDisplay = this.siteSettings.header_dropdown_category_count;
    categoriesByCount = this.site.get("categoriesByCount").slice();
    categoriesByCount.every(c => {
      if (!topCategoryIds.includes(c.id)) {
        if (mutedCategoryIds.length === 0) {
          mutedCategoryIds.push(c.id);
          c.set("notification_level", NotificationLevels.MUTED);
        } else if (unreadCategoryIds.length === 0) {
          unreadCategoryIds.push(c.id);
          c.set("unreadTopics", 5);
        } else {
          unreadCategoryIds.splice(0, 0, c.id);
          c.set("newTopics", 10);
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
      c => !mutedCategoryIds.includes(c.id)
    );
    let ids = [
      ...unreadCategoryIds,
      ...topCategoryIds,
      ...categoriesByCount.map(c => c.id)
    ]
      .uniq()
      .slice(0, maxCategoriesToDisplay);

    assert.equal(
      find(".category-link .category-name").text(),
      ids.map(i => categoriesByCount.find(c => c.id === i).name).join("")
    );
  }
});

widgetTest("badges link - disabled", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.siteSettings.enable_badges = false;
  },

  test(assert) {
    assert.ok(!this.$(".badge-link").length);
  }
});

widgetTest("badges link", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  test(assert) {
    assert.ok(this.$(".badge-link").length);
  }
});

widgetTest("user directory link", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  test(assert) {
    assert.ok(this.$(".user-directory-link").length);
  }
});

widgetTest("user directory link - disabled", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    this.siteSettings.enable_user_directory = false;
  },

  test(assert) {
    assert.ok(!this.$(".user-directory-link").length);
  }
});

widgetTest("general links", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  test(assert) {
    assert.ok(this.$(".about-link").length);
    assert.ok(this.$(".keyboard-shortcuts-link").length);
  }
});
