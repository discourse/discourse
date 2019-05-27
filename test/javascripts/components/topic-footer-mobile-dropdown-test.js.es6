import componentTest from "helpers/component-test";
import Topic from "discourse/models/topic";

const buildTopic = function() {
  return Topic.create({
    id: 1234,
    title: "Qunit Test Topic"
  });
};

moduleForComponent("topic-footer-mobile-dropdown", {
  integration: true,
  beforeEach: function() {
    this.set("subject", selectKit());
  }
});

componentTest("default", {
  template: "{{topic-footer-mobile-dropdown topic=topic}}",
  beforeEach() {
    this.set("topic", buildTopic());
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .header()
        .title(),
      "Topic Controls"
    );
    assert.equal(
      this.subject
        .header()
        .value(),
      null
    );
    assert.notOk(
      this.subject
        .selectedRow()
        .exists(),
      "it doesn’t preselect first row"
    );
  }
});
