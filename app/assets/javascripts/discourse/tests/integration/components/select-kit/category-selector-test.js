import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module(
  "Integration | Component | select-kit/category-selector",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("with value", async function (assert) {
      const category = Category.findById(1001);
      const subcategory = Category.findById(1002);
      this.set("value", [category, subcategory]);

      await render(hbs`
        <CategorySelector
          @categories={{this.value}}
        />
      `);

      assert.strictEqual(this.subject.header().value(), "1001,1002");
      assert.strictEqual(
        this.subject.header().label(),
        "Parent Category, Sub Category"
      );
    });

    test("has +subcategories row", async function (assert) {
      this.set("value", []);

      await render(hbs`
        <CategorySelector
          @categories={{this.value}}
        />
      `);
      await this.subject.expand();
      await this.subject.fillInFilter("Parent Category");

      assert.strictEqual(this.subject.rows().length, 2);
      assert.strictEqual(
        this.subject.rowByIndex(0).el().innerText.replace("\n", " "),
        "Parent Category × 95"
      );
      assert.strictEqual(
        this.subject.rowByIndex(1).el().innerText.replaceAll("\n", " "),
        "Parent Category × 95 +2 subcategories"
      );
    });
  }
);
