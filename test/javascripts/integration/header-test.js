integration("Header", {
  setup: function() {
    var originalUser = Discourse.User.current();
    sandbox.stub(Discourse.User, "current").returns(originalUser);
    Discourse.User.current.returns(Ember.Object.create({
      username: 'test',
      staff: true,
      site_flagged_posts_count: 1
    }));
  },

  teardown: function() {
    Discourse.User.current.restore();
  }
});

test("header", function() {
  expect(20);

  visit("/");
  andThen(function() {
    ok(exists("header"), "is rendered");
    ok(exists(".logo-big"), "it renders the large logo by default");
    not(exists("#notifications-dropdown li"), "no notifications at first");
    not(exists('#site-map-dropdown'), "no site map by default");
    not(exists("#user-dropdown:visible"), "initially user dropdown is closed");
    not(exists("#search-dropdown:visible"), "initially search box is closed");
  });

  // Logo changing
  andThen(function() {
    controllerFor('header').set("showExtraInfo", true);
  });

  andThen(function() {
    ok(exists(".logo-small"), "it shows the small logo when `showExtraInfo` is enabled");
  });

  // Notifications
  click("#user-notifications");
  andThen(function() {
    var $items = $("#notifications-dropdown li");
    ok(exists($items), "is lazily populated after user opens it");
    ok($items.first().hasClass("read"), "correctly binds items' 'read' class");
  });

  // Site Map
  click("#site-map");
  andThen(function() {
    ok(exists('#site-map-dropdown'), "is rendered after user opens it");
    ok(exists("#site-map-dropdown .admin-link"), "it has the admin link");
    ok(exists("#site-map-dropdown .flagged-posts.badge-notification"), "it displays flag notifications");
    ok(exists("#site-map-dropdown .faq-link"), "it shows the faq link");
    ok(exists("#site-map-dropdown .category-links"), "has categories correctly bound");
  });

  // User dropdown
  click("#current-user");
  andThen(function() {
    ok(exists("#user-dropdown:visible"), "is lazily rendered after user opens it");
    ok(exists("#user-dropdown .user-dropdown-links"), "has showing / hiding user-dropdown links correctly bound");
  });

  // Search
  click("#search-button");
  andThen(function() {
    ok(exists("#search-dropdown:visible"), "after clicking a button search box opens");
    not(exists("#search-dropdown .heading"), "initially, immediately after opening, search box is empty");
  });

  // Perform Search
  fillIn("#search-term", "hello");
  andThen(function() {
    ok(exists("#search-dropdown .heading"), "when user completes a search, search box shows search results");
    equal(find("#search-dropdown .selected a").attr("href"), "some-url", "the first search result is selected");
  });
});
