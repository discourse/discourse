import componentTest from "helpers/component-test";
import Category from "discourse/models/category";

moduleForComponent("category-drop", {
  integration: true,
  beforeEach: function() {
    this.set("subject", selectKit());
  }
});

componentTest("subcatgories - no selection", {
  template:
    "{{category-drop onSelect=onSelect category=category parentCategory=parentCategory categories=childCategories subCategory=true noSubcategories=false}}",

  beforeEach() {
    const parentCategory = Category.findById(2);

    const childCategories = this.site.get("categoriesList").filter(c => {
      return c.get("parentCategory") === parentCategory;
    });

    this.set("childCategories", childCategories);
    this.set("parentCategory", parentCategory);
  },

  async test(assert) {
    assert.equal(
      this.get("subject")
        .header()
        .title(),
      I18n.t("categories.all_subcategories")
    );

    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .rowByIndex(0)
        .name(),
      I18n.t("categories.no_subcategory")
    );

    assert.equal(
      this.get("subject")
        .rowByIndex(1)
        .name(),
      this.get("childCategories.firstObject.name")
    );
  }
});

componentTest("subcatgories - selection", {
  template:
    "{{category-drop onSelect=onSelect category=category parentCategory=parentCategory categories=childCategories subCategory=true noSubcategories=false}}",

  beforeEach() {
    const parentCategory = Category.findById(2);

    const childCategories = this.site.get("categoriesList").filter(c => {
      return c.get("parentCategory") === parentCategory;
    });

    this.set("childCategories", childCategories);
    this.set("category", childCategories.get("firstObject"));
    this.set("parentCategory", parentCategory);
  },

  async test(assert) {
    assert.equal(
      this.get("subject")
        .header()
        .title(),
      this.get("childCategories.firstObject.name")
    );

    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .rowByIndex(0)
        .name(),
      I18n.t("categories.all_subcategories")
    );

    assert.equal(
      this.get("subject")
        .rowByIndex(1)
        .name(),
      I18n.t("categories.no_subcategory")
    );
  }
});
