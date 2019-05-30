import componentTest from "helpers/component-test";
import Category from "discourse/models/category";

moduleForComponent("category-selector", {
  integration: true,
  beforeEach: function() {
    this.set("subject", selectKit());
  }
});

componentTest("default", {
  template: "{{category-selector categories=categories}}",

  beforeEach() {
    this.set("categories", [Category.findById(2)]);
  },

  test(assert) {
    assert.equal(this.subject.header().value(), 2);
    assert.notOk(
      this.subject.rowByValue(2).exists(),
      "selected categories are not in the list"
    );
  }
});

componentTest("with blacklist", {
  template: "{{category-selector categories=categories blacklist=blacklist}}",

  beforeEach() {
    this.set("categories", [Category.findById(2)]);
    this.set("blacklist", [Category.findById(8)]);
  },

  async test(assert) {
    await this.subject.expand();

    assert.ok(
      this.subject.rowByValue(6).exists(),
      "not blacklisted categories are in the list"
    );
    assert.notOk(
      this.subject.rowByValue(8).exists(),
      "blacklisted categories are not in the list"
    );
  }
});

componentTest("interactions", {
  template: "{{category-selector categories=categories}}",

  beforeEach() {
    this.set("categories", [Category.findById(2), Category.findById(6)]);
  },

  skip: true,
  async test(assert) {
    await this.subject.expand();
    await this.subject.selectRowByValue(8);

    assert.equal(
      this.subject.header().value(),
      "2,6,8",
      "it adds the selected category"
    );
    assert.equal(this.categories.length, 3);

    await this.subject.expand();

    await this.subject.keyboard("backspace");
    await this.subject.keyboard("backspace");

    assert.equal(
      this.subject.header().value(),
      "2,6",
      "it removes the last selected category"
    );
    assert.equal(this.categories.length, 2);
  }
});
