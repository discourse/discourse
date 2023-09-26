import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";

module("Unit | Model | invite", function (hooks) {
  setupTest(hooks);

  test("create", function (assert) {
    const store = getOwnerWithFallback(this).lookup("service:store");
    assert.ok(
      store.createRecord("invite"),
      "it can be created without arguments"
    );
  });
});
