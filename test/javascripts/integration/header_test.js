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
