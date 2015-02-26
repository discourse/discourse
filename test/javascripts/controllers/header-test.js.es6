moduleFor("controller:header", "controller:header", {
  needs: ['controller:application']
});

test("showNotifications action", function() {
  let resolveRequestWith;
  const request = new Ember.RSVP.Promise(function(resolve) {
    resolveRequestWith = resolve;
  });

  const currentUser = Discourse.User.create({ unread_notifications: 1});
  const controller = this.subject({ currentUser: currentUser });
  const viewSpy = { showDropdownBySelector: sinon.spy() };

  sandbox.stub(Discourse, "ajax").withArgs("/notifications").returns(request);

  Ember.run(function() {
    controller.send("showNotifications", viewSpy);
  });

  equal(controller.get("notifications"), null, "notifications are null before data has finished loading");
  equal(currentUser.get("unread_notifications"), 1, "current user's unread notifications count is not zeroed before data has finished loading");
  ok(viewSpy.showDropdownBySelector.calledWith("#user-notifications"), "dropdown with loading glyph is shown before data has finished loading");

  Ember.run(function() {
    resolveRequestWith(["notification"]);
  });

  // Can't use deepEquals because controller.get("notifications") is an ArrayProxy, not an Array
  ok(controller.get("notifications").indexOf("notification") !== -1, "notification is in the controller");
  equal(currentUser.get("unread_notifications"), 0, "current user's unread notifications count is zeroed after data has finished loading");
  ok(viewSpy.showDropdownBySelector.calledWith("#user-notifications"), "dropdown with notifications is shown after data has finished loading");
});
