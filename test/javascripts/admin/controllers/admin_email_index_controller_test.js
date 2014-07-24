module("controller:admin-email-index");

test("mixes in Discourse.Presence", function() {
  ok(Discourse.Presence.detect(controllerFor("admin-email-index")));
});
