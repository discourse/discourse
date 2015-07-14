import componentTest from 'helpers/component-test';

moduleForComponent('post-menu', {integration: true});

function setup(store) {
  const topic = store.createRecord('topic', {id: 123});
  const post = store.createRecord('post', {
    id: 1,
    post_number: 1,
    topic,
    like_count: 3,
    actions_summary: [
      {id: 2, count: 3, hidden: false, can_act: true}
    ]
  });

  this.on('toggleLike', function() {
    post.toggleProperty('likeAction.acted');
  });

  this.set('post', post);
}

componentTest('basic render', {
  template: '{{post-menu post=post}}',
  setup,
  test(assert) {
    assert.ok(!!this.$('.post-menu-area').length, 'it renders a post menu');
    assert.ok(!!this.$('.actions button[data-share-url]').length, 'it renders a share button');
  }
});

componentTest('liking', {
  template: '{{post-menu post=post toggleLike="toggleLike"}}',
  setup,
  test(assert) {
    assert.ok(!!this.$('.actions button.like').length);
    assert.ok(!!this.$('.actions button.like-count').length);

    click('.actions button.like');
    andThen(() => {
      assert.ok(!this.$('.actions button.like').length);
      assert.ok(!!this.$('.actions button.has-like').length);
    });

    click('.actions button.has-like');
    andThen(() => {
      assert.ok(!!this.$('.actions button.like').length);
      assert.ok(!this.$('.actions button.has-like').length);
    });
  }
});
