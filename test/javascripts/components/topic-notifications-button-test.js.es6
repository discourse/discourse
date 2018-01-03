import componentTest from 'helpers/component-test';
import Topic from 'discourse/models/topic';

const buildTopic = function(level) {
  return Topic.create({
    id: 4563,
    title: "Qunit Test Topic",
    details: {
      notification_level: level
    }
  });
};

moduleForComponent('topic-notifications-button', { integration: true });

componentTest('the header has a localized title', {
  template: '{{topic-notifications-button notificationLevel=topic.details.notification_level topic=topic}}',

  beforeEach() {
    this.set("topic", buildTopic(1));
  },

  test(assert) {
    andThen(() => {
      assert.equal(selectKit().header().name(), "Normal", "it has the correct title");
    });

    this.set("topic", buildTopic(2));

    andThen(() => {
      assert.equal(selectKit().header().name(), "Tracking", "it correctly changes the title");
    });
  }
});
