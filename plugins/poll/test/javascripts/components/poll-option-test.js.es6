import componentTest from 'helpers/component-test';
moduleForComponent('poll-option', { integration: true });

componentTest('test poll option', {
  template: '{{poll-option option=option isMultiple=isMultiple}}',

  setup(store) {
    this.set('option', Em.Object.create({ id: 1, selected: false }));
  },

  test(assert) {
    assert.ok(this.$('li .fa-circle-o:eq(0)').length === 1);

    this.set('option.selected', true);

    assert.ok(this.$('li .fa-dot-circle-o:eq(0)').length === 1);

    this.set('isMultiple', true);

    assert.ok(this.$('li .fa-check-square-o:eq(0)').length === 1);

    this.set('option.selected', false);

    assert.ok(this.$('li .fa-square-o:eq(0)').length === 1);
  }
});
