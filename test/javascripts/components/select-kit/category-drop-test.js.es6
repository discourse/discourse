import Category from "discourse/models/category";
import componentTest from "helpers/component-test";
import { testSelectKitModule } from "./select-kit-test-helper";
import {
  NO_CATEGORIES_ID,
  ALL_CATEGORIES_ID
} from "select-kit/components/category-drop";
import { set } from "@ember/object";

testSelectKitModule("category-drop");

function initCategories(context) {
  const categories = context.site.categoriesList;
  context.setProperties({
    category: categories.firstObject,
    categories
  });
}

function initCategoriesWithParentCategory(context) {
  const parentCategory = Category.findById(2);
  const childCategories = context.site.categoriesList.filter(c => {
    return c.parentCategory === parentCategory;
  });

  context.setProperties({
    parentCategory,
    category: null,
    categories: childCategories
  });
}

function template(options = []) {
  return `
    {{category-drop
      category=category
      categories=categories
      parentCategory=parentCategory
      options=(hash
        ${options.join("\n")}
      )
    }}
  `;
}

componentTest("caretUpIcon", {
  template: `
    {{category-drop
      category=value
      categories=content
    }}
  `,

  async test(assert) {
    const $header = this.subject.header().el();

    assert.ok(
      exists($header.find(`.d-icon-caret-right`)),
      "it uses the correct default icon"
    );
  }
});

componentTest("none", {
  template: `
    {{category-drop
      category=value
      categories=content
    }}
  `,

  async test(assert) {
    const text = this.subject.header().label();
    assert.equal(
      text,
      I18n.t("category.all").toLowerCase(),
      "it uses the noneLabel"
    );
  }
});

componentTest("[not staff - TL0] displayCategoryDescription", {
  template: template(),

  beforeEach() {
    set(this.currentUser, "staff", false);
    set(this.currentUser, "trustLevel", 0);

    initCategories(this);
  },

  async test(assert) {
    await this.subject.expand();

    const row = this.subject.rowByValue(this.category.id);
    assert.ok(
      exists(row.el().find(".category-desc")),
      "it shows category description for newcomers"
    );
  }
});

componentTest("[not staff - TL1] displayCategoryDescription", {
  template: template(),

  beforeEach() {
    set(this.currentUser, "staff", false);
    set(this.currentUser, "trustLevel", 1);

    initCategories(this);
  },

  async test(assert) {
    await this.subject.expand();

    const row = this.subject.rowByValue(this.category.id);
    assert.ok(
      exists(row.el().find(".category-desc")),
      "it doesn't show category description for TL0+"
    );
  }
});

componentTest("[staff - TL0] displayCategoryDescription", {
  template: template(),

  beforeEach() {
    set(this.currentUser, "staff", true);
    set(this.currentUser, "trustLevel", 0);

    initCategories(this);
  },

  async test(assert) {
    await this.subject.expand();

    const row = this.subject.rowByValue(this.category.id);
    assert.ok(
      exists(row.el().find(".category-desc")),
      "it doesn't show category description for staff"
    );
  }
});

componentTest("hideParentCategory (default: false)", {
  template: template(),

  beforeEach() {
    initCategories(this);
  },

  async test(assert) {
    await this.subject.expand();

    const row = this.subject.rowByValue(this.category.id);
    assert.equal(row.value(), this.category.id);
    assert.equal(this.category.parent_category_id, null);
  }
});

componentTest("hideParentCategory (true)", {
  template: template(["hideParentCategory=true"]),

  beforeEach() {
    initCategoriesWithParentCategory(this);
  },

  async test(assert) {
    await this.subject.expand();

    const parentRow = this.subject.rowByValue(this.parentCategory.id);
    assert.notOk(parentRow.exists(), "the parent row is not showing");

    const childCategory = this.categories.firstObject;
    const childCategoryId = childCategory.id;
    const childRow = this.subject.rowByValue(childCategoryId);
    assert.ok(childRow.exists(), "the child row is showing");

    const $categoryStatus = childRow.el().find(".category-status");
    assert.ok(
      $categoryStatus
        .text()
        .trim()
        .match(/^spec/)
    );
  }
});

componentTest("allowUncategorized (default: true)", {
  template: template(),

  beforeEach() {
    initCategories(this);
  },

  async test(assert) {
    await this.subject.expand();

    const uncategorizedCategoryId = this.site.uncategorized_category_id;
    const row = this.subject.rowByValue(uncategorizedCategoryId);
    assert.ok(row.exists(), "the uncategorized row is showing");
  }
});

componentTest("allowUncategorized (false)", {
  template: template(["allowUncategorized=false"]),

  beforeEach() {
    initCategories(this);
  },

  async test(assert) {
    await this.subject.expand();

    const uncategorizedCategoryId = this.site.uncategorized_category_id;
    const row = this.subject.rowByValue(uncategorizedCategoryId);
    assert.notOk(row.exists(), "the uncategorized row is not showing");
  }
});

componentTest("countSubcategories (default: false)", {
  template: template(),

  beforeEach() {
    initCategories(this);
  },

  async test(assert) {
    await this.subject.expand();

    const category = Category.findById(7);
    const row = this.subject.rowByValue(category.id);
    const topicCount = row
      .el()
      .find(".topic-count")
      .text()
      .trim();

    assert.equal(
      topicCount,
      "× 481",
      "it doesn't include the topic count of subcategories"
    );
  }
});

componentTest("countSubcategories (true)", {
  template: template(["countSubcategories=true"]),

  beforeEach() {
    initCategories(this);
  },

  async test(assert) {
    await this.subject.expand();

    const category = Category.findById(7);
    const row = this.subject.rowByValue(category.id);
    const topicCount = row
      .el()
      .find(".topic-count")
      .text()
      .trim();

    assert.equal(
      topicCount,
      "× 584",
      "it includes the topic count of subcategories"
    );
  }
});

componentTest("shortcuts:default", {
  template: template(),

  beforeEach() {
    initCategories(this);
    this.set("category", null);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject.rowByIndex(0).value(),
      this.categories.firstObject.id,
      "Shortcuts are not prepended when no category is selected"
    );
  }
});

componentTest("shortcuts:category is set", {
  template: template(),

  beforeEach() {
    initCategories(this);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(this.subject.rowByIndex(0).value(), ALL_CATEGORIES_ID);
  }
});

componentTest("shortcuts with parentCategory/subCategory=true:default", {
  template: template(["subCategory=true"]),

  beforeEach() {
    initCategoriesWithParentCategory(this);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(this.subject.rowByIndex(0).value(), NO_CATEGORIES_ID);
  }
});

componentTest(
  "shortcuts with parentCategory/subCategory=true:category is selected",
  {
    template: template(["subCategory=true"]),

    beforeEach() {
      initCategoriesWithParentCategory(this);
      this.set("category", this.categories.firstObject);
    },

    async test(assert) {
      await this.subject.expand();

      assert.equal(this.subject.rowByIndex(0).value(), ALL_CATEGORIES_ID);
      assert.equal(this.subject.rowByIndex(1).value(), NO_CATEGORIES_ID);
    }
  }
);
