import { mapRoutes } from "discourse/mapping-router";
import createStore from "helpers/create-store";

moduleFor("controller:reorder-categories", "controller:reorder-categories", {
  beforeEach() {
    this.registry.register("router:main", mapRoutes());
  },
  needs: ["controller:modal"]
});

QUnit.test("fixIndices set unique position number", function(assert) {
  const store = createStore();

  const categories = [];
  for (let i = 0; i < 3; ++i) {
    categories.push(store.createRecord("category", { id: i, position: 0 }));
  }

  const site = Ember.Object.create({ categories: categories });
  const reorderCategoriesController = this.subject({ site });

  reorderCategoriesController.fixIndices();

  reorderCategoriesController
    .get("categoriesOrdered")
    .forEach((category, index) => {
      assert.equal(category.get("position"), index);
    });
});

QUnit.test(
  "fixIndices places subcategories after their parent categories, while maintaining the relative order",
  function(assert) {
    const store = createStore();

    const parent = store.createRecord("category", {
      id: 1,
      position: 1,
      slug: "parent"
    });
    const child1 = store.createRecord("category", {
      id: 2,
      position: 3,
      slug: "child1",
      parent_category_id: 1
    });
    const child2 = store.createRecord("category", {
      id: 3,
      position: 0,
      slug: "child2",
      parent_category_id: 1
    });
    const other = store.createRecord("category", {
      id: 4,
      position: 2,
      slug: "other"
    });

    const categories = [child2, parent, other, child1];
    const expectedOrderSlugs = ["parent", "child2", "child1", "other"];

    const site = Ember.Object.create({ categories: categories });
    const reorderCategoriesController = this.subject({ site });

    reorderCategoriesController.fixIndices();

    assert.deepEqual(
      reorderCategoriesController.get("categoriesOrdered").mapBy("slug"),
      expectedOrderSlugs
    );
  }
);
