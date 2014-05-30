var controller, view;

var appendView = function() {
  Ember.run(function() {
    view.appendTo(fixture());
  });
};

var noItemsMessageSelector = "div.none";
var itemListSelector = "ul";
var itemSelector = "li";

module("controller:notifications", {
  setup: function() {
    sinon.stub(I18n, "t", function (scope, options) {
      options = options || {};
      return [scope, options.username, options.link].join(" ").trim();
    });

    controller = testController('notifications');

    view = Ember.View.create({
      container: Discourse.__container__,
      controller: controller,
      templateName: "notifications"
    });
  },

  teardown: function() {
    I18n.t.restore();
  }
});

test("mixes in HasCurrentUser", function() {
  ok(Discourse.HasCurrentUser.detect(controller));
});

test("by default uses NotificationController as its item controller", function() {
  equal(controller.get("itemController"), "notification");
});

test("shows proper info when there are no notifications", function() {
  controller.set("content", null);

  appendView();

  ok(exists(fixture(noItemsMessageSelector)), "special 'no notifications' message is displayed");
  equal(fixture(noItemsMessageSelector).text(), "notifications.none", "'no notifications' message contains proper internationalized text");
  equal(count(fixture(itemListSelector)), 0, "a list of notifications is not displayed");
});

test("displays a list of notifications and a 'more' link when there are notifications", function() {
  controller.set("itemController", null);
  controller.set("content", [
    {
      read: false,
      scope: "scope_1",
      username: "username_1",
      link: "link_1"
    },
    {
      read: true,
      scope: "scope_2",
      username: "username_2",
      link: "link_2"
    }
  ]);

  appendView();

  var items = fixture(itemSelector);
  equal(count(items), 3, "number of list items is correct");

  equal(items.eq(0).attr("class"), "ember-view", "first (unread) item has proper class");
  equal(items.eq(0).text().trim(), "scope_1 username_1 link_1", "first item has correct content");

  equal(items.eq(1).attr("class"), "ember-view read", "second (read) item has proper class");
  equal(items.eq(1).text().trim(), "scope_2 username_2 link_2", "second item has correct content");

  var moreLink = items.eq(2).find("> a");
  equal(moreLink.attr("href"), Discourse.User.current().get("path"), "'more' link points to a correct URL");
  equal(moreLink.text(), "notifications.more …", "'more' link has correct text");
});
