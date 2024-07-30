import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReorderCategories from "discourse/components/modal/reorder-categories";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | ReorderCategories", function (hooks) {
  setupRenderingTest(hooks);

  test("shows categories in order", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const site = getOwner(this).lookup("service:site");
    site.set("categories", [
      store.createRecord("category", { id: 1, position: 0 }),
      store.createRecord("category", { id: 2, position: 0 }),
      store.createRecord("category", { id: 3, position: 0 }),
    ]);

    await render(<template><ReorderCategories @inline={{true}} /></template>);

    assert.dom("tr:nth-child(1)").hasAttribute("data-category-id", "1");
    assert.dom("tr:nth-child(2)").hasAttribute("data-category-id", "2");
    assert.dom("tr:nth-child(3)").hasAttribute("data-category-id", "3");
  });

  test("reorders subcategories after their parent categories, while maintaining the relative order", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const parent = store.createRecord("category", {
      id: 1,
      position: 1,
      name: "parent",
    });
    const child1 = store.createRecord("category", {
      id: 2,
      position: 3,
      name: "child1",
      parent_category_id: 1,
    });
    const child2 = store.createRecord("category", {
      id: 3,
      position: 0,
      name: "child2",
      parent_category_id: 1,
    });
    const other = store.createRecord("category", {
      id: 4,
      position: 2,
      name: "other",
    });
    const site = getOwner(this).lookup("service:site");
    site.set("categories", [child2, parent, other, child1]);

    await render(<template><ReorderCategories @inline={{true}} /></template>);

    assert.dom("tr:nth-child(1) .badge-category__name").hasText("parent");
    assert.dom("tr:nth-child(2) .badge-category__name").hasText("child2");
    assert.dom("tr:nth-child(3) .badge-category__name").hasText("child1");
    assert.dom("tr:nth-child(4) .badge-category__name").hasText("other");
  });

  test("changing the position number of a category should place it at given position", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const foo = store.createRecord("category", {
      id: 1,
      position: 0,
      name: "foo",
    });
    const bar = store.createRecord("category", {
      id: 2,
      position: 1,
      name: "bar",
    });
    const baz = store.createRecord("category", {
      id: 3,
      position: 2,
      name: "baz",
    });
    const site = getOwner(this).lookup("service:site");
    site.set("categories", [foo, bar, baz]);

    await render(<template><ReorderCategories @inline={{true}} /></template>);

    // Move category 'foo' from position 0 to position 2
    await fillIn("tr:nth-child(1) input", "2");

    assert.dom("tr:nth-child(1) .badge-category__name").hasText("bar");
    assert.dom("tr:nth-child(2) .badge-category__name").hasText("baz");
    assert.dom("tr:nth-child(3) .badge-category__name").hasText("foo");
  });

  test("changing the position number of a category should place it at given position and respect children", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const foo = store.createRecord("category", {
      id: 1,
      position: 0,
      name: "foo",
    });
    const fooChild = store.createRecord("category", {
      id: 4,
      position: 1,
      name: "foo-child",
      parent_category_id: 1,
    });
    const bar = store.createRecord("category", {
      id: 2,
      position: 2,
      name: "bar",
    });
    const baz = store.createRecord("category", {
      id: 3,
      position: 3,
      name: "baz",
    });
    const site = getOwner(this).lookup("service:site");
    site.set("categories", [foo, fooChild, bar, baz]);

    await render(<template><ReorderCategories @inline={{true}} /></template>);
    await fillIn("tr:nth-child(1) input", "3");

    assert.dom("tr:nth-child(1) .badge-category__name").hasText("bar");
    assert.dom("tr:nth-child(2) .badge-category__name").hasText("baz");
    assert.dom("tr:nth-child(3) .badge-category__name").hasText("foo");
    assert.dom("tr:nth-child(4) .badge-category__name").hasText("foo-child");
  });

  test("changing the position through click on arrow of a category should place it at given position and respect children", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const fooChildChild = store.createRecord("category", {
      id: 105,
      position: 2,
      name: "foo-child-child",
      parent_category_id: 104,
    });
    const fooChild = store.createRecord("category", {
      id: 104,
      position: 1,
      name: "foo-child",
      parent_category_id: 101,
    });
    const foo = store.createRecord("category", {
      id: 101,
      position: 0,
      name: "foo",
    });
    const bar = store.createRecord("category", {
      id: 102,
      position: 3,
      name: "bar",
    });
    const baz = store.createRecord("category", {
      id: 103,
      position: 4,
      name: "baz",
    });
    const site = getOwner(this).lookup("service:site");
    site.set("categories", [foo, fooChild, fooChildChild, bar, baz]);

    await render(<template><ReorderCategories @inline={{true}} /></template>);
    await click("tr:nth-child(1) button.move-down");

    assert.dom("tr:nth-child(1) .badge-category__name").hasText("bar");
    assert.dom("tr:nth-child(2) .badge-category__name").hasText("foo");
    assert.dom("tr:nth-child(3) .badge-category__name").hasText("foo-child");
    assert
      .dom("tr:nth-child(4) .badge-category__name")
      .hasText("foo-child-child");
    assert.dom("tr:nth-child(5) .badge-category__name").hasText("baz");
  });
});
