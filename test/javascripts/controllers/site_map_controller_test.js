var controller, oldMobileView;

module("controller:site-map", {
  setup: function() {
    oldMobileView = Discourse.Mobile.mobileView;

    controller = testController('site-map');
  },

  teardown: function() {
    Discourse.Mobile.mobileView = oldMobileView;
  }
});

test("itemController", function() {
  equal(controller.get("itemController"), "site-map-category", "defaults to site-map-category");
});

test("showAdminLinks", function() {
  var currentUserStub = Ember.Object.create();
  this.stub(Discourse.User, "current").returns(currentUserStub);

  currentUserStub.set("staff", true);
  equal(controller.get("showAdminLinks"), true, "is true when current user is a staff member");

  currentUserStub.set("staff", false);
  equal(controller.get("showAdminLinks"), false, "is false when current user is not a staff member");
});

test("flaggedPostsCount", function() {
  var currentUserStub = Ember.Object.create();
  this.stub(Discourse.User, "current").returns(currentUserStub);

  currentUserStub.set("site_flagged_posts_count", 5);
  equal(controller.get("flaggedPostsCount"), 5, "returns current user's flagged posts count");

  currentUserStub.set("site_flagged_posts_count", 0);
  equal(controller.get("flaggedPostsCount"), 0, "is bound (reacts to change of current user's flagged posts count)");
});

test("faqUrl returns faq url configured in site settings if it is set", function() {
  Discourse.SiteSettings.faq_url = "faq-url";
  equal(controller.get("faqUrl"), "faq-url");
});

test("faqUrl returns default '/faq' url when there is no corresponding site setting set", function() {
  Discourse.SiteSettings.faq_url = null;
  equal(controller.get("faqUrl"), "/faq");
});

test("showMoblieToggle returns true when mobile theme is enabled in site settings", function() {
  Discourse.SiteSettings.enable_mobile_theme = true;
  equal(controller.get("showMobileToggle"), true);
});

test("showMoblieToggle returns false when mobile theme is disabled in site settings", function() {
  Discourse.SiteSettings.enable_mobile_theme = false;
  equal(controller.get("showMobileToggle"), false);
});

test("mobileViewLinkTextKey returns translation key for a desktop view if the current view is mobile view", function() {
  Discourse.Mobile.mobileView = true;
  equal(controller.get("mobileViewLinkTextKey"), "desktop_view");
});

test("mobileViewLinkTextKey returns translation key for a mobile view if the current view is desktop view", function() {
  Discourse.Mobile.mobileView = false;
  equal(controller.get("mobileViewLinkTextKey"), "mobile_view");
});

test("categories", function() {
  var categoryListStub = ["category1", "category2"];
  this.stub(Discourse.Category, "list").returns(categoryListStub);

  equal(controller.get("categories"), categoryListStub, "returns the list of categories");
});

test("toggleMobleView", function() {
  this.stub(Discourse.Mobile, "toggleMobileView");

  controller.send("toggleMobileView");
  ok(Discourse.Mobile.toggleMobileView.calledOnce, "switches between desktop and mobile views");
});
