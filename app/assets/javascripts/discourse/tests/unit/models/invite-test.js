import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import { getOwner } from "@ember/application";

module("Unit | Model | invite", function (hooks) {
  setupTest(hooks);

  test("create", function (assert) {
    const store = getOwner(this).lookup("service:store");
    assert.ok(
      store.createRecord("invite"),
      "it can be created without arguments"
    );
  });
});
