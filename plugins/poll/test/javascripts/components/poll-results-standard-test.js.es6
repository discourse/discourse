import componentTest from 'helpers/component-test';
moduleForComponent('poll-results-standard', { integration: true });

componentTest('options in descending order', {
  template: '{{poll-results-standard poll=poll}}',

  setup(store) {
    this.set('poll', {
      options: [Em.Object.create({ votes: 5 }), Em.Object.create({ votes: 4 })],
      voters: 9
    });
  },

  test(assert) {
    assert.equal(this.$('.option .percentage:eq(0)').text(), '56%');
    assert.equal(this.$('.option .percentage:eq(1)').text(), '44%');
  }
});

componentTest('options in ascending order', {
  template: '{{poll-results-standard poll=poll sortResults=sortResults}}',

  setup() {
    this.set('poll', {
      options: [Em.Object.create({ votes: 4 }), Em.Object.create({ votes: 5 })],
      voters: 9
    });
  },

  test(assert) {
    assert.equal(this.$('.option .percentage:eq(0)').text(), '56%');
    assert.equal(this.$('.option .percentage:eq(1)').text(), '44%');
  }
});

componentTest('multiple options in descending order', {
  template: '{{poll-results-standard poll=poll}}',

  setup(store) {
    this.set('poll', {
      type: 'multiple',
      options: [Em.Object.create({ votes: 5 }), Em.Object.create({ votes: 4 })],
      voters: 9
    });
  },

  test(assert) {
    assert.equal(this.$('.option .percentage:eq(0)').text(), '55%');
    assert.equal(this.$('.option .percentage:eq(1)').text(), '44%');
  }
});
