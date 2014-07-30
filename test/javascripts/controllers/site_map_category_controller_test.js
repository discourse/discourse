moduleFor("controller:site-map-category");

test("showBadges", function() {
  sandbox.stub(Discourse.User, "current");
  var controller = this.subject();

  Discourse.User.current.returns(null);
  ok(!controller.get("showBadges"), "returns false when no user is logged in");

  Discourse.User.current.returns({});
  ok(controller.get("showBadges"), "returns true when an user is logged in");
});
