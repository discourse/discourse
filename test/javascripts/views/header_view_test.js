module("Discourse.HeaderView");

test("showNotifications", function() {
  var controllerSpy = {
    send: sinon.spy()
  };
  var view = viewClassFor('header').create({
    controller: controllerSpy
  });

  view.showNotifications();

  ok(controllerSpy.send.calledWith("showNotifications", view), "sends showNotifications message to the controller, passing header view as a param");
});
