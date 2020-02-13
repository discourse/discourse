import selectKit from "helpers/select-kit-helper";
import componentTest from "helpers/component-test";
import Topic from "discourse/models/topic";

const buildTopic = function() {
  return Topic.create({
    id: 1234,
    title: "Qunit Test Topic",
    deleted: false,
    pinned: true
  });
};

moduleForComponent("select-kit/pinned-options", {
  integration: true,
  beforeEach: function() {
    this.set("subject", selectKit());
  }
});

componentTest("updating the content refreshes the list", {
  template: "{{pinned-options value=pinned topic=topic}}",

  beforeEach() {
    this.siteSettings.automatically_unpin_topics = false;
    this.set("topic", buildTopic());
    this.set("pinned", "pinned");
  },

  async test(assert) {
    assert.equal(this.subject.header().name(), "pinned");

    // we do it manually as clearPin is an ajax call
    await this.set("pinned", false);

    assert.equal(this.subject.header().name(), "unpinned");
  }
});
