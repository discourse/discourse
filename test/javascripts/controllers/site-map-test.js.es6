var oldMobileView;

moduleFor("controller:site-map", "controller:site-map", {
  needs: ['controller:application'],

  setup: function() {
    oldMobileView = Discourse.Mobile.mobileView;
  },

  teardown: function() {
    Discourse.Mobile.mobileView = oldMobileView;
  }
});

test("showAdminLinks", function() {
  var currentUserStub = Ember.Object.create();
  sandbox.stub(Discourse.User, "current").returns(currentUserStub);

  currentUserStub.set("staff", true);
  var controller = this.subject();
  equal(controller.get("showAdminLinks"), true, "is true when current user is a staff member");

  currentUserStub.set("staff", false);
  equal(controller.get("showAdminLinks"), false, "is false when current user is not a staff member");
});

test("flaggedPostsCount", function() {
  var currentUserStub = Ember.Object.create();
  sandbox.stub(Discourse.User, "current").returns(currentUserStub);

  currentUserStub.set("site_flagged_posts_count", 5);
  var controller = this.subject();
  equal(controller.get("flaggedPostsCount"), 5, "returns current user's flagged posts count");

  currentUserStub.set("site_flagged_posts_count", 0);
  equal(controller.get("flaggedPostsCount"), 0, "is bound (reacts to change of current user's flagged posts count)");
});

test("faqUrl returns faq url configured in site settings if it is set", function() {
  Discourse.SiteSettings.faq_url = "faq-url";
  var controller = this.subject();
  equal(controller.get("faqUrl"), "faq-url");
});

test("faqUrl returns default '/faq' url when there is no corresponding site setting set", function() {
  Discourse.SiteSettings.faq_url = null;
  var controller = this.subject();
  equal(controller.get("faqUrl"), "/faq");
});

test("showMoblieToggle returns true when mobile theme is enabled in site settings", function() {
  Discourse.SiteSettings.enable_mobile_theme = true;
  Discourse.Mobile.isMobileDevice = true;
  var controller = this.subject();
  controller.capabilities = { touch: true };
  equal(controller.get("showMobileToggle"), true);
});

test("showMoblieToggle returns false when mobile theme is disabled in site settings", function() {
  Discourse.SiteSettings.enable_mobile_theme = false;
  Discourse.Mobile.isMobileDevice = true;
  var controller = this.subject();
  equal(controller.get("showMobileToggle"), false);
});

test("mobileViewLinkTextKey returns translation key for a desktop view if the current view is mobile view", function() {
  Discourse.Mobile.mobileView = true;
  var controller = this.subject();
  equal(controller.get("mobileViewLinkTextKey"), "desktop_view");
});

test("mobileViewLinkTextKey returns translation key for a mobile view if the current view is desktop view", function() {
  Discourse.Mobile.mobileView = false;
  var controller = this.subject();
  equal(controller.get("mobileViewLinkTextKey"), "mobile_view");
});

test("categories", function() {
  var categoryListStub = ["category1", "category2"];
  sandbox.stub(Discourse.Category, "list").returns(categoryListStub);

  var controller = this.subject({ siteSettings: Discourse.SiteSettings });
  deepEqual(controller.get("categories"), categoryListStub, "returns the list of categories");
});

test("toggleMobleView", function() {
  sandbox.stub(Discourse.Mobile, "toggleMobileView");

  var controller = this.subject();
  controller.send("toggleMobileView");
  ok(Discourse.Mobile.toggleMobileView.calledOnce, "switches between desktop and mobile views");
});
