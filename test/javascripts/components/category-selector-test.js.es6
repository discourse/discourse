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
    andThen(() => {
      assert.equal(
        this.get("subject")
          .header()
          .value(),
        2
      );
      assert.notOk(
        this.get("subject")
          .rowByValue(2)
          .exists(),
        "selected categories are not in the list"
      );
    });
  }
});

componentTest("with blacklist", {
  template: "{{category-selector categories=categories blacklist=blacklist}}",

  beforeEach() {
    this.set("categories", [Category.findById(2)]);
    this.set("blacklist", [Category.findById(8)]);
  },

  test(assert) {
    this.get("subject").expand();

    andThen(() => {
      assert.ok(
        this.get("subject")
          .rowByValue(6)
          .exists(),
        "not blacklisted categories are in the list"
      );
      assert.notOk(
        this.get("subject")
          .rowByValue(8)
          .exists(),
        "blacklisted categories are not in the list"
      );
    });
  }
});

componentTest("interactions", {
  template: "{{category-selector categories=categories}}",

  beforeEach() {
    this.set("categories", [Category.findById(2), Category.findById(6)]);
  },

  test(assert) {
    this.get("subject")
      .expand()
      .selectRowByValue(8);

    andThen(() => {
      assert.equal(
        this.get("subject")
          .header()
          .value(),
        "2,6,8",
        "it adds the selected category"
      );
      assert.equal(this.get("categories").length, 3);
    });

    this.get("subject").expand();
    this.get("subject")
      .keyboard()
      .backspace();
    this.get("subject")
      .keyboard()
      .backspace();

    andThen(() => {
      assert.equal(
        this.get("subject")
          .header()
          .value(),
        "2,6",
        "it removes the last selected category"
      );
      assert.equal(this.get("categories").length, 2);
    });
  }
});
