import StaffActionLog from "admin/models/staff-action-log";

QUnit.module("StaffActionLog");

QUnit.test("create", assert => {
  assert.ok(StaffActionLog.create(), "it can be created without arguments");
});
