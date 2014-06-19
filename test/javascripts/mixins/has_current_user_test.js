module("Discourse.HasCurrentUser");

test("adds `currentUser` property to an object and ensures it is not cached", function() {
  this.stub(Discourse.User, "current");
  var testObj = Ember.Object.createWithMixins(Discourse.HasCurrentUser, {});

  Discourse.User.current.returns("first user");
  equal(testObj.get("currentUser"), "first user", "on the first call property returns initial user");

  Discourse.User.current.returns("second user");
  equal(testObj.get("currentUser"), "second user", "if the user changes, on the second call property returns changed user");
});
