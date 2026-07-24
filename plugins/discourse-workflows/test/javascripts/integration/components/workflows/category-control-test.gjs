import { tracked } from "@glimmer/tracking";
import { render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import CategoryControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/category-control";

class TestField {
  @tracked value;

  constructor(value) {
    this.value = value;
  }

  set(newValue) {
    this.value = newValue;
  }
}

function regularCategories() {
  return Category.list().filter(
    (category) => !category.isUncategorizedCategory
  );
}

module(
  "Integration | Component | Workflows | CategoryControl",
  function (hooks) {
    setupRenderingTest(hooks);

    test("stores one category id string by default", async function (assert) {
      this.field = new TestField("");

      await render(
        <template>
          <CategoryControl
            @field={{this.field}}
            @supportsExpression={{false}}
          />
        </template>
      );

      const category = regularCategories()[0];
      const chooser = selectKit(".category-chooser");
      await chooser.expand();
      await chooser.selectRowByValue(category.id);

      assert.strictEqual(this.field.value, String(category.id));
    });

    test("stores an array of category ids when configured as multiple", async function (assert) {
      this.field = new TestField([]);
      this.schema = { type: "array", ui: { multiple: true } };

      await render(
        <template>
          <CategoryControl
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{false}}
          />
        </template>
      );

      const [first, second] = regularCategories();
      const selector = selectKit(".category-selector");

      await selector.expand();
      await selector.selectRowByValue(first.id);

      assert.deepEqual(this.field.value, [first.id]);

      await selector.selectRowByValue(second.id);

      assert.deepEqual(this.field.value, [first.id, second.id]);
    });

    test("hydrates selected categories from stored ids", async function (assert) {
      const category = regularCategories()[0];
      this.field = new TestField([category.id]);
      this.schema = { type: "array", ui: { multiple: true } };

      await render(
        <template>
          <CategoryControl
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{false}}
          />
        </template>
      );

      await waitFor(
        `.category-selector .select-kit-header[data-value='${category.id}']`
      );

      assert.strictEqual(
        selectKit(".category-selector").header().value(),
        String(category.id)
      );
    });

    test("ignores non-numeric stored entries when hydrating", async function (assert) {
      const category = regularCategories()[0];
      this.field = new TestField(["=$json.category_ids", category.id]);
      this.schema = { type: "array", ui: { multiple: true } };

      await render(
        <template>
          <CategoryControl
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{false}}
          />
        </template>
      );

      await waitFor(
        `.category-selector .select-kit-header[data-value='${category.id}']`
      );

      assert.strictEqual(
        selectKit(".category-selector").header().value(),
        String(category.id)
      );
    });
  }
);
