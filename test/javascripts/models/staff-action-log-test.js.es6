import StaffActionLog from 'admin/models/staff-action-log';

module("StaffActionLog");

test("create", function() {
  ok(StaffActionLog.create(), "it can be created without arguments");
});
