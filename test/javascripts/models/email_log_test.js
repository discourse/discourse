module("Discourse.EmailLog");

test("create", function() {
  ok(Discourse.EmailLog.create(), "it can be created without arguments");
});