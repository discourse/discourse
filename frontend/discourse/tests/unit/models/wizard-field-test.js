import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { Field } from "discourse/static/wizard/models/wizard";

module("Unit | Model | Wizard | wizard-field", function (hooks) {
  setupTest(hooks);

  test("basic state", function (assert) {
    const field = new Field({ type: "text" });
    assert.true(field.unchecked);
    assert.false(field.valid);
    assert.false(field.invalid);
  });

  test("text - required - validation", function (assert) {
    const field = new Field({ type: "text", required: true });
    assert.true(field.unchecked);

    field.validate();
    assert.false(field.unchecked);
    assert.false(field.valid);
    assert.true(field.invalid);

    field.value = "a value";
    field.validate();
    assert.false(field.unchecked);
    assert.true(field.valid);
    assert.false(field.invalid);
  });

  test("text - optional - validation", function (assert) {
    const field = new Field({ type: "text" });
    assert.true(field.unchecked);

    field.validate();
    assert.true(field.valid);
  });
});
