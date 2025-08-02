import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Model | staff-action-log", function (hooks) {
  setupTest(hooks);

  test("create", function (assert) {
    const store = getOwner(this).lookup("service:store");
    assert.true(
      !!store.createRecord("staff-action-log"),
      "can be created without arguments"
    );
  });

  test("useModalForDetails - should return true when details is > 100 characters long", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const model = store.createRecord("staff-action-log", {
      details: "a".repeat(101),
    });
    assert.true(
      model.useModalForDetails,
      "should return true when details is > 100 characters long"
    );

    model.set("details", "a".repeat(100));
    assert.false(
      model.useModalForDetails,
      "should return false when details is <= 100 characters long"
    );
  });

  test("useModalForDetails - should return true when details includes a \n", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const model = store.createRecord("staff-action-log", {
      details: "important information\nthat doesn't exceed the limit",
    });
    assert.true(
      model.useModalForDetails,
      "should return true when details includes a newline character"
    );
  });
});
