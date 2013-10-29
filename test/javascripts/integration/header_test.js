integration("Header");

test("/", function() {
  expect(2);

  visit("/").then(function() {
    ok(exists("header"), "The header was rendered");
    ok(exists("#site-logo"), "The logo was shown");
  });
});

test("displays small logo when extra info is shown and it is not mobile view", function() {
  expect(4);

  Ember.run(function() {
    Discourse.SiteSettings.logo_small_url = "logo-small-url";
    Discourse.Mobile.mobileView = false;
    controllerFor("header").set("showExtraInfo", true);
  });

  visit("/").then(function() {
    ok(exists("img.logo-small"), "small logo image is present");
    equal(Ember.$("img.logo-small").attr("src"), "logo-small-url", "small logo image has correct image as a source");
    ok(!exists(".icon-home"), "default home icon is not present");
    ok(!exists("img.logo-big"), "big logo image is not present");
  });
});

test("displays default home icon when small logo image source is not configured", function() {
  expect(3);

  Ember.run(function() {
    Discourse.SiteSettings.logo_small_url = "";
    Discourse.Mobile.mobileView = false;
    controllerFor("header").set("showExtraInfo", true);
  });

  visit("/").then(function() {
    ok(exists("i.icon-home"), "default home icon is present");
    ok(!exists(".logo-small"), "small logo image is not present");
    ok(!exists("img.logo-big"), "big logo image is not present");
  });
});

test("displays normal (big) logo when extra info is not shown", function() {
  expect(2);

  Ember.run(function() {
    Discourse.Mobile.mobileView = false;
    controllerFor("header").set("showExtraInfo", false);
  });

  visit("/").then(function() {
    ok(exists("img.logo-big"), "big logo image is present");
    ok(!exists(".logo-small"), "small logo image is not present");
  });
});

test("displays normal (big) logo when it is mobile view", function() {
  expect(2);

  Ember.run(function() {
    Discourse.Mobile.mobileView = true;
    controllerFor("header").set("showExtraInfo", true);
  });

  visit("/").then(function() {
    ok(exists("img.logo-big"), "big logo image is present");
    ok(!exists(".logo-small"), "small logo image is not present");
  });
});

test("displays normal (big) logo image with alt title when big logo image source is configured", function() {
  expect(4);

  Ember.run(function() {
    Discourse.SiteSettings.logo_url = "logo-big-url";
    Discourse.SiteSettings.title = "site-title";
    Discourse.Mobile.mobileView = true;
    controllerFor("header").set("showExtraInfo", false);
  });

  visit("/").then(function() {
    ok(exists("img#site-logo.logo-big"), "big logo image is present");
    equal(Ember.$("img#site-logo.logo-big").attr("src"), "logo-big-url", "big logo image has correct image as a source");
    equal(Ember.$("img#site-logo.logo-big").attr("alt"), "site-title", "big logo image has correct text as alt");
    ok(!exists("#site-text-logo"), "header with title is not present");
  });
});

test("displays header with site title when big logo image source is not configured", function() {
  expect(3);

  Ember.run(function() {
    Discourse.SiteSettings.logo_url = "";
    Discourse.SiteSettings.title = "site-title";
    Discourse.Mobile.mobileView = true;
    controllerFor("header").set("showExtraInfo", false);
  });

  visit("/").then(function() {
    ok(exists("h2#site-text-logo.text-logo"), "header with title is present");
    equal(Ember.$("h2#site-text-logo.text-logo").text(), "site-title", "header with title contains correct text");
    ok(!exists(".logo-big"), "big logo image is not present");
  });
});

test("dynamically toggles logo size when showing or hiding extra info", function() {
  expect(2);

  Ember.run(function() {
    Discourse.SiteSettings.logo_small_url = "logo-small-url";
    Discourse.Mobile.mobileView = false;
    controllerFor("header").set("showExtraInfo", true);
  });

  visit("/").then(function() {
    ok(exists("img.logo-small"), "initially small logo is shown");

    Ember.run(function() {
      controllerFor("header").set("showExtraInfo", false);
    });
    ok(exists("img.logo-big"), "when extra info is hidden, small logo is replaced with the normal (big) one");
  });
});

test("links logo to the site root", function() {
  expect(1);

  visit("/").then(function() {
    equal(Ember.$(".title > a").attr("href"), "/");
  });
});
