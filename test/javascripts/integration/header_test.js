integration("Header", {
  setup: function() {
    sinon.stub(I18n, "t", function(scope, options) {
      if (options) {
        if (options.count) {
          return [scope, options.count].join(" ");
        } else {
          return [scope, options.username, options.link].join(" ").trim();
        }
      }
      return scope;
    });

    sinon.stub(Ember.run, "debounce").callsArg(1);

    var originalCategories = Discourse.Category.list();
    sinon.stub(Discourse.Category, "list").returns(originalCategories);

    var originalUser = Discourse.User.current();
    sinon.stub(Discourse.User, "current").returns(originalUser);
  },

  teardown: function() {
    I18n.t.restore();
    Ember.run.debounce.restore();
    Discourse.Category.list.restore();
    Discourse.User.current.restore();
  }
});

test("header", function() {
  expect(1);

  visit("/").then(function() {
    ok(exists("header"), "is rendered");
  });
});

test("logo", function() {
  expect(2);

  visit("/").then(function() {
    ok(exists(".logo-big"), "is rendered");

    Ember.run(function() {
      controllerFor("header").set("showExtraInfo", true);
    });
    ok(exists(".logo-small"), "is properly wired to showExtraInfo property (when showExtraInfo value changes, logo size also changes)");
  });
});

test("notifications dropdown", function() {
  expect(4);

  var itemSelector = "#notifications-dropdown li";

  Ember.run(function() {
    Discourse.URL_FIXTURES["/notifications"] = [
      {
        notification_type: 2, //replied
        read: true,
        post_number: 2,
        topic_id: 1234,
        slug: "a-slug",
        data: {
          topic_title: "some title",
          display_username: "velesin"
        }
      }
    ];
  });

  visit("/")
  .then(function() {
    ok(!exists($(itemSelector)), "initially is empty");
  })
  .click("#user-notifications")
  .then(function() {
    var $items = $(itemSelector);

    ok(exists($items), "is lazily populated after user opens it");
    ok($items.first().hasClass("read"), "correctly binds items' 'read' class");
    equal($items.first().find('span').html().trim(), 'notifications.replied velesin <a href="/t/a-slug/1234/2">some title</a>', "correctly generates items' content");
  });
});

test("sitemap dropdown", function() {
  expect(8);

  Discourse.SiteSettings.faq_url = "faq-url";
  Discourse.SiteSettings.enable_mobile_theme = true;

  Discourse.User.current.returns(Ember.Object.create({
    username: 'test',
    staff: true,
    site_flagged_posts_count: 1
  }));

  Discourse.Category.list.returns([
    Discourse.Category.create({
      newTopics: 20
    })
  ]);

  var siteMapDropdownSelector = "#site-map-dropdown";

  visit("/")
  .then(function() {
    ok(!exists($(siteMapDropdownSelector)), "initially is not rendered");
  })
  .click("#site-map")
  .then(function() {
    var $siteMapDropdown = $(siteMapDropdownSelector);

    ok(exists($siteMapDropdown), "is lazily rendered after user opens it");

    ok(exists($siteMapDropdown.find(".admin-link")), "has showing / hiding admin links correctly bound");
    ok(exists($siteMapDropdown.find(".flagged-posts.badge-notification")), "has displaying flagged posts badge correctly bound");
    equal($siteMapDropdown.find(".faq-link").attr("href"), "faq-url", "is correctly bound to the FAQ url site config");
    notEqual($siteMapDropdown.find(".mobile-toggle-link").text().indexOf("mobile_view"), -1, "has displaying mobile theme toggle link correctly bound");

    ok(exists($siteMapDropdown.find(".category-links")), "has categories correctly bound");
    ok(exists($siteMapDropdown.find(".new-posts")), "has displaying category badges correctly bound");
  });
});

test("search dropdown", function() {
  Discourse.SiteSettings.min_search_term_length = 2;
  Ember.run(function() {
    Discourse.URL_FIXTURES["/search"] = [
      {
        type: "topic",
        more: true,
        results: [
          {
            url: "some-url"
          }
        ]
      }
    ];
  });

  visit("/");
  andThen(function() {
    not(exists("#search-dropdown:visible"), "initially search box is closed");
  });
  click("#search-button");
  andThen(function() {
    ok(exists("#search-dropdown:visible"), "after clicking a button search box opens");
    not(exists("#search-dropdown .heading"), "initially, immediately after opening, search box is empty");
  });
  fillIn("#search-term", "ab");
  andThen(function() {
    ok(exists("#search-dropdown .heading"), "when user completes a search, search box shows search results");
    equal(find("#search-dropdown .selected a").attr("href"), "some-url", "the first search result is selected");
  });
  andThen(function() {
    Discourse.URL_FIXTURES["/search"] = [
      {
        type: "topic",
        more: true,
        results: [
          {
            url: "another-url"
          }
        ]
      }
    ];
  });
  click("#search-dropdown .filter");
  andThen(function() {
    equal(find("#search-dropdown .selected a").attr("href"), "another-url", "after clicking 'more of type' link, results are reloaded");
  });
});

test("user dropdown when logged in", function() {
  expect(3);

  var userDropdownSelector = "#user-dropdown";

  visit("/")
  .then(function() {
    not(exists(userDropdownSelector + ":visible"), "initially user dropdown is closed");
  })
  .click("#current-user")
  .then(function() {
    var $userDropdown = $(userDropdownSelector);

    ok(exists(userDropdownSelector + ":visible"), "is lazily rendered after user opens it");

    ok(exists($userDropdown.find(".user-dropdown-links")), "has showing / hiding user-dropdown links correctly bound");
  });
});
