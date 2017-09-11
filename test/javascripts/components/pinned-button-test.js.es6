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
    andThen(() => {
      assert.equal(find(".pinned-button").hasClass("is-hidden"), false);
    });

    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-row.is-selected .title").html().trim(), "Pinned");
    });

    andThen(() => {
      this.set("topic.pinned", false);
      assert.equal(find(".select-box-row.is-selected .title").html().trim(), "Unpinned");
    });

    andThen(() => {
      this.set("topic.deleted", true);
      assert.equal(find(".pinned-button").hasClass("is-hidden"), true);
    });
  }
});
