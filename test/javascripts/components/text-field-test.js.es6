import componentTest from 'helpers/component-test';

moduleForComponent("text-field", { integration: true });

componentTest("renders correctly with no properties set", {
  template: `{{text-field}}`,

  test(assert) {
    assert.ok(this.$('input[type=text]').length);
  }
});

componentTest("support a placeholder", {
  template: `{{text-field placeholderKey="placeholder.i18n.key"}}`,

  setup() {
    sandbox.stub(I18n, "t").returnsArg(0);
  },

  test(assert) {
    assert.ok(this.$('input[type=text]').length);
    assert.equal(this.$('input').prop('placeholder'), 'placeholder.i18n.key');
  }
});
