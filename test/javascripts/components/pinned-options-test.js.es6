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

moduleForComponent("pinned-options", {
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
    this.set("pinned", true);
  },

  test(assert) {
    andThen(() => {
      assert.equal(
        this.get("subject")
          .header()
          .name(),
        "pinned"
      );
    });

    andThen(() => this.set("pinned", false));

    andThen(() => {
      assert.equal(
        this.get("subject")
          .header()
          .name(),
        "unpinned"
      );
    });
  }
});
