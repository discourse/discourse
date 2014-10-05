moduleFor("controller:admin-email-index");

test("mixes in Discourse.Presence", function() {
  ok(Discourse.Presence.detect(this.subject()));
});
