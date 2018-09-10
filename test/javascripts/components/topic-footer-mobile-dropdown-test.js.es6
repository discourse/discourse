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
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .header()
        .title(),
      "Topic Controls"
    );
    assert.equal(
      this.get("subject")
        .header()
        .value(),
      null
    );
    assert.equal(
      this.get("subject")
        .rowByIndex(0)
        .name(),
      "Bookmark"
    );
    assert.equal(
      this.get("subject")
        .rowByIndex(1)
        .name(),
      "Share"
    );
    assert.notOk(
      this.get("subject")
        .selectedRow()
        .exists(),
      "it doesn’t preselect first row"
    );

    await this.get("subject").selectRowByValue("share");

    assert.equal(this.get("value"), null, "it resets the value");
  }
});
