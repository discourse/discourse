import { moduleForWidget, widgetTest } from "helpers/widget-test";
moduleForWidget("discourse-poll-standard-results");

const template = `{{mount-widget
                    widget="discourse-poll-standard-results"
                    args=(hash poll=poll isMultiple=isMultiple)}}`;

widgetTest("options in descending order", {
  template,

  beforeEach() {
    this.set(
      "poll",
      Ember.Object.create({
        options: [{ votes: 5 }, { votes: 4 }],
        voters: 9
      })
    );
  },

  test(assert) {
    assert.equal(this.$(".option .percentage:eq(0)").text(), "56%");
    assert.equal(this.$(".option .percentage:eq(1)").text(), "44%");
  }
});

widgetTest("options in ascending order", {
  template,

  beforeEach() {
    this.set(
      "poll",
      Ember.Object.create({
        options: [{ votes: 4 }, { votes: 5 }],
        voters: 9
      })
    );
  },

  test(assert) {
    assert.equal(this.$(".option .percentage:eq(0)").text(), "56%");
    assert.equal(this.$(".option .percentage:eq(1)").text(), "44%");
  }
});

widgetTest("multiple options in descending order", {
  template,

  beforeEach() {
    this.set("isMultiple", true);
    this.set(
      "poll",
      Ember.Object.create({
        type: "multiple",
        options: [
          { votes: 5, html: "a" },
          { votes: 2, html: "b" },
          { votes: 4, html: "c" },
          { votes: 1, html: "b" },
          { votes: 1, html: "a" }
        ],
        voters: 12
      })
    );
  },

  test(assert) {
    assert.equal(this.$(".option .percentage:eq(0)").text(), "41%");
    assert.equal(this.$(".option .percentage:eq(1)").text(), "33%");
    assert.equal(this.$(".option .percentage:eq(2)").text(), "16%");
    assert.equal(this.$(".option .percentage:eq(3)").text(), "8%");
    assert.equal(this.$(".option span:nth-child(2):eq(3)").text(), "a");
    assert.equal(this.$(".option .percentage:eq(4)").text(), "8%");
    assert.equal(this.$(".option span:nth-child(2):eq(4)").text(), "b");
  }
});
