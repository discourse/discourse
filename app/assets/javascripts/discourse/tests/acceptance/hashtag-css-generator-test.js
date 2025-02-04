import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Hashtag CSS Generator", function (needs) {
  needs.user();

  needs.site({
    categories: [
      { id: 1, color: "ff0000", text_color: "ffffff", name: "category1" },
      { id: 2, color: "333", text_color: "ffffff", name: "category2" },
      {
        id: 4,
        color: "2B81AF",
        text_color: "ffffff",
        parent_category_id: 1,
        name: "category3",
      },
    ],
  });

  test("classes are generated", async function (assert) {
    await visit("/");
    const cssTag = document.querySelector("style#hashtag-css-generator");
    assert
      .dom(cssTag)
      .hasHtml(
        ".hashtag-category-badge { background-color: var(--primary-medium); }\n" +
          ".hashtag-color--category-1 { background-color: #ff0000; }\n" +
          ".hashtag-color--category-2 { background-color: #333; }\n" +
          ".hashtag-color--category-4 { background: linear-gradient(-90deg, #2B81AF 50%, #ff0000 50%); }"
      );
  });
});
