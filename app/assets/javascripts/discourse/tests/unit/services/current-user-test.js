import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("current-user", function (needs) {
  needs.user();

  test("currentUser has appEvents", function (assert) {
    let currentUser = this.container.lookup("service:current-user");
    assert.ok(currentUser.appEvents);
  });
});
