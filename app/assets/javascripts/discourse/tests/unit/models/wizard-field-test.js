import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { Field } from "discourse/static/wizard/models/wizard";

module("Unit | Model | Wizard | wizard-field", function (hooks) {
  setupTest(hooks);

  test("basic state", function (assert) {
    const field = new Field({ type: "text" });
    assert.ok(field.unchecked);
    assert.ok(!field.valid);
    assert.ok(!field.invalid);
  });

  test("text - required - validation", function (assert) {
    const field = new Field({ type: "text", required: true });
    assert.ok(field.unchecked);

    field.validate();
    assert.ok(!field.unchecked);
    assert.ok(!field.valid);
    assert.ok(field.invalid);

    field.value = "a value";
    field.validate();
    assert.ok(!field.unchecked);
    assert.ok(field.valid);
    assert.ok(!field.invalid);
  });

  test("text - optional - validation", function (assert) {
    const field = new Field({ type: "text" });
    assert.ok(field.unchecked);

    field.validate();
    assert.ok(field.valid);
  });
});
