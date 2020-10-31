import { test, module } from "qunit";
import StaffActionLog from "admin/models/staff-action-log";

module("Unit | Model | StaffActionLog", function () {
  test("create", function (assert) {
    assert.ok(StaffActionLog.create(), "it can be created without arguments");
  });
});
