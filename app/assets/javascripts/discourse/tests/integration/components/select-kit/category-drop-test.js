import { set } from "@ember/object";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import {
  ALL_CATEGORIES_ID,
  NO_CATEGORIES_ID,
} from "select-kit/components/category-drop";

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

module("Integration | Component | select-kit/category-drop", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("caretUpIcon", async function (assert) {
    await render(hbs`
      <CategoryDrop
        @category={{this.value}}
        @categories={{this.content}}
      />
    `);

    assert
      .dom(".d-icon-caret-right", this.subject.header().el())
      .exists("uses the correct default icon");
  });

  test("none", async function (assert) {
    await render(hbs`
      <CategoryDrop
        @category={{this.value}}
        @categories={{this.content}}
      />
    `);

    const text = this.subject.header().label();
    assert.strictEqual(
      text,
      i18n("categories.categories_label"),
      "uses the noneLabel"
    );
  });

  test("[not staff - TL0] displayCategoryDescription", async function (assert) {
    set(this.currentUser, "staff", false);
    set(this.currentUser, "trust_level", 0);

    initCategories(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
      />
    `);

    await this.subject.expand();

    const row = this.subject.rowByValue(this.category.id);
    assert
      .dom(".category-desc", row.el())
      .exists("shows category description for newcomers");
  });

  test("[not staff - TL1] displayCategoryDescription", async function (assert) {
    set(this.currentUser, "moderator", false);
    set(this.currentUser, "admin", false);
    set(this.currentUser, "trust_level", 1);
    initCategories(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
      />
    `);

    await this.subject.expand();

    const row = this.subject.rowByValue(this.category.id);
    assert
      .dom(".category-desc", row.el())
      .doesNotExist("doesn't shows category description for TL0+");
  });

  test("[staff - TL0] displayCategoryDescription", async function (assert) {
    set(this.currentUser, "moderator", true);
    set(this.currentUser, "trust_level", 0);

    initCategories(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
      />
    `);

    await this.subject.expand();

    const row = this.subject.rowByValue(this.category.id);
    assert
      .dom(".category-desc", row.el())
      .doesNotExist("doesn't show category description for staff");
  });

  test("hideParentCategory (default: false)", async function (assert) {
    initCategories(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
      />
    `);

    await this.subject.expand();

    const row = this.subject.rowByValue(this.category.id);
    assert.strictEqual(row.value(), this.category.id.toString());
    assert.strictEqual(this.category.parent_category_id, undefined);
  });

  test("hideParentCategory (true)", async function (assert) {
    initCategoriesWithParentCategory(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
        @options={{hash
          hideParentCategory=true
        }}
      />
    `);

    await this.subject.expand();

    const parentRow = this.subject.rowByValue(this.parentCategory.id);
    assert.false(parentRow.exists(), "the parent row is not showing");

    const childCategory = this.categories.firstObject;
    const childCategoryId = childCategory.id;
    const childRow = this.subject.rowByValue(childCategoryId);
    assert.true(childRow.exists(), "the child row is showing");

    assert.dom(".category-status", childRow.el()).includesText("spec");
  });

  test("allow_uncategorized_topics (true)", async function (assert) {
    this.siteSettings.allow_uncategorized_topics = true;
    initCategories(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
      />
    `);

    await this.subject.expand();

    const uncategorizedCategoryId = this.site.uncategorized_category_id;
    const row = this.subject.rowByValue(uncategorizedCategoryId);
    assert.true(row.exists(), "the uncategorized row is showing");
  });

  test("allow_uncategorized_topics (false)", async function (assert) {
    this.siteSettings.allow_uncategorized_topics = false;
    initCategories(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
      />
    `);

    await this.subject.expand();

    const uncategorizedCategoryId = this.site.uncategorized_category_id;
    const row = this.subject.rowByValue(uncategorizedCategoryId);
    assert.false(row.exists(), "the uncategorized row is not showing");
  });

  test("countSubcategories (default: false)", async function (assert) {
    initCategories(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
      />
    `);

    await this.subject.expand();

    const category = Category.findById(7);
    const row = this.subject.rowByValue(category.id);
    const topicCount = row.el().querySelector(".topic-count").innerText.trim();

    assert.strictEqual(
      topicCount,
      "× 481",
      "doesn't include the topic count of subcategories"
    );
  });

  test("countSubcategories (true)", async function (assert) {
    initCategories(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
        @options={{hash
          countSubcategories=true
        }}
      />
    `);

    await this.subject.expand();

    const category = Category.findById(7);
    const row = this.subject.rowByValue(category.id);
    const topicCount = row.el().querySelector(".topic-count").innerText.trim();

    assert.strictEqual(
      topicCount,
      "× 584",
      "includes the topic count of subcategories"
    );
  });

  test("shortcuts:default", async function (assert) {
    initCategories(this);
    this.set("category", null);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
      />
    `);

    await this.subject.expand();

    assert.strictEqual(
      this.subject.rowByIndex(0).value(),
      this.categories.firstObject.id.toString(),
      "Shortcuts are not prepended when no category is selected"
    );
  });

  test("shortcuts:category is set", async function (assert) {
    initCategories(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
      />
    `);

    await this.subject.expand();

    assert.strictEqual(this.subject.rowByIndex(0).value(), ALL_CATEGORIES_ID);
  });

  test("shortcuts with parentCategory/subCategory=true:default", async function (assert) {
    initCategoriesWithParentCategory(this);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
        @options={{hash
          subCategory=true
        }}
      />
    `);

    await this.subject.expand();

    assert.strictEqual(this.subject.rowByIndex(0).value(), NO_CATEGORIES_ID);
  });

  test("shortcuts with parentCategory/subCategory=true:category is selected", async function (assert) {
    initCategoriesWithParentCategory(this);
    this.set("category", this.categories.firstObject);

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
        @options={{hash
          subCategory=true
        }}
      />
    `);

    await this.subject.expand();

    assert.strictEqual(this.subject.rowByIndex(0).value(), ALL_CATEGORIES_ID);
    assert.strictEqual(this.subject.rowByIndex(1).value(), NO_CATEGORIES_ID);
  });

  test("category url", async function (assert) {
    initCategoriesWithParentCategory(this);
    sinon.stub(DiscourseURL, "routeTo");

    await render(hbs`
      <CategoryDrop
        @category={{this.category}}
        @categories={{this.categories}}
        @parentCategory={{this.parentCategory}}
      />
    `);

    await this.subject.expand();
    await this.subject.selectRowByValue(26);

    assert.true(
      DiscourseURL.routeTo.calledWith("/c/feature/spec/26"),
      "builds a correct URL"
    );
  });
});
