var smallLogoUrl = "/assets/logo-single.png",
    bigLogoUrl = "/assets/logo.png",
    smallLogoSelector = "img.logo-small",
    bigLogoSelector = "img#site-logo.logo-big",
    homeIconSelector = "i.fa-home",
    headerSelector = "h2#site-text-logo.text-logo";


function setSmallLogoUrl(url) {
  Discourse.SiteSettings.logo_small_url = url;
}

function setBigLogoUrl(url) {
  Discourse.SiteSettings.logo_url = url;
}

function setTitle(title) {
  Discourse.SiteSettings.title = title;
}

function setMobileView(value) {
  Discourse.Mobile.mobileView = value;
}

var view;
function setMinimized(value) {
  Ember.run(function() {
    view.set("minimized", value);
  });
}

function appendView() {
  Ember.run(function() {
    view.appendTo(fixture());
  });
}

var oldMobileView;
module("Discourse.HomeLogoComponent", {
  setup: function() {
    oldMobileView = Discourse.Mobile.mobileView;

    view = Ember.View.create({
      container: Discourse.__container__,
      template: Ember.Handlebars.compile("{{home-logo minimized=view.minimized}}")
    });
  },

  teardown: function() {
    Discourse.Mobile.mobileView = oldMobileView;
  }
});

test("displays small logo when 'minimized' version is chosen and application is not in mobile mode", function() {
  setMobileView(false);
  setMinimized(true);

  appendView();

  ok(exists(fixture(smallLogoSelector)), "small logo image is present");
  equal(fixture(smallLogoSelector).attr("src"), smallLogoUrl, "small logo image has correct source");
  ok(!exists(fixture(homeIconSelector)), "default home icon is not present");
  ok(!exists(fixture(bigLogoSelector)), "big logo image is not present");
});

test("displays default home icon when small logo image should be displayed but its url is not configured", function() {
  setMobileView(false);
  setMinimized(true);
  setSmallLogoUrl("");

  appendView();

  ok(exists(fixture(homeIconSelector)), "default home icon is present");
  ok(!exists(fixture(smallLogoSelector)), "small logo image is not present");
  ok(!exists(fixture(bigLogoSelector)), "big logo image is not present");
});

test("displays big logo when 'minimized' version is not chosen", function() {
  setMobileView(false);
  setMinimized(false);

  appendView();

  ok(exists(fixture(bigLogoSelector)), "big logo image is present");
  ok(!exists(fixture(smallLogoSelector)), "small logo image is not present");
});

test("displays big logo when application is in mobile mode", function() {
  setMobileView(true);
  setMinimized(true);

  appendView();

  ok(exists(fixture(bigLogoSelector)), "big logo image is present");
  ok(!exists(fixture(smallLogoSelector)), "small logo image is not present");
});

test("displays big logo image with alt title when big logo url is configured", function() {
  setMobileView(true);
  setMinimized(false);
  setTitle("site-title");

  appendView();

  ok(exists(fixture(bigLogoSelector)), "big logo image is present");
  equal(fixture(bigLogoSelector).attr("src"), bigLogoUrl, "big logo image has correct source");
  equal(fixture(bigLogoSelector).attr("alt"), "site-title", "big logo image has correct alt text");
  ok(!exists(fixture(headerSelector)), "header with title is not present");
});

test("displays header with site title when big logo image should be displayed but its url is not configured", function() {
  setMobileView(true);
  setMinimized(false);
  setTitle("site-title");
  setBigLogoUrl("");

  appendView();

  ok(exists(fixture(headerSelector)), "header with title is present");
  equal(fixture(headerSelector).text(), "site-title", "header with title has correct text");
  ok(!exists(fixture(bigLogoSelector)), "big logo image is not present");
});

test("dynamically toggles logo size when 'minimized' property changes", function() {
  setMobileView(false);
  setMinimized(true);

  appendView();
  ok(exists(fixture(smallLogoSelector)), "initially small logo is shown");

  setMinimized(false);
  ok(exists(fixture(bigLogoSelector)), "when 'minimized' version is turned off, small logo is replaced with the big one");
});
