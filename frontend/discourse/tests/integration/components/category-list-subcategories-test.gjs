import { array } from "@ember/helper";
import { getOwner } from "@ember/owner";
import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CategoriesBoxes from "discourse/components/categories-boxes";
import CategoriesOnly from "discourse/components/categories-only";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | category-list-subcategories",
  function (hooks) {
    setupRenderingTest(hooks);

    function seedNestedCategories(owner) {
      const store = owner.lookup("service:store");
      const site = owner.lookup("service:site");

      const common = {
        color: "0088CC",
        text_color: "FFFFFF",
        description_excerpt: "",
        uploaded_logo: null,
        topic_count: 1,
        post_count: 1,
        stat: "1 topic",
        statTotal: "1 topic",
        statTitle: "1 topic",
      };

      const parent = store.createRecord("category", {
        id: 1001,
        name: "Parent",
        slug: "parent",
        parent_category_id: null,
        ...common,
      });
      const child = store.createRecord("category", {
        id: 1002,
        name: "Child",
        slug: "child",
        parent_category_id: 1001,
        ...common,
      });
      const grandchild = store.createRecord("category", {
        id: 1003,
        name: "Grandchild",
        slug: "grandchild",
        parent_category_id: 1002,
        ...common,
      });

      site.set("categories", [parent, child, grandchild]);
      return { parent, child, grandchild };
    }

    function hideGrandchildren() {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "category-list-subcategories",
          ({ value, context }) => {
            return context.category.level >= 1 ? [] : value;
          }
        );
      });
    }

    // A transformer that only collapses deeper levels when the categories are
    // rendered inside a single category's topic list (the subcategory-list
    // surface), leaving the global /categories page at full depth.
    function hideGrandchildrenOnSubcategoryListSurface() {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "category-list-subcategories",
          ({ value, context }) => {
            if (
              context.surface === "subcategory_list" &&
              context.category.level >= 1
            ) {
              return [];
            }
            return value;
          }
        );
      });
    }

    // The surface is derived from the current route, which a rendering test
    // doesn't have.
    function stubDiscovery(owner) {
      class DiscoveryStub extends Service {
        showingSubcategoryList = false;
      }

      owner.unregister("service:discovery");
      owner.register("service:discovery", DiscoveryStub);
      return owner.lookup("service:discovery");
    }

    test("categories_boxes shows grandchildren by default", async function (assert) {
      const { parent } = seedNestedCategories(getOwner(this));

      await render(
        <template><CategoriesBoxes @categories={{array parent}} /></template>
      );

      assert
        .dom(".category-box[data-category-id='1001']")
        .containsText("Child", "second level is still shown");
      assert
        .dom(".category-box[data-category-id='1001']")
        .containsText(
          "Grandchild",
          "third level grandchildren are shown by default"
        );
    });

    test("categories_boxes hides grandchildren when the transformer prunes deeper levels", async function (assert) {
      hideGrandchildren();
      const { parent } = seedNestedCategories(getOwner(this));

      await render(
        <template><CategoriesBoxes @categories={{array parent}} /></template>
      );

      assert
        .dom(".category-box[data-category-id='1001']")
        .containsText("Child", "second level is still shown");
      assert
        .dom(".category-box[data-category-id='1001']")
        .doesNotContainText(
          "Grandchild",
          "third level grandchildren are hidden"
        );
      assert
        .dom(
          ".category-box[data-category-id='1001'] .subcategory.with-subcategories"
        )
        .doesNotExist(
          "falls back to the simple subcategory list rather than the grandparent layout"
        );
    });

    test("the transformer doesn't affect Category#subcategories", async function (assert) {
      hideGrandchildren();
      const { parent, child } = seedNestedCategories(getOwner(this));

      await render(
        <template><CategoriesBoxes @categories={{array parent}} /></template>
      );

      assert.deepEqual(
        child.subcategories.map((c) => c.id),
        [1003],
        "the model keeps its subcategories for the sidebar and other surfaces"
      );
    });

    test("categories_only shows grandchildren as subcategory rows by default", async function (assert) {
      const { parent } = seedNestedCategories(getOwner(this));

      await render(
        <template><CategoriesOnly @categories={{array parent}} /></template>
      );

      assert
        .dom("tr[data-category-id='1002']")
        .exists("second level is rendered as a subcategory row");
      assert
        .dom("table.category-list")
        .containsText(
          "Grandchild",
          "third level grandchildren are shown by default"
        );
    });

    test("categories_only hides grandchildren when the transformer prunes deeper levels", async function (assert) {
      hideGrandchildren();
      const { parent } = seedNestedCategories(getOwner(this));

      await render(
        <template><CategoriesOnly @categories={{array parent}} /></template>
      );

      assert
        .dom("tr[data-category-id='1002']")
        .doesNotExist(
          "no subcategory rows are needed when grandchildren are hidden"
        );
      assert
        .dom("table.category-list")
        .containsText("Child", "second level is still shown as a simple list");
      assert
        .dom("table.category-list")
        .doesNotContainText(
          "Grandchild",
          "third level grandchildren are hidden"
        );
    });

    test("categories_boxes scope pruning to the subcategory-list surface", async function (assert) {
      hideGrandchildrenOnSubcategoryListSurface();
      const { parent, child } = seedNestedCategories(getOwner(this));

      await render(
        <template><CategoriesBoxes @categories={{array parent}} /></template>
      );
      assert
        .dom(".category-box[data-category-id='1001']")
        .containsText(
          "Grandchild",
          "global /categories page still shows the third level"
        );

      await render(
        <template>
          <CategoriesBoxes
            @categories={{array child}}
            @isSubcategoryList={{true}}
          />
        </template>
      );
      assert
        .dom(".category-box[data-category-id='1002']")
        .containsText("Child", "the subcategory-list surface shows its box");
      assert
        .dom(".category-box[data-category-id='1002']")
        .doesNotContainText(
          "Grandchild",
          "but the same transformer caps the subcategory-list surface at two levels"
        );
    });

    test("categories_only derives the subcategory-list surface from the route", async function (assert) {
      hideGrandchildrenOnSubcategoryListSurface();
      const discovery = stubDiscovery(getOwner(this));
      const { parent, child } = seedNestedCategories(getOwner(this));

      await render(
        <template><CategoriesOnly @categories={{array parent}} /></template>
      );
      assert
        .dom("table.category-list")
        .containsText(
          "Grandchild",
          "global /categories rows still show the third level"
        );

      discovery.showingSubcategoryList = true;

      await render(
        <template><CategoriesOnly @categories={{array child}} /></template>
      );
      assert
        .dom("tr[data-category-id='1002']")
        .exists("the subcategory-list surface renders the row");
      assert
        .dom("table.category-list")
        .doesNotContainText(
          "Grandchild",
          "and caps it at two levels without anything forwarding the surface"
        );
    });
  }
);
