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
    expandSelectBox();

    andThen(() => {
      assert.equal(selectBox().header.name(), "Topic Controls");
      assert.equal(selectBox().rowByIndex(0).name(), "Bookmark");
      assert.equal(selectBox().rowByIndex(1).name(), "Share");
      assert.equal(selectBox().selectedRow.el.length, 0, "it doesn’t preselect first row");
    });

    selectBoxSelectRow("share");

    andThen(() => {
      assert.equal(this.get("value"), null, "it resets the value");
    });
  }
});
