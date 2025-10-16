import { render, settled } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import CategoryList from "discourse/models/category-list";

module("Integration | Component | CategoryList", function (hooks) {
  setupRenderingTest(hooks);

  test("UI updates when CategoryList array and properties change", async function (assert) {
    const categories = [
      { id: 1, name: "Cat 1" },
      { id: 2, name: "Cat 2" },
    ];
    this.categoryList = CategoryList.create({ categories });

    await render(
      <template>
        <div data-test-category-list>
          <ul>
            {{#each this.categoryList as |cat|}}
              <li data-test-category>{{cat.name}}</li>
            {{/each}}
          </ul>
          <div data-test-page>Page: {{this.categoryList.page}}</div>
          <div data-test-fetched-last-page>Fetched Last Page:
            {{this.categoryList.fetchedLastPage}}</div>
        </div>
      </template>
    );

    assert
      .dom("[data-test-category]")
      .exists({ count: 2 }, "renders initial categories");
    assert.dom("[data-test-category]:nth-child(1)").hasText("Cat 1");
    assert.dom("[data-test-category]:nth-child(2)").hasText("Cat 2");

    // Add a category
    this.categoryList.push({ id: 3, name: "Cat 3" });
    await settled();
    assert
      .dom("[data-test-category]")
      .exists({ count: 3 }, "renders after adding category");
    assert.dom("[data-test-category]:nth-child(3)").hasText("Cat 3");

    // Remove a category
    this.categoryList.splice(0, 1);
    await settled();
    assert
      .dom("[data-test-category]")
      .exists({ count: 2 }, "renders after removing category");
    assert.dom("[data-test-category]:nth-child(1)").hasText("Cat 2");

    // Change page property
    this.categoryList.page = 2;
    await settled();
    assert.dom("[data-test-page]").hasText("Page: 2");

    // Change fetchedLastPage property
    this.categoryList.fetchedLastPage = true;
    await settled();
    assert
      .dom("[data-test-fetched-last-page]")
      .hasText("Fetched Last Page: true");
  });
});
