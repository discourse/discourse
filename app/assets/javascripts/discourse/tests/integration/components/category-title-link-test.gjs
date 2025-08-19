import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import CategoryTitleLink from "discourse/components/category-title-link";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Category Title Link", function (hooks) {
  setupRenderingTest(hooks);

  const testCategories = [
    Category.create({
      id: 0,
      name: "category one",
      description: "first test category",
    }),
    Category.create({
      id: 1,
      name: "category two",
      description: "second test category with icon",
      style_type: "icon",
      icon: "heart",
    }),
    Category.create({
      id: 2,
      name: "category three",
      description: "third test category with icon",
      style_type: "emoji",
      emoji: "face_savoring_food",
      uploaded_logo: {
        url: "/images/avatar.png",
      },
    }),
  ];

  test("Shows title, icon/emoji, and logo when switching categories in styled mode", async function (assert) {
    const testState = new (class {
      @tracked category = testCategories[0];
    })();

    await render(
      <template>
        <CategoryTitleLink
          @category={{testState.category}}
          @unstyled={{false}}
        />
      </template>
    );

    assert.dom(".category-title-link").hasText(testCategories[0].name);

    testState.category = testCategories[1];
    await settled();
    assert
      .dom(".category-title-link .badge-category svg")
      .hasClass("d-icon-heart", "shows icon");
    assert
      .dom(".category-title-link")
      .hasText(testCategories[1].name, "shows title");

    testState.category = testCategories[2];
    await settled();
    assert
      .dom(".category-title-link .category-logo img")
      .hasAttribute("src", "/images/avatar.png", "shows logo");
    assert
      .dom(".category-title-link .badge-category img.emoji")
      .hasAttribute(
        "src",
        new RegExp("^.*face_savoring_food.*$"),
        "shows emoji"
      );
    assert
      .dom(".category-title-link")
      .hasText(testCategories[2].name, "shows title");
  });

  test("Shows title only when switching categories in unstyled mode", async function (assert) {
    const testState = new (class {
      @tracked category = testCategories[0];
    })();

    await render(
      <template>
        <CategoryTitleLink
          @category={{testState.category}}
          @unstyled={{true}}
        />
      </template>
    );
    assert
      .dom(".category-title-link")
      .hasText(testCategories[0].name, "shows title");

    testState.category = testCategories[1];
    await settled();
    assert
      .dom(".category-title-link .badge-category svg")
      .doesNotExist("does not show icon");
    assert
      .dom(".category-title-link")
      .hasText(testCategories[1].name, "shows title");

    testState.category = testCategories[2];
    await settled();
    assert
      .dom(".category-title-link .badge-category img.emoji")
      .doesNotExist("does not show emoji");
    assert
      .dom(".category-title-link")
      .hasText(testCategories[2].name, "shows title");
  });

  test("Respects the tagName attribute", async function (assert) {
    const testState = new (class {
      @tracked category = testCategories[0];
    })();

    await render(
      <template>
        <CategoryTitleLink @category={{testState.category}} />
      </template>
    );

    assert.dom("h3:has(> .category-title-link)").exists(); // defaults to h3

    await render(
      <template>
        <CategoryTitleLink @category={{testState.category}} @tagName="h1" />
      </template>
    );

    assert.dom("h1:has(> .category-title-link)").exists();

    await render(
      <template>
        <CategoryTitleLink @category={{testState.category}} @tagName="span" />
      </template>
    );

    assert.dom("span:has(> .category-title-link)").exists();
  });
});
