import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("category-boxes-url transformer", function (needs) {
  needs.settings({
    desktop_category_page_style: "categories_boxes",
  });

  test("transforms the category box URL", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "category-boxes-url",
        ({ value, context }) => {
          if (context.category.slug === "bug") {
            return "https://example.com/bug-tracker";
          }
          return value;
        }
      );
    });

    await visit("/categories");

    assert
      .dom(
        ".category-box[data-category-id='1'] a.parent-box-link[href='https://example.com/bug-tracker']"
      )
      .exists("it transforms the category URL for matched slug");

    assert
      .dom(
        ".category-box[data-category-id='1'] a.parent-box-link[target='_blank']"
      )
      .exists("it adds target=_blank for transformed URLs");

    assert
      .dom(
        ".category-box[data-category-id='1'] a.parent-box-link[rel='noopener noreferrer']"
      )
      .exists("it adds rel=noopener noreferrer for transformed URLs");

    assert
      .dom(".category-box[data-category-id='2'] a.parent-box-link")
      .doesNotHaveAttribute(
        "target",
        "it does not add target for non-transformed URLs"
      );

    assert
      .dom(".category-box[data-category-id='2'] a.parent-box-link")
      .doesNotHaveAttribute(
        "rel",
        "it does not add rel for non-transformed URLs"
      );
  });
});
