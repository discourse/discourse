import { moduleForWidget, widgetTest } from 'helpers/widget-test';
moduleForWidget('discourse-poll-option');

const template = `{{mount-widget
                    widget="discourse-poll-option"
                    args=(hash option=option isMultiple=isMultiple vote=vote)}}`;

widgetTest('single, not selected', {
  template,

  setup() {
    this.set('option', { id: 'opt-id' });
    this.set('vote', []);
  },

  test(assert) {
    assert.ok(find('li .fa-circle-o:eq(0)').length === 1);
  }
});

widgetTest('single, selected', {
  template,

  setup() {
    this.set('option', { id: 'opt-id' });
    this.set('vote', ['opt-id']);
  },

  test(assert) {
    assert.ok(find('li .fa-dot-circle-o:eq(0)').length === 1);
  }
});

widgetTest('multi, not selected', {
  template,

  setup() {
    this.setProperties({
      option: { id: 'opt-id' },
      isMultiple: true,
      vote: []
    });
  },

  test(assert) {
    assert.ok(find('li .fa-square-o:eq(0)').length === 1);
  }
});

widgetTest('multi, selected', {
  template,

  setup() {
    this.setProperties({
      option: { id: 'opt-id' },
      isMultiple: true,
      vote: ['opt-id']
    });
  },

  test(assert) {
    assert.ok(find('li .fa-check-square-o:eq(0)').length === 1);
  }
});
