module("Discourse.UserDropdownController");

test("logout action logs out the current user", function () {
  var logout_mock = sinon.mock(Discourse, "logout");
  logout_mock.expects("logout").once();

  var controller = Discourse.UserDropdownController.create();
  controller.send("logout");

  logout_mock.verify();
});

test("showAdminLinks", function() {
  var currentUserStub = Ember.Object.create();
  this.stub(Discourse.User, "current").returns(currentUserStub);

  var controller = Discourse.UserDropdownController.create();
  currentUserStub.set("staff", true);
  equal(controller.get("showAdminLinks"), true, "is true when current user is a staff member");

  currentUserStub.set("staff", false);
  equal(controller.get("showAdminLinks"), false, "is false when current user is not a staff member");
});
