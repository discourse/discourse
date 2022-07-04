import {
  ALL_CATEGORIES_ID,
  NO_CATEGORIES_ID,
} from "select-kit/components/category-drop";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import Category from "discourse/models/category";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { set } from "@ember/object";
import sinon from "sinon";

function initCategories(context) {
  const categories = context.site.categoriesList;
  context.setProperties({
    category: categories.firstObject,
    categories,
  });
}

function initCategoriesWithParentCategory(context) {
  const parentCategory = Category.findById(2);
  const childCategories = context.site.categoriesList.filter((c) => {
    return c.parentCategory === parentCategory;
  });

  context.setProperties({
    parentCategory,
    category: null,
    categories: childCategories,
  });
}

discourseModule(
  "Integration | Component | select-kit/category-drop",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("caretUpIcon", {
      template: hbs`
      {{category-drop
        category=value
        categories=content
      }}
    `,

      async test(assert) {
        const header = this.subject.header().el();

        assert.ok(
          header.querySelector(`.d-icon-caret-right`),
          "it uses the correct default icon"
        );
      },
    });

    componentTest("none", {
      template: hbs`
      {{category-drop
        category=value
        categories=content
      }}
    `,

      async test(assert) {
        const text = this.subject.header().label();
        assert.strictEqual(
          text,
          I18n.t("category.all").toLowerCase(),
          "it uses the noneLabel"
        );
      },
    });

    componentTest("[not staff - TL0] displayCategoryDescription", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
      }}
    `,

      beforeEach() {
        set(this.currentUser, "staff", false);
        set(this.currentUser, "trust_level", 0);

        initCategories(this);
      },

      async test(assert) {
        await this.subject.expand();

        const row = this.subject.rowByValue(this.category.id);
        assert.ok(
          row.el().querySelector(".category-desc"),
          "it shows category description for newcomers"
        );
      },
    });

    componentTest("[not staff - TL1] displayCategoryDescription", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
      }}
    `,

      beforeEach() {
        set(this.currentUser, "moderator", false);
        set(this.currentUser, "admin", false);
        set(this.currentUser, "trust_level", 1);
        initCategories(this);
      },

      async test(assert) {
        await this.subject.expand();

        const row = this.subject.rowByValue(this.category.id);
        assert.notOk(
          row.el().querySelector(".category-desc"),
          "it doesn't shows category description for TL0+"
        );
      },
    });

    componentTest("[staff - TL0] displayCategoryDescription", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
      }}
    `,

      beforeEach() {
        set(this.currentUser, "moderator", true);
        set(this.currentUser, "trust_level", 0);

        initCategories(this);
      },

      async test(assert) {
        await this.subject.expand();

        const row = this.subject.rowByValue(this.category.id);
        assert.notOk(
          row.el().querySelector(".category-desc"),
          "it doesn't show category description for staff"
        );
      },
    });

    componentTest("hideParentCategory (default: false)", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
      }}
    `,

      beforeEach() {
        initCategories(this);
      },

      async test(assert) {
        await this.subject.expand();

        const row = this.subject.rowByValue(this.category.id);
        assert.strictEqual(row.value(), this.category.id.toString());
        assert.strictEqual(this.category.parent_category_id, undefined);
      },
    });

    componentTest("hideParentCategory (true)", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
        options=(hash
          hideParentCategory=true
        )
      }}
    `,

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

        const categoryStatus = childRow.el().querySelector(".category-status");
        assert.ok(categoryStatus.innerText.trim().match(/^spec/));
      },
    });

    componentTest("allow_uncategorized_topics (true)", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
      }}
    `,

      beforeEach() {
        this.siteSettings.allow_uncategorized_topics = true;
        initCategories(this);
      },

      async test(assert) {
        await this.subject.expand();

        const uncategorizedCategoryId = this.site.uncategorized_category_id;
        const row = this.subject.rowByValue(uncategorizedCategoryId);
        assert.ok(row.exists(), "the uncategorized row is showing");
      },
    });

    componentTest("allow_uncategorized_topics (false)", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
      }}
    `,

      beforeEach() {
        this.siteSettings.allow_uncategorized_topics = false;
        initCategories(this);
      },

      async test(assert) {
        await this.subject.expand();

        const uncategorizedCategoryId = this.site.uncategorized_category_id;
        const row = this.subject.rowByValue(uncategorizedCategoryId);
        assert.notOk(row.exists(), "the uncategorized row is not showing");
      },
    });

    componentTest("countSubcategories (default: false)", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
      }}
    `,

      beforeEach() {
        initCategories(this);
      },

      async test(assert) {
        await this.subject.expand();

        const category = Category.findById(7);
        const row = this.subject.rowByValue(category.id);
        const topicCount = row
          .el()
          .querySelector(".topic-count")
          .innerText.trim();

        assert.strictEqual(
          topicCount,
          "× 481",
          "it doesn't include the topic count of subcategories"
        );
      },
    });

    componentTest("countSubcategories (true)", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
        options=(hash
          countSubcategories=true
        )
      }}
    `,

      beforeEach() {
        initCategories(this);
      },

      async test(assert) {
        await this.subject.expand();

        const category = Category.findById(7);
        const row = this.subject.rowByValue(category.id);
        const topicCount = row
          .el()
          .querySelector(".topic-count")
          .innerText.trim();

        assert.strictEqual(
          topicCount,
          "× 584",
          "it includes the topic count of subcategories"
        );
      },
    });

    componentTest("shortcuts:default", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
      }}
    `,

      beforeEach() {
        initCategories(this);
        this.set("category", null);
      },

      async test(assert) {
        await this.subject.expand();

        assert.strictEqual(
          this.subject.rowByIndex(0).value(),
          this.categories.firstObject.id.toString(),
          "Shortcuts are not prepended when no category is selected"
        );
      },
    });

    componentTest("shortcuts:category is set", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
      }}
    `,

      beforeEach() {
        initCategories(this);
      },

      async test(assert) {
        await this.subject.expand();

        assert.strictEqual(
          this.subject.rowByIndex(0).value(),
          ALL_CATEGORIES_ID
        );
      },
    });

    componentTest("shortcuts with parentCategory/subCategory=true:default", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
        options=(hash
          subCategory=true
        )
      }}
    `,

      beforeEach() {
        initCategoriesWithParentCategory(this);
      },

      async test(assert) {
        await this.subject.expand();

        assert.strictEqual(
          this.subject.rowByIndex(0).value(),
          NO_CATEGORIES_ID
        );
      },
    });

    componentTest(
      "shortcuts with parentCategory/subCategory=true:category is selected",
      {
        template: hbs`
        {{category-drop
          category=category
          categories=categories
          parentCategory=parentCategory
          options=(hash
            subCategory=true
          )
        }}
      `,

        beforeEach() {
          initCategoriesWithParentCategory(this);
          this.set("category", this.categories.firstObject);
        },

        async test(assert) {
          await this.subject.expand();

          assert.strictEqual(
            this.subject.rowByIndex(0).value(),
            ALL_CATEGORIES_ID
          );
          assert.strictEqual(
            this.subject.rowByIndex(1).value(),
            NO_CATEGORIES_ID
          );
        },
      }
    );

    componentTest("category url", {
      template: hbs`
      {{category-drop
        category=category
        categories=categories
        parentCategory=parentCategory
      }}
    `,

      beforeEach() {
        initCategoriesWithParentCategory(this);
        sinon.stub(DiscourseURL, "routeTo");
      },

      async test(assert) {
        await this.subject.expand();
        await this.subject.selectRowByValue(26);

        assert.ok(
          DiscourseURL.routeTo.calledWith("/c/feature/spec/26"),
          "it builds a correct URL"
        );
      },
    });
  }
);
