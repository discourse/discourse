var controller;

module("controller:site-map-category", {
  setup: function() {
    controller = testController('site-map-category');
  }
});

test("showBadges", function() {
  this.stub(Discourse.User, "current");

  Discourse.User.current.returns(null);
  ok(!controller.get("showBadges"), "returns false when no user is logged in");

  Discourse.User.current.returns({});
  ok(controller.get("showBadges"), "returns true when an user is logged in");
});
