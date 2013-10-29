module("Discourse.Notification");

test("create", function() {
  ok(Discourse.Notification.create(), "it can be created without arguments");
});