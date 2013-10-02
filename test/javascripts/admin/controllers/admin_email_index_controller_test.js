module("Discourse.AdminEmailIndexController");

test("mixes in Discourse.Presence", function() {
  ok(Discourse.Presence.detect(Discourse.AdminEmailIndexController.create()));
});
