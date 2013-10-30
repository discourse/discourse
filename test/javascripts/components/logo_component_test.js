var view, oldMobileView;

var View = Ember.View.extend({
  template: Ember.Handlebars.compile("{{discourse-logo minimized=view.minimized}}")
});


var setSmallLogoUrl = function(url) {
  Discourse.SiteSettings.logo_small_url = url;
};

var setBigLogoUrl = function(url) {
  Discourse.SiteSettings.logo_url = url;
};

var setTitle = function(title) {
  Discourse.SiteSettings.title = title;
};

var setMobileView = function(value) {
  Discourse.Mobile.mobileView = value;
};

var setMinimized = function(value) {
  Ember.run(function() {
    view.set("minimized", value);
  });
};


var smallLogoSelector = "img.logo-small";
var bigLogoSelector = "img#site-logo.logo-big";
var homeIconSelector = "i.icon-home";
var headerSelector = "h2#site-text-logo.text-logo";


var appendView = function() {
  Ember.run(function() {
    view.appendTo(Ember.$("#qunit-fixture"));
  });
};

var exists = function(selector) {
  return Ember.$(selector).length > 0;
};


module("Discourse.DiscourseLogoComponent", {
  setup: function() {
    oldMobileView = Discourse.Mobile.mobileView;

    setSmallLogoUrl("small-logo-url");
    setBigLogoUrl("big-logo-url");

    view = View.create();
  },

  teardown: function() {
    Discourse.Mobile.mobileView = oldMobileView;
  }
});

test("displays small logo when 'minimized' version is chosen and application is not in mobile mode", function() {
  setMobileView(false);
  setMinimized(true);

  appendView();

  ok(exists(smallLogoSelector), "small logo image is present");
  equal(Ember.$(smallLogoSelector).attr("src"), "small-logo-url", "small logo image has correct source");
  ok(!exists(homeIconSelector), "default home icon is not present");
  ok(!exists(bigLogoSelector), "big logo image is not present");
});

test("displays default home icon when small logo image should be displayed but its url is not configured", function() {
  setMobileView(false);
  setMinimized(true);
  setSmallLogoUrl("");

  appendView();

  ok(exists(homeIconSelector), "default home icon is present");
  ok(!exists(smallLogoSelector), "small logo image is not present");
  ok(!exists(bigLogoSelector), "big logo image is not present");
});

test("displays big logo when 'minimized' version is not chosen", function() {
  setMobileView(false);
  setMinimized(false);

  appendView();

  ok(exists(bigLogoSelector), "big logo image is present");
  ok(!exists(smallLogoSelector), "small logo image is not present");
});

test("displays big logo when application is in mobile mode", function() {
  setMobileView(true);
  setMinimized(true);

  appendView();

  ok(exists(bigLogoSelector), "big logo image is present");
  ok(!exists(smallLogoSelector), "small logo image is not present");
});

test("displays big logo image with alt title when big logo url is configured", function() {
  setMobileView(true);
  setMinimized(false);
  setTitle("site-title");

  appendView();

  ok(exists(bigLogoSelector), "big logo image is present");
  equal(Ember.$(bigLogoSelector).attr("src"), "big-logo-url", "big logo image has correct source");
  equal(Ember.$(bigLogoSelector).attr("alt"), "site-title", "big logo image has correct alt text");
  ok(!exists(headerSelector), "header with title is not present");
});

test("displays header with site title when big logo image should be displayed but its url is not configured", function() {
  setMobileView(true);
  setMinimized(false);
  setTitle("site-title");
  setBigLogoUrl("");

  appendView();

  ok(exists(headerSelector), "header with title is present");
  equal(Ember.$(headerSelector).text(), "site-title", "header with title has correct text");
  ok(!exists(bigLogoSelector), "big logo image is not present");
});

test("dynamically toggles logo size when 'minimized' property changes", function() {
  setMobileView(false);
  setMinimized(true);

  appendView();
  ok(exists(smallLogoSelector), "initially small logo is shown");

  setMinimized(false);
  ok(exists(bigLogoSelector), "when 'minimized' version is turned off, small logo is replaced with the big one");
});

test("links logo to the site root", function() {
  appendView();

  equal(Ember.$(".title > a").attr("href"), "/");
});
