module("Discourse.Invite");

test("create", function() {
  ok(Discourse.Invite.create(), "it can be created without arguments");
});