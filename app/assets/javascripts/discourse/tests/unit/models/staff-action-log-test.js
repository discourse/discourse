import { module, test } from "qunit";
import StaffActionLog from "admin/models/staff-action-log";

module("Unit | Model | staff-action-log", function () {
  test("create", function (assert) {
    assert.ok(StaffActionLog.create(), "it can be created without arguments");
  });
});
