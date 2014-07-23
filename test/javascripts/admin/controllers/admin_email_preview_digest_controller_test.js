module("controller:admin-email-preview-digest");

test("mixes in Discourse.Presence", function() {
  ok(Discourse.Presence.detect(controllerFor("admin-email-preview-digest")));
});
