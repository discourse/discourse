import componentTest from 'helpers/component-test';

moduleForComponent('ace-editor', {integration: true});

componentTest('css editor', {
  template: '{{ace-editor mode="css"}}',
  test(assert) {
    expect(1);
    assert.ok(this.$('.ace_editor').length, 'it renders the ace editor');
  }
});

componentTest('html editor', {
  template: '{{ace-editor mode="html" content="<b>wat</b>"}}',
  test(assert) {
    expect(1);
    assert.ok(this.$('.ace_editor').length, 'it renders the ace editor');
  }
});
