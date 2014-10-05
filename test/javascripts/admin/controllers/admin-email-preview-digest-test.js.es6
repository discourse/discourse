moduleFor("controller:admin-email-preview-digest");

test("mixes in Discourse.Presence", function() {
  ok(Discourse.Presence.detect(this.subject()));
});
