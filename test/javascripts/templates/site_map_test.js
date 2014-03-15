var controller;

var setUpController = function(properties) {
  Ember.run(function() {
    controller.setProperties(properties);
  });
};

var appendView = function() {
  Ember.run(function() {
    Discourse.advanceReadiness();
    Ember.View.create({
      container: Discourse.__container__,
      controller: controller,
      templateName: "siteMap"
    }).appendTo(fixture());
  });
};

var locationLinksSelector = ".location-links";
var categoryLinksSelector = ".category-links";

module("Template: site_map", {
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

    controller = Ember.ArrayController.create({
      container: Discourse.__container__
    });
  },

  teardown: function() {
    I18n.t.restore();
  }
});

test("location links part is rendered correctly", function() {
  setUpController({
    showAdminLinks: true,
    flaggedPostsCount: 2,
    faqUrl: "faq-url",
    showMobileToggle: true,
    mobileViewLinkTextKey: "mobile_view_link_text_key"
  });

  appendView();

  var $locationLinks = fixture(locationLinksSelector);

  var $adminLink = $locationLinks.find(".admin-link");
  ok(exists($adminLink), "a link to the admin section is present");
  equal($adminLink.attr("href"), "/admin", "the link to the admin section points to a correct URL");
  notEqual($adminLink.text().indexOf("admin_title"), -1, "the link to the admin section contains correct text");
  ok(exists($adminLink.find(".fa-wrench")), "the link to the admin section contains correct icon");

  var $flaggedPostsLink = $locationLinks.find(".flagged-posts-link");
  ok(exists($flaggedPostsLink), "link to the flagged posts list is present");
  equal($flaggedPostsLink.attr("href"), "/admin/flags/active", "the link to the flagged posts list points to a correct URL");
  notEqual($flaggedPostsLink.text().indexOf("flags_title"), -1, "the link to the flagged posts list contains correct text");
  ok(exists($flaggedPostsLink.find(".fa-flag")), "the link to the flagged posts list contains correct icon");

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
  equal($mobileToggleLink.text().trim(), "mobile_view_link_text_key", "the mobile theme toggle link has correct text");
});

test("binds mobile theme toggle link to the correct controller action", function() {
  this.stub(Ember.Handlebars.helpers, "action", function(actionName) {
    return new Handlebars.SafeString('data-test-stub-action-name="' + actionName + '"');
  });

  setUpController({
    showMobileToggle: true
  });

  appendView();

  equal(fixture(locationLinksSelector).find(".mobile-toggle-link").data("test-stub-action-name"), "toggleMobileView");
});

test("does not show flagged posts badge when there are no flagged posts", function() {
  setUpController({
    showAdminLinks: true,
    flaggedPostsCount: 0
  });

  appendView();

  var $locationLinks = fixture(locationLinksSelector);
  ok(exists($locationLinks.find(".flagged-posts-link")), "primary link to flagged posts list is still shown");
  ok(!exists($locationLinks.find(".flagged-posts.badge-notification")), "badge with the number of flagged posts is not shown");
});

test("does not show any admin links when current user is not a staff member", function() {
  setUpController({
    showAdminLinks: false,
    flaggedPostsCount: 2
  });

  appendView();

  var $locationLinks = fixture(locationLinksSelector);
  ok(!exists($locationLinks.find(".admin-link")), "the link to the admin section is not shown");
  ok(!exists($locationLinks.find(".flagged-posts-link")), "the link to flagged posts list is not shown");
  ok(!exists($locationLinks.find(".flagged-posts.badge-notification")), "the badge with the number of flagged posts is not shown");
});

test("does not show mobile theme toggle link if mobile theme is disabled in configuration", function() {
  setUpController({
    showMobileToggle: false,
    mobileViewLinkTextKey: "mobile_view_link_text_key"
  });

  appendView();

  ok(!exists(fixture(locationLinksSelector).find(".mobile-toggle-link")));
});

var categoryFixture = {
  showBadges: true,
  name: "category name",
  color: "ffffff",
  text_color: "000000",
  slug: "category-slug",
  topic_count: 123,
  description: "category description",
  unreadTopics: 10,
  newTopics: 20
};

test("category links part is rendered correctly", function() {
  setUpController({
    categories: [
      Discourse.Category.create(categoryFixture),
      Discourse.Category.create(categoryFixture)
    ]
  });

  appendView();

  var $categoryLinks = fixture(categoryLinksSelector);

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
  notEqual($firstCategoryNewTopicsLink.text().indexOf("20"), -1, "the new topics link contains correct text");

  var $firstCategoryAllTopicsCount = $categories.first().find(".topics-count");
  ok(!exists($firstCategoryAllTopicsCount), "the count of all topics is not shown");
});

test("categories show the count of all topics instead of new and unread ones when user is not logged in", function() {
  var categoryWithoutBadgesFixture = _.extend({}, categoryFixture, {
    showBadges: false
  });

  setUpController({
    categories: [
      Discourse.Category.create(categoryWithoutBadgesFixture)
    ]
  });

  appendView();

  var $firstCategory = fixture(categoryLinksSelector).find(".category").first();

  var $allTopicsCountTag = $firstCategory.find(".topics-count");
  ok(exists($allTopicsCountTag), "the tag with all topics count is shown");
  equal($allTopicsCountTag.text(), "123", "the tag with all topics count has correct text");

  ok(!exists($firstCategory.find(".unread-posts")), "the unread posts link is not shown");
  ok(!exists($firstCategory.find(".new-posts")), "the new posts link is not shown");
});

test("unread topics link is not shown when there are no unread topics", function() {
  var categoryWithNoUnreadTopicsFixture = _.extend({}, categoryFixture, {
    unreadTopics: 0
  });

  setUpController({
    categories: [
      Discourse.Category.create(categoryWithNoUnreadTopicsFixture)
    ]
  });

  appendView();

  var $firstCategory = fixture(categoryLinksSelector).find(".category").first();
  ok(!exists($firstCategory.find(".unread-posts")));
});

test("new topics link are not shown when there are no new topics", function() {
  var categoryWithNoNewTopicsFixture = _.extend({}, categoryFixture, {
    newTopics: 0
  });

  setUpController({
    categories: [
      Discourse.Category.create(categoryWithNoNewTopicsFixture)
    ]
  });

  appendView();

  var $firstCategory = fixture(categoryLinksSelector).find(".category").first();
  ok(!exists($firstCategory.find(".new-posts")));
});

test("the whole categories section is hidden if there are no categories", function() {
  setUpController({
    categories: []
  });

  appendView();

  ok(!exists(fixture(categoryLinksSelector)));
});
