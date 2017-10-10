import componentTest from 'helpers/component-test';
import Topic from 'discourse/models/topic';

const buildTopic = function() {
  return Topic.create({
    id: 1234,
    title: "Qunit Test Topic",
    deleted: false,
    pinned: true
  });
};

moduleForComponent('pinned-button', { integration: true });

componentTest('updating the content refreshes the list', {
  template: '{{pinned-button topic=topic}}',

  beforeEach() {
    this.siteSettings.automatically_unpin_topics = false;
    this.set("topic", buildTopic());
  },

  test(assert) {
    andThen(() => assert.notOk(selectBox().isHidden) );

    expandSelectBox();

    andThen(() => assert.equal(selectBox().selectedRow.name(), "Pinned") );

    andThen(() => {
      this.set("topic.pinned", false);
      assert.equal(selectBox().selectedRow.name(), "Unpinned");
    });

    andThen(() => {
      this.set("topic.deleted", true);
      assert.ok(find(".pinned-button").hasClass("is-hidden"), "it hides the button when topic is deleted");
    });
  }
});
