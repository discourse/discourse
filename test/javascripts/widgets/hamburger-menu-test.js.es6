import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("hamburger-menu");

const maxCategoriesToDisplay = 6;

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

widgetTest("top categories - anonymous", {
  template: '{{mount-widget widget="hamburger-menu"}}',
  anonymous: true,

  test(assert) {
    const count = this.site.get("categoriesList").length;
    const maximum = count <= maxCategoriesToDisplay ? count : maxCategoriesToDisplay;
    assert.equal(this.$(".category-link").length, maximum);
  }
});

widgetTest("top categories", {
  template: '{{mount-widget widget="hamburger-menu"}}',

  beforeEach() {
    const topicTrackingState = this.site.get("categoriesList")[0].get("topicTrackingState");

    const parent1 = Discourse.Category.create({
      id: 1,
      topic_count: 5,
      name: "parent",
      url: "https://test.com/parent",
      show_subcategory_list: true,
      topicTrackingState: topicTrackingState
    });
    const child1 = Discourse.Category.create({
      id: 2,
      parent_category_id: 1,
      parentCategory: parent,
      topic_count: 4,
      name: "child",
      url: "https://test.com/child",
      topicTrackingState: topicTrackingState
    });
    const parent2 = Discourse.Category.create({
      id: 3,
      topic_count: 7,
      name: "parent 2",
      url: "https://test.com/parent2",
      show_subcategory_list: false,
      topicTrackingState: topicTrackingState
    });
    const child2 = Discourse.Category.create({
      id: 4,
      parent_category_id: 3,
      parentCategory: parent,
      topic_count: 8,
      name: "child 2",
      url: "https://test.com/child2",
      topicTrackingState: topicTrackingState
    });
    const parent3 = Discourse.Category.create({
      id: 5,
      topic_count: 2,
      name: "parent 3",
      url: "https://test.com/parent3",
      show_subcategory_list: true,
      topicTrackingState: topicTrackingState
    });
    const parent4 = Discourse.Category.create({
      id: 6,
      topic_count: 2,
      name: "parent 4",
      url: "https://test.com/parent4",
      show_subcategory_list: true,
      topicTrackingState: topicTrackingState
    });
    const parent5 = Discourse.Category.create({
      id: 7,
      topic_count: 9,
      name: "parent 5",
      url: "https://test.com/parent5",
      show_subcategory_list: false,
      topicTrackingState: topicTrackingState
    });

    parent1.subcategories = [child1];
    parent2.subcategories = [child2];
    const list = [parent1, child1, parent2, child2, parent3, parent4, parent5];
    this.site.set("categoriesList", list);
    this.currentUser.set("top_category_ids", [6, 7, 4, 5, 2]);
  },

  test(assert) {
    assert.equal(this.$(".category-link").length, maxCategoriesToDisplay);
    assert.equal(this.$(".category-link .category-name").text(), "parent 4parent 5child 2parent 3childparent");
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
