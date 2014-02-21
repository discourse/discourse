module("Discourse.HeaderController");

test("showNotifications action", function() {

  var controller = Discourse.HeaderController.create();
  var viewSpy = {
    showDropdownBySelector: sinon.spy()
  };
  var latest_notificaiton_id = 2, older_notificaion_id = 1;

  this.stub(Discourse.User, "current").returns(Discourse.User.create({
    id: 1,
    unread_notifications: 1,
    recent_notifications: [{id: older_notificaion_id}, {id: latest_notificaiton_id}]
  }));

  this.stub(Discourse, 'ajax');

  Ember.run(function() {
    controller.send("showNotifications", viewSpy);
  });

  equal(Discourse.User.current().get("unread_notifications"), 0, "current user's unread notifications count is zeroed");
  ok(viewSpy.showDropdownBySelector.calledWith("#user-notifications"), "dropdown with notifications is shown");
  ok(Discourse.ajax.calledWith("/users/1/saw_notification",
    { type: 'PUT', data: { last_notification_id: latest_notificaiton_id } }
  ), "updates the server with the latest seen notificaion");
});
