import { getOwner } from "@ember/application";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Component | reorder-categories", function (hooks) {
  setupTest(hooks);

  test("reorder set unique position number", function (assert) {
    const component = this.owner
      .factoryFor("component:modal/reorder-categories")
      .create();
    const store = getOwner(this).lookup("service:store");

    const site = getOwner(this).lookup("service:site");
    site.set("categories", [
      store.createRecord("category", { id: 1, position: 0 }),
      store.createRecord("category", { id: 2, position: 0 }),
      store.createRecord("category", { id: 3, position: 0 }),
    ]);

    component.reorder();

    component.sortedEntries.forEach((category, index) => {
      assert.strictEqual(category.position, index);
    });
  });

  test("reorder places subcategories after their parent categories, while maintaining the relative order", function (assert) {
    const component = this.owner
      .factoryFor("component:modal/reorder-categories")
      .create();
    const store = getOwner(this).lookup("service:store");

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
    const site = getOwner(this).lookup("service:site");
    site.set("categories", [child2, parent, other, child1]);

    component.reorder();

    assert.deepEqual(
      component.sortedEntries.mapBy("category.slug"),
      expectedOrderSlugs
    );
  });

  test("changing the position number of a category should place it at given position", function (assert) {
    const component = this.owner
      .factoryFor("component:modal/reorder-categories")
      .create();
    const store = getOwner(this).lookup("service:store");

    const foo = store.createRecord("category", {
      id: 1,
      position: 0,
      slug: "foo",
    });

    const bar = store.createRecord("category", {
      id: 2,
      position: 1,
      slug: "bar",
    });

    const baz = store.createRecord("category", {
      id: 3,
      position: 2,
      slug: "baz",
    });

    const site = getOwner(this).lookup("service:site");
    site.set("categories", [foo, bar, baz]);

    // Move category 'foo' from position 0 to position 2
    const entry = component.sortedEntries.findBy("category.slug", "foo");
    component.change(entry, "2");

    assert.deepEqual(component.sortedEntries.mapBy("category.slug"), [
      "bar",
      "baz",
      "foo",
    ]);
  });

  test("changing the position number of a category should place it at given position and respect children", function (assert) {
    const component = this.owner
      .factoryFor("component:modal/reorder-categories")
      .create();
    const store = getOwner(this).lookup("service:store");

    const foo = store.createRecord("category", {
      id: 1,
      position: 0,
      slug: "foo",
    });

    const fooChild = store.createRecord("category", {
      id: 4,
      position: 1,
      slug: "foo-child",
      parent_category_id: 1,
    });

    const bar = store.createRecord("category", {
      id: 2,
      position: 2,
      slug: "bar",
    });

    const baz = store.createRecord("category", {
      id: 3,
      position: 3,
      slug: "baz",
    });

    const site = getOwner(this).lookup("service:site");
    site.set("categories", [foo, fooChild, bar, baz]);

    const entry = component.sortedEntries.findBy("category.slug", "foo");
    component.change(entry, "3");

    assert.deepEqual(component.sortedEntries.mapBy("category.slug"), [
      "bar",
      "baz",
      "foo",
      "foo-child",
    ]);
  });

  test("changing the position through click on arrow of a category should place it at given position and respect children", function (assert) {
    const component = this.owner
      .factoryFor("component:modal/reorder-categories")
      .create();
    const store = getOwner(this).lookup("service:store");

    const fooChildChild = store.createRecord("category", {
      id: 105,
      position: 2,
      slug: "foo-child-child",
      parent_category_id: 104,
    });

    const fooChild = store.createRecord("category", {
      id: 104,
      position: 1,
      slug: "foo-child",
      parent_category_id: 101,
      subcategories: [fooChildChild],
    });

    const foo = store.createRecord("category", {
      id: 101,
      position: 0,
      slug: "foo",
      subcategories: [fooChild],
    });

    const bar = store.createRecord("category", {
      id: 102,
      position: 3,
      slug: "bar",
    });

    const baz = store.createRecord("category", {
      id: 103,
      position: 4,
      slug: "baz",
    });

    const site = getOwner(this).lookup("service:site");
    site.set("categories", [foo, fooChild, fooChildChild, bar, baz]);

    component.reorder();

    const entry = component.sortedEntries.findBy("category.slug", "foo");
    component.move(entry, 1);

    assert.deepEqual(component.sortedEntries.mapBy("category.slug"), [
      "bar",
      "foo",
      "foo-child",
      "foo-child-child",
      "baz",
    ]);
  });
});
