import componentTest from "helpers/component-test";
import { testSelectKitModule } from "./select-kit-test-helper";

testSelectKitModule("category-chooser");

function template(options = []) {
  return `
    {{category-chooser
      value=value
      options=(hash
        ${options.join("\n")}
      )
    }}
  `;
}

componentTest("with value", {
  template: template(),

  beforeEach() {
    this.set("value", 2);
  },

  async test(assert) {
    assert.equal(this.subject.header().value(), 2);
    assert.equal(this.subject.header().label(), "feature");
  }
});

componentTest("with excludeCategoryId", {
  template: template(["excludeCategoryId=2"]),
  async test(assert) {
    await this.subject.expand();

    assert.notOk(this.subject.rowByValue(2).exists());
  }
});

componentTest("with scopedCategoryId", {
  template: template(["scopedCategoryId=2"]),

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject.rowByIndex(0).title(),
      "Discussion about features or potential features of Discourse: how they work, why they work, etc."
    );
    assert.equal(this.subject.rowByIndex(0).value(), 2);
    assert.equal(
      this.subject.rowByIndex(1).title(),
      "My idea here is to have mini specs for features we would like built but have no bandwidth to build"
    );
    assert.equal(this.subject.rowByIndex(1).value(), 26);
    assert.equal(this.subject.rows().length, 2);

    await this.subject.fillInFilter("spec");

    assert.equal(this.subject.rows().length, 1);
  }
});

componentTest("with allowUncategorized=null", {
  template: template(["allowUncategorized=null"]),

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    assert.equal(this.subject.header().value(), null);
    assert.equal(this.subject.header().label(), "category…");
  }
});

componentTest("with allowUncategorized=null rootNone=true", {
  template: template(["allowUncategorized=null", "none=true"]),

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    assert.equal(this.subject.header().value(), null);
    assert.equal(this.subject.header().label(), "(no category)");
  }
});

componentTest("with disallowed uncategorized, none", {
  template: template(["allowUncategorized=null", "none='test.root'"]),

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { root: "root none label" };
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    assert.equal(this.subject.header().value(), null);
    assert.equal(this.subject.header().label(), "root none label");
  }
});

componentTest("with allowed uncategorized", {
  template: template(["allowUncategorized=true"]),

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    assert.equal(this.subject.header().value(), null);
    assert.equal(this.subject.header().label(), "uncategorized");
  }
});

componentTest("with allowed uncategorized and none=true", {
  template: template(["allowUncategorized=true", "none=true"]),

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    assert.equal(this.subject.header().value(), null);
    assert.equal(this.subject.header().label(), "(no category)");
  }
});

componentTest("with allowed uncategorized and none", {
  template: template(["allowUncategorized=true", "none='test.root'"]),

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { root: "root none label" };
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    assert.equal(this.subject.header().value(), null);
    assert.equal(this.subject.header().label(), "root none label");
  }
});
