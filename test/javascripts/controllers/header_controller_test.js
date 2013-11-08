var server;

module("Discourse.HeaderController", {
  setup: function() {
    server = sinon.fakeServer.create();
  },

  teardown: function() {
    server.restore();
  }
});

test("showNotifications action", function() {
  var controller = Discourse.HeaderController.create();
  var viewSpy = {
    showDropdownBySelector: sinon.spy()
  };
  Discourse.User.current().set("unread_notifications", 1);
  server.respondWith("/notifications", [200, { "Content-Type": "application/json" }, '["notification"]']);


  Ember.run(function() {
    controller.send("showNotifications", viewSpy);
  });

  equal(controller.get("notifications"), null, "notifications are null before data has finished loading");
  equal(Discourse.User.current().get("unread_notifications"), 1, "current user's unread notifications count is not zeroed before data has finished loading");
  ok(viewSpy.showDropdownBySelector.notCalled, "dropdown with notifications is not shown before data has finished loading");


  server.respond();

  deepEqual(controller.get("notifications"), ["notification"], "notifications are set correctly after data has finished loading");
  equal(Discourse.User.current().get("unread_notifications"), 0, "current user's unread notifications count is zeroed after data has finished loading");
  ok(viewSpy.showDropdownBySelector.calledWith("#user-notifications"), "dropdown with notifications is shown after data has finished loading");
});
