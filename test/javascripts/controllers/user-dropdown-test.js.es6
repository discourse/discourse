moduleFor("controller:user-dropdown");

test("logout action logs out the current user", function () {
  const logoutMock = sinon.mock(Discourse, "logout");
  logoutMock.expects("logout").once();

  this.subject().send('logout');

  logoutMock.verify();
});

test("showAdminLinks", function() {
  const currentUser = Ember.Object.create({ staff: true });
  const controller = this.subject({ currentUser });
  equal(controller.get("showAdminLinks"), true, "is true when current user is a staff member");

  currentUser.set("staff", false);
  equal(controller.get("showAdminLinks"), false, "is false when current user is not a staff member");
});
