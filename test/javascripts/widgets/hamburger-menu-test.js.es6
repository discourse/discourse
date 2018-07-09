import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("hamburger-menu");

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

widgetTest("category links", {
  template: '{{mount-widget widget="hamburger-menu"}}',
  anonymous: true,

  beforeEach() {
    const cat = this.site.get("categoriesList")[0];

    const parent = Discourse.Category.create({
      id: 1,
      topic_count: 5,
      name: "parent",
      url: "https://test.com/parent",
      show_subcategory_list: true,
      topicTrackingState: cat.get("topicTrackingState")
    });
    const child = Discourse.Category.create({
      id: 2,
      parent_category_id: 1,
      parentCategory: parent,
      topic_count: 4,
      name: "child",
      url: "https://test.com/child",
      topicTrackingState: cat.get("topicTrackingState")
    });

    parent.subcategories = [child];

    const list = [parent, child];
    this.site.set("categoriesList", list);
  },

  test(assert) {
    // if show_subcategory_list is enabled we suppress the categories from hamburger
    // this means that people can be confused about counts
    assert.equal(this.$(".category-link").length, 1);
    assert.equal(this.$(".category-link .topics-count").text(), "9");
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
