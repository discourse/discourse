import WizardField from "wizard/models/wizard-field";
import { moduleFor } from "ember-qunit";
import { test } from "qunit";

moduleFor("model:wizard-field");

test("basic state", function (assert) {
  const w = WizardField.create({ type: "text" });
  assert.ok(w.get("unchecked"));
  assert.ok(!w.get("valid"));
  assert.ok(!w.get("invalid"));
});

test("text - required - validation", function (assert) {
  const w = WizardField.create({ type: "text", required: true });
  assert.ok(w.get("unchecked"));

  w.check();
  assert.ok(!w.get("unchecked"));
  assert.ok(!w.get("valid"));
  assert.ok(w.get("invalid"));

  w.set("value", "a value");
  w.check();
  assert.ok(!w.get("unchecked"));
  assert.ok(w.get("valid"));
  assert.ok(!w.get("invalid"));
});

test("text - optional - validation", function (assert) {
  const f = WizardField.create({ type: "text" });
  assert.ok(f.get("unchecked"));

  f.check();
  assert.ok(f.get("valid"));
});
