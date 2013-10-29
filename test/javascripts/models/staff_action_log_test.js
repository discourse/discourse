module("Discourse.StaffActionLog");

test("create", function() {
  ok(Discourse.StaffActionLog.create(), "it can be created without arguments");
});