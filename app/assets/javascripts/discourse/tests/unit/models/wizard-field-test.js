import { module, test } from "qunit";
import WizardField from "wizard/models/wizard-field";

module("Unit | Model | Wizard | wizard-field", function () {
  test("basic state", function (assert) {
    const w = WizardField.create({ type: "text" });
    assert.ok(w.unchecked);
    assert.ok(!w.valid);
    assert.ok(!w.invalid);
  });

  test("text - required - validation", function (assert) {
    const w = WizardField.create({ type: "text", required: true });
    assert.ok(w.unchecked);

    w.check();
    assert.ok(!w.unchecked);
    assert.ok(!w.valid);
    assert.ok(w.invalid);

    w.set("value", "a value");
    w.check();
    assert.ok(!w.unchecked);
    assert.ok(w.valid);
    assert.ok(!w.invalid);
  });

  test("text - optional - validation", function (assert) {
    const f = WizardField.create({ type: "text" });
    assert.ok(f.unchecked);

    f.check();
    assert.ok(f.valid);
  });
});
