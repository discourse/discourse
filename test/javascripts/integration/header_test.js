var oldMobileView;

integration("Header", {
  setup: function() {
    oldMobileView = Discourse.Mobile.mobileView;

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

    sinon.stub(Discourse.Category, "list").returns([]);

    var originalUser = Discourse.User.current();
    sinon.stub(Discourse.User, "current").returns(originalUser);

    Discourse.reset();
  },

  teardown: function() {
    Discourse.Mobile.mobileView = oldMobileView;
    I18n.t.restore();
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
    equal($items.first().html(), 'notifications.replied velesin <a href="/t/a-slug/1234/2">some title</a>', "correctly generates items' content");
  });
});

var siteMapButtonSelector = "#site-map";
var siteMapDropdownSelector = "#site-map-dropdown";
var locationLinksSelector = siteMapDropdownSelector + " .location-links";
var categoryLinksSelector = siteMapDropdownSelector + " .category-links";

test("sitemap dropdown is lazily loaded", function() {
  expect(2);

  visit("/")
  .then(function() {
    ok(!exists($(siteMapDropdownSelector)), "initially it is not rendered");
  })
  .click(siteMapButtonSelector)
  .then(function() {
    ok(exists($(siteMapDropdownSelector)), "after clicking the button it is rendered");
  });
});

test("sitemap location links part is rendered correctly", function() {
  expect(20);

  Discourse.User.current().staff = true;
  Discourse.User.current().site_flagged_posts_count = 2;
  Discourse.Mobile.mobileView = true;
  Discourse.SiteSettings.faq_url = "faq-url";
  Discourse.SiteSettings.enable_mobile_theme = true;
  Discourse.reset();

  visit("/")
  .click(siteMapButtonSelector)
  .then(function() {
    var $locationLinks = $(locationLinksSelector);

    var $adminLink = $locationLinks.find(".admin-link");
    ok(exists($adminLink), "a link to the admin section is present");
    equal($adminLink.attr("href"), "/admin", "the link to the admin section points to a correct URL");
    equal($adminLink.html(), '<i class="icon icon-wrench"></i>admin_title', "the link to the admin section has correct content");

    var $flaggedPostsLink = $locationLinks.find(".flagged-posts-link");
    ok(exists($flaggedPostsLink), "link to the flagged posts list is present");
    equal($flaggedPostsLink.attr("href"), "/admin/flags/active", "the link to the flagged posts list points to a correct URL");
    equal($flaggedPostsLink.html(), '<i class="icon icon-flag"></i>flags_title', "the link to the flagged posts list has correct content");

    var $flaggedPostsBadge = $locationLinks.find(".flagged-posts.badge-notification");
    ok(exists($flaggedPostsBadge), "a flagged posts badge is present");
    equal($flaggedPostsBadge.attr("href"), "/admin/flags/active", "the flagged posts badge points to a correct URL");
    equal($flaggedPostsBadge.attr("title"), "notifications.total_flagged", "the flagged posts badge has correct title attr");
    equal($flaggedPostsBadge.text(), "2", "the flagged posts badge has correct text");

    var $latestTopicsLink = $locationLinks.find(".latest-topics-link");
    ok(exists($latestTopicsLink), "the latest topics link is present");
    equal($latestTopicsLink.attr("href"), "/", "the latest topics link points to a correct URL");
    equal($latestTopicsLink.attr("title"), "filters.latest.help", "the latest topics link has correct title attr");
    equal($latestTopicsLink.text(), "filters.latest.title", "the latest topics link has correct text");

    var $faqLink = $locationLinks.find(".faq-link");
    ok(exists($faqLink), "the FAQ link is present");
    equal($faqLink.attr("href"), "faq-url", "the FAQ link points to a correct URL");
    equal($faqLink.text(), "faq", "the FAQ link has correct text");

    var $mobileToggleLink = $locationLinks.find(".mobile-toggle-link");
    ok(exists($mobileToggleLink), "the mobile theme toggle link is present");
    equal($mobileToggleLink.attr("href"), "#", "the mobile theme toggle link has correct href attr");
    equal($mobileToggleLink.text().trim(), "desktop_view", "the mobile theme toggle link has correct text");
  });
});

test("sitemap does not show flagged posts badge when there are no flagged posts", function() {
  expect(2);

  Discourse.User.current().staff = true;
  Discourse.User.current().site_flagged_posts_count = 0;
  Discourse.reset();

  visit("/")
  .click(siteMapButtonSelector)
  .then(function() {
    var $locationLinks = $(locationLinksSelector);
    ok(exists($locationLinks.find(".flagged-posts-link")), "primary link to flagged posts list is still shown");
    ok(!exists($locationLinks.find(".flagged-posts.badge-notification")), "badge with the number of flagged posts is not shown");
  });
});

test("sitemap does not show any admin links when current user is not a staff member", function() {
  expect(3);

  Discourse.User.current().staff = false;
  Discourse.reset();

  visit("/")
  .click(siteMapButtonSelector)
  .then(function() {
    var $locationLinks = $(locationLinksSelector);
    ok(!exists($locationLinks.find(".admin-link")), "the link to the admin section is not shown");
    ok(!exists($locationLinks.find(".flagged-posts-link")), "the link to flagged posts list is not shown");
    ok(!exists($locationLinks.find(".flagged-posts.badge-notification")), "the badge with the number of flagged posts is not shown");
  });
});

test("sitemap does not show mobile theme toggle link if mobile theme is disabled in configuration", function() {
  expect(1);

  Discourse.Mobile.mobileView = false;
  Discourse.SiteSettings.enable_mobile_theme = false;
  Discourse.reset();

  visit("/")
  .click(siteMapButtonSelector)
  .then(function() {
    ok(!exists($(locationLinksSelector).find(".mobile-toggle-link")));
  });
});

test("sitemap's mobile theme toggle link's text changes according to the current configuration (mobile/desktop)", function() {
  expect(1);

  Discourse.SiteSettings.enable_mobile_theme = true;
  Discourse.Mobile.mobileView = false;
  Discourse.reset();

  visit("/")
  .click(siteMapButtonSelector)
  .then(function() {
    ok($(locationLinksSelector).find(".mobile-toggle-link").is(":contains(mobile_view)"));
  });
});

test("sitemap hides the whole categories section if there are no categories", function() {
  expect(1);

  visit("/")
    .click(siteMapButtonSelector)
    .then(function() {
      ok(!exists($(categoryLinksSelector)));
    });
});

var categoryFixture = {
  name: "category name",
  color: "ffffff",
  text_color: "000000",
  slug: "category-slug",
  topic_count: 123,
  description: "category description",
  unreadTopics: 10,
  newTopics: 20
};

test("sitemap category links part is rendered correctly", function() {
  // TODO this magic number is kind of crazytown, we can't expect people to keep updating it as they add
  //  assertions
  expect(22);

  Discourse.Category.list.returns([
    Discourse.Category.create(categoryFixture),
    Discourse.Category.create(categoryFixture)
  ]);

  visit("/")
  .click(siteMapButtonSelector)
  .then(function() {
    var $categoryLinks = $(categoryLinksSelector);

    var $heading = $categoryLinks.find(".heading");
    ok(exists($heading), "a categories list heading exists");
    equal($heading.attr("title"), "filters.categories.help", "categories list heading has correct title attr");

    var $allCategoriesLink = $heading.find("a");
    ok(exists($allCategoriesLink), "an 'all categories' link exists");
    equal($allCategoriesLink.attr("href"), "/categories", "the 'all categories' link points to a correct URL");
    equal($allCategoriesLink.text(), "filters.categories.title", "the 'all categories' link has correct text");

    var $categories = $categoryLinks.find(".category");
    equal(count($categories), 2, "the number of categories is correct");

    var $firstCategoryLink = $categories.first().find(".badge-category");
    ok(exists($firstCategoryLink), "a category item contains a category link");
    equal($firstCategoryLink.attr("href"), "/category/category-slug", "the category link points to a correct URL");
    equal($firstCategoryLink.attr("title"), "category description", "the category link has correct title attr");
    equal($firstCategoryLink.css("color"), "rgb(0, 0, 0)", "the category link has correct color css rule set");
    equal($firstCategoryLink.css("background-color"), "rgb(255, 255, 255)", "the category link has correct background-color css rule set");
    equal($firstCategoryLink.text(), "category name", "the category link has correct text");

    var $firstCategoryUnreadTopicsLink = $categories.first().find(".unread-posts");
    ok(exists($firstCategoryUnreadTopicsLink), "a category item contains current user unread topics link");
    equal($firstCategoryUnreadTopicsLink.attr("href"), "/category/category-slug/l/unread", "the unread topics link points to a correct URL");
    ok($firstCategoryUnreadTopicsLink.hasClass("badge") && $firstCategoryUnreadTopicsLink.hasClass("badge-notification"), "the unread topics link has correct classes");
    equal($firstCategoryUnreadTopicsLink.attr("title"), "topic.unread_topics 10", "the unread topics link has correct title");
    equal($firstCategoryUnreadTopicsLink.text(), "10", "the unread topics link has correct text");

    var $firstCategoryNewTopicsLink = $categories.first().find(".new-posts");
    ok(exists($firstCategoryNewTopicsLink), "a category item contains current user new topics link");
    equal($firstCategoryNewTopicsLink.attr("href"), "/category/category-slug/l/new", "the new topics link points to a correct URL");
    ok($firstCategoryNewTopicsLink.hasClass("badge") && $firstCategoryNewTopicsLink.hasClass("badge-notification"), "the new topics link has correct classes");
    equal($firstCategoryNewTopicsLink.attr("title"), "topic.new_topics 20", "the new topics link has correct title");
    // TODO: assertion too fragile, breaks when node is bound
    //equal($firstCategoryNewTopicsLink.html(), '20 <i class="icon icon-asterisk"></i>', "the new topics link has correct content");

    var $firstCategoryAllTopicsCount = $categories.first().find(".topics-count");
    ok(!exists($firstCategoryAllTopicsCount), "the count of all topics is not shown");
  });
});

test("sitemap's categories show the count of all topics instead of new and unread ones when user is not logged in", function() {
  expect(4);

  Discourse.Category.list.returns([
    Discourse.Category.create(categoryFixture)
  ]);
  Discourse.User.current.returns(null);

  visit("/")
  .click(siteMapButtonSelector)
  .then(function() {
    var $firstCategory = $(categoryLinksSelector).find(".category").first();

    var $allTopicsCountTag = $firstCategory.find(".topics-count");
    ok(exists($allTopicsCountTag), "the tag with all topics count is shown");
    equal($allTopicsCountTag.text(), "123", "the tag with all topics count has correct text");

    ok(!exists($firstCategory.find(".unread-posts")), "the unread posts link is not shown");
    ok(!exists($firstCategory.find(".new-posts")), "the new posts link is not shown");
  });
});

test("sitemap does not show unread and new topic links when there are no such topics", function() {
  expect(2);

  var categoryWithNoUnreadAndNewTopicsFixture = _.extend({}, categoryFixture, {
    unreadTopics: 0,
    newTopics: 0
  });
  Discourse.Category.list.returns([
    Discourse.Category.create(categoryWithNoUnreadAndNewTopicsFixture)
  ]);

  visit("/")
  .click(siteMapButtonSelector)
  .then(function() {
    var $firstCategory = $(categoryLinksSelector).find(".category").first();
    ok(!exists($firstCategory.find(".unread-posts")), "there is no unread topics link");
    ok(!exists($firstCategory.find(".new-posts")), "there is no new topics link");
  });
});
