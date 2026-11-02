import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BreadCrumbs from "discourse/components/bread-crumbs";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | BreadCrumbs", function (hooks) {
  setupRenderingTest(hooks);

  test("shows lazy loaded search results in the category drop", async function (assert) {
    this.site.set("lazy_load_categories", true);

    pretender.post("/categories/search", () =>
      response({
        categories: [{ id: 9999, name: "Newcomer", slug: "newcomer" }],
        ancestors: [],
        categories_count: 1,
      })
    );

    const site = this.site;

    await render(
      <template><BreadCrumbs @categories={{site.categoriesList}} /></template>
    );

    const categoryDrop = selectKit(".category-breadcrumb__category-selector");
    await categoryDrop.expand();
    await categoryDrop.fillInFilter("new");

    assert
      .dom(categoryDrop.rowByValue(9999).el())
      .exists("the matching category can be picked");
  });
});
