import createStore from "discourse/tests/helpers/create-store";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

discourseModule("Unit | Controller | reorder-categories", function () {
  test("reorder set unique position number", function (assert) {
    const store = createStore();

    const categories = [];
    for (let i = 0; i < 3; ++i) {
      categories.push(store.createRecord("category", { id: i, position: 0 }));
    }

    const controller = this.getController("reorder-categories", {
      site: { categories },
    });
    controller.reorder();

    controller.get("categoriesOrdered").forEach((category, index) => {
      assert.equal(category.get("position"), index);
    });
  });

  test("reorder places subcategories after their parent categories, while maintaining the relative order", function (assert) {
    const store = createStore();

    const parent = store.createRecord("category", {
      id: 1,
      position: 1,
      slug: "parent",
    });
    const child1 = store.createRecord("category", {
      id: 2,
      position: 3,
      slug: "child1",
      parent_category_id: 1,
    });
    const child2 = store.createRecord("category", {
      id: 3,
      position: 0,
      slug: "child2",
      parent_category_id: 1,
    });
    const other = store.createRecord("category", {
      id: 4,
      position: 2,
      slug: "other",
    });

    const expectedOrderSlugs = ["parent", "child2", "child1", "other"];
    const controller = this.getController("reorder-categories", {
      site: { categories: [child2, parent, other, child1] },
    });
    controller.reorder();

    assert.deepEqual(
      controller.get("categoriesOrdered").mapBy("slug"),
      expectedOrderSlugs
    );
  });

  test("changing the position number of a category should place it at given position", function (assert) {
    const store = createStore();

    const elem1 = store.createRecord("category", {
      id: 1,
      position: 0,
      slug: "foo",
    });

    const elem2 = store.createRecord("category", {
      id: 2,
      position: 1,
      slug: "bar",
    });

    const elem3 = store.createRecord("category", {
      id: 3,
      position: 2,
      slug: "test",
    });

    const controller = this.getController("reorder-categories", {
      site: { categories: [elem1, elem2, elem3] },
    });

    // Move category 'foo' from position 0 to position 2
    controller.send("change", elem1, { target: { value: "2" } });

    assert.deepEqual(controller.get("categoriesOrdered").mapBy("slug"), [
      "bar",
      "test",
      "foo",
    ]);
  });

  test("changing the position number of a category should place it at given position and respect children", function (assert) {
    const store = createStore();

    const elem1 = store.createRecord("category", {
      id: 1,
      position: 0,
      slug: "foo",
    });

    const child1 = store.createRecord("category", {
      id: 4,
      position: 1,
      slug: "foochild",
      parent_category_id: 1,
    });

    const elem2 = store.createRecord("category", {
      id: 2,
      position: 2,
      slug: "bar",
    });

    const elem3 = store.createRecord("category", {
      id: 3,
      position: 3,
      slug: "test",
    });

    const controller = this.getController("reorder-categories", {
      site: { categories: [elem1, child1, elem2, elem3] },
    });

    controller.send("change", elem1, { target: { value: 3 } });

    assert.deepEqual(controller.get("categoriesOrdered").mapBy("slug"), [
      "bar",
      "test",
      "foo",
      "foochild",
    ]);
  });

  test("changing the position through click on arrow of a category should place it at given position and respect children", function (assert) {
    const store = createStore();

    const child2 = store.createRecord("category", {
      id: 105,
      position: 2,
      slug: "foochildchild",
      parent_category_id: 104,
    });

    const child1 = store.createRecord("category", {
      id: 104,
      position: 1,
      slug: "foochild",
      parent_category_id: 101,
      subcategories: [child2],
    });

    const elem1 = store.createRecord("category", {
      id: 101,
      position: 0,
      slug: "foo",
      subcategories: [child1],
    });

    const elem2 = store.createRecord("category", {
      id: 102,
      position: 3,
      slug: "bar",
    });

    const elem3 = store.createRecord("category", {
      id: 103,
      position: 4,
      slug: "test",
    });

    const controller = this.getController("reorder-categories", {
      site: { categories: [elem1, child1, child2, elem2, elem3] },
    });

    controller.reorder();

    controller.send("moveDown", elem1);

    assert.deepEqual(controller.get("categoriesOrdered").mapBy("slug"), [
      "bar",
      "foo",
      "foochild",
      "foochildchild",
      "test",
    ]);
  });
});
