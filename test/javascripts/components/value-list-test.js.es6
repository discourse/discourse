import componentTest from 'helpers/component-test';
moduleForComponent('value-list', {integration: true});

componentTest('functionality', {
  template: '{{value-list value=values}}',
  test: function(assert) {
    andThen(() => {
      assert.ok(this.$('.values .value').length === 0, 'it has no values');
      assert.ok(this.$('input').length, 'it renders the input');
      assert.ok(this.$('.btn-primary[disabled]').length, 'it is disabled with no value');
    });

    fillIn('input', 'eviltrout');
    andThen(() => {
      assert.ok(!this.$('.btn-primary[disabled]').length, "it isn't disabled anymore");
    });

    click('.btn-primary');
    andThen(() => {
      assert.ok(this.$('.values .value').length === 1, 'it adds the value');
      assert.ok(this.$('input').val() === '', 'it clears the input');
      assert.ok(this.$('.btn-primary[disabled]').length, "it is disabled again");
    });

    click('.value .btn-small');
    andThen(() => {
      assert.ok(this.$('.values .value').length === 0, 'it removes the value');
    });
  }
});
