moduleFor("controller:user-dropdown");

test("showAdminLinks", function() {
  const currentUser = Ember.Object.create({ staff: true });
  const controller = this.subject({ currentUser });
  equal(controller.get("showAdminLinks"), true, "is true when current user is a staff member");

  currentUser.set("staff", false);
  equal(controller.get("showAdminLinks"), false, "is false when current user is not a staff member");
});
