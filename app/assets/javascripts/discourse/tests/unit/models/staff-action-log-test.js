import { test, module } from "qunit";
import StaffActionLog from "admin/models/staff-action-log";

module("StaffActionLog");

test("create", (assert) => {
  assert.ok(StaffActionLog.create(), "it can be created without arguments");
});
