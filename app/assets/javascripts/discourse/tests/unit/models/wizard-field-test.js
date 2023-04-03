import { getOwner } from "discourse-common/lib/get-owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Model | Wizard | wizard-field", function (hooks) {
  setupTest(hooks);

  test("basic state", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const field = store.createRecord("wizard-field", { type: "text" });
    assert.ok(field.unchecked);
    assert.ok(!field.valid);
    assert.ok(!field.invalid);
  });

  test("text - required - validation", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const field = store.createRecord("wizard-field", {
      type: "text",
      required: true,
    });
    assert.ok(field.unchecked);

    field.check();
    assert.ok(!field.unchecked);
    assert.ok(!field.valid);
    assert.ok(field.invalid);

    field.set("value", "a value");
    field.check();
    assert.ok(!field.unchecked);
    assert.ok(field.valid);
    assert.ok(!field.invalid);
  });

  test("text - optional - validation", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const field = store.createRecord("wizard-field", { type: "text" });
    assert.ok(field.unchecked);

    field.check();
    assert.ok(field.valid);
  });
});
