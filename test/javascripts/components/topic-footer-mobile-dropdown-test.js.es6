import componentTest from 'helpers/component-test';
import Topic from 'discourse/models/topic';

const buildTopic = function() {
  return Topic.create({
    id: 1234,
    title: 'Qunit Test Topic'
  });
};

moduleForComponent('topic-footer-mobile-dropdown', {integration: true});

componentTest('default', {
  template: '{{topic-footer-mobile-dropdown topic=topic}}',
  beforeEach() {
    this.set("topic", buildTopic());
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().header.name(), "Topic Controls");
      assert.equal(selectKit().rowByIndex(0).name(), "Bookmark");
      assert.equal(selectKit().rowByIndex(1).name(), "Share");
      assert.equal(selectKit().selectedRow.el.length, 0, "it doesn’t preselect first row");
    });

    selectKitSelectRow("share");

    andThen(() => {
      assert.equal(this.get("value"), null, "it resets the value");
    });
  }
});
