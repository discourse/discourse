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

moduleForComponent('pinned-options', { integration: true });

componentTest('updating the content refreshes the list', {
  template: '{{pinned-options value=pinned topic=topic}}',

  beforeEach() {
    this.siteSettings.automatically_unpin_topics = false;
    this.set("topic", buildTopic());
    this.set("pinned", true);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => assert.equal(selectKit().header.name(), "Pinned") );

    andThen(() => this.set("pinned", false));

    andThen(() => {
      assert.equal(selectKit().header.name(), "Unpinned");
    });
  }
});
