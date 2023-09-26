import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";

module("Unit | Model | staff-action-log", function (hooks) {
  setupTest(hooks);

  test("create", function (assert) {
    const store = getOwnerWithFallback(this).lookup("service:store");
    assert.ok(
      store.createRecord("staff-action-log"),
      "it can be created without arguments"
    );
  });
});
