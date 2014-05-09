module("controller:header", "Header Controller");

test("showNotifications action", function() {
  var resolveRequestWith;
  var request = new Ember.RSVP.Promise(function(resolve) {
    resolveRequestWith = resolve;
  });


  var controller = controllerFor('header');
  var viewSpy = {
    showDropdownBySelector: sinon.spy()
  };
  this.stub(Discourse, "ajax").withArgs("/notifications").returns(request);
  this.stub(Discourse.User, "current").returns(Discourse.User.create({
    unread_notifications: 1
  }));


  Ember.run(function() {
    controller.send("showNotifications", viewSpy);
  });

  equal(controller.get("notifications"), null, "notifications are null before data has finished loading");
  equal(Discourse.User.current().get("unread_notifications"), 1, "current user's unread notifications count is not zeroed before data has finished loading");
  ok(viewSpy.showDropdownBySelector.calledWith("#user-notifications"), "dropdown with loading glyph is shown before data has finished loading");


  Ember.run(function() {
    resolveRequestWith(["notification"]);
  });

  deepEqual(controller.get("notifications"), ["notification"], "notifications are set correctly after data has finished loading");
  equal(Discourse.User.current().get("unread_notifications"), 0, "current user's unread notifications count is zeroed after data has finished loading");
  ok(viewSpy.showDropdownBySelector.calledWith("#user-notifications"), "dropdown with notifications is shown after data has finished loading");
});
