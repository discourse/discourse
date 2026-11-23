import { array } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscoveryFilterBar from "discourse/components/discovery/filter-bar";
import DMenus from "discourse/float-kit/components/d-menus";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | Discovery | FilterBar", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const store = this.owner.lookup("service:store");
    this.parent = store.createRecord("category", {
      id: 501,
      name: "Feedback",
      slug: "feedback",
    });
    this.site.categories = [...this.site.categories, this.parent];

    this.tag = store.createRecord("tag", {
      id: 7,
      name: "ember",
      slug: "ember",
    });
    this.routeTo = sinon.stub(DiscourseURL, "routeTo");
  });

  test("shows the list's category and tags as tokens", async function (assert) {
    const subcategory = this.owner
      .lookup("service:site")
      .categoriesList.find((c) => c.parentCategory);
    const path = `${subcategory.parentCategory.slug}:${subcategory.slug}`;

    await render(
      <template>
        <DiscoveryFilterBar
          @additionalTags={{array "rails"}}
          @category={{subcategory}}
          @noSubcategories={{true}}
          @tag={{this.tag}}
        />
      </template>
    );

    assert
      .dom(".filter-navigation-token[data-filter='category']")
      .hasAttribute(
        "data-token",
        `=category:${path}`,
        "subcategories use the parent path; no subcategories is `=`"
      );
    assert
      .dom(".filter-navigation-token[data-token='tag:ember+rails']")
      .exists("tag intersections become one token");
  });

  test("removing every token returns to the plain list", async function (assert) {
    await render(
      <template>
        <DiscoveryFilterBar @category={{this.parent}} @filterType="new" />
      </template>
    );

    await click(".filter-navigation-token__remove");

    assert.true(this.routeTo.calledWith("/new"));
  });

  test("a category and tag stay on the category's tag list", async function (assert) {
    await render(
      <template>
        <DiscoveryFilterBar
          @category={{this.parent}}
          @filterType="latest"
          @tag={{this.tag}}
        />
        <DMenus />
      </template>
    );

    await click(
      ".filter-navigation-token[data-filter='category'] .filter-navigation-token__remove"
    );

    assert.true(
      this.routeTo.calledWith("/tag/ember/7/l/latest"),
      "keeps the canonical tag URL"
    );
  });

  test("filters a list URL can't express open the filter page", async function (assert) {
    pretender.get("/filter/options.json", () =>
      response({
        options: [
          { name: "category:", type: "category", priority: 1 },
          { name: "tag:", type: "tag", priority: 1 },
          { name: "status:", priority: 1 },
          { name: "status:open", description: "Open topics" },
        ],
      })
    );

    await render(
      <template>
        <DiscoveryFilterBar @category={{this.parent}} @tag={{this.tag}} />
        <DMenus />
      </template>
    );

    await click(".filter-navigation-builder__add");
    await click(
      ".filter-navigation-builder__menu .filter-navigation__tip-item[data-filter='status:']"
    );
    await click(
      ".filter-navigation-token__editor .filter-navigation__tip-item"
    );

    assert.true(
      this.routeTo.calledWith(
        `/filter?q=${encodeURIComponent("category:feedback tag:ember status:open")}`
      )
    );
  });
});
