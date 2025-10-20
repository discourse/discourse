import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("current-user", function (needs) {
  needs.user();

  test("currentUser has appEvents", function (assert) {
    let currentUser = this.container.lookup("service:current-user");
    assert.notStrictEqual(currentUser.appEvents, undefined);
  });
});
