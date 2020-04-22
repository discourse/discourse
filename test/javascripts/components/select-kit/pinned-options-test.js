import selectKit from "helpers/select-kit-helper";
import componentTest from "helpers/component-test";
import Topic from "discourse/models/topic";

const buildTopic = function(pinned = true) {
  return Topic.create({
    id: 1234,
    title: "Qunit Test Topic",
    deleted: false,
    pinned
  });
};

moduleForComponent("select-kit/pinned-options", {
  integration: true,
  beforeEach: function() {
    this.set("subject", selectKit());
  }
});

componentTest("unpinning", {
  template: "{{pinned-options value=topic.pinned topic=topic}}",

  beforeEach() {
    this.siteSettings.automatically_unpin_topics = false;
    this.set("topic", buildTopic());
  },

  async test(assert) {
    assert.equal(this.subject.header().name(), "pinned");

    await this.subject.expand();
    await this.subject.selectRowByValue("unpinned");

    assert.equal(this.subject.header().name(), "unpinned");
  }
});

componentTest("pinning", {
  template: "{{pinned-options value=topic.pinned topic=topic}}",

  beforeEach() {
    this.siteSettings.automatically_unpin_topics = false;
    this.set("topic", buildTopic(false));
  },

  async test(assert) {
    assert.equal(this.subject.header().name(), "unpinned");

    await this.subject.expand();
    await this.subject.selectRowByValue("pinned");

    assert.equal(this.subject.header().name(), "pinned");
  }
});
