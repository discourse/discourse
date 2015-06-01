moduleForComponent('ace-editor', {integration: true});

test('css editor', function(assert) {
  andThen(() => {
    this.render('{{ace-editor mode="css"}}');
  });
  andThen(() => {
    assert.ok(this.$('.ace_editor').length, 'it renders the ace editor');
  });
});

test('html editor', function(assert) {
  andThen(() => {
    this.render('{{ace-editor mode="html"}}');
  });
  andThen(() => {
    assert.ok(this.$('.ace_editor').length, 'it renders the ace editor');
  });
});
