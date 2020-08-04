import I18n from "I18n";
import componentTest from "helpers/component-test";
import { testSelectKitModule } from "helpers/select-kit-helper";

testSelectKitModule("mini-tag-chooser");

function template() {
  return `{{mini-tag-chooser value=value}}`;
}

componentTest("displays tags", {
  template: template(),

  beforeEach() {
    this.set("value", ["foo", "bar"]);
  },

  async test(assert) {
    assert.equal(this.subject.header().value(), "foo,bar");
  }
});

componentTest("create a tag", {
  template: template(),

  beforeEach() {
    this.set("value", ["foo", "bar"]);
  },

  async test(assert) {
    assert.equal(this.subject.header().value(), "foo,bar");

    await this.subject.expand();
    await this.subject.fillInFilter("mon");
    assert.equal(
      find(".select-kit-row")
        .text()
        .trim(),
      "monkey x1"
    );
    await this.subject.fillInFilter("key");
    assert.equal(
      find(".select-kit-row")
        .text()
        .trim(),
      "monkey x1"
    );
    await this.subject.keyboard("enter");

    assert.equal(this.subject.header().value(), "foo,bar,monkey");
  }
});

componentTest("max_tags_per_topic", {
  template: template(),

  beforeEach() {
    this.set("value", ["foo", "bar"]);
    this.siteSettings.max_tags_per_topic = 2;
  },

  async test(assert) {
    assert.equal(this.subject.header().value(), "foo,bar");

    await this.subject.expand();
    await this.subject.fillInFilter("baz");
    await this.subject.keyboard("enter");

    const error = find(".select-kit-error").text();
    assert.equal(
      error,
      I18n.t("select_kit.max_content_reached", {
        count: this.siteSettings.max_tags_per_topic
      })
    );
  }
});
