import EmberObject from "@ember/object";
import { mapRoutes } from "discourse/mapping-router";
import createStore from "helpers/create-store";

moduleFor("controller:reorder-categories", "controller:reorder-categories", {
  beforeEach() {
    this.registry.register("router:main", mapRoutes());
  },
  needs: ["controller:modal"]
});

QUnit.test("reorder set unique position number", function(assert) {
  const store = createStore();

  const categories = [];
  for (let i = 0; i < 3; ++i) {
    categories.push(store.createRecord("category", { id: i, position: 0 }));
  }

  const site = EmberObject.create({ categories: categories });
  const reorderCategoriesController = this.subject({ site });

  reorderCategoriesController.reorder();

  reorderCategoriesController
    .get("categoriesOrdered")
    .forEach((category, index) => {
      assert.equal(category.get("position"), index);
    });
});

QUnit.test(
  "reorder places subcategories after their parent categories, while maintaining the relative order",
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

    const site = EmberObject.create({ categories: categories });
    const reorderCategoriesController = this.subject({ site });

    reorderCategoriesController.reorder();

    assert.deepEqual(
      reorderCategoriesController.get("categoriesOrdered").mapBy("slug"),
      expectedOrderSlugs
    );
  }
);

QUnit.test(
  "changing the position number of a category should place it at given position",
  function(assert) {
    const store = createStore();

    const elem1 = store.createRecord("category", {
      id: 1,
      position: 0,
      slug: "foo"
    });

    const elem2 = store.createRecord("category", {
      id: 2,
      position: 1,
      slug: "bar"
    });

    const elem3 = store.createRecord("category", {
      id: 3,
      position: 2,
      slug: "test"
    });

    const categories = [elem1, elem2, elem3];
    const site = EmberObject.create({ categories: categories });
    const reorderCategoriesController = this.subject({ site });

    reorderCategoriesController.actions.change.call(
      reorderCategoriesController,
      elem1,
      { target: { value: "2" } }
    );

    assert.deepEqual(
      reorderCategoriesController.get("categoriesOrdered").mapBy("slug"),
      ["test", "bar", "foo"]
    );
  }
);

QUnit.test(
  "changing the position number of a category should place it at given position and respect children",
  function(assert) {
    const store = createStore();

    const elem1 = store.createRecord("category", {
      id: 1,
      position: 0,
      slug: "foo"
    });

    const child1 = store.createRecord("category", {
      id: 4,
      position: 1,
      slug: "foochild",
      parent_category_id: 1
    });

    const elem2 = store.createRecord("category", {
      id: 2,
      position: 2,
      slug: "bar"
    });

    const elem3 = store.createRecord("category", {
      id: 3,
      position: 3,
      slug: "test"
    });

    const categories = [elem1, child1, elem2, elem3];
    const site = EmberObject.create({ categories: categories });
    const reorderCategoriesController = this.subject({ site });

    reorderCategoriesController.actions.change.call(
      reorderCategoriesController,
      elem1,
      { target: { value: 3 } }
    );

    assert.deepEqual(
      reorderCategoriesController.get("categoriesOrdered").mapBy("slug"),
      ["test", "bar", "foo", "foochild"]
    );
  }
);

QUnit.test(
  "changing the position through click on arrow of a category should place it at given position and respect children",
  function(assert) {
    const store = createStore();

    const elem1 = store.createRecord("category", {
      id: 1,
      position: 0,
      slug: "foo"
    });

    const child1 = store.createRecord("category", {
      id: 4,
      position: 1,
      slug: "foochild",
      parent_category_id: 1
    });

    const child2 = store.createRecord("category", {
      id: 5,
      position: 2,
      slug: "foochildchild",
      parent_category_id: 4
    });

    const elem2 = store.createRecord("category", {
      id: 2,
      position: 3,
      slug: "bar"
    });

    const elem3 = store.createRecord("category", {
      id: 3,
      position: 4,
      slug: "test"
    });

    const categories = [elem1, child1, child2, elem2, elem3];
    const site = EmberObject.create({ categories: categories });
    const reorderCategoriesController = this.subject({ site });

    reorderCategoriesController.reorder();

    reorderCategoriesController.actions.moveDown.call(
      reorderCategoriesController,
      elem1
    );

    assert.deepEqual(
      reorderCategoriesController.get("categoriesOrdered").mapBy("slug"),
      ["bar", "foo", "foochild", "foochildchild", "test"]
    );
  }
);
