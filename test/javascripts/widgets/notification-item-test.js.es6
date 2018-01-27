import { moduleForWidget, widgetTest } from 'helpers/widget-test';

moduleForWidget('notification-item');

const externalUrl = 'https://somedomain.com/some-url';

widgetTest('notification-item with external url', {
  template: '{{mount-widget widget="notification-item" args=args}}',

  beforeEach() {
    const args = {
      created_at: '2018-01-25T14:32:52.290Z',
      data: {
        topic_title: 'A title',
        message: 'liked',
        external_url: externalUrl,
        display_username: 'aaron'
      },
      id: 2655820,
      notification_type: 14
    }

    this.set('args', Ember.Object.create(args));
  },

  test(assert) {
    assert.ok(this.$().find('a').attr('href') == externalUrl);
  }
});