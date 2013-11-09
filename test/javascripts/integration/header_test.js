integration("Header", {
  setup: function() {
    sinon.stub(I18n, "t", function(scope, options) {
      if (options) {
        return [scope, options.username, options.link].join(" ").trim();
      }
      return scope;
    });
    Discourse.reset();
  },

  teardown: function() {
    I18n.t.restore();
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

var notificationsDropdown = function() {
  return Ember.$("#notifications-dropdown");
};

var notificationFixture = [
  {
    notification_type: 1, //mentioned
    read: false,
    created_at: "2013-11-03T12:12:12-04:00",
    post_number: 1, //post number == 1 means no number included in URL
    topic_id: 1234,
    slug: "some-topic-title",
    data: {
      topic_title: "Some topic title",
      display_username: "velesin"
    }
  },
  {
    notification_type: 2, //replied
    read: true,
    created_at: "2013-11-02T10:10:10-04:00",
    post_number: 2, //post number > 1 means number is included in URL
    topic_id: 1234,
    slug: "", //no slug == differently formatted URL (hardcoded 'topic/' segment instead of slug)
    data: {
      topic_title: "Some topic title",
      display_username: "velesin"
    }
  },
  {
    notification_type: 5, //liked
    read: true,
    created_at: "2013-11-01T11:11:11-04:00",
    post_number: 2,
    topic_id: 1234,
    slug: "some-topic-title",
    data: {
      topic_title: "", //no title == link URL should be empty
      display_username: "velesin"
    }
  }
];

test("notifications: flow", function() {
  expect(8);

  Ember.run(function() {
    Discourse.URL_FIXTURES["/notifications"] = [notificationFixture[0]];
    Discourse.User.current().set("unread_notifications", 1);
  });

  visit("/")
    .then(function() {
      equal(notificationsDropdown().find("ul").length, 0, "initially a list of notifications is not loaded");
      equal(notificationsDropdown().find("div.none").length, 1, "initially special 'no notifications' message is displayed");
      equal(notificationsDropdown().find("div.none").text(), "notifications.none", "'no notifications' message contains proper internationalized text");
      equal(Discourse.User.current().get("unread_notifications"), 1, "initially current user's unread notification count is not reset");
    })
    .click("#user-notifications")
    .then(function() {
      equal(notificationsDropdown().find("li").length, 2, "after user opens notifications dropdown, notifications are loaded");
      equal(Discourse.User.current().get("unread_notifications"), 0, "after user opens notifications dropdown, current user's notification count is zeroed");
    })
    .then(function() {
      Ember.run(function() {
        Discourse.URL_FIXTURES["/notifications"] = [notificationFixture[0], notificationFixture[1]];
        Discourse.User.current().set("unread_notifications", 1);
      });
    })
    .click("#user-notifications")
    .then(function() {
      equal(notificationsDropdown().find("li").length, 3, "when user opens notifications dropdown for the second time, notifications are reloaded afresh");
      equal(Discourse.User.current().get("unread_notifications"), 0, "when user opens notifications dropdown for the second time, current user's notification count is zeroed again");
    });
});

test("notifications: when there are no notifications", function() {
  expect(3);

  Discourse.URL_FIXTURES["/notifications"] = [];

  visit("/")
  .click("#user-notifications")
  .then(function() {
    equal(notificationsDropdown().find("ul").length, 0, "a list of notifications is not displayed");
    equal(notificationsDropdown().find("div.none").length, 1, "special 'no notifications' message is displayed");
    equal(notificationsDropdown().find("div.none").text(), "notifications.none", "'no notifications' message contains proper internationalized text");
  });
});

test("notifications: content", function() {
  expect(9);

  Ember.run(function() {
    Discourse.URL_FIXTURES["/notifications"] = notificationFixture;
    Discourse.User.current().set("unread_notifications", 2);
  });

  visit("/")
    .click("#user-notifications")
    .then(function() {
      equal(notificationsDropdown().find("li").length, 4, "dropdown contains list items for all notifications plus for additional 'more' link");

      equal(notificationsDropdown().find("li").eq(0).attr("class"), "", "list item for unread notification has no class");
      equal(notificationsDropdown().find("li").eq(0).html(), 'notifications.mentioned velesin <a href="/t/some-topic-title/1234">Some topic title</a>', "notification with a slug and for the first post in a topic is rendered correctly");

      equal(notificationsDropdown().find("li").eq(1).attr("class"), "read", "list item for read notification has correct class");
      equal(notificationsDropdown().find("li").eq(1).html(), 'notifications.replied velesin <a href="/t/topic/1234/2">Some topic title</a>', "notification without a slug and for a non-first post in a topic is rendered correctly");

      equal(notificationsDropdown().find("li").eq(2).html(), 'notifications.liked velesin <a href=""></a>', "notification without topic title is rendered correctly");

      equal(notificationsDropdown().find("li").eq(3).attr("class"), "read last", "list item for 'more' link has correct class");
      equal(notificationsDropdown().find("li").eq(3).find("a").attr("href"), Discourse.User.current().get("path"), "'more' link points to a correct URL");
      equal(notificationsDropdown().find("li").eq(3).find("a").text(), "notifications.more" + " …", "'more' link has correct text");
    });
});
