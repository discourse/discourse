import componentTest from 'helpers/component-test';

moduleForComponent('post-menu', {integration: true});

componentTest('render buttons', {
  template: "{{post-menu post=post}}",
  setup(store) {
    const topic = store.createRecord('topic', {id: 123});
    this.set('post', store.createRecord('post', {id: 1, post_number: 1, topic}));
  },
  test(assert) {
    assert.ok(this.$('.post-menu-area').length, 'it renders a post menu');
  }
});
