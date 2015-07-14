import componentTest from 'helpers/component-test';

moduleForComponent('ace-editor', {integration: true});

componentTest('css editor', {
  template: '{{ace-editor mode="css"}}',
  test(assert) {
    assert.ok(this.$('.ace_editor').length, 'it renders the ace editor');
  }
});

componentTest('html editor', {
  template: '{{ace-editor mode="html"}}',
  test(assert) {
    assert.ok(this.$('.ace_editor').length, 'it renders the ace editor');
  }
});
