import componentTest from 'helpers/component-test';
import Topic from 'discourse/models/topic';

const buildTopic = function() {
  return Topic.create({
    id: 4563,
    title: "Qunit Test Topic",
    details: {
      notification_level: 1
    }
  });
};


moduleForComponent('topic-notifications-button', { integration: true });

componentTest('the header has a localized title', {
  template: '{{topic-notifications-button topic=topic}}',

  beforeEach() {
    this.set("topic", buildTopic());
  },

  test(assert) {
    andThen(() => {
      assert.equal(selectBox().header.name(), "Normal", "it has the correct title");
    });

    andThen(() => {
      this.set("topic.details.notification_level", 2);
      assert.equal(selectBox().header.name(), "Tracking", "it correctly changes the title");
    });
  }
});
