import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import MultipleCategoriesSelector, {
  LIMITED_RESULTS_NOTICE_VALUE,
  MAX_UNSELECTED_RESULTS,
} from "discourse/select-kit/components/multiple-categories-selector";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module(
  "Integration | Component | SelectKit | MultipleCategoriesSelector",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
      this.site = Site.current();
      this.originalCategories = this.site.categories;
    });

    hooks.afterEach(function () {
      this.site.categories = this.originalCategories;
    });

    test("with value", async function (assert) {
      const category = Category.findById(1001);
      const subcategory = Category.findById(1002);
      const value = [category, subcategory];

      await render(
        <template>
          <MultipleCategoriesSelector @categories={{value}} />
        </template>
      );

      assert.strictEqual(this.subject.header().value(), "1001,1002");
      assert.strictEqual(
        this.subject.header().label(),
        "Parent Category, Sub Category"
      );
    });

    test("has +subcategories row", async function (assert) {
      const value = [];

      await render(
        <template>
          <MultipleCategoriesSelector @categories={{value}} />
        </template>
      );
      await this.subject.expand();
      await this.subject.fillInFilter("Parent Category");

      assert.strictEqual(this.subject.rows().length, 2);
      assert
        .dom(this.subject.rowByIndex(0).el())
        .hasText("Parent Category× 95");
      assert
        .dom(this.subject.rowByIndex(1).el())
        .hasText("Parent Category× 95+ Subcategories");
    });

    test("shows a +subcategories row for every matching category with children, without requiring an exact match", async function (assert) {
      const value = [];

      await render(
        <template>
          <MultipleCategoriesSelector @categories={{value}} />
        </template>
      );
      await this.subject.expand();
      await this.subject.fillInFilter("Category");

      assert.strictEqual(this.subject.rows().length, 5);
      assert
        .dom(this.subject.rowByIndex(0).el())
        .hasText("Parent Category× 95");
      assert
        .dom(this.subject.rowByIndex(1).el())
        .hasText("Parent Category× 95+ Subcategories");
      assert
        .dom(this.subject.rowByIndex(2).el())
        .hasText("Parent CategorySub Category× 95");
      assert
        .dom(this.subject.rowByIndex(3).el())
        .hasText(
          "Parent Category+ SubcategoriesSub Category× 95+ Subcategories"
        );
      assert
        .dom(this.subject.rowByIndex(4).el())
        .hasText("Parent CategorySub CategorySub Sub Category× 95");
    });

    test("does not show a +subcategories row for a single-character search", async function (assert) {
      const value = [];

      await render(
        <template>
          <MultipleCategoriesSelector @categories={{value}} />
        </template>
      );
      await this.subject.expand();
      await this.subject.fillInFilter("S");

      assert.dom(this.subject.el()).doesNotIncludeText("+ Subcategories");
    });

    test("selecting +subcategories adds the full descendant tree", async function (assert) {
      this.set("value", []);
      this.set("onChange", (categories) => this.set("value", categories));

      await render(
        <template>
          <MultipleCategoriesSelector
            @categories={{this.value}}
            @onChange={{this.onChange}}
          />
        </template>
      );
      await this.subject.expand();
      await this.subject.fillInFilter("Parent Category");
      await this.subject.selectRowByIndex(1);

      assert.strictEqual(this.subject.header().value(), "1001,1002,1003");
    });

    test("caps unselected results and shows a notice when there are more than the limit", async function (assert) {
      const extraCategories = Array.from(
        { length: MAX_UNSELECTED_RESULTS + 20 },
        (_, i) =>
          Category.create({
            id: 90000 + i,
            name: `Extra Category ${i}`,
            topic_count: 0,
          })
      );
      this.site.categories = [...this.originalCategories, ...extraCategories];

      const value = [];

      await render(
        <template>
          <MultipleCategoriesSelector @categories={{value}} />
        </template>
      );
      await this.subject.expand();

      assert.strictEqual(
        this.subject.rows().length,
        MAX_UNSELECTED_RESULTS + 1,
        "shows the capped number of categories plus the notice row"
      );
      assert.true(
        this.subject.rowByValue(LIMITED_RESULTS_NOTICE_VALUE).exists(),
        "the notice row is rendered"
      );
    });

    test("search reveals categories beyond the cap", async function (assert) {
      const extraCategories = Array.from(
        { length: MAX_UNSELECTED_RESULTS + 20 },
        (_, i) =>
          Category.create({
            id: 90000 + i,
            name: `Extra Category ${i}`,
            topic_count: 0,
          })
      );
      this.site.categories = [...this.originalCategories, ...extraCategories];

      const value = [];

      await render(
        <template>
          <MultipleCategoriesSelector @categories={{value}} />
        </template>
      );
      await this.subject.expand();
      await this.subject.fillInFilter("Extra Category 39");

      assert.strictEqual(
        this.subject.rows().length,
        1,
        "the search matches exactly one category"
      );
      assert.true(
        this.subject.rowByValue(90039).exists(),
        "search finds a category beyond the cap"
      );
    });

    test("no notice when the number of categories is within the limit", async function (assert) {
      const value = [];

      await render(
        <template>
          <MultipleCategoriesSelector @categories={{value}} />
        </template>
      );
      await this.subject.expand();

      assert.false(
        this.subject.rowByValue(LIMITED_RESULTS_NOTICE_VALUE).exists(),
        "no capped-results notice when nothing is capped"
      );
    });
  }
);
