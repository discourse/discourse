module("Discourse.AdminEmailPreviewDigestController");

test("mixes in Discourse.Presence", function() {
  ok(Discourse.Presence.detect(Discourse.AdminEmailPreviewDigestController.create()));
});
