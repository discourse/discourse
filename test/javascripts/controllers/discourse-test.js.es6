module("Discourse.Controller");

test("includes mixins", function() {
  ok(Discourse.Presence.detect(Discourse.Controller.create()), "Discourse.Presence");
  ok(Discourse.HasCurrentUser.detect(Discourse.Controller.create()), "Discourse.HasCurrentUser");
});
