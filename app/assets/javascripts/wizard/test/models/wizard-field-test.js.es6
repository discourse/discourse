import WizardField from 'wizard/models/wizard-field';

module("model:wizard-field");

test('basic state', assert => {
  const w = WizardField.create({ type: 'text' });
  assert.ok(w.get('unchecked'));
  assert.ok(!w.get('valid'));
  assert.ok(!w.get('invalid'));
});

test('text - required - validation', assert => {
  const w = WizardField.create({ type: 'text', required: true });
  assert.ok(w.get('unchecked'));

  w.check();
  assert.ok(!w.get('unchecked'));
  assert.ok(!w.get('valid'));
  assert.ok(w.get('invalid'));

  w.set('value', 'a value');
  w.check();
  assert.ok(!w.get('unchecked'));
  assert.ok(w.get('valid'));
  assert.ok(!w.get('invalid'));
});

test('text - optional - validation', assert => {
  const w = WizardField.create({ type: 'text' });
  assert.ok(w.get('unchecked'));

  w.check();
  assert.ok(w.get('valid'));
});
